local logic = { type = "valve" } ---@type Rates.Configuration.Type

logic.affects_entity = function(prototype)
    return prototype.type == "valve"
end

logic.analyze_flow = function(entity, prototype, inputs)
    if (prototype.type ~= "valve") then
        return
    end

    local result = {} ---@type Rates.Analyzer.EntityOutputs

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
