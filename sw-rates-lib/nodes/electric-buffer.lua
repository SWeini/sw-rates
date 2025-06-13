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
    ---@type Rates.Gui.NodeDescription
    return {
        icon = { sprite = "virtual-signal/signal-battery-full" },
        name = { "sw-rates-node.electric-buffer" },
        number_format = { factor = 1e6, unit = "J" },
    }
end

return result
