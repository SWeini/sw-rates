do
    --- A buffer of electric energy, as provided by accumulators.
    ---@class (exact) Rates.Node.ElectricBuffer : Rates.Node.Base
    ---@field type "electric-buffer"
end

local creator = {} ---@class Rates.Node.Creator
local result = { type = "electric-buffer", creator = creator } ---@type Rates.Node.Type

---@return Rates.Node.ElectricBuffer
creator.electric_buffer = function()
    return {}
end

---@param node Rates.Node.ElectricBuffer
result.gui_default = function(node)
    return { sprite = "virtual-signal/signal-battery-full" }
end

return result
