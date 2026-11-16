local event_handler = require("__core__.lualib.event_handler")
local error_handling = require("scripts.error_handling")
local glib = require("__glib__.glib")
local gui_util = require("gui_util")
local presenter = require("presenter") ---@class Rates.Gui.Presenter

local api = require("__sw-rates-lib__.api-usage")
local component = require("component")
local rate_format = require("rate_format")

local handlers = {}

---@param data Rates.Gui.WindowDataFull
---@param number_format Rates.Node.NumberFormat
---@param amount number
---@return GuiElemDef[]
local function format(data, number_format, amount)
    local settings = data.window.settings
    local force = data.player.force --[[@as LuaForce]]
    return rate_format.format(settings.timescale, amount, number_format, force)
end

---@class (exact) Rates.Gui.Component.Rate : Rates.Gui.Component
---@field number_format Rates.Node.NumberFormat
---@field amount number

---@param data Rates.Gui.WindowDataFull
---@param number_format Rates.Node.NumberFormat
---@param amount number
---@return GuiElemDef
local function define(data, number_format, amount)
    ---@type GuiElemDef
    local result = {
        args = {
            type = "flow",
            direction = "horizontal",
            style = "packed_horizontal_flow",
        },
        children = format(data, number_format, amount),
        callback = function(element)
            ---@type Rates.Gui.Component.Rate
            local element_data = {
                number_format = number_format,
                amount = amount
            }
            component.set_element_data(element, element_data)
        end,
    }

    return result
end

---@param data Rates.Gui.WindowDataFull
local function update_all_rates(data)
    local all_element_data = data.window.element_data
    for index, element_data in pairs(all_element_data) do
        local element = element_data.element ---@cast element -nil
        if (element.valid) then
            ---@cast element_data Rates.Gui.Component.Rate
            local number_format = element_data.number_format
            if (number_format) then
                local new_content = format(data, number_format, element_data.amount)
                element.clear()
                for _, child in ipairs(new_content) do
                    glib.add(element, child)
                end
            end
        else
            all_element_data[index] = nil
        end
    end
end

local timescales = { nil, second, minute, hour }
local timescale_long_names = {
    { "gui.sw-rates-calc-extreme-rate-automatic" },
    { "gui.sw-rates-calc-extreme-rate-per-second" },
    { "gui.sw-rates-calc-extreme-rate-per-minute" },
    { "gui.sw-rates-calc-extreme-rate-per-hour" },
}
---@param data Rates.Gui.WindowDataFull
---@param element LuaGuiElement
local function update_dropdown_timescale(data, element)
    ---@type integer
    local index = 1
    local timescale = data.window.settings.timescale
    if (timescale == second) then
        index = 2
    elseif (timescale == minute) then
        index = 3
    elseif (timescale == hour) then
        index = 4
    end

    element.selected_index = index
end

---@param data Rates.Gui.WindowDataFull
---@param container LuaGuiElement
---@param active_index integer
local function update_dropdowns(data, container, active_index)
    local children = container.children
    update_dropdown_timescale(data, children[1])
end

---@param data Rates.Gui.WindowDataFull
---@return GuiElemDef
local function define_toolbar(data)
    ---@type GuiElemDef
    return {
        args = {
            type = "flow",
            direction = "horizontal",
            style = "packed_horizontal_flow",
        },
        children = {
            {
                args = {
                    type = "drop-down",
                    items = timescale_long_names,
                },
                _click = handlers.on_click_dropdown,
                _selection_state_changed = handlers.on_select_timescale,
            },
        },
        callback = function(element)
            local window = gui_util.find_top(element)
            local data = presenter.get_window_data(window)
            update_dropdowns(data, element, 1)
        end
    }
end

---@param event EventData.on_gui_click
handlers.on_click_dropdown = function(event)
    local element = event.element
    local window = gui_util.find_top(element)
    local data = presenter.get_window_data(window)
    local container = element.parent ---@cast container -nil

    if (event.button == defines.mouse_button_type.right) then
        data.window.settings.timescale = nil
        update_dropdowns(data, container, 1)
        update_all_rates(data)
    end
end

---@param event EventData.on_gui_selection_state_changed
handlers.on_select_timescale = function(event)
    local element = event.element
    local window = gui_util.find_top(element)
    local data = presenter.get_window_data(window)
    local timescale = timescales[element.selected_index]
    data.window.settings.timescale = timescale
    update_all_rates(data)
end

glib.register_handlers(handlers, error_handling.safe_event_handler_glib, "component_rate")

return {
    define = define,
    define_toolbar = define_toolbar,
}
