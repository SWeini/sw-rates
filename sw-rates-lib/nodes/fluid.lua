do
    --- A fluid of specific temperature.
    ---@class (exact) Rates.Node.Fluid : Rates.Node.Base
    ---@field type "fluid"
    ---@field fluid LuaFluidPrototype
    ---@field temperature number
end

do
    --- A fluid with a temperature filter.
    ---@class (exact) Rates.Node.Any.Details.Fluid : Rates.Node.Base
    ---@field type "any-fluid"
    ---@field fluid LuaFluidPrototype
    ---@field min_temperature? number
    ---@field max_temperature? number
end

local generated_temperatures = require("scripts.generated-temperatures")

local creator = {} ---@class Rates.Node.Creator
local result = { type = "fluid", creator = creator } ---@type Rates.Node.Type
local result_any = { type = "any-fluid" } ---@type Rates.Node.Type

local temperature_edge = (2 - 2 ^ -23) * 2 ^ 127

---@param fluid LuaFluidPrototype
---@param temperature number | { min: number?,  max: number? }
---@return Rates.Node.Fluid | Rates.Node.Any
creator.fluid = function(fluid, temperature)
    if (type(temperature) == "number") then
        return {
            fluid = fluid,
            temperature = temperature
        }
    end

    if (temperature.min == -temperature_edge) then
        temperature.min = nil
    end
    if (temperature.max == temperature_edge) then
        temperature.max = nil
    end

    local nodes = {} ---@type Rates.Node.Fluid[]
    for _, temp in ipairs(generated_temperatures.get_generated_fluid_temperatures(fluid, temperature)) do
        local node = { type = "fluid", fluid = fluid, temperature = temp }
        node.id = "fluid/" .. result.get_id(node)
        nodes[#nodes + 1] = node
    end

    if (#nodes == 1) then
        return nodes[1]
    end

    ---@type Rates.Node.Any.Details.Fluid
    local details = {
        type = "any-fluid",
        id = nil, ---@diagnostic disable-line: assign-type-mismatch
        fluid = fluid,
        min_temperature = temperature.min,
        max_temperature = temperature.max
    }
    details.id = "any-fluid/" .. result_any.get_id(details)

    return {
        type = "any",
        children = nodes,
        details = details
    }
end

---@param node Rates.Node.Fluid
result.get_id = function(node)
    return node.fluid.name .. "/" .. tostring(node.temperature)
end

---@param node Rates.Node.Any.Details.Fluid
result_any.get_id = function(node)
    local result = node.fluid.name
    if (node.min_temperature) then
        result = result .. "≥" .. node.min_temperature
    end
    if (node.max_temperature) then
        result = result .. "≤" .. node.max_temperature
    end
    return result
end

---@param node Rates.Node.Fluid
result.gui_default = function(node)
    return { sprite = "fluid/" .. node.fluid.name }
end

---@param node Rates.Node.Any.Details.Fluid
result_any.gui_default = function(node)
    return { sprite = "fluid/" .. node.fluid.name }
end

---@param node Rates.Node.Fluid
result.gui_text = function(node, options)
    local temps = generated_temperatures.get_generated_fluid_temperatures(node.fluid)
    if (#temps == 1 and temps[1] == node.temperature) then
        return "[fluid=" .. node.fluid.name .. "]"
    else
        return { "", "[fluid=" .. node.fluid.name .. "] (" .. node.temperature .. " ", { "si-unit-degree-celsius" }, ")" }
    end
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

---@param node Rates.Node.Any.Details.Fluid
result_any.gui_text = function(node, options)
    local temperature = format_temperature(node.min_temperature, node.max_temperature)
    if (temperature) then
        return { "", "[fluid=" .. node.fluid.name .. "] (", temperature, " ", { "si-unit-degree-celsius" }, ")" }
    else
        return { "", "[fluid=" .. node.fluid.name .. "]" }
    end
end

return { types = { result, result_any } }
