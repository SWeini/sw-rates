do
    --- A rocket carrying items to a space platform (using the rocket lift weight).
    ---@class (exact) Rates.Node.SendToPlatform : Rates.Node.Base
    ---@field type "send-to-platform"
end

local gui = require("scripts.gui")

local creator = {} ---@class Rates.Node.Creator
local result = { type = "send-to-platform", creator = creator } ---@type Rates.Node.Type

---@return Rates.Node.SendToPlatform
creator.send_to_platform = function()
    return {}
end

---@param weight number
---@return LocalisedString
local function format_weight(weight)
    if (weight >= 1000000) then
        local tons = weight / 1000000
        return { "tons", tons, gui.format_number(tons) }
    elseif (weight >= 1000) then
        local kg = weight / 1000
        return { "", gui.format_number(kg), " ", { "si-unit-kilogram" } }
    else
        return { "", gui.format_number(weight), " ", { "si-unit-gram" } }
    end
end

local rocket_lift_weight = format_weight(prototypes.utility_constants["rocket_lift_weight"] --[[@as number]])

---@param node Rates.Node.SendToPlatform
result.gui_default = function(node)
    ---@type Rates.Gui.NodeDescription
    return {
        icon = { sprite = "utility/space_age_icon" },
        name = { "sw-rates-node.send-to-platform" },
        tooltip = { "", { "sw-rates-node.rocket-lift-weight" }, ": ", rocket_lift_weight },
    }
end

return result
