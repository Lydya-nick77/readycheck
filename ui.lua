local imgui = require('imgui')
local bit = require('bit')

local ui = {}

local function push_xidb_theme()
    local color_count = 0
    local var_count = 0

    local function push_color(col, value)
        imgui.PushStyleColor(col, value)
        color_count = color_count + 1
    end

    local function push_var(style_var, value)
        imgui.PushStyleVar(style_var, value)
        var_count = var_count + 1
    end

    local gold = { 0.957, 0.855, 0.592, 1.0 }
    local gold_dark = { 0.765, 0.684, 0.474, 1.0 }
    local gold_darker = { 0.573, 0.512, 0.355, 1.0 }
    local bg_dark = { 0.0, 0.0, 0.0, 1.0 }
    local bg_medium = { 0.098, 0.090, 0.075, 1.0 }
    local bg_light = { 0.137, 0.125, 0.106, 1.0 }
    local bg_lighter = { 0.176, 0.161, 0.137, 1.0 }
    local text_light = { 0.878, 0.855, 0.812, 1.0 }
    local border_dark = { 0.3, 0.275, 0.235, 1.0 }
    local border_gold = { gold_dark[1], gold_dark[2], gold_dark[3], 0.85 }
    local button_base = { 0.176, 0.149, 0.106, 0.95 }
    local button_hover = { 0.286, 0.239, 0.165, 0.95 }
    local button_active = { 0.420, 0.353, 0.243, 0.95 }

    push_color(ImGuiCol_WindowBg, bg_dark)
    push_color(ImGuiCol_ChildBg, { 0.0, 0.0, 0.0, 1.0 })
    push_color(ImGuiCol_TitleBg, bg_medium)
    push_color(ImGuiCol_TitleBgActive, bg_light)
    push_color(ImGuiCol_TitleBgCollapsed, bg_dark)
    push_color(ImGuiCol_FrameBg, { 0.125, 0.110, 0.086, 0.98 })
    push_color(ImGuiCol_FrameBgHovered, { 0.173, 0.153, 0.122, 0.98 })
    push_color(ImGuiCol_FrameBgActive, { 0.231, 0.200, 0.157, 0.98 })
    push_color(ImGuiCol_Header, bg_light)
    push_color(ImGuiCol_HeaderHovered, bg_lighter)
    push_color(ImGuiCol_HeaderActive, { gold[1], gold[2], gold[3], 0.3 })
    push_color(ImGuiCol_Border, border_gold)
    push_color(ImGuiCol_Text, text_light)
    push_color(ImGuiCol_TextDisabled, gold_dark)
    push_color(ImGuiCol_Button, button_base)
    push_color(ImGuiCol_ButtonHovered, button_hover)
    push_color(ImGuiCol_ButtonActive, button_active)
    push_color(ImGuiCol_CheckMark, gold)
    push_color(ImGuiCol_SliderGrab, gold_dark)
    push_color(ImGuiCol_SliderGrabActive, gold)
    push_color(ImGuiCol_ScrollbarBg, bg_medium)
    push_color(ImGuiCol_ScrollbarGrab, bg_lighter)
    push_color(ImGuiCol_ScrollbarGrabHovered, border_dark)
    push_color(ImGuiCol_ScrollbarGrabActive, gold_dark)
    push_color(ImGuiCol_Separator, border_dark)
    push_color(ImGuiCol_PopupBg, bg_medium)
    push_color(ImGuiCol_ResizeGrip, gold_darker)
    push_color(ImGuiCol_ResizeGripHovered, gold_dark)
    push_color(ImGuiCol_ResizeGripActive, gold)

    push_var(ImGuiStyleVar_WindowPadding, { 12, 12 })
    push_var(ImGuiStyleVar_FramePadding, { 8, 6 })
    push_var(ImGuiStyleVar_ItemSpacing, { 8, 7 })
    push_var(ImGuiStyleVar_FrameRounding, 4.0)
    push_var(ImGuiStyleVar_WindowRounding, 6.0)
    push_var(ImGuiStyleVar_ChildRounding, 4.0)
    push_var(ImGuiStyleVar_PopupRounding, 4.0)
    push_var(ImGuiStyleVar_ScrollbarRounding, 4.0)
    push_var(ImGuiStyleVar_GrabRounding, 4.0)
    push_var(ImGuiStyleVar_WindowBorderSize, 1.0)
    push_var(ImGuiStyleVar_ChildBorderSize, 1.0)
    push_var(ImGuiStyleVar_FrameBorderSize, 1.0)
    push_var(ImGuiStyleVar_WindowTitleAlign, { 0.5, 0.5 })

    return color_count, var_count
