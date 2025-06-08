do
    --- A buffer of electric energy, as provided by accumulators.
    ---@class (exact) Rates.Node.AgriculturalCell : Rates.Node.Base
    ---@field type "agricultural-cell"
    ---@field plant LuaEntityPrototype
end

local creator = {} ---@class Rates.Node.Creator
local result = { type = "agricultural-cell", creator = creator } ---@type Rates.Node.Type

---@return Rates.Node.AgriculturalCell
---@param plant LuaEntityPrototype
creator.agricultural_cell = function(plant)
    return {
        plant = plant
    }
end

---@param node Rates.Node.AgriculturalCell
result.get_id = function(node)
    return node.plant.name
end

---@param node Rates.Node.AgriculturalCell
result.gui_default = function(node)
    return { sprite = "entity/" .. node.plant.name }
end

return result
