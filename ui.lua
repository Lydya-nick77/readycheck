local imgui = require('imgui')
local bit   = require('bit')
local ffi   = require('ffi')
local d3d8  = require('d3d8')
local C     = ffi.C

local ui = {}

-- ── Job icon loader ───────────────────────────────────────────────────────────
-- Icons are sourced from XIUI's bundled assets (Classic theme).
-- If XIUI is not installed the icons are simply skipped; no errors are thrown.

local JOB_ABBRS = {
    'WAR', 'MNK', 'WHM', 'BLM', 'RDM', 'THF',
    'PLD', 'DRK', 'BST', 'BRD', 'RNG', 'SAM',
    'NIN', 'DRG', 'SMN', 'BLU', 'COR', 'PUP',
    'DNC', 'SCH', 'GEO', 'RUN',
}

-- Computed once at first load; points to the addon's own icons/ folder.
local ICON_DIR = addon.path .. 'icons\\'

-- Cache: jobIdx (1-22) -> { ptr=uint32, tex=cdata } keeping tex alive, or false (load failed).
local icon_cache = {}

local function load_job_icon(jobIdx)
    if jobIdx == nil or type(jobIdx) ~= 'number' or jobIdx < 1 or jobIdx > 22 then
        return nil
    end

    local cached = icon_cache[jobIdx]
    if cached ~= nil then
        return cached ~= false and cached.ptr or nil
    end

    local abbr = JOB_ABBRS[jobIdx]
    if not abbr then
        icon_cache[jobIdx] = false
        return nil
    end

    local path = ICON_DIR .. abbr:lower() .. '.png'
    if not ashita.fs.exists(path) then
        icon_cache[jobIdx] = false
        return nil
    end

    local device = d3d8.get_device()
    if device == nil then
        -- Don't cache a nil device; try again next frame.
        return nil
    end

    local tex_ptr = ffi.new('IDirect3DTexture8*[1]')
    if C.D3DXCreateTextureFromFileA(device, path, tex_ptr) ~= C.S_OK then
        icon_cache[jobIdx] = false
        return nil
    end

    local tex = d3d8.gc_safe_release(ffi.cast('IDirect3DTexture8*', tex_ptr[0]))
    local ptr = tonumber(ffi.cast('uint32_t', tex))
    -- Store tex alongside ptr so the gc_safe_release wrapper stays reachable
    -- and the underlying D3D texture is never freed while we hold the cache entry.
    icon_cache[jobIdx] = { ptr = ptr, tex = tex }
    return ptr
end

-- ── XIDB theme ───────────────────────────────────────────────────────────────
-- All tables allocated once at module load so push_xidb_theme() has zero
-- heap allocations per call.

