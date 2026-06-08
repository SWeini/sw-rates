do
    ---@class (exact) Rates.Configuration.FusionReactor : Rates.Configuration.Base
    ---@field type "fusion-reactor"
    ---@field entity LuaEntityPrototype
    ---@field quality LuaQualityPrototype
    ---@field neighbours number
end

local configuration = require("scripts.configuration-util")
local node = require("scripts.node")
local progression = require("scripts.progression")

local logic = { type = "fusion-reactor" } ---@type Rates.Configuration.Type

local entities = configuration.get_all_entities("fusion-reactor")

---@param prototype LuaEntityPrototype
---@return { input: LuaFluidPrototype, output: LuaFluidPrototype }
local function get_fluids(prototype)
    local fluidbox = prototype.fluidbox_prototypes
    local input_fluid = fluidbox[#fluidbox - 1].filter --[[@as LuaFluidPrototype]]
    local output_fluid = fluidbox[#fluidbox].filter --[[@as LuaFluidPrototype]]
    return { input = input_fluid, output = output_fluid }
end

---@param entity LuaEntity
---@param use_ghosts boolean
---@return integer
local function count_neighbours(entity, use_ghosts)
    local result = 0
    for _, connection in ipairs(entity.neighbour_connectable_connections) do
        if (connection.first and connection.target) then
            if (use_ghosts or connection.target_real) then
                result = result + 1
            end
        end
    end

    return result
end

---@param conf Rates.Configuration.FusionReactor
logic.get_id = function(conf)
    return tostring(conf.neighbours)
end

---@param conf Rates.Configuration.FusionReactor
logic.gui_recipe = function(conf)
    local fluids = get_fluids(conf.entity)
    ---@type Rates.Gui.NodeDescription
    return {
        element = { type = "fluid", name = fluids.output.name }
    }
end

---@param conf Rates.Configuration.FusionReactor
logic.gui_entity = function(conf)
    ---@type Rates.Gui.NodeDescription
    return {
        element = { type = "entity-with-quality", name = conf.entity.name, quality = conf.quality.name },
        qualifier = configuration.create_qualifier_neighbours(conf.neighbours)
    }
end

logic.get_production = function(conf, result, options)
    local fluids = get_fluids(conf.entity)
    local target_temperature = conf.entity.target_temperature or fluids.output.default_temperature
    local energy_per_fluid = fluids.output.heat_capacity * target_temperature
    local flow = conf.entity.get_fluid_usage_per_tick(conf.quality)
    local burner_energy_usage = flow * energy_per_fluid
    local energy_usage = conf.entity.get_max_energy_usage(conf.quality)

    local neighbour_bonus = conf.entity.neighbour_bonus
    local output_temperature = target_temperature * (1 + conf.neighbours * neighbour_bonus)
    if (output_temperature > fluids.output.max_temperature) then
        output_temperature = fluids.output.max_temperature
    end

    configuration.calculate_energy_source(result, conf.entity, burner_energy_usage, options)
    result[#result + 1] = {
        tag = "energy-source-input",
        tag_extra = "fusion-reactor",
        node = node.create.electric_power(),
        amount = -energy_usage * 60
    }

    result[#result + 1] = {
        tag = "ingredient",
        node = node.create.fluid(fluids.input, {}),
        amount = -flow * 60
    }
    result[#result + 1] = {
        tag = "product",
        node = node.create.fluid(fluids.output, output_temperature),
        amount = flow * 60
    }
end

logic.fill_generated_temperatures = function(result)
    for _, entity in pairs(entities) do
        local neighbour_bonus = entity.neighbour_bonus
        local fluid = get_fluids(entity).output
        local max_neighbours = #entity.neighbour_connectable.connections
        local target_temperature = entity.target_temperature or fluid.default_temperature
        for i = 0, max_neighbours do
            local temperature = target_temperature * (1 + neighbour_bonus * i)
            if (temperature > fluid.max_temperature) then
                temperature = fluid.max_temperature
            end

            configuration.add_fluid_temperature(result.fluids, fluid, temperature)
        end
    end
end

logic.fill_progression = function(result, options)
    for _, entity in pairs(entities) do
        local fluids = get_fluids(entity)
        local target_temperature = entity.target_temperature or fluids.output.default_temperature
        local id = "fusion-reactor/" .. entity.name .. "/*"
        result[id] = {
            pre = {
                progression.create.map_entity(entity.name, "*"),
                progression.create.energy_source(entity, "*"),
                progression.create.electric_power("*"),
                progression.create.fluid(fluids.input.name, {}, "*")
            },
            post = {
                progression.create.fluid(fluids.output.name, target_temperature, "*")
            },
            multi = options.locations
        }

        progression.add_burner(result, entity, {
            progression.create.electric_power("*"),
            progression.create.fluid(fluids.input.name, {}, "*")
        }, "*").multi = options.locations
    end
end

---@param result Rates.Configuration.FusionReactor[]
logic.fill_basic_configurations = function(result, options)
    for _, entity in pairs(entities) do
        result[#result + 1] = {
            type = nil, ---@diagnostic disable-line: assign-type-mismatch
            entity = entity,
            quality = prototypes.quality.normal,
            neighbours = 0
        }
    end
end

logic.get_from_entity = function(entity, options)
    if (options.type ~= "fusion-reactor") then
        return
    end

    local neighbours = count_neighbours(entity, options.use_ghosts)

    ---@type Rates.Configuration.FusionReactor
    return {
        type = nil, ---@diagnostic disable-line: assign-type-mismatch
        entity = options.entity,
        quality = options.quality,
        neighbours = neighbours
    }
end

logic.analyze_flow = function(entity, prototype, inputs)
    if (prototype.type ~= "fusion-reactor") then
        return
    end

    local neighbours = count_neighbours(entity, true)

    local fluids = get_fluids(prototype)
    local target_temperature = prototype.target_temperature or fluids.output.default_temperature

    local neighbour_bonus = prototype.neighbour_bonus
    local output_temperature = target_temperature * (1 + neighbours * neighbour_bonus)
    if (output_temperature > fluids.output.max_temperature) then
        output_temperature = fluids.output.max_temperature
    end

    ---@type Rates.Analyzer.EntityOutputs
    return {
        fluid_box_outputs = {
            [2] = configuration.build_fluid_set(fluids.output, output_temperature)
        }
    }
end

return logic
