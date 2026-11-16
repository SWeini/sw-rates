local event_handler = require("__core__.lualib.event_handler")
local error_handling = require("scripts.error_handling")
local glib = require("__glib__.glib")
local gui_util = require("gui_util")
local presenter = require("presenter") ---@class Rates.Gui.Presenter

local api = require("__sw-rates-lib__.api-usage")
local component = require("component")
local expander = require("component_expander")
local component_rate = require("component_rate")
local sheet_manipulation = require("scripts.sheet_manipulation")

local handlers = {}

---@param location Rates.Location
---@return Rates.Gui.NodeDescription
local function gui_location(location)
    local planet = location.planet
    if (planet) then
        ---@type Rates.Gui.NodeDescription
        return {
            element = { type = "space-location", name = planet.name },
            name = planet.prototype.localised_name,
        }
    end

    local platform = location.platform
    if (platform) then
        ---@type Rates.Gui.NodeDescription
        return {
            icon = { sprite = "surface/space-platform" },
            name = platform.name
        }
    end

    ---@type Rates.Gui.NodeDescription
    return {
        name = location.name
    }
end

glib.register_handlers(handlers, error_handling.safe_event_handler_glib, "component_location")

return {
    gui_location = gui_location,
}
