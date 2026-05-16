do
    ---@class (exact) Rates.Configuration.Generator : Rates.Configuration.Base
    ---@field type "generator"
    ---@field entity LuaEntityPrototype
    ---@field quality LuaQualityPrototype
    ---@field fluid? LuaFluidPrototype
    ---@field temperature number
end

do
    ---@class (exact) Rates.Configuration.Annotation.GeneratorInputFluidUnknown : Rates.Configuration.Annotation.Base
    ---@field type "generator/input-fluid-unknown"
end

do
    ---@class (exact) Rates.Configuration.Annotation.GeneratorInputFluidTemperatureUnknown : Rates.Configuration.Annotation.Base
    ---@field type "generator/input-fluid-temperature-unknown"
end

local configuration = require("scripts.configuration-util")
local node = require("scripts.node")
local progression = require("scripts.progression")
local generated_temperatures = require("scripts.generated-temperatures")

local logic = { type = "generator" } ---@type Rates.Configuration.Type

local entities = configuration.get_all_entities("generator")

---@param prototype LuaEntityPrototype
---@return { input: LuaFluidPrototype? }
local function get_fluids(prototype)
    local fluidbox = prototype.fluidbox_prototypes
    local input_fluid = fluidbox[1].filter
    return { input = input_fluid }
end

---@param conf Rates.Configuration.Generator
logic.get_id = function(conf)
    return (conf.fluid and conf.fluid.name or "<no-fluid>") .. tostring(conf.temperature)
end

---@param conf Rates.Configuration.Generator
logic.gui_recipe = function(conf)
    ---@type Rates.Gui.NodeDescription
    return {
        icon = { sprite = "tooltip-category-electricity" },
        name = { "sw-rates-node.electric-power" }
    }
end

---@param conf Rates.Configuration.Generator
logic.get_production = function(conf, result, options)
    local fluid = conf.fluid

    if (fluid == nil or conf.entity.scale_fluid_usage) then
        return
    end

    local amount = conf.entity.get_fluid_usage_per_tick(conf.quality) * 60

    result[#result + 1] = {
        tag = "energy-source-input",
        node = node.create.fluid(fluid, conf.temperature),
        amount = -amount
    }

    local temperature = conf.temperature
    if (conf.entity.maximum_temperature and temperature > conf.entity.maximum_temperature) then
        temperature = conf.entity.maximum_temperature
    end

    local energy_per_fluid ---@type number
    if (conf.entity.burns_fluid) then
        energy_per_fluid = fluid.fuel_value
    else
        energy_per_fluid = (temperature - fluid.default_temperature) * fluid.heat_capacity
    end

    if (energy_per_fluid <= 0) then
        return
    end

    local energy = amount * energy_per_fluid

    result[#result + 1] = {
        tag = "product",
        node = node.create.electric_power(),
        amount = energy * conf.entity.effectivity
    }
end

logic.gui_annotation = function(annotation, conf)
    if (annotation.type == "generator/input-fluid-unknown") then
        ---@type Rates.Gui.AnnotationDescription
        return {
            text = { "sw-rates-annotation.generator-input-fluid-unknown" },
            severity = "error"
        }
    elseif (annotation.type == "generator/input-fluid-temperature-unknown") then
        local fluids = get_fluids(conf.entity)
        ---@type Rates.Gui.AnnotationDescription
        return {
            text = { "sw-rates-annotation.generator-input-fluid-temperature-unknown", "[fluid=" .. fluids.input.name .. "]", { "", conf.temperature, " ", { "si-unit-degree-celsius" } } },
            severity = "information"
        }
    end
end

logic.fill_progression = function(result, options)
    for _, entity in pairs(entities) do
        local fluids = get_fluids(entity)
        local id = "generator/" .. entity.name .. "/*"
        result[id] = {
            pre = {
                progression.create.map_entity(entity.name, "*"),
                progression.create.fluid(fluids.input.name, {}, "*") -- TODO: temp must be above default
            },
            post = {
                progression.create.electric_power("*")
            },
            multi = options.locations
        }
    end
end

---@param result Rates.Configuration.Generator[]
logic.fill_basic_configurations = function(result, options)
    for _, entity in pairs(entities) do
        local fluids = get_fluids(entity)
        local temperatures = generated_temperatures.get_generated_fluid_temperatures(fluids.input)
        for _, temperature in ipairs(temperatures) do
            result[#result + 1] = {
                type = nil, ---@diagnostic disable-line: assign-type-mismatch
                entity = entity,
                quality = prototypes.quality.normal,
                temperature = temperature
            }
        end
    end
end

logic.get_from_entity = function(entity, options)
    if (options.type ~= "generator") then
        return
    end

    local fluids = get_fluids(options.entity)
    local temperature = options.entity.maximum_temperature or fluids.input.default_temperature
    local temperature_set = false
    local configured_fluid = fluids.input
    if (entity.type ~= "entity-ghost") then
        local fluid = entity.fluidbox[1]
        if (fluid) then
            temperature = fluid.temperature --[[@as number]]
            temperature_set = true
            if (configured_fluid == nil) then
                configured_fluid = prototypes.fluid[fluid.name]
            end
        end
    end

    local annotations = nil ---@type Rates.Configuration.Annotation[]?
    if (not fluids.input and not configured_fluid) then
        annotations = { { type = "generator/input-fluid-unknown" } }
    elseif (not temperature_set and not options.entity.burns_fluid) then
        annotations = { { type = "generator/input-fluid-temperature-unknown" } }
    end

    if (options.analyzer_inputs) then
        local fluid_boxes = options.analyzer_inputs.fluid_boxes
        if (fluid_boxes) then
            local fb1 = fluid_boxes[1]
            if (fb1) then
                local first_id, first_temp = next(fb1)
                if (first_id and next(fb1, first_id) == nil) then
                    ---@cast first_temp -nil
                    configured_fluid = first_temp.fluid
                    temperature = first_temp.temperature
                    annotations = nil
                end
            end
        end
    end

    -- TODO: return all possible temperatures

    ---@type Rates.Configuration.Generator
    return {
        type = nil, ---@diagnostic disable-line: assign-type-mismatch
        entity = options.entity,
        quality = options.quality,
        fluid = configured_fluid,
        temperature = temperature,
        annotations = annotations
    }
end

logic.analyze_flow = function(entity, prototype, inputs)
    if (prototype.type ~= "generator") then
        return
    end

    ---@type Rates.Analyzer.EntityOutputs
    return {
        required_fluid_box_inputs = { [1] = "once" }
    }
end

return logic
