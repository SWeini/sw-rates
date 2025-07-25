do
    --- Continuous electric power. Also supports day/night-only power, as provided by solar panels.
    ---@class (exact) Rates.Node.ElectricPower : Rates.Node.Base
    ---@field type "electric-power"
    ---@field day? boolean
end

local creator = {} ---@class Rates.Node.Creator
local result = { type = "electric-power", creator = creator } ---@type Rates.Node.Type

---@param day boolean?
---@return Rates.Node.ElectricPower
creator.electric_power = function(day)
    return {
        day = day
    }
end

---@param node Rates.Node.ElectricPower
result.get_id = function(node)
    if (node.day == nil) then
        return nil
    elseif (node.day) then
        return "day"
    else
        return "night"
    end
end

---@param node Rates.Node.ElectricPower
result.gui_default = function(node)
    ---@type Rates.Gui.NodeDescription
    return {
        icon = { sprite = "tooltip-category-electricity" },
        name = { "sw-rates-node.electric-power" },
        number_format = { factor = 1, unit = "W" },
    }
end

return result
