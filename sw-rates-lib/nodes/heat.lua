do
    --- Energy provided by heat of specific temperature.
    ---@class (exact) Rates.Node.Heat : Rates.Node.Base
    ---@field type "heat"
    ---@field temperature number
end

do
    --- Energy provided by heat with a temperature filter.
    ---@class (exact) Rates.Node.Any.Details.Heat : Rates.Node.Base
    ---@field type "any-heat"
    ---@field min_temperature? number
    ---@field max_temperature? number
end

local generated_temperatures = require("scripts.generated-temperatures")

local creator = {} ---@class Rates.Node.Creator
local result = { type = "heat", creator = creator } ---@type Rates.Node.Type
local result_any = { type = "any-heat" } ---@type Rates.Node.Type

---@param temperature number | { min: number?, max: number? }
---@return Rates.Node.Heat | Rates.Node.Any
creator.heat = function(temperature)
    if (type(temperature) == "number") then
        return {
            temperature = temperature
        }
    end

    local nodes = {} ---@type Rates.Node.Heat[]
    for _, temp in ipairs(generated_temperatures.get_generated_heat_temperatures(temperature)) do
        nodes[#nodes + 1] = { type = "heat", temperature = temp }
    end

    if (#nodes == 1) then
        return nodes[1]
    end

    ---@type Rates.Node.Any.Details.Heat
    local details = {
        type = "any-heat",
        min_temperature = temperature.min,
        max_temperature = temperature.max
    }

    return {
        type = "any",
        children = nodes,
        details = details
    }
end

---@param node Rates.Node.Heat
result.get_id = function(node)
    return tostring(node.temperature)
end

---@param node Rates.Node.Any.Details.Heat
result_any.get_id = function(node)
    local result = ""

    if (node.min_temperature) then
        result = result .. "≥" .. node.min_temperature
    end

    if (node.max_temperature) then
        result = result .. "≤" .. node.max_temperature
    end
    
    return result
end

---@param node Rates.Node.Heat
result.gui_default = function(node)
    ---@type Rates.Gui.NodeDescription
    return {
        icon = { sprite = "tooltip-category-heat" },
        name = { "sw-rates-node.heat" },
        qualifier = { "", node.temperature, { "si-unit-degree-celsius" } },
        number_format = { factor = 1, unit = "W" },
    }
end

---@param min number?
---@param max number?
---@return LocalisedString
local function format_any_temperature(min, max)
    if (min and max) then
        return { "", min, { "si-unit-degree-celsius" }, "-", max, { "si-unit-degree-celsius" } }
    elseif (min) then
        return { "", "≥", min, { "si-unit-degree-celsius" } }
    elseif (max) then
        return { "", "≤", max, { "si-unit-degree-celsius" } }
    end
end

---@param node Rates.Node.Any.Details.Heat
result_any.gui_default = function(node)
    ---@type Rates.Gui.NodeDescription
    return {
        icon = { sprite = "tooltip-category-heat" },
        name = { "sw-rates-node.heat" },
        qualifier = format_any_temperature(node.min_temperature, node.max_temperature),
        number_format = { factor = 1, unit = "W" },
    }
end

return { types = { result, result_any } }
