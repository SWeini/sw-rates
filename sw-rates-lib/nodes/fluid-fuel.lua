do
    --- Energy provided by any fluid with a fuel value.
    ---@class (exact) Rates.Node.FluidFuel : Rates.Node.Base
    ---@field type "fluid-fuel"
end

local creator = {} ---@class Rates.Node.Creator
local result = { type = "fluid-fuel", creator = creator } ---@type Rates.Node.Type

---@return Rates.Node.FluidFuel
creator.fluid_fuel = function()
    return {}
end

---@param node Rates.Node.FluidFuel
result.gui_default = function(node)
    return { sprite = "tooltip-category-fuel" }
end

return result
