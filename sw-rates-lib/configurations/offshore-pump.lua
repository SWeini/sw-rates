do
    ---@class (exact) Rates.Configuration.OffshorePump : Rates.Configuration.Base
    ---@field type "offshore-pump"
    ---@field entity LuaEntityPrototype
    ---@field quality LuaQualityPrototype
    ---@field fluid LuaFluidPrototype
end

local configuration = require("scripts.configuration-util")
local node = require("scripts.node")
local progression = require("scripts.progression")

local logic = { type = "offshore-pump" } ---@type Rates.Configuration.Type

local entities = configuration.get_all_entities("offshore-pump")

---@type table<string, LuaTilePrototype[]>
local fluid_tiles = {}
for _, tile in pairs(prototypes.tile) do
    local fluid = tile.fluid
    if (fluid) then
        local tiles = fluid_tiles[fluid.name]
        if (not tiles) then
            tiles = {}
            fluid_tiles[fluid.name] = tiles
        end
        tiles[#tiles + 1] = tile
    end
end

---@param prototype LuaEntityPrototype
---@return LuaFluidPrototype?
local function get_filtered_fluid(prototype)
    return prototype.fluidbox_prototypes[1].filter
end

---@param conf Rates.Configuration.OffshorePump
logic.get_id = function(conf)
    return conf.fluid.name
end

---@param conf Rates.Configuration.OffshorePump
logic.gui_recipe = function(conf)
    return { sprite = "fluid/" .. conf.fluid.name }
end

---@param conf Rates.Configuration.OffshorePump
logic.get_production = function(conf, result, options)
    configuration.calculate_energy_source(result, conf.entity, conf.entity.energy_usage) -- TODO: check for quality needs
    result[#result + 1] = {
        tag = "product",
        node = node.create.fluid(conf.fluid, conf.fluid.default_temperature),
        amount = conf.entity.pumping_speed * 60
    }
end

logic.fill_generated_temperatures = function(result)
    local has_unfiltered_pump = false
    for _, entity in pairs(entities) do
        local fluid = get_filtered_fluid(entity)
        if (fluid) then
            configuration.add_fluid_temperature(result.fluids, fluid)
        else
            has_unfiltered_pump = true
        end
    end

    if (has_unfiltered_pump) then
        for fluid_name, _ in pairs(fluid_tiles) do
            configuration.add_fluid_temperature(result.fluids, prototypes.fluid[fluid_name])
        end
    end
end

logic.fill_progression = function(result, options)
    for _, entity in pairs(entities) do
        local filter = get_filtered_fluid(entity)
        if (filter) then
            local id = "offshore-pump/" .. entity.name .. "/*"
            result[id] = {
                pre = {
                    progression.create.map_entity(entity.name, "*"),
                    progression.create.energy_source(entity, "*")
                },
                post = {
                    progression.create.fluid(filter.name, filter.default_temperature, "*")
                },
                multi = options.locations
            }

            progression.add_burner(result, entity, {}, "*").multi = options.locations
        else
            for fluid_name, tiles in pairs(fluid_tiles) do
                ---@type Rates.Progression.MultiItemPre
                local nodes = {}
                for _, tile in ipairs(tiles) do
                    nodes[#nodes + 1] = progression.create.map_tile(tile.name, "*")
                end

                local fluid = prototypes.fluid[fluid_name]
                local id = "offshore-pump/" .. entity.name .. "/" .. fluid.name .. "/*"
                result[id] = {
                    pre = {
                        progression.create.map_entity(entity.name, "*"),
                        nodes,
                        progression.create.energy_source(entity, "*")
                    },
                    post = {
                        progression.create.fluid(fluid.name, fluid.default_temperature, "*")
                    },
                    multi = options.locations
                }

                progression.add_burner(result, entity, {
                    nodes
                }, "*", fluid.name).multi = options.locations
            end
        end
    end
end

---@param result Rates.Configuration.OffshorePump[]
logic.fill_basic_configurations = function(result, options)
    for _, entity in pairs(entities) do
        local filter = get_filtered_fluid(entity)
        if (filter) then
            result[#result + 1] = {
                type = nil, ---@diagnostic disable-line: assign-type-mismatch
                id = nil, ---@diagnostic disable-line: assign-type-mismatch
                entity = entity,
                quality = prototypes.quality.normal,
                fluid = filter
            }
        else
            for fluid_name, _ in pairs(fluid_tiles) do
                result[#result + 1] = {
                    type = nil, ---@diagnostic disable-line: assign-type-mismatch
                    id = nil, ---@diagnostic disable-line: assign-type-mismatch
                    entity = entity,
                    quality = prototypes.quality.normal,
                    fluid = prototypes.fluid[fluid_name]
                }
            end
        end
    end
end

logic.get_from_entity = function(entity, options)
    if (options.type ~= "offshore-pump") then
        return
    end

    local fluid = prototypes.fluid[entity.get_fluid_source_fluid()]

    ---@type Rates.Configuration.OffshorePump
    return {
        type = nil, ---@diagnostic disable-line: assign-type-mismatch
        id = nil, ---@diagnostic disable-line: assign-type-mismatch
        entity = options.entity,
        quality = options.quality,
        fluid = fluid
    }
end

return logic
