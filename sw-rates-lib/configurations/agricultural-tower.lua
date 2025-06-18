do
    ---@class (exact) Rates.Configuration.AgriculturalTower : Rates.Configuration.Base
    ---@field type "agricultural-tower"
    ---@field entity LuaEntityPrototype
    ---@field quality LuaQualityPrototype
    ---@field seed LuaItemPrototype
    ---@field seed_quality LuaQualityPrototype
end

local configuration = require("scripts.configuration-util")
local configuration_api = require("scripts.configuration")
local node = require("scripts.node")
local progression = require("scripts.progression")

local logic = { type = "agricultural-tower" } ---@type Rates.Configuration.Type

local entities = configuration.get_all_entities("agricultural-tower")
local seeds = prototypes.get_item_filtered { { filter = "plant-result" } }

---@param entity LuaEntityPrototype
---@return table<string, LuaItemPrototype>
local function get_accepted_seeds(entity)
    if (entity.accepted_seeds) then
        local accepted_seeds = {} ---@type table<string, LuaItemPrototype>
        for _, seed in ipairs(entity.accepted_seeds) do
            accepted_seeds[seed] = prototypes.item[seed]
        end

        return accepted_seeds
    else
        return seeds
    end
end

---@param surface LuaSurface
---@param seed LuaItemPrototype
---@return boolean
local function can_plant_seed(surface, seed)
    local plant = seed.plant_result ---@cast plant -nil

    if (not configuration.has_surface_conditions(surface, plant.surface_conditions)) then
        return false
    end

    return true
end

---@param entity LuaEntity
---@param x integer
---@param y integer
---@param tile_restriction table<string, true>?
---@param plant LuaEntityPrototype
---@return boolean
local function is_cell_compatible(entity, x, y, tile_restriction, plant)
    local surface = entity.surface
    local force = entity.force
    if (tile_restriction) then
        for dx = -1, 1 do
            for dy = -1, 1 do
                local tile = surface.get_tile(x + dx, y + dy)
                local name = tile.name
                local ghosts = tile.get_tile_ghosts(force)
                if (#ghosts > 0) then
                    name = ghosts[#ghosts].ghost_name
                end
                if (not (tile_restriction[name])) then
                    return false
                end
            end
        end
    end

    return true
end

---@param entity LuaEntity
---@param seed LuaItemPrototype
---@return boolean
local function has_compatible_cell(entity, seed)
    local plant = seed.plant_result ---@cast plant -nil
    local tile_restriction = nil ---@type table<string, true>?
    if (plant.autoplace_specification.tile_restriction) then
        tile_restriction = {}
        for _, restriction in ipairs(plant.autoplace_specification.tile_restriction) do
            tile_restriction[restriction.first] = true
        end
    end

    -- TODO: configurable grid size of agricultural tower
    local px = entity.position.x - 0.5
    local py = entity.position.y - 0.5
    for x = -3, 3 do
        for y = -3, 3 do
            if (is_cell_compatible(entity, px + 3 * x, py + 3 * y, tile_restriction, plant)) then
                return true
            end
        end
    end

    return false
end

---@param conf Rates.Configuration.AgriculturalTower
logic.get_id = function(conf)
    return conf.seed.name .. "(" .. conf.seed_quality.name .. ")"
end

---@param conf Rates.Configuration.AgriculturalTower
logic.gui_recipe = function(conf)
    local plant_result = conf.seed.plant_result ---@cast plant_result -nil
    ---@type Rates.Gui.NodeDescription
    return {
        element = { type = "entity", name = plant_result.name }
    }
end

---@param conf Rates.Configuration.AgriculturalTower
logic.get_production = function(conf, result, options)
    local plant_result = conf.seed.plant_result ---@cast plant_result -nil
    local num_tiles = 7 * 7 - 1

    result[#result + 1] = {
        tag = "infrastructure",
        node = node.create.agricultural_cell(plant_result),
        amount = -num_tiles
    }

    local duration = plant_result.growth_ticks / 60
    local frequency = num_tiles / duration

    local energy_usage = conf.entity.get_max_energy_usage(conf.quality)
    configuration.calculate_energy_source(result, conf.entity, energy_usage, options)

    result[#result + 1] = {
        tag = "ingredient",
        node = node.create.item(conf.seed, conf.seed_quality),
        amount = -frequency
    }

    configuration.calculate_products(result, prototypes.quality.normal, plant_result.mineable_properties.products or {},
        frequency, 0, nil)
end

---@param result Rates.Configuration.AgriculturalTower[]
logic.fill_basic_configurations = function(result, options)
    for _, entity in pairs(entities) do
        local accepted_seeds = get_accepted_seeds(entity)
        for _, seed in pairs(accepted_seeds) do
            result[#result + 1] = {
                type = nil, ---@diagnostic disable-line: assign-type-mismatch
                entity = entity,
                quality = prototypes.quality.normal,
                seed = seed,
                seed_quality = prototypes.quality.normal
            }
        end
    end
end

logic.get_from_entity = function(entity, options)
    if (options.type ~= "agricultural-tower") then
        return
    end

    local possible_seeds = {} ---@type LuaItemPrototype[]
    for _, seed in pairs(get_accepted_seeds(options.entity)) do
        if (can_plant_seed(entity.surface, seed)) then
            possible_seeds[#possible_seeds + 1] = seed
        end
    end

    if (#possible_seeds == 0) then
        return
    end

    local preferred_seeds ---@type LuaItemPrototype[]
    if (#possible_seeds == 1) then
        preferred_seeds = possible_seeds
    else
        preferred_seeds = {}
        for _, seed in ipairs(possible_seeds) do
            if (has_compatible_cell(entity, seed)) then
                preferred_seeds[#preferred_seeds + 1] = seed
            end
        end

        if (#preferred_seeds == 0) then
            preferred_seeds = possible_seeds
        end
    end

    if (#preferred_seeds == 1) then
        ---@type Rates.Configuration.AgriculturalTower
        return {
            type = nil, ---@diagnostic disable-line: assign-type-mismatch
            entity = options.entity,
            quality = options.quality,
            seed = preferred_seeds[1],
            seed_quality = prototypes.quality.normal
        }
    end

    local children = {} ---@type Rates.Configuration[]
    for _, seed in ipairs(preferred_seeds) do
        ---@type Rates.Configuration.AgriculturalTower
        local child = {
            type = "agricultural-tower",
            entity = options.entity,
            quality = options.quality,
            seed = seed,
            seed_quality = prototypes.quality.normal
        }
        children[#children + 1] = child
    end

    ---@type Rates.Configuration.Meta
    return {
        type = "meta",
        children = children
    }
end

return logic