local THEME_COLORS = {
    { ImGuiCol_WindowBg,             { 0.000, 0.000, 0.000, 1.00 } },
    { ImGuiCol_ChildBg,              { 0.000, 0.000, 0.000, 1.00 } },
    { ImGuiCol_TitleBg,              { 0.098, 0.090, 0.075, 1.00 } },
    { ImGuiCol_TitleBgActive,        { 0.137, 0.125, 0.106, 1.00 } },
    { ImGuiCol_TitleBgCollapsed,     { 0.000, 0.000, 0.000, 1.00 } },
    { ImGuiCol_FrameBg,              { 0.125, 0.110, 0.086, 0.98 } },
    { ImGuiCol_FrameBgHovered,       { 0.173, 0.153, 0.122, 0.98 } },
    { ImGuiCol_FrameBgActive,        { 0.231, 0.200, 0.157, 0.98 } },
    { ImGuiCol_Header,               { 0.137, 0.125, 0.106, 1.00 } },
    { ImGuiCol_HeaderHovered,        { 0.176, 0.161, 0.137, 1.00 } },
    { ImGuiCol_HeaderActive,         { 0.957, 0.855, 0.592, 0.30 } },
    { ImGuiCol_Border,               { 0.765, 0.684, 0.474, 0.85 } },
    { ImGuiCol_Text,                 { 0.878, 0.855, 0.812, 1.00 } },
    { ImGuiCol_TextDisabled,         { 0.765, 0.684, 0.474, 1.00 } },
    { ImGuiCol_Button,               { 0.176, 0.149, 0.106, 0.95 } },
    { ImGuiCol_ButtonHovered,        { 0.286, 0.239, 0.165, 0.95 } },
    { ImGuiCol_ButtonActive,         { 0.420, 0.353, 0.243, 0.95 } },
    { ImGuiCol_CheckMark,            { 0.957, 0.855, 0.592, 1.00 } },
    { ImGuiCol_SliderGrab,           { 0.765, 0.684, 0.474, 1.00 } },
    { ImGuiCol_SliderGrabActive,     { 0.957, 0.855, 0.592, 1.00 } },
    { ImGuiCol_ScrollbarBg,          { 0.098, 0.090, 0.075, 1.00 } },
    { ImGuiCol_ScrollbarGrab,        { 0.176, 0.161, 0.137, 1.00 } },
    { ImGuiCol_ScrollbarGrabHovered, { 0.300, 0.275, 0.235, 1.00 } },
    { ImGuiCol_ScrollbarGrabActive,  { 0.765, 0.684, 0.474, 1.00 } },
    { ImGuiCol_Separator,            { 0.300, 0.275, 0.235, 1.00 } },
    { ImGuiCol_PopupBg,              { 0.098, 0.090, 0.075, 1.00 } },
    { ImGuiCol_ResizeGrip,           { 0.573, 0.512, 0.355, 1.00 } },
    { ImGuiCol_ResizeGripHovered,    { 0.765, 0.684, 0.474, 1.00 } },
    { ImGuiCol_ResizeGripActive,     { 0.957, 0.855, 0.592, 1.00 } },
}

local THEME_VARS = {
    { ImGuiStyleVar_WindowPadding,    { 12, 12 } },
    { ImGuiStyleVar_FramePadding,     { 8,  6  } },
    { ImGuiStyleVar_ItemSpacing,      { 8,  7  } },
    { ImGuiStyleVar_FrameRounding,    4.0        },
    { ImGuiStyleVar_WindowRounding,   6.0        },
    { ImGuiStyleVar_ChildRounding,    4.0        },
    { ImGuiStyleVar_PopupRounding,    4.0        },
    { ImGuiStyleVar_ScrollbarRounding, 4.0       },
    { ImGuiStyleVar_GrabRounding,     4.0        },
    { ImGuiStyleVar_WindowBorderSize, 1.0        },
    { ImGuiStyleVar_ChildBorderSize,  1.0        },
    { ImGuiStyleVar_FrameBorderSize,  1.0        },
    { ImGuiStyleVar_WindowTitleAlign, { 0.5, 0.5 } },
}

local THEME_COLOR_COUNT = #THEME_COLORS
local THEME_VAR_COUNT   = #THEME_VARS

-- Window flags pre-computed so bit.bor() is not called every frame.
local PROMPT_FLAGS = bit.bor(
    ImGuiWindowFlags_NoCollapse,
    ImGuiWindowFlags_NoResize,
    ImGuiWindowFlags_NoScrollbar,
    ImGuiWindowFlags_AlwaysAutoResize,
    ImGuiWindowFlags_NoSavedSettings,
    ImGuiWindowFlags_NoMove
)
local TRACKER_FLAGS = bit.bor(
    ImGuiWindowFlags_NoCollapse,
    ImGuiWindowFlags_AlwaysAutoResize,
    ImGuiWindowFlags_NoScrollbar,
    ImGuiWindowFlags_NoSavedSettings,
    ImGuiWindowFlags_NoMove
)

