do
    ---@class (exact) Rates.Node.Pollution : Rates.Node.Base
    ---@field type "pollution"
    ---@field pollutant LuaAirbornePollutantPrototype
end

local creator = {} ---@class Rates.Node.Creator
local result = { type = "pollution", creator = creator } ---@type Rates.Node.Type

---@param pollutant LuaAirbornePollutantPrototype
---@return Rates.Node.Pollution
creator.pollution = function(pollutant)
    return {
        pollutant = pollutant
    }
end

---@param node Rates.Node.Pollution
result.get_id = function(node)
    return node.pollutant.name
end

---@param node Rates.Node.Pollution
result.gui_default = function(node)
    ---@type Rates.Gui.NodeDescription
    return {
        icon = { sprite = "airborne-pollutant/" .. node.pollutant.name },
        name = node.pollutant.localised_name
    }
end

return result
