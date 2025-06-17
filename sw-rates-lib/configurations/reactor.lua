do
    ---@class (exact) Rates.Configuration.Reactor : Rates.Configuration.Base
    ---@field type "reactor"
    ---@field entity LuaEntityPrototype
    ---@field quality LuaQualityPrototype
    ---@field neighbours number
end

local configuration = require("scripts.configuration-util")
local node = require("scripts.node")
local progression = require("scripts.progression")
local math2d = require("math2d")

local logic = { type = "reactor" } ---@type Rates.Configuration.Type

local entities = configuration.get_all_entities("reactor")

---@param entity LuaEntity
---@param use_ghosts boolean
---@return integer
local function count_neighbours(entity, use_ghosts)
    local data = configuration.get_useful_entity_data(entity, use_ghosts)
    if (not data) then
        return 0
    end

    local size = entity.tile_width
    local position = entity.position
    if (entity.tile_height ~= size) then
        error("missing neighbour calculation for non-square reactors")
    end

    local bbox = math2d.bounding_box.create_from_centre(entity.position, size + 2)
    local candidates = entity.surface.find_entities_filtered { area = bbox }
    local result = 0
    for _, other in ipairs(candidates) do
        local other_data = configuration.get_useful_entity_data(other, use_ghosts)
        if (other_data and other_data.entity.name == data.entity.name) then
            if (math2d.position.distance_squared(position, other.position) == size * size) then
                result = result + 1
            end
        end
    end

    return result
end

---@param conf Rates.Configuration.Reactor
logic.get_id = function(conf)
    return tostring(conf.neighbours)
end

---@param conf Rates.Configuration.Reactor
logic.gui_recipe = function(conf)
    ---@type Rates.Gui.NodeDescription
    return {
        icon = { sprite = "tooltip-category-heat" },
        name = { "sw-rates-node.heat" },
        qualifier = { "", conf.entity.heat_buffer_prototype.max_temperature, { "si-unit-degree-celsius" } },
    }
end

---@param conf Rates.Configuration.Reactor
logic.gui_entity = function(conf)
    ---@type Rates.Gui.NodeDescription
    return {
        element = { type = "entity-with-quality", name = conf.entity.name, quality = conf.quality.name },
        qualifier = conf.neighbours ~= 0 and ("+" .. conf.neighbours) or nil
    }
end

---@param conf Rates.Configuration.Reactor
logic.get_production = function(conf, result, options)
    local energy_usage = conf.entity.get_max_energy_usage(conf.quality)
    configuration.calculate_energy_source(result, conf.entity, energy_usage)
    local neighbour_bonus = (conf.entity.neighbour_bonus or 1) * conf.neighbours
    result[#result + 1] = {
        tag = "product",
        node = node.create.heat(conf.entity.heat_buffer_prototype.max_temperature),
        amount = energy_usage * 60 / configuration.energy_factor * (1 + neighbour_bonus)
    }
end

logic.fill_generated_temperatures = function(result)
    for _, entity in pairs(entities) do
        result.heat[entity.heat_buffer_prototype.max_temperature] = true
    end
end

logic.fill_progression = function(result, options)
    for _, entity in pairs(entities) do
        local id = "reactor/" .. entity.name .. "/*"
        result[id] = {
            pre = {
                progression.create.map_entity(entity.name, "*"),
                progression.create.energy_source(entity, "*")
            },
            post = {
                progression.create.heat(entity.heat_buffer_prototype.max_temperature, "*")
            },
            multi = options.locations
        }

        progression.add_burner(result, entity, {}, "*").multi = options.locations
    end
end

---@param result Rates.Configuration.Reactor[]
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
    if (options.type ~= "reactor") then
        return
    end

    local neighbours ---@type number
    if (options.entity.neighbour_bonus and options.entity.neighbour_bonus ~= 0) then
        neighbours = count_neighbours(entity, options.use_ghosts)
    else
        neighbours = 0
    end

    ---@type Rates.Configuration.Reactor
    return {
        type = nil, ---@diagnostic disable-line: assign-type-mismatch
        entity = options.entity,
        quality = options.quality,
        neighbours = neighbours
    }
end

return logic
