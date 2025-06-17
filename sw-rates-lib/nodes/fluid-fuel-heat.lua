do
    --- Energy provided by fluid with temperature above its default temperature.
    ---@class (exact) Rates.Node.FluidFuelHeat : Rates.Node.Base
    ---@field type "fluid-fuel-heat"
    ---@field fluid LuaFluidPrototype
end

local creator = {} ---@class Rates.Node.Creator
local result = { type = "fluid-fuel-heat", creator = creator } ---@type Rates.Node.Type

---@param fluid LuaFluidPrototype
---@return Rates.Node.FluidFuelHeat
creator.fluid_fuel_heat = function(fluid)
    return {
        fluid = fluid
    }
end

---@param node Rates.Node.FluidFuelHeat
result.gui_default = function(node)
    ---@type Rates.Gui.NodeDescription
    return {
        element = { type = "fluid", name = node.fluid.name },
        number_format = { factor = 1, unit = "W" },
    }
end

return result
