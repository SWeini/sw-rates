local event_handler = require("__core__.lualib.event_handler")
local glib = require("__glib__.glib")
local gui_util = require("gui_util")
local presenter = require("presenter") ---@class Rates.Gui.Presenter

---@class (exact) Rates.Gui.Component
---@field element? LuaGuiElement
---@field index? uint32

---@param element LuaGuiElement
---@return Rates.Gui.Component?
local function get_element_data(element)
    local window = gui_util.find_top(element)
    return presenter.get_window_data(window).window.element_data[element.index]
end

---@param element LuaGuiElement
---@param data Rates.Gui.Component
local function set_element_data(element, data)
    local window = gui_util.find_top(element)
    data.element = element
    data.index = element.index
    presenter.get_window_data(window).window.element_data[element.index] = data
end

return {
    get_element_data = get_element_data,
    set_element_data = set_element_data,
}
