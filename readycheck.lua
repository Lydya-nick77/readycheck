--[[
* ReadyCheck - Party/Alliance ready check addon for Ashita v4 (HorizonXI).
*
* Usage:
*   /readycheck        - Sends a ready check to party chat and opens the
*                        response tracker window.
*
* How it works:
*   The sender's client broadcasts a marker message in /p chat.
*   Every party member who has this addon loaded sees a prompt window
*   with "Yes" and "No" buttons.  Their reply is sent back into /p chat
*   and the sender's tracker window colourises each name:
*     White  = no reply yet
*     Green  = ready
*     Red    = not ready
]]--

addon.name    = 'ReadyCheck'
addon.author  = 'Lydya'
addon.version = '0.1.0'
addon.desc    = 'Sends a party-wide ready check and tracks responses.'

require('common')
local bit   = require('bit')
local ui    = require('ui')

-- ──────────────────────────────────────────────────────────────────────────────
-- Marker strings (plain ASCII so string.find without regex is safe)
-- ──────────────────────────────────────────────────────────────────────────────
local TRIGGER_MSG = 'Are you ready? Sent by ReadyCheck'
local YES_MSG     = 'I am ready - Sent by ReadyCheck'
local NO_MSG      = 'I am not ready - Sent by ReadyCheck'

-- Chat modes that carry party / alliance messages
local PARTY_MODES = { [13] = true, [215] = true }

-- ──────────────────────────────────────────────────────────────────────────────
-- Runtime state
-- ──────────────────────────────────────────────────────────────────────────────
local state = {
    -- Checker window (only shown to the player who initiated the ready check)
    checker_open     = { false },   -- ImGui open flag table
    checker_deadline = nil,         -- os.clock() deadline matching the 30s responder timeout
    checker_summary_sent = false,   -- true once the sender summary has been announced
    party_members    = {},          -- { name=string, status=nil|'ready'|'not_ready' }
    is_checker       = false,       -- true while WE are the active checker

    -- Responder prompt (shown to all OTHER players when they see the trigger)
    prompt_open     = { false },   -- ImGui open flag table
    prompt_answered = false,       -- true after Yes/No clicked (prevents double-send)
    prompt_deadline = nil,         -- os.clock() deadline for auto-No timeout
}

-- ──────────────────────────────────────────────────────────────────────────────
-- Helpers
-- ──────────────────────────────────────────────────────────────────────────────

--- Return the local player's name from party memory (slot 0 is always self).
local function get_player_name()
    local party = AshitaCore:GetMemoryManager():GetParty()
    if party == nil then return nil end
    local name = party:GetMemberName(0)
    if name == nil or name == '' then return nil end
    return name
end

--- Collect all active party / alliance member names from memory (slots 0-17).
local function collect_party_members()
    local members = {}
    local party = AshitaCore:GetMemoryManager():GetParty()
    if party == nil then return members end
    for i = 0, 17 do
        if party:GetMemberIsActive(i) == 1 then
            local name = party:GetMemberName(i)
            if name ~= nil and name ~= '' then
                table.insert(members, { name = name, status = nil })
            end
        end
    end
    return members
end

--- Strip FFXI / Ashita inline colour-code pairs (\x1E<byte> and \x1F<byte>)
--- so that plain pattern matching is reliable.
local function strip_color_codes(text)
    return (text:gsub('\x1E.', ''):gsub('\x1F.', ''))
end

--- Try to extract "SenderName" from a message formatted as "SenderName: body".
--- Returns sender (string|nil), body (string).
local function parse_sender(text)
    -- Strip colour codes first so the colon separator is visible.
    local clean = strip_color_codes(text)
    -- Strip any leading timestamp added by e.g. the timestamp addon: [HH:MM] or [HH:MM:SS]
    clean = clean:gsub('^%s*%[%d%d:%d%d:?%d?%d?%]%s*', '')
    local sender, body = clean:match('^([%a][%w_%-]+)%s*:%s*(.+)$')
    if sender then
        return sender, body
    end
    return nil, clean
end

--- Find a party member by name (case-insensitive) and set their status.
local function update_member_status(name, status)
    local lower = name:lower()
    for _, member in ipairs(state.party_members) do
        if member.name:lower() == lower then
            member.status = status
            return
        end
    end
end

--- Queue a /p message through Ashita's chat manager.
local function send_party(msg)
    AshitaCore:GetChatManager():QueueCommand(-1, '/p ' .. msg)
end

local function everyone_answered()
    for _, member in ipairs(state.party_members) do
        if member.status == nil then
            return false
        end
    end
    return true
end

