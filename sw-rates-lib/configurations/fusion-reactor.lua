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
local extra_data = require("scripts.extra-data")
local flib_direction = require("__flib__.direction")
local math2d = require("math2d")

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
---@param connectable data.NeighbourConnectable
---@param i integer
---@param search boolean
---@return { x: number, y: number, direction: defines.direction }, data.MapPosition.struct?
local function get_connection_point(entity, connectable, i, search)
    local search_distance = connectable.neighbour_search_distance or 0.7
    local affected_by_direction = connectable.affected_by_direction ~= false
    local connection = connectable.connections[i]
    local direction = affected_by_direction and entity.direction or defines.direction.north
    local connection_loc = math2d.position.ensure_xy(connection.location.position)
    local connection_pos = flib_direction.to_vector_2d(direction, -connection_loc.y, connection_loc.x) --[[@as data.MapPosition.struct]]
    local connection_dir = (direction + connection.location.direction) % 16 ---@type defines.direction
    connection_pos = math2d.position.add(entity.position, connection_pos)
    local search_pos = nil
    if (search) then
        local search_connection = flib_direction.to_vector(connection_dir, search_distance)
        search_pos = math2d.position.add(connection_pos, search_connection)
    end

    return { x = connection_pos.x, y = connection_pos.y, direction = connection_dir }, search_pos
end

---@param entity LuaEntity
---@param connectable data.NeighbourConnectable
---@param pos { x: number, y: number, direction: defines.direction }
---@return integer?
local function get_connection_at(entity, connectable, pos)
    local opposite = flib_direction.opposite(pos.direction)
    for i = 1, #connectable.connections do
        local point = get_connection_point(entity, connectable, i, false)
        if (point.x == pos.x and point.y == pos.y and point.direction == opposite) then
            return i
        end
    end
end

---@param category data.NeighbourConnectableConnectionCategory
---@param categories data.NeighbourConnectableConnectionCategory[]
---@return boolean
local function is_category_compatible(category, categories)
    for _, cat in ipairs(categories) do
        if (cat == category) then
            return true
        end
    end

    return false
end

---@param a data.NeighbourConnectableConnectionDefinition
---@param b data.NeighbourConnectableConnectionDefinition
---@return boolean
local function is_connection_compatible(a, b)
    if (not is_category_compatible(a.category, b.neighbour_category)) then
        return false
    end

    if (not is_category_compatible(b.category, a.neighbour_category)) then
        return false
    end

    return true
end

---@param entity LuaEntity
---@param use_ghosts boolean
---@return integer
local function count_neighbours(entity, use_ghosts)
    local data = configuration.get_useful_entity_data(entity, use_ghosts) ---@cast data -nil
    local prototype = data.entity

    local neighbours = {}
    local connectable = extra_data.fusion_reactor_neighbour_connectable(prototype)
    for i, connection in ipairs(connectable.connections) do
        local connection_pos, search_pos = get_connection_point(entity, connectable, i, true)
        local candidates = entity.surface.find_entities_filtered({ position = search_pos })
        for _, other in ipairs(candidates) do
            local other_data = configuration.get_useful_entity_data(other, use_ghosts)
            if (other_data and other_data.entity.name == prototype.name) then
                local j = get_connection_at(other, connectable, connection_pos)
                if (j) then
                    if (is_connection_compatible(connection, connectable.connections[j])) then
                        neighbours[other.unit_number] = other
                    end
                end
            end
        end
    end

    local result = 0
    for _, _ in pairs(neighbours) do
        result = result + 1
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
        qualifier = "+" .. conf.neighbours
    }
end

logic.get_production = function(conf, result, options)
    local fluids = get_fluids(conf.entity)
    local target_temperature = conf.entity.target_temperature or fluids.output.default_temperature
    local energy_per_fluid = fluids.output.heat_capacity * target_temperature
    local flow = extra_data.fusion_reactor_max_fluid_usage(conf.entity) * conf.quality.default_multiplier
    local burner_energy_usage = flow * energy_per_fluid
    local energy_usage = conf.entity.get_max_energy_usage(conf.quality)

    local neighbour_bonus = extra_data.fusion_reactor_neighbour_bonus(conf.entity)
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
        local neighbour_bonus = extra_data.fusion_reactor_neighbour_bonus(entity)
        local fluid = get_fluids(entity).output
        local max_neighbours = #extra_data.fusion_reactor_neighbour_connectable(entity).connections
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

return logic
