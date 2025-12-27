do
    ---@class (exact) Rates.Configuration.Boiler : Rates.Configuration.Base
    ---@field type "boiler"
    ---@field entity LuaEntityPrototype
    ---@field quality LuaQualityPrototype
    ---@field temperature number
end

do
    ---@class (exact) Rates.Configuration.Annotations.BoilerInputFluidTemperatureUnknown : Rates.Configuration.Annotation.Base
    ---@field type "boiler/input-fluid-temperature-unknown"
end

do
    ---@class (exact) Rates.Configuration.Annotations.BoilerInputFluidTemperatureTooHigh : Rates.Configuration.Annotation.Base
    ---@field type "boiler/input-fluid-temperature-too-high"
    ---@field fluid LuaFluidPrototype
    ---@field temperature number
    ---@field max_temperature number
end

local configuration = require("scripts.configuration-util")
local node = require("scripts.node")
local progression = require("scripts.progression")

local logic = { type = "boiler" } ---@type Rates.Configuration.Type

local entities = configuration.get_all_entities("boiler")

---@param prototype LuaEntityPrototype
---@return { input: LuaFluidPrototype, output: LuaFluidPrototype }
local function get_fluids(prototype)
    local fluidbox = prototype.fluidbox_prototypes
    local input_fluid = fluidbox[#fluidbox - 1].filter --[[@as LuaFluidPrototype]]
    local output_fluid = fluidbox[#fluidbox].filter --[[@as LuaFluidPrototype]]
    return { input = input_fluid, output = output_fluid }
end

---@param prototype LuaEntityPrototype
---@return boolean
local function is_supported(prototype)
    if (prototype.boiler_mode == "output-to-separate-pipe") then
        local fluids = get_fluids(prototype)
        if (fluids.input and fluids.output) then
            return true
        end
    end

    return false
end

---@param conf Rates.Configuration.Boiler
logic.get_id = function(conf)
    return tostring(conf.temperature)
end

---@param conf Rates.Configuration.Boiler
logic.gui_recipe = function(conf)
    local fluid = get_fluids(conf.entity).output
    ---@type Rates.Gui.NodeDescription
    return {
        element = { type = "fluid", name = fluid.name }
    }
end

local use_legacy_boiler_mechanics = helpers.compare_versions(helpers.game_version, "2.0.63") < 0

---@param conf Rates.Configuration.Boiler
logic.get_production = function(conf, result, options)
    local fluids = get_fluids(conf.entity)
    local input_temperature = conf.temperature
    local output_temperature = conf.entity.target_temperature --[[@as number]]

    if (input_temperature >= output_temperature) then
        if (options.annotations) then
            options.annotations[#options.annotations + 1] = {
                type = "boiler/input-fluid-temperature-too-high",
                fluid = fluids.input,
                temperature = input_temperature,
                max_temperature = output_temperature
            } --[[@as Rates.Configuration.Annotations.BoilerInputFluidTemperatureTooHigh]]
        end
        return
    end

    local energy_usage = conf.entity.get_max_energy_usage(conf.quality)
    configuration.calculate_energy_source(result, conf.entity, energy_usage, options)

    local energy_value_in = (output_temperature - input_temperature) * fluids.input.heat_capacity
    local amount_in = energy_usage * 60 / energy_value_in
    local amount_out
    if (use_legacy_boiler_mechanics) then
        local energy_value_out = (output_temperature - fluids.output.default_temperature) * fluids.output.heat_capacity
        amount_out = energy_usage * 60 / energy_value_out
    else
        amount_out = amount_in * (fluids.input.heat_capacity / fluids.output.heat_capacity)
    end
    result[#result + 1] = {
        tag = "ingredient",
        node = node.create.fluid(fluids.input, input_temperature),
        amount = -amount_in
    }
    result[#result + 1] = {
        tag = "product",
        node = node.create.fluid(fluids.output, output_temperature),
        amount = amount_out
    }
end

logic.gui_annotation = function(annotation, conf)
    if (annotation.type == "boiler/input-fluid-temperature-unknown") then
        local fluids = get_fluids(conf.entity)
        ---@type Rates.Gui.AnnotationDescription
        return {
            text = { "sw-rates-annotation.boiler-input-fluid-temperature-unknown",
                "[fluid=" .. fluids.input.name .. "]",
                { "", conf.temperature, " ", { "si-unit-degree-celsius" } }
            },
            severity = "information"
        }
    elseif (annotation.type == "boiler/input-fluid-temperature-too-high") then
        ---@cast annotation Rates.Configuration.Annotations.BoilerInputFluidTemperatureTooHigh
        ---@type Rates.Gui.AnnotationDescription
        return {
            text = { "sw-rates-annotation.boiler-input-fluid-temperature-too-high",
                "[fluid=" .. annotation.fluid.name .. "]",
                { "", annotation.temperature,     " ", { "si-unit-degree-celsius" } },
                { "", annotation.max_temperature, " ", { "si-unit-degree-celsius" } }
            },
            severity = "error"
        }
    end
end

logic.fill_generated_temperatures = function(result)
    for _, entity in pairs(entities) do
        if (is_supported(entity)) then
            local fluid = get_fluids(entity)
            configuration.add_fluid_temperature(result.fluids, fluid.output, entity.target_temperature)
        end
    end
end

logic.fill_progression = function(result, options)
    for _, entity in pairs(entities) do
        if (is_supported(entity)) then
            local fluid = get_fluids(entity)
            local id = "boiler/" .. entity.name .. "/*"
            result[id] = {
                pre = {
                    progression.create.map_entity(entity.name, "*"),
                    progression.create.fluid(fluid.input.name, {}, "*"),
                    progression.create.energy_source(entity, "*")
                },
                post = {
                    progression.create.fluid(fluid.output.name, entity.target_temperature, "*")
                },
                multi = options.locations
            }

            progression.add_burner(result, entity, {
                progression.create.fluid(fluid.input.name, {}, "*")
            }, "*").multi = options.locations
        end
    end
end

---@param result Rates.Configuration.Boiler[]
logic.fill_basic_configurations = function(result, options)
    for _, entity in pairs(entities) do
        if (is_supported(entity)) then
            local fluid = get_fluids(entity)
            -- TODO: loop over all input temperatures
            result[#result + 1] = {
                type = nil, ---@diagnostic disable-line: assign-type-mismatch
                entity = entity,
                quality = prototypes.quality.normal,
                temperature = fluid.input.default_temperature
            }
        end
    end
end

logic.get_from_entity = function(entity, options)
    if (options.type ~= "boiler") then
        return
    end

    if (not is_supported(options.entity)) then
        return
    end

    local fluid = get_fluids(options.entity)
    local temperature = fluid.input.default_temperature
    local fluidbox = entity.fluidbox[1]
    local annotations = nil ---@type Rates.Configuration.Annotation[]?
    if (fluidbox) then
        temperature = fluidbox.temperature --[[@as number]]
    else
        annotations = {
            { type = "boiler/input-fluid-temperature-unknown" } --[[@as Rates.Configuration.Annotations.BoilerInputFluidTemperatureUnknown]]
        }
    end

    ---@type Rates.Configuration.Boiler
    return {
        type = nil, ---@diagnostic disable-line: assign-type-mismatch
        entity = options.entity,
        quality = options.quality,
        temperature = temperature,
        annotations = annotations
    }
end

return logic
