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
addon.version = '0.3.0'
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

-- Sound settings
local SOUND_FILE = addon.path .. 'sound\\levelup2.wav'
local SOUND_ON_CHECKER = true   -- Play sound when starting a ready check
local SOUND_ON_PROMPT = true    -- Play sound when receiving a ready-check prompt

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
    party_members    = {},          -- { name, name_lower, status, job, party }
    is_checker       = false,       -- true while WE are the active checker
    pending_count    = 0,           -- number of members with status == nil

    -- Responder prompt (shown to all OTHER players when they see the trigger)
    prompt_open     = { false },   -- ImGui open flag table
    prompt_answered = false,       -- true after Yes/No clicked (prevents double-send)
    prompt_deadline = nil,         -- os.clock() deadline for auto-close timeout
    prompt_sender   = nil,         -- name of the player who initiated the check
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
                table.insert(members, { name = name, name_lower = name:lower(), status = nil, job = party:GetMemberMainJob(i), slot = i, party = math.floor(i / 6) + 1 })
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
    -- Strip any leading mode/channel markers used by some chat addons: |2|...
    clean = clean:gsub('^%s*|%d+|%s*', '')
    -- Strip any leading timestamp added by e.g. the timestamp addon: [HH:MM] or [HH:MM:SS]
    clean = clean:gsub('^%s*%[%d%d:%d%d:?%d?%d?%]%s*', '')

    -- Common chat render format: <SenderName> body
    local sender, body = clean:match('^<([%a][%w_%-]+)>%s*(.+)$')
    if sender then
        return sender, body
    end

    -- Alternate chat render format: (SenderName) body
    sender, body = clean:match('^%(([%a][%w_%-]+)%)%s*(.+)$')
    if sender then
        return sender, body
    end

    -- Fallback format: SenderName: body
    sender, body = clean:match('^([%a][%w_%-]+)%s*:%s*(.+)$')
    if sender then
        return sender, body
    end
    return nil, clean
end

local function normalize_chat_tokens(text)
    local s = strip_color_codes(text or ''):lower()
    s = s:gsub('^%s*|%d+|%s*', ''):gsub('^%s*%[%d%d:%d%d:?%d?%d?%]%s*', '')
    s = s:gsub('[^%w%s]', ' '):gsub('%s+', ' ')
    return s
end

local TOKEN_TRIGGER = 'are you ready sent by readycheck'
local TOKEN_YES     = 'i am ready sent by readycheck'
local TOKEN_NO      = 'i am not ready sent by readycheck'

--- Strip colour codes and chat-addon prefixes, return lowercase cleaned string.
local function clean_message(text)
    local s = strip_color_codes(text):lower()
    return s:gsub('^%s*|%d+|%s*', ''):gsub('^%s*%[%d%d:%d%d:?%d?%d?%]%s*', '')
end

--- Find a party member by name (case-insensitive) and update their status.
local function update_member_status(name, status)
    local lower = name:lower()
    for _, member in ipairs(state.party_members) do
        if member.name_lower == lower then
            if member.status == nil then
                state.pending_count = state.pending_count - 1
            end
            member.status = status
            return
        end
    end
end

local function escape_lua_pattern(s)
    return (s:gsub('([%^%$%(%)%%%.%[%]%*%+%-%?])', '%%%1'))
end

--- Best-effort sender resolution against current tracked party members.
local function resolve_sender_from_party(text)
    local clean = clean_message(text)
    for _, member in ipairs(state.party_members) do
        if clean:find('%f[%w]' .. escape_lua_pattern(member.name_lower) .. '%f[%W]') then
            return member.name
        end
    end
    return nil
end

--- Scan live party memory for a member name that appears in the raw text.
local function resolve_sender_from_live_party(text)
    local clean = clean_message(text)
    local party = AshitaCore:GetMemoryManager():GetParty()
    if party == nil then return nil end
    for i = 0, 17 do
        if party:GetMemberIsActive(i) == 1 then
            local name = party:GetMemberName(i)
            if name and name ~= '' then
                if clean:find('%f[%w]' .. escape_lua_pattern(name:lower()) .. '%f[%W]') then
                    return name
                end
            end
        end
    end
    return nil
end

local function infer_single_pending_member()
    local my_lower = get_player_name()
    my_lower = my_lower and my_lower:lower() or nil
    local found, count = nil, 0
    for _, member in ipairs(state.party_members) do
        if member.status == nil and (my_lower == nil or member.name_lower ~= my_lower) then
            found = member.name
            count = count + 1
            if count > 1 then return nil end
        end
    end
    return found
end

--- Queue a /p message through Ashita's chat manager.
local function send_party(msg)
    AshitaCore:GetChatManager():QueueCommand(-1, '/p ' .. msg)
