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
    return { sprite = "tooltip-category-thrust" }
end

---@param node Rates.Node.Thrust
result.gui_text = function(node, options)
    return { "", "[img=tooltip-category-thrust] ", { "description.thrust" } }
end

---@param node Rates.Node.Thrust
result.gui_number_format = function(node)
    return { factor = 1e6, unit = "N" }
end

return result
