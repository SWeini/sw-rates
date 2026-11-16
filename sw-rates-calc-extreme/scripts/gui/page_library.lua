local event_handler = require("__core__.lualib.event_handler")
local error_handling = require("scripts.error_handling")
local glib = require("__glib__.glib")
local gui_util = require("gui_util")
local presenter = require("presenter") ---@class Rates.Gui.Presenter

local library = require("scripts.library")
local sheet_solver = require("scripts.sheet")

do
    ---@class Rates.Gui.PageDescription.Library : Rates.Gui.PageDescription.Base
    ---@field type "library"
end

local page = { left_panel = {}, right_panel = {} } ---@type Rates.Gui.PagePresenter
presenter.pages["library"] = page

local handlers = {}

page.left_panel.define_toolbar = function(data, page)
    ---@type GuiElemDef[]
    return {
        { args = { type = "label", style = "subheader_caption_label", caption = { "gui.sw-rates-calc-extreme-library" } } },
        {
            args = { type = "empty-widget" },
            style_mods = { horizontally_stretchable = true },
        },
        {
            args = {
                type = "sprite-button",
                sprite = "utility/sort_by_name",
                mouse_button_filter = { "left" },
                style = "tool_button",
                tooltip = { "gui-load-game.sort-by-name" },
                enabled = false,
            }
        },
        {
            args = {
                type = "sprite-button",
                sprite = "utility/sort_by_time",
                mouse_button_filter = { "left" },
                style = "tool_button",
                tooltip = { "gui-load-game.sort-by-recent" },
                toggled = true,
            }
        },
        {
            args = {
                type = "sprite-button",
                sprite = "utility/trash",
                mouse_button_filter = { "left" },
                style = "tool_button_red",
                tooltip = { "gui.delete" },
                enabled = data.sheet.metadata.id ~= 0,
                tags = { sheet_id = data.sheet.metadata.id }
            },
            _click = handlers.on_click_delete,
        },
    }
end

page.right_panel.define_toolbar = function(data, page, state)
    ---@type GuiElemDef[]
    return {
        { args = { type = "label", style = "subheader_caption_label", caption = { "gui.sw-rates-calc-extreme-recipes" } } },
        {
            args = { type = "empty-widget" },
            style_mods = { horizontally_stretchable = true },
        },
    }
end

local font_color_default = { 1, 1, 1 }
local font_color_selected = { 0, 0, 0 }

---@param sheet Rates.Data.Sheet
---@param opened_sheet_id Rates.Data.SheetId
---@return GuiElemDef[]
local function define_item_button(sheet, opened_sheet_id)
    local t = sheet.metadata.tick_modified
    local s = math.floor(t / 60)
    local m = math.floor(s / 60)
    s = s - m * 60
    local h = math.floor(m / 60)
    m = m - h * 60
    local time = string.format("%d:%02d:%02d", h, m, s)
    ---@type LocalisedString
    local title = sheet.metadata.name or { "gui.sw-rates-calc-extreme-unnamed-sheet" }

    local tooltip = presenter.create_action_tooltip(nil, {
        left = sheet.metadata.id == opened_sheet_id
            and { "gui.sw-rates-calc-extreme-library-open" }
            or { "gui.sw-rates-calc-extreme-library-preview" }
    })

    ---@type GuiElemDef[]
    return {
        {
            args = {
                type = "button",
                caption = title,
                style = "list_box_item",
                tooltip = tooltip,
                toggled = sheet.metadata.id == opened_sheet_id,
                raise_hover_events = true,
            },
            style_mods = {
                minimal_width = 200,
                maximal_width = 400,
                right_padding = 80,
                horizontally_stretchable = true,
            },
            _hover = handlers.on_hover_item,
            _leave = handlers.on_leave_item,
            _click = handlers.on_click_item,
        },
        {
            args = {
                type = "label",
                caption = time,
                ignored_by_interaction = true,
            },
            style_mods = {
                width = 80,
                left_margin = -88,
                top_margin = 4,
                right_margin = 8,
                horizontal_align = "right",
                font_color = sheet.metadata.id == opened_sheet_id and font_color_selected or font_color_default
            },
        },
    }
end

---@param a Rates.Data.Sheet
---@param b Rates.Data.Sheet
---@return boolean
local function sort_by_recent(a, b)
    return a.metadata.tick_modified > b.metadata.tick_modified
end

page.left_panel.define_content = function(data, page, state)
    local player = data.player
    local sheet = data.sheet
    ---@type GuiElemDef[]
    local result = {}
    local opened_sheet_id = sheet and sheet.metadata.id
    local sheets = library.get_sheets(player)
    table.sort(sheets, sort_by_recent)
    for _, sheet in ipairs(sheets) do
        result[#result + 1] = {
            args = {
                type = "flow",
                direction = "horizontal",
                style = "packed_horizontal_flow",
                tags = { sheet_id = sheet.metadata.id },
            },
            style_mods = {
                horizontally_stretchable = true,
                horizontally_squashable = true,
            },
            children = define_item_button(sheet, opened_sheet_id),
        }
    end

    return result
