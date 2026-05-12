local configuration = require("scripts.configuration-util")
local generated_temperatures = require("scripts.generated-temperatures")

local logic = { type = "infinity-pipe" } ---@type Rates.Configuration.Type

local adding_filter_modes = { ["at-least"] = true, ["exactly"] = true, ["add"] = true } ---@type table<string, true>

---@param filter InfinityPipeFilter
---@return boolean
local function filter_can_add_fluid(filter)
    if (not adding_filter_modes[filter.mode]) then
        return false
    end
    return filter.percentage > 0
end

logic.analyze_flow = function(entity, prototype, inputs)
    if (prototype.type ~= "infinity-pipe") then
        return
    end

    local result = {} ---@type Rates.Analyzer.EntityOutputs

    local filter = entity.get_infinity_pipe_filter()
    if (filter and filter_can_add_fluid(filter)) then
        local fluid = prototypes.fluid[filter.name]
        result.fluid_box_outputs = {
            [1] = configuration.build_fluid_set(fluid, filter.temperature or fluid.default_temperature)
        }
    end

    return result
end

return logic