end

local function render_prompt(state, handlers)
    if not state.prompt_open[1] then
        return
    end

    imgui.SetNextWindowSize({ 260, 110 }, ImGuiCond_Appearing)
    imgui.SetNextWindowBgAlpha(0.90)
    local flags = bit.bor(
        ImGuiWindowFlags_NoCollapse,
        ImGuiWindowFlags_NoResize,
        ImGuiWindowFlags_NoScrollbar,
        ImGuiWindowFlags_AlwaysAutoResize,
        ImGuiWindowFlags_NoSavedSettings
    )

    if imgui.Begin('ReadyCheck##prompt', state.prompt_open, flags) then
        imgui.Spacing()
        imgui.Text('  Are you ready?')
        imgui.Spacing()
        imgui.Separator()
        imgui.Spacing()

        local remaining = state.prompt_deadline and math.max(0, math.ceil(state.prompt_deadline - os.clock())) or 0
        imgui.TextDisabled(('Auto-close in %ds'):format(remaining))
        imgui.Spacing()

        if imgui.Button('  Yes  ', { 100, 28 }) and not state.prompt_answered then
            handlers.answer_yes()
        end

        imgui.SameLine()

        if imgui.Button('  No   ', { 100, 28 }) and not state.prompt_answered then
            handlers.answer_no()
        end
    end

    imgui.End()
end

local function render_tracker(state, handlers)
    if not state.checker_open[1] then
        return
    end

    imgui.SetNextWindowSize({ 220, 0 }, ImGuiCond_Appearing)
    imgui.SetNextWindowBgAlpha(0.90)
    local flags = bit.bor(
        ImGuiWindowFlags_NoCollapse,
        ImGuiWindowFlags_AlwaysAutoResize,
        ImGuiWindowFlags_NoScrollbar,
        ImGuiWindowFlags_NoSavedSettings
    )

    if imgui.Begin('Ready Check##tracker', state.checker_open, flags) then
        imgui.Text('Party / Alliance Status')
        imgui.SameLine()
        local secs_left = state.checker_deadline and math.max(0, math.ceil(state.checker_deadline - os.clock())) or 0
        imgui.TextDisabled(('  (%ds)'):format(secs_left))
        imgui.Separator()
        imgui.Spacing()

        if #state.party_members == 0 then
            imgui.TextDisabled('No party members found.')
        else
            for _, member in ipairs(state.party_members) do
                if member.status == 'ready' then
                    imgui.PushStyleColor(ImGuiCol_Text, { 0.20, 1.00, 0.20, 1.0 })
                elseif member.status == 'not_ready' then
                    imgui.PushStyleColor(ImGuiCol_Text, { 1.00, 0.25, 0.25, 1.0 })
                else
                    imgui.PushStyleColor(ImGuiCol_Text, { 1.00, 1.00, 1.00, 1.0 })
                end
                imgui.Text(member.name)
                imgui.PopStyleColor(1)
            end
        end

        imgui.Spacing()
        imgui.Separator()
        imgui.Spacing()

        if imgui.Button('Close', { -1, 24 }) then
            handlers.close_checker()
        end
    end

    imgui.End()
end

function ui.render(state, handlers)
    local draw_prompt = state.prompt_open[1]
    local draw_checker = state.checker_open[1]
    local pushed_style_colors = 0
    local pushed_style_vars = 0

    if draw_prompt or draw_checker then
        pushed_style_colors, pushed_style_vars = push_xidb_theme()
    end

    render_prompt(state, handlers)
    render_tracker(state, handlers)

    if pushed_style_vars > 0 then
        imgui.PopStyleVar(pushed_style_vars)
    end
    if pushed_style_colors > 0 then
        imgui.PopStyleColor(pushed_style_colors)
    end
end

return ui