local configuration = require("scripts.configuration-util")
local generated_temperatures = require("scripts.generated-temperatures")

local logic = { type = "pump" } ---@type Rates.Configuration.Type

logic.affects_entity = function(prototype)
    return prototype.type == "pump"
end

logic.analyze_flow = function(entity, prototype, inputs)
    if (prototype.type ~= "pump") then
        return
    end

    local result = {} ---@type Rates.Analyzer.EntityOutputs

    local filter = entity.get_fluid_filter(1)
    if (filter) then
        local fluid = filter.fluid --[[@as LuaFluidPrototype]]
        if (fluid) then
            local temperatures = generated_temperatures.get_generated_fluid_temperatures(fluid)
            if (#temperatures == 1) then
                result.fluid_box_outputs = { [1] = configuration.build_fluid_set(fluid, temperatures[1]) }
                return result
            end
        end
    end

    result.required_fluid_box_inputs = { [1] = "on-change" }
    result.fluid_box_outputs = { [1] = {} }

    if (inputs.fluid_boxes) then
        local fb = inputs.fluid_boxes[1]
        if (fb) then
            local set = {} ---@type Rates.Analyzer.FluidSet
            for id, fluid in pairs(fb) do
                set[id] = fluid
            end
            result.fluid_box_outputs = { [1] = set }
        end
    end

    return result
end

return logic
