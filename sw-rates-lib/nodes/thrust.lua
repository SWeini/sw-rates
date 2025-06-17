do
    --- Thrust of space platforms.
    ---@class (exact) Rates.Node.Thrust : Rates.Node.Base
    ---@field type "thrust"
end

local creator = {} ---@class Rates.Node.Creator
local result = { type = "thrust", creator = creator } ---@type Rates.Node.Type

---@return Rates.Node.Thrust
creator.thrust = function()
    return {}
end

---@param node Rates.Node.Thrust
result.gui_default = function(node)
    ---@type Rates.Gui.NodeDescription
    return {
        icon = { sprite = "tooltip-category-thrust" },
        name = { "sw-rates-node.thrust" },
        number_format = { factor = 1, unit = "N" }
    }
end

return result