-- Per-row colours and icon call arguments: pre-allocated, zero GC per frame.
local COLOR_READY     = { 0.20, 1.00, 0.20, 1.0 }
local COLOR_NOT_READY = { 1.00, 0.25, 0.25, 1.0 }
local COLOR_PENDING   = { 1.00, 1.00, 1.00, 1.0 }
local ICON_SIZE       = { 18, 18 }
local ICON_UV0        = { 0, 0 }
local ICON_UV1        = { 1, 1 }
local ICON_TINT       = { 1, 1, 1, 1 }
local ICON_BORDER     = { 0, 0, 0, 0 }
local PIVOT_CENTER    = { 0.5, 0.5 }
local BTN_YES_NO      = { 100, 28 }
local BTN_CLOSE       = { -1, 24 }
local BTN_PROMPT      = { 120, 36 }
-- Prompt button colours: deep red (matches WoW-style dark red buttons).
local BTN_YES_COL        = { 0.45, 0.12, 0.10, 1.0 }
local BTN_YES_COL_HOVER  = { 0.60, 0.18, 0.14, 1.0 }
local BTN_YES_COL_ACTIVE = { 0.30, 0.08, 0.06, 1.0 }
local BTN_NO_COL         = { 0.38, 0.10, 0.08, 1.0 }
local BTN_NO_COL_HOVER   = { 0.55, 0.16, 0.12, 1.0 }
local BTN_NO_COL_ACTIVE  = { 0.25, 0.06, 0.05, 1.0 }
local COLOR_GOLD_BRIGHT  = { 0.957, 0.855, 0.592, 1.0 }
-- Mutable position buffer updated each frame; avoids a new table per window.
local WIN_CENTER      = { 0, 0 }

local function push_xidb_theme()
    for i = 1, THEME_COLOR_COUNT do
        local e = THEME_COLORS[i]
        imgui.PushStyleColor(e[1], e[2])
    end
    for i = 1, THEME_VAR_COUNT do
        local e = THEME_VARS[i]
        imgui.PushStyleVar(e[1], e[2])
    end
end

local function render_prompt(state, handlers)
    if not state.prompt_open[1] then return end

    imgui.SetNextWindowPos(WIN_CENTER, ImGuiCond_Always, PIVOT_CENTER)
    imgui.SetNextWindowBgAlpha(0.95)

    if imgui.Begin('Ready Check##prompt', state.prompt_open, PROMPT_FLAGS) then
        -- ── Header: who initiated ────────────────────────────────────────────
        local sender = state.prompt_sender or 'Someone'
        imgui.Spacing()
        imgui.PushStyleColor(ImGuiCol_Text, COLOR_GOLD_BRIGHT)
        local header = sender .. ' has initiated a ready check.'
        local win_w  = imgui.GetContentRegionAvail()
        local text_w = imgui.CalcTextSize(header)
        -- Centre the text manually.
        imgui.SetCursorPosX((win_w - text_w) * 0.5 + imgui.GetCursorPosX())
        imgui.Text(header)
        imgui.PopStyleColor(1)

        -- ── Subtitle ────────────────────────────────────────────────────────
        local subtitle = 'Are you ready?'
        local sub_w    = imgui.CalcTextSize(subtitle)
        imgui.SetCursorPosX((win_w - sub_w) * 0.5 + imgui.GetCursorPosX())
        imgui.Text(subtitle)
        imgui.Spacing()
        imgui.Separator()
        imgui.Spacing()

        -- ── Countdown ───────────────────────────────────────────────────────
        local remaining = state.prompt_deadline
            and math.max(0, math.ceil(state.prompt_deadline - os.clock())) or 0
        local cd_str = ('Auto-close in %ds'):format(remaining)
        local cd_w   = imgui.CalcTextSize(cd_str)
        imgui.SetCursorPosX((win_w - cd_w) * 0.5 + imgui.GetCursorPosX())
        imgui.TextDisabled(cd_str)
        imgui.Spacing()

        -- ── Buttons ─────────────────────────────────────────────────────────
        -- Centre the two buttons.
        local spacing   = imgui.GetStyle().ItemSpacing
        local total_btn = BTN_PROMPT[1] * 2 + spacing.x
        imgui.SetCursorPosX((win_w - total_btn) * 0.5 + imgui.GetCursorPosX())

        imgui.PushStyleColor(ImGuiCol_Button,        BTN_YES_COL)
        imgui.PushStyleColor(ImGuiCol_ButtonHovered, BTN_YES_COL_HOVER)
        imgui.PushStyleColor(ImGuiCol_ButtonActive,  BTN_YES_COL_ACTIVE)
        if imgui.Button('Yes', BTN_PROMPT) and not state.prompt_answered then
            handlers.answer_yes()
        end
        imgui.PopStyleColor(3)

        imgui.SameLine()

        imgui.PushStyleColor(ImGuiCol_Button,        BTN_NO_COL)
        imgui.PushStyleColor(ImGuiCol_ButtonHovered, BTN_NO_COL_HOVER)
        imgui.PushStyleColor(ImGuiCol_ButtonActive,  BTN_NO_COL_ACTIVE)
        if imgui.Button('No', BTN_PROMPT) and not state.prompt_answered then
            handlers.answer_no()
        end
        imgui.PopStyleColor(3)
        imgui.Spacing()
    end

    imgui.End()