end

page.left_panel.define_panel = function(data, p, state)
    local toolbar = page.left_panel.define_toolbar(data, p, state)
    ---@type GuiElemDef
    return {
        args = {
            type = "frame",
            style = "inside_shallow_frame",
            direction = "vertical",
        },
        style_mods = {
            minimal_width = 250,
            vertically_stretchable = true,
        },
        children = {
            {
                args = {
                    name = "toolbar",
                    type = "frame",
                    style = "subheader_frame",
                    direction = "horizontal",
                },
                children = toolbar,
            },
            {
                args = {
                    name = "content",
                    type = "scroll-pane",
                    style = "list_box_scroll_pane",
                    horizontal_scroll_policy = "never",
                    vertical_scroll_policy = "auto-and-reserve-space",
                },
                style_mods = {
                    vertically_stretchable = true,
                    horizontally_stretchable = true,
                    minimal_height = 280,
                },
                children = page.left_panel.define_content(data, p, state),
            },
        },
    }
end

page.right_panel.define_content = function(data, page, state)
    return presenter.pages["rates"].right_panel.define_content(data, { type = "rates" }, state)
end

---@param element LuaGuiElement
---@param color Color
local function set_time_color(element, color)
    local parent = element.parent ---@cast parent -nil
    local idx = element.get_index_in_parent()
    local sibling = parent.children[idx + 1]
    sibling.style.font_color = color
end

---@param event EventData.on_gui_hover
function handlers.on_hover_item(event)
    set_time_color(event.element, font_color_selected)
end

---@param event EventData.on_gui_leave
function handlers.on_leave_item(event)
    local element = event.element
    set_time_color(element, element.toggled and font_color_selected or font_color_default)
end

---@param event EventData.on_gui_click
function handlers.on_click_delete(event)
    local element = event.element
    local window = gui_util.find_top(element)
    local player = game.get_player(event.player_index) ---@cast player -nil
    local sheet_id = gui_util.find_tag(event.element, "sheet_id") ---@cast sheet_id Rates.Data.SheetId;
    local sheet = library.get_sheet(sheet_id)
    library.delete_sheet(sheet)
    presenter.open_sheet(window, library.create_sheet(player))
end

---@param event EventData.on_gui_click
function handlers.on_click_item(event)
    local element = event.element
    local sheet_id = gui_util.find_tag(element, "sheet_id") --[[@as Rates.Data.SheetId]]
    local sheet = library.get_sheet(sheet_id)
    local window = gui_util.find_top(element)
    local data = presenter.get_window_data(window)
    if (element.toggled) then
        presenter.open_sheet(window, sheet)
    else
        local items = element.parent.parent.children
        for _, item in ipairs(items) do
            local button = item.children[1]
            if (button.toggled) then
                button.toggled = false
                button.tooltip = presenter.create_action_tooltip(nil,
                    { left = { "gui.sw-rates-calc-extreme-library-preview" } })
                set_time_color(button, font_color_default)
            end
        end

        element.toggled = true
        element.tooltip = presenter.create_action_tooltip(nil, { left = { "gui.sw-rates-calc-extreme-library-open" } })
        set_time_color(element, font_color_selected)

        ---@type Rates.Gui.NavigationEntry
        local right_side_page = { page_id = { type = "rates" }, state = data.page.state }
        ---@type Rates.Gui.WindowDataFull
        local right_side_data = {
            page = right_side_page,
            player = data.player,
            player_settings = data.player_settings,
            player_data = data.player_data,
            sheet = sheet,
            window = {
                element_data = {},
                navigation_stack = {},
                redo_stack = {},
                undo_stack = {},
                settings = data.window.settings,
                sheet_rates = sheet_solver.calculate(data.player, sheet)
            }
        }
        local content = presenter.define_page(right_side_data, right_side_page.page_id, right_side_page.state, "right")
        local toolbar = page.left_panel.define_toolbar(right_side_data, right_side_page.page_id, right_side_page.state)

        local container = window.children[3]
        local left_page = container.children[1]
        local left_toolbar = left_page.children[1]

        left_toolbar.clear()
        for _, element in ipairs(toolbar) do
            glib.add(left_toolbar, element)
        end

        container.children[2].destroy()
        glib.add(container, content)

        presenter.stop_selection_tool(data.player)
    end
end

glib.register_handlers(handlers, error_handling.safe_event_handler_glib, "page_library")
