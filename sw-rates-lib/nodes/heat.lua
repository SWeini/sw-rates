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
        local node = { type = "heat", temperature = temp }
        node.id = "heat/" .. result.get_id(node)
        nodes[#nodes + 1] = node
    end

    if (#nodes == 1) then
        return nodes[1]
    end

    ---@type Rates.Node.Any.Details.Heat
    local details = {
        type = "any-heat",
        id = nil, ---@diagnostic disable-line: assign-type-mismatch
        min_temperature = temperature.min,
        max_temperature = temperature.max
    }
    details.id = "any-heat/" .. result_any.get_id(details)

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
    return { sprite = "tooltip-category-heat" }
end

---@param node Rates.Node.Any.Details.Heat
result_any.gui_default = function(node)
    return { sprite = "tooltip-category-heat" }
end

---@param node Rates.Node.Heat
result.gui_text = function(node, options)
    return { "", "[img=tooltip-category-heat] ", { "tooltip-category.heat" },
        " (" .. node.temperature .. " ", { "si-unit-degree-celsius" }, ")" }
end

---@param min number?
---@param max number?
---@return LocalisedString
local function format_temperature(min, max)
    if (min and max) then
        return min .. "-" .. max
    elseif (min) then
        return "≥ " .. min
    elseif (max) then
        return "≤ " .. max
    end
end

---@param node Rates.Node.Any.Details.Heat
result_any.gui_text = function(node, options)
    local temperature = format_temperature(node.min_temperature, node.max_temperature)
    if (temperature) then
        return { "", "[img=tooltip-category-heat] ", { "tooltip-category.heat" },
            " (", temperature, " ", { "si-unit-degree-celsius" }, ")" }
    else
        return { "", "[img=tooltip-category-heat] ", { "tooltip-category.heat" } }
    end
end

---@param node Rates.Node.Heat
result.gui_number_format = function(node)
    return { factor = 1e6, unit = "W" }
end

---@param node Rates.Node.Any.Details.Heat
result_any.gui_number_format = function(node)
    return { factor = 1e6, unit = "W" }
end

return { types = { result, result_any } }
