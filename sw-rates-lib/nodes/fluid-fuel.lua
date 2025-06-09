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

---@param node Rates.Node.FluidFuel
result.gui_text = function(node, options)
    return { "", "[img=tooltip-category-fuel] fluid fuel" }
end

---@param node Rates.Node.FluidFuel
result.gui_number_format = function(node)
    return { factor = 1e6, unit = "W" }
end

return result