local function mark_unanswered_not_ready()
    for _, member in ipairs(state.party_members) do
        if member.status == nil then
            member.status = 'not_ready'
        end
    end
end

local function get_not_ready_names()
    local names = {}
    for _, member in ipairs(state.party_members) do
        if member.status ~= 'ready' then
            table.insert(names, member.name)
        end
    end
    return names
end

local function announce_ready_check_summary()
    if state.checker_summary_sent then
        return
    end

    local not_ready_names = get_not_ready_names()
    if #not_ready_names == 0 then
        send_party('Players not ready: none')
    else
        send_party('Players not ready: ' .. table.concat(not_ready_names, ', '))
    end

    state.checker_summary_sent = true
end

local function close_checker()
    state.checker_open[1] = false
    state.is_checker = false
    state.party_members = {}
    state.checker_deadline = nil
    state.checker_summary_sent = false
end

local function answer_yes()
    state.prompt_answered = true
    state.prompt_open[1] = false
    state.prompt_deadline = nil
    send_party(YES_MSG)
end

local function answer_no()
    state.prompt_answered = true
    state.prompt_open[1] = false
    state.prompt_deadline = nil
    send_party(NO_MSG)
end

--- Begin a new ready check: snapshot the party, reset state, broadcast trigger.
local function start_ready_check()
    state.is_checker       = true
    state.party_members    = collect_party_members()
    state.checker_open[1]  = true
    state.checker_deadline = os.clock() + 30
    state.checker_summary_sent = false
    -- Mark ourselves as ready immediately
    local my_name = get_player_name()
    if my_name then
        update_member_status(my_name, 'ready')
    end
    ashita.misc.play_sound(addon.path .. 'sound\\levelup2.wav')
    send_party(TRIGGER_MSG)
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Event: /readycheck command
-- ──────────────────────────────────────────────────────────────────────────────
ashita.events.register('command', 'readycheck_command_cb', function(e)
    local args = e.command:args()
    if #args == 0 or args[1] ~= '/readycheck' then return end
    e.blocked = true
    start_ready_check()
end)

-- ──────────────────────────────────────────────────────────────────────────────
-- Event: incoming text
-- ──────────────────────────────────────────────────────────────────────────────
ashita.events.register('text_in', 'readycheck_text_in_cb', function(e)
    -- Only care about party / alliance chat
    local mode = bit.band(e.mode_modified or e.mode or 0, 0x000000FF)
    if not PARTY_MODES[mode] then return end

    local raw = e.message_modified or e.message or ''

    -- ── Detect the ready-check trigger ──────────────────────────────────────
    if raw:find(TRIGGER_MSG, 1, true) then
        -- If WE are the checker we triggered this ourselves – skip the prompt.
        if not state.is_checker then
            state.prompt_answered = false
            state.prompt_open[1]  = true
            state.prompt_deadline = os.clock() + 30
            ashita.misc.play_sound(addon.path .. 'sound\\levelup2.wav')
        end
        return
    end

    -- ── Detect YES response ─────────────────────────────────────────────────
    if raw:find(YES_MSG, 1, true) then
        if state.checker_open[1] then
            local sender = parse_sender(raw)
            if sender then
                update_member_status(sender, 'ready')
            end
        end
        return
    end

    -- ── Detect NO response ──────────────────────────────────────────────────
    if raw:find(NO_MSG, 1, true) then
        if state.checker_open[1] then
            local sender = parse_sender(raw)
            if sender then
                update_member_status(sender, 'not_ready')
            end
        end
        return
    end
end)

-- ──────────────────────────────────────────────────────────────────────────────
-- Event: d3d_present – render ImGui windows every frame
-- ──────────────────────────────────────────────────────────────────────────────
ashita.events.register('d3d_present', 'readycheck_present_cb', function()
    -- ── Responder prompt: auto-timeout after 30 seconds ────────────────────
    if state.prompt_open[1] and not state.prompt_answered
            and state.prompt_deadline ~= nil and os.clock() >= state.prompt_deadline then
        state.prompt_open[1]   = false
        state.prompt_deadline  = nil
    end

    if state.checker_open[1] and not state.checker_summary_sent then
        local checker_timed_out = state.checker_deadline ~= nil and os.clock() >= state.checker_deadline
        if checker_timed_out then
            mark_unanswered_not_ready()
            announce_ready_check_summary()
        elseif everyone_answered() then
            announce_ready_check_summary()
        end
    end
    ui.render(state, {
        answer_yes = answer_yes,
        answer_no = answer_no,
        close_checker = close_checker,
    })

    if not state.checker_open[1] then
        close_checker()
    end
end)