end

local function play_readycheck_sound()
    ashita.misc.play_sound(SOUND_FILE)
end

local function everyone_answered()
    return state.pending_count == 0
end

-- Single-pass: optionally mark unanswered members not-ready, then build
-- the summary message and send it once.
local function announce_ready_check_summary(mark_unanswered)
    if state.checker_summary_sent then return end
    local names = {}
    for _, member in ipairs(state.party_members) do
        if mark_unanswered and member.status == nil then
            member.status = 'not_ready'
        end
        if member.status ~= 'ready' then
            names[#names + 1] = member.name
        end
    end
    if #names == 0 then
        send_party('Players not ready: none')
    else
        send_party('Players not ready: ' .. table.concat(names, ', '))
    end
    state.checker_summary_sent = true
end

local function close_checker()
    state.checker_open[1]      = false
    state.is_checker           = false
    state.party_members        = {}
    state.checker_deadline     = nil
    state.checker_summary_sent = false
    state.pending_count        = 0
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
    state.is_checker           = true
    state.party_members        = collect_party_members()
    state.pending_count        = #state.party_members
    state.checker_open[1]      = true
    state.checker_deadline     = os.clock() + 30
    state.checker_summary_sent = false
    local my_name = get_player_name()
    if my_name then
        update_member_status(my_name, 'ready')
    end
    if SOUND_ON_CHECKER then play_readycheck_sound() end
    send_party(TRIGGER_MSG)
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Cached handlers table – allocated once; never reallocated per frame.
-- ──────────────────────────────────────────────────────────────────────────────
local handlers = {
    answer_yes    = answer_yes,
    answer_no     = answer_no,
    close_checker = close_checker,
}

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
    local mode = bit.band(e.mode_modified or e.mode or 0, 0x000000FF)
    local raw  = e.message_modified or e.message or ''
    -- Normalize once; derive all three flags from the same string.
    local norm       = normalize_chat_tokens(raw)
    local is_trigger = norm:find(TOKEN_TRIGGER, 1, true) ~= nil
    local is_yes     = not is_trigger and norm:find(TOKEN_YES, 1, true) ~= nil
    local is_no      = not is_trigger and not is_yes and norm:find(TOKEN_NO, 1, true) ~= nil
    local is_marker  = is_trigger or is_yes or is_no

    if not PARTY_MODES[mode] and not is_marker then return end

    -- ── Detect the ready-check trigger ──────────────────────────────────────
    if is_trigger then
        if not state.is_checker then
            state.prompt_answered = false
            state.prompt_open[1]  = true
            state.prompt_deadline = os.clock() + 30
            state.prompt_sender   = resolve_sender_from_live_party(e.message or raw)
                                  or parse_sender(e.message or '')
                                  or parse_sender(raw)
            if SOUND_ON_PROMPT then play_readycheck_sound() end
        end
        return
    end

    if not state.checker_open[1] then return end

    -- ── Detect YES / NO response ─────────────────────────────────────────────
    if is_yes or is_no then
        local sender = parse_sender(raw) or resolve_sender_from_party(raw)
                    or infer_single_pending_member()
        if sender then
            update_member_status(sender, is_yes and 'ready' or 'not_ready')
        end
    end
end)

-- ──────────────────────────────────────────────────────────────────────────────
-- Event: d3d_present – render ImGui windows every frame
-- ──────────────────────────────────────────────────────────────────────────────
ashita.events.register('d3d_present', 'readycheck_present_cb', function()
    local now = os.clock()

    -- Refresh job indices for members whose job was 0 at snapshot time
    -- (happens when the member is in a different zone).
    if state.checker_open[1] then
        local party = AshitaCore:GetMemoryManager():GetParty()
        if party then
            for i = 1, #state.party_members do
                local m = state.party_members[i]
                if (m.job == nil or m.job == 0) and m.slot then
                    local j = party:GetMemberMainJob(m.slot)
                    if j and j > 0 then m.job = j end
                end
            end
        end
    end

    if state.prompt_open[1] and not state.prompt_answered
            and state.prompt_deadline ~= nil and now >= state.prompt_deadline then
        state.prompt_open[1]  = false
        state.prompt_deadline = nil
    end

    if state.checker_open[1] and not state.checker_summary_sent then
        if state.checker_deadline ~= nil and now >= state.checker_deadline then
            announce_ready_check_summary(true)   -- mark unanswered as not-ready
        elseif everyone_answered() then
            state.checker_deadline = nil
            announce_ready_check_summary(false)
        end
    end
    ui.render(state, handlers)

    if not state.checker_open[1] then
        close_checker()
    end
end)
