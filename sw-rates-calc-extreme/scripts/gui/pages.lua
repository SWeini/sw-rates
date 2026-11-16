local event_handler = require("__core__.lualib.event_handler")
local error_handling = require("scripts.error_handling")
local glib = require("__glib__.glib")
local gui_util = require("gui_util")
local presenter = require("presenter") ---@class Rates.Gui.Presenter

---@class Rates.Gui.PanelPresenter
---@field define_toolbar? fun(data: Rates.Gui.WindowDataFull, page: Rates.Gui.PageDescription, state: Rates.Gui.PageVisualState.Base): GuiElemDef[]
---@field define_content? fun(data: Rates.Gui.WindowDataFull, page: Rates.Gui.PageDescription, state: Rates.Gui.PageVisualState.Base): GuiElemDef[]
---@field define_panel? fun(data: Rates.Gui.WindowDataFull, page: Rates.Gui.PageDescription, state: Rates.Gui.PageVisualState.Base): GuiElemDef
---@field update_panel? fun(element: LuaGuiElement, data: Rates.Gui.WindowDataFull, changed: Rates.Gui.ChangedProperties): boolean

---@class Rates.Gui.PagePresenter
---@field left_panel Rates.Gui.PanelPresenter
---@field right_panel Rates.Gui.PanelPresenter

---@class Rates.Gui.PageDescription.Base
---@field type string

---@alias Rates.Gui.PageDescription
--- | Rates.Gui.PageDescription.Base
--- | Rates.Gui.PageDescription.Library
--- | Rates.Gui.PageDescription.Rates
--- | Rates.Gui.PageDescription.SelectedEntity
--- | Rates.Gui.PageDescription.SelectedNode
--- | Rates.Gui.PageDescription.Selection

---@alias Rates.Gui.RateFormatId string

---@class Rates.Gui.PageVisualState.Base
---@field expanders table<string, boolean>
---@field rate_configs table<string, Rates.Gui.RateFormatId>

local handlers = {}

---@param window LuaGuiElement
---@param all boolean
local function navigate_back(window, all)
    local data = presenter.get_window_data(window)
    local navigation = data.window.navigation_stack

    if (all) then
        while (#navigation > 1) do
            navigation[#navigation] = nil
        end
    else
        navigation[#navigation] = nil
    end

    local last = navigation[#navigation]
    if (not last) then
        last = {
            page_id = { type = "rates" },
            state = {
                expanders = {},
                rate_configs = {},
            }
        }
        data.window.navigation_stack = { last }
    end
    data.page = last

    presenter.update_main_toolbar(window, data)

    local container = window.children[3]
    container.clear()

    local content_left = presenter.define_page(data, last.page_id, last.state, "left")
    glib.add(container, content_left)

    local content_right = presenter.define_page(data, last.page_id, last.state, "right")
    glib.add(container, content_right)
end

---@param window LuaGuiElement
---@param page Rates.Gui.PageDescription
---@param state Rates.Gui.PageVisualState.Base?
function presenter.open_page(window, page, state)
    local data = presenter.get_window_data(window)
    local navigation = data.window.navigation_stack
    local current = navigation[#navigation].page_id
    if (current.type == page.type) then
        if (table_size(current) == 1 and table_size(page) == 1) then
            navigate_back(window, false)
            return
        end
    end
    if (not state) then
        state = {
            expanders = {},
            rate_configs = {},
        }
    end
    navigation[#navigation + 1] = { page_id = page, state = state }
    data.page = navigation[#navigation]

    presenter.update_main_toolbar(window, data)

    local container = window.children[3]
    container.clear()

    local content_left = presenter.define_page(data, page, state, "left")
    glib.add(container, content_left)

    local content_right = presenter.define_page(data, page, state, "right")
    glib.add(container, content_right)
end

---@param data Rates.Gui.WindowDataFull
---@param page Rates.Gui.PageDescription
---@param panel_presenter Rates.Gui.PanelPresenter
---@param state Rates.Gui.PageVisualState.Base
---@return GuiElemDef
local function define_default_panel(data, page, panel_presenter, state)
    local toolbar ---@type GuiElemDef[]
    local define_toolbar = panel_presenter.define_toolbar
    if (define_toolbar) then
        toolbar = define_toolbar(data, page, state)
    else
        toolbar = {
            {
                args = { type = "empty-widget" },
                style_mods = { horizontally_stretchable = true },
            }
        }
    end

    local content ---@type GuiElemDef[]
    local define_content = panel_presenter.define_content
    if (define_content) then
        content = define_content(data, page, state)
    else
        content = {}
    end

    ---@type GuiElemDef
    return {
        args = {
            type = "frame",
            style = "inside_shallow_frame",
            direction = "vertical",
        },
        style_mods = {
            vertically_stretchable = true,
            minimal_width = 250,
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
                    style = "entity_frame_scroll_pane",
                    horizontal_scroll_policy = "never",
                    vertical_scroll_policy = "auto-and-reserve-space",
                },
                style_mods = {
                    horizontally_stretchable = true,
                },
                children = content,
            },
        },
    }
end

---@param data Rates.Gui.WindowDataFull
---@param page Rates.Gui.PageDescription
---@param state Rates.Gui.PageVisualState.Base
---@param panel "left" | "right"
---@return GuiElemDef
function presenter.define_page(data, page, state, panel)
    local panel_presenter = presenter.pages[page.type][panel .. "_panel"] --[[@as Rates.Gui.PanelPresenter]]
    local define = panel_presenter.define_panel
    local result
    if (define) then
        result = define(data, page, state)
    else
        result = define_default_panel(data, page, panel_presenter, state)
    end

    return result
end

---@param element LuaGuiElement
---@param data Rates.Gui.WindowDataFull
---@param page Rates.Gui.PageDescription
---@param panel_presenter Rates.Gui.PanelPresenter
function presenter.update_page(element, data, page, panel_presenter)
    local toolbar = element.children[1]
    local scroll_pane = element.children[2]
    local state = data.page.state

    if (panel_presenter.define_toolbar) then
        toolbar.clear()
        local toolbar_new = panel_presenter.define_toolbar(data, page, state)
        for _, part in ipairs(toolbar_new) do
            glib.add(toolbar, part)
        end
    end

    if (panel_presenter.define_content) then
        scroll_pane.clear()

        local content_new = panel_presenter.define_content(data, page, state)
        for _, part in ipairs(content_new) do
            glib.add(scroll_pane, part)
        end
    end
end

---@param data Rates.Gui.WindowDataFull
---@return GuiElemDef
function presenter.define_back_button(data)
    ---@type GuiElemDef
    return {
        args = {
            type = "sprite-button",
            sprite = "utility/backward_arrow",
            style = "tool_button_simple",
            tooltip = { "gui.cancel" },
            enabled = #data.window.navigation_stack > 1,
        },
        _click = handlers.on_click_back,
    }
end

---@param event EventData.on_gui_click
function handlers.on_click_back(event)
    local window = gui_util.find_top(event.element)
    navigate_back(window, event.button == defines.mouse_button_type.right)
end

glib.register_handlers(handlers, error_handling.safe_event_handler_glib, "pages")
