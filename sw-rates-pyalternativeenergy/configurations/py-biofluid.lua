do
    ---@class Rates.Configuration.PyBiofluid : Rates.Configuration.Base
    ---@field type "py-biofluid"
    ---@field entity LuaEntityPrototype
    ---@field quality LuaQualityPrototype
    ---@field module_effects Rates.Configuration.ModuleEffects
    ---@field food LuaItemPrototype
    ---@field creature LuaItemPrototype
end

local api = require("__sw-rates-lib__.api-configuration")
local node = api.node
local progression = api.progression

local logic = { type = "py-biofluid", stats = { priority = 100 } } ---@type Rates.Configuration.Type

local foods = {
    ["workers-food"] = 1,
    ["workers-food-02"] = 1,
    ["workers-food-03"] = 1,
}

local creatures = {
    ["gobachov"] = 0.6,
    ["huzu"] = 0.8,
    ["chorkok"] = 1.3,
}

---@param conf Rates.Configuration.PyBiofluid
logic.get_id = function(conf)
    return conf.food.name .. "/" .. conf.creature.name
end

---@param conf Rates.Configuration.PyBiofluid
logic.gui_recipe = function(conf)
    return { sprite = "item/guano" }
end

---@param conf Rates.Configuration.PyBiofluid
logic.get_production = function(conf, result, options)
    local amount = foods[conf.food.name] * creatures[conf.creature.name]
    result[#result + 1] = {
        tag = "ingredient",
        tag_extra = 1,
        node = node.create.item(conf.food, prototypes.quality.normal),
        amount = -1
    }
    result[#result + 1] = {
        tag = "product",
        tag_extra = 1,
        node = node.create.item(prototypes.item["guano"], prototypes.quality.normal),
        amount = amount
    }
end

logic.fill_progression = function(result, options)
    local entity = prototypes.entity["bioport"]

    local food_nodes = {} ---@type Rates.Progression.MultiItemPre
    for food, _ in pairs(foods) do
        food_nodes[#food_nodes + 1] = progression.create.item(food, "*")
    end

    local creature_nodes = {} ---@type Rates.Progression.MultiItemPre
    for creature, _ in pairs(creatures) do
        creature_nodes[#creature_nodes + 1] = progression.create.item(creature, "*")
    end

    local id = "crafting-machine/" .. entity.name .. "/*"
    result[id] = {
        pre = {
            progression.create.map_entity(entity.name, "*"),
            food_nodes,
            creature_nodes,
            progression.create.energy_source(entity, "*")
        },
        post = {
            progression.create.item("guano", "*")
        },
        multi = options.locations
    }
end

---@param result Rates.Configuration.PyBiofluid[]
logic.fill_basic_configurations = function(result, options)
    for food, _ in pairs(foods) do
        for creature, _ in pairs(creatures) do
            result[#result + 1] = {
                type = nil, ---@diagnostic disable-line: assign-type-mismatch
                id = nil, ---@diagnostic disable-line: assign-type-mismatch
                entity = prototypes.entity["bioport"],
                quality = prototypes.quality.normal,
                module_effects = {},
                creature = prototypes.item[creature],
                food = prototypes.item[food]
            }
        end
    end
end

logic.get_from_entity = function(entity, options)
    if (options.type ~= "assembling-machine" or options.entity.name ~= "bioport") then
        return
    end

    ---@type Rates.Configuration.PyBiofluid
    return {
        type = nil, ---@diagnostic disable-line: assign-type-mismatch
        id = nil, ---@diagnostic disable-line: assign-type-mismatch
        entity = options.entity,
        quality = options.quality,
        module_effects = {},
        creature = prototypes.item["gobachov"],
        food = prototypes.item["workers-food"]
    }
end

return logic
