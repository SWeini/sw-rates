do
    ---@class (exact) Rates.Configuration.BurnerGenerator : Rates.Configuration.Base
    ---@field type "burner-generator"
    ---@field entity LuaEntityPrototype
    ---@field quality LuaQualityPrototype
end

local configuration = require("scripts.configuration-util")
local node = require("scripts.node")
local progression = require("scripts.progression")

local logic = { type = "burner-generator" } ---@type Rates.Configuration.Type

local entities = configuration.get_all_entities("burner-generator")

---@param conf Rates.Configuration.BurnerGenerator
logic.gui_recipe = function(conf)
    ---@type Rates.Gui.NodeDescription
    return {
        icon = { sprite = "tooltip-category-electricity" },
        name = { "sw-rates-node.electric-power" }
    }
end

---@param conf Rates.Configuration.BurnerGenerator
logic.get_production = function(conf, result, options)
    local energy_usage = conf.entity.get_max_energy_usage(conf.quality)
    configuration.calculate_energy_source(result, conf.entity, energy_usage, options.surface)

    result[#result + 1] = {
        tag = "product",
        node = node.create.electric_power(),
        amount = energy_usage * 60
    }
end

logic.fill_progression = function(result, options)
    for _, entity in pairs(entities) do
        local id = "burner-generator/" .. entity.name .. "/*"
        result[id] = {
            pre = {
                progression.create.map_entity(entity.name, "*"),
                progression.create.energy_source(entity, "*")
            },
            post = {
                progression.create.electric_power("*")
            },
            multi = options.locations
        }

        progression.add_burner(result, entity, {}, "*").multi = options.locations
    end
end

---@param result Rates.Configuration.BurnerGenerator[]
logic.fill_basic_configurations = function(result, options)
    for _, entity in pairs(entities) do
        result[#result + 1] = {
            type = nil, ---@diagnostic disable-line: assign-type-mismatch
            entity = entity,
            quality = prototypes.quality.normal,
        }
    end
end

logic.get_from_entity = function(entity, options)
    if (options.type ~= "burner-generator") then
        return
    end

    ---@type Rates.Configuration.BurnerGenerator
    return {
        type = nil, ---@diagnostic disable-line: assign-type-mismatch
        entity = options.entity,
        quality = options.quality
    }
end

return logic
