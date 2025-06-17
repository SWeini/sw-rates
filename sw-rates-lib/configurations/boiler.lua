do
    ---@class (exact) Rates.Configuration.Boiler : Rates.Configuration.Base
    ---@field type "boiler"
    ---@field entity LuaEntityPrototype
    ---@field quality LuaQualityPrototype
    ---@field temperature number
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

---@param conf Rates.Configuration.Boiler
logic.get_production = function(conf, result, options)
    local energy_usage = conf.entity.get_max_energy_usage(conf.quality)
    configuration.calculate_energy_source(result, conf.entity, energy_usage)

    local fluids = get_fluids(conf.entity)
    local input_temperature = conf.temperature
    local output_temperature = conf.entity.target_temperature --[[@as number]]
    local energy_value_in = (output_temperature - input_temperature) * fluids.input.heat_capacity
    local amount_in = energy_usage * 60 / energy_value_in
    local energy_value_out = (output_temperature - fluids.output.default_temperature) * fluids.output.heat_capacity
    local amount_out = energy_usage * 60 / energy_value_out
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

logic.fill_generated_temperatures = function(result)
    for _, entity in pairs(entities) do
        if (entity.boiler_mode == "output-to-separate-pipe") then
            local fluid = get_fluids(entity)
            configuration.add_fluid_temperature(result.fluids, fluid.output, entity.target_temperature)
        end
    end
end

logic.fill_progression = function(result, options)
    for _, entity in pairs(entities) do
        if (entity.boiler_mode == "output-to-separate-pipe") then
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
        if (entity.boiler_mode == "output-to-separate-pipe") then
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

    if (options.entity.boiler_mode ~= "output-to-separate-pipe") then
        return
    end

    local fluid = get_fluids(options.entity)
    local temperature = fluid.input.default_temperature
    local fluidbox = entity.fluidbox[1]
    if (fluidbox) then
        temperature = fluidbox.temperature --[[@as number]]
    end

    ---@type Rates.Configuration.Boiler
    return {
        type = nil, ---@diagnostic disable-line: assign-type-mismatch
        entity = options.entity,
        quality = options.quality,
        temperature = temperature
    }
end

return logic