end

local function render_tracker(state, handlers)
    if not state.checker_open[1] then return end

    imgui.SetNextWindowPos(WIN_CENTER, ImGuiCond_Always, PIVOT_CENTER)
    imgui.SetNextWindowBgAlpha(0.90)

    if imgui.Begin('Ready Check##tracker', state.checker_open, TRACKER_FLAGS) then
        imgui.Text('Party / Alliance Status')
        imgui.SameLine()
        local secs_left = state.checker_deadline
            and math.max(0, math.ceil(state.checker_deadline - os.clock())) or 0
        imgui.TextDisabled(('  (%ds)'):format(secs_left))
        imgui.Separator()
        imgui.Spacing()

        local members = state.party_members
        if #members == 0 then
            imgui.TextDisabled('No party members found.')
        else
            -- Split into per-party buckets (party field = 1/2/3).
            local parties = { {}, {}, {} }
            for i = 1, #members do
                local m = members[i]
                table.insert(parties[m.party or 1], m)
            end

            -- Find the highest occupied party index to set column count.
            local num_cols = 1
            for p = 3, 1, -1 do
                if #parties[p] > 0 then num_cols = p; break end
            end

            imgui.Columns(num_cols, 'rc_party_cols', num_cols > 1)

            for col = 1, num_cols do
                if num_cols > 1 then
                    imgui.TextDisabled('Party ' .. col)
                    imgui.Separator()
                end
                local grp = parties[col]
                for i = 1, #grp do
                    local member = grp[i]
                    local status = member.status
                    local col_c = status == 'ready'     and COLOR_READY
                               or status == 'not_ready' and COLOR_NOT_READY
                               or COLOR_PENDING
                    imgui.PushStyleColor(ImGuiCol_Text, col_c)
                    local icon_ptr = load_job_icon(member.job)
                    if icon_ptr then
                        imgui.Image(icon_ptr, ICON_SIZE, ICON_UV0, ICON_UV1, ICON_TINT, ICON_BORDER)
                        imgui.SameLine()
                    end
                    imgui.Text(member.name)
                    imgui.PopStyleColor(1)
                end
                if col < num_cols then imgui.NextColumn() end
            end

            imgui.Columns(1)
        end

        imgui.Spacing()
        imgui.Separator()
        imgui.Spacing()

        if imgui.Button('Close', BTN_CLOSE) then
            handlers.close_checker()
        end
    end

    imgui.End()
end

function ui.render(state, handlers)
    if not (state.prompt_open[1] or state.checker_open[1]) then return end

    -- Update shared position buffer once; both render functions read it.
    local display = imgui.GetIO().DisplaySize
    WIN_CENTER[1] = display.x * 0.5
    WIN_CENTER[2] = display.y * 0.5

    push_xidb_theme()
    render_prompt(state, handlers)
    render_tracker(state, handlers)
    imgui.PopStyleVar(THEME_VAR_COUNT)
    imgui.PopStyleColor(THEME_COLOR_COUNT)
end

return ui