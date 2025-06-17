do
    ---@class Rates.Configuration.PyDigsite : Rates.Configuration.Base
    ---@field type "py-digsite"
    ---@field entity LuaEntityPrototype
    ---@field quality LuaQualityPrototype
    ---@field module_effects Rates.Configuration.ModuleEffects
    ---@field food LuaItemPrototype
    ---@field food_quality LuaQualityPrototype
end

local api = require("__sw-rates-lib__.api-configuration")
local configuration = api.configuration
local node = api.node
local progression = api.progression

local logic = { type = "py-digsite", stats = { priority = 100 } } ---@type Rates.Configuration.Type

---@type { [string]: { amount: number, ticks: number } }
local dig_creatures = {
    ["digosaurus"] = { amount = 1, ticks = 15 * 30 },
    ["thikat"] = { amount = 2, ticks = 4 * 49 * 2 },
    ["work-o-dile"] = { amount = 3, ticks = 8 * 49 * 2 },
}

---@type { [string]: number }
local food_types = {
    ["dried-meat"] = 1,
    ["guts"] = 1,
    ["meat"] = 2,
    ["workers-food"] = 8,
    ["workers-food-02"] = 16,
    ["workers-food-03"] = 32,
}

---@param inventory  LuaInventory
---@return LuaItemPrototype?, LuaQualityPrototype?
local function get_food_from_inventory(inventory)
    for i = 1, #inventory do
        local stack = inventory[i]
        if (stack.valid and stack.count > 0 and food_types[stack.name]) then
            return prototypes.item[stack.name], stack.quality
        end
    end
end

---@param conf Rates.Configuration.PyDigsite
logic.get_id = function(conf)
    return conf.food.name .. "(" .. conf.food_quality.name .. ")"
end

---@param conf Rates.Configuration.PyDigsite
logic.gui_recipe = function(conf)
    ---@type Rates.Gui.NodeDescription
    return {
        element = { type = "entity", name = "ore-nexelit" }
    }
end

---@param conf Rates.Configuration.PyDigsite
logic.get_production = function(conf, result, options)
    configuration.calculate_energy_source(result, conf.entity, conf.entity.energy_usage)
    local resource = 0
    local ore = 0
    local food = 0
    for _, module in ipairs(conf.module_effects.modules) do
        local creature = dig_creatures[module.module.name]
        if (creature) then
            local frequency = 60 / creature.ticks
            food = food + module.count * frequency
            resource = resource + module.count * frequency
            ore = ore + module.count * creature.amount * food_types[conf.food.name] * frequency
        end
    end
    result[#result + 1] = {
        tag = "resource",
        node = node.create.map_entity(prototypes.entity["ore-nexelit"], prototypes.quality["normal"]),
        amount = -resource
    }
    result[#result + 1] = {
        tag = "ingredient",
        tag_number = 1,
        node = node.create.item(conf.food, conf.food_quality),
        amount = -food
    }
    result[#result + 1] = {
        tag = "product",
        tag_number = 1,
        node = node.create.item(prototypes.item["nexelit-ore"], prototypes.quality["normal"]),
        amount = ore
    }
end

logic.fill_progression = function(result, options)
    local entity = prototypes.entity["dino-dig-site"]
    local resource = prototypes.entity["ore-nexelit"]
    local ore = prototypes.item["nexelit-ore"]
    for _, loc in ipairs(options.locations) do
        ---@type Rates.Progression.MultiItemPre
        local foods = {}
        for food, _ in pairs(food_types) do
            foods[#foods + 1] = progression.create.item(food, loc)
        end

        ---@type Rates.Progression.MultiItemPre
        local creatures = {}
        for creature, _ in pairs(dig_creatures) do
            creatures[#creatures + 1] = progression.create.item(creature, loc)
        end

        local id = "crafting-machine/" .. entity.name .. "/" .. loc
        result[id] = {
            pre = {
                progression.create.map_entity(entity.name, loc),
                progression.create.map_entity(resource.name, loc),
                foods,
                creatures,
                progression.create.energy_source(entity, loc)
            },
            post = {
                progression.create.item(ore.name, loc)
            }
        }
    end
end

---@param result Rates.Configuration.PyDigsite[]
logic.fill_basic_configurations = function(result, options)
    for food, _ in pairs(food_types) do
        for creature, _ in pairs(dig_creatures) do
            result[#result + 1] = {
                type = nil, ---@diagnostic disable-line: assign-type-mismatch
                entity = prototypes.entity["dino-dig-site"],
                quality = prototypes.quality.normal,
                module_effects = {
                    modules = { { module = prototypes.item[creature], quality = prototypes.quality.normal, count = 4 } }
                },
                food = prototypes.item[food],
                food_quality = prototypes.quality.normal
            }
        end
    end
end

logic.get_from_entity = function(entity, options)
    if (options.type ~= "assembling-machine" or options.entity.name ~= "dino-dig-site") then
        return
    end

    local module_effects = configuration.get_useful_module_effects(entity, options.use_ghosts)
    module_effects.beacons = nil

    local food_input = entity.surface.find_entities_filtered { name = "dino-dig-site-food-input", position = entity.position }
    if (#food_input ~= 1) then
        return
    end

    local food_inventory = food_input[1].get_inventory(defines.inventory.chest)
    if (not food_inventory) then
        return
    end

    local food, food_quality = get_food_from_inventory(food_inventory)
    if (not food or not food_quality) then
        return
    end

    ---@type Rates.Configuration.PyDigsite
    return {
        type = nil, ---@diagnostic disable-line: assign-type-mismatch
        entity = options.entity,
        quality = options.quality,
        module_effects = module_effects,
        food = food,
        food_quality = food_quality
    }
end

return logic
