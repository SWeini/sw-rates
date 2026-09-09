do
    ---@class Rates.Configuration.PyDigsite : Rates.Configuration.Base
    ---@field type "py-digsite"
    ---@field entity LuaEntityPrototype
    ---@field quality LuaQualityPrototype
    ---@field module_effects Rates.Configuration.ModuleEffects
    ---@field resource? LuaEntityPrototype
    ---@field food? LuaItemPrototype
    ---@field food_quality? LuaQualityPrototype
end

do
    ---@class Rates.Configuration.Annotation.PyDigsiteSpeedInaccurate : Rates.Configuration.Annotation.Base
    ---@field type "py-digsite/speed-inaccurate"
end

do
    ---@class Rates.Configuration.Annotation.PyDigsiteFoodUnknown : Rates.Configuration.Annotation.Base
    ---@field type "py-digsite/food-unknown"
end

---@type { creatures: table<string, { proxy: string, mining_bonus: number }>, foods: table<string, number>, resource_categories: table<string, true>, dig_sites: table<string, { mining_range: number, mining_range_offsets: table<defines.direction, MapPosition.0> }> }
local mod_data = prototypes.mod_data["pyanodons"].data["digosaurus"]
local supported_resource_categories = mod_data.resource_categories
---@type string[]
local supported_resources = {}
for _, resource in pairs(prototypes.get_entity_filtered { { filter = "type", type = "resource" } }) do
    if (supported_resource_categories[resource.resource_category]) then
        supported_resources[#supported_resources + 1] = resource.name
    end
end

local api = require("__sw-rates-lib__.api-configuration")
local configuration = api.configuration
local node = api.node
local progression = api.progression

local logic = { type = "py-digsite", stats = { priority = 100 } } ---@type Rates.Configuration.Type

---@type { [string]: { amount: number, ticks: number } }
local dig_creatures = {}
for name, data in pairs(mod_data.creatures) do
    local unit = prototypes.entity[name]
    local proxy = prototypes.entity[data.proxy]
    local ticks = proxy.get_max_health() * unit.attack_parameters.cooldown
    dig_creatures[name] = { amount = data.mining_bonus, ticks = ticks }
end

local food_types = mod_data.foods

for _, site_data in pairs(mod_data.dig_sites) do
    for _, direction in pairs { "north", "east", "south", "west" } do
        local offset = site_data.mining_range_offsets[defines.direction[direction] .. ""]
        offset = { x = offset.x or offset[1], y = offset.y or offset[2] }
        site_data.mining_range_offsets[defines.direction[direction]] = offset
    end
end

---@param data { mining_range: number, mining_range_offsets: table<defines.direction, MapPosition.0> }
---@param entity LuaEntity
---@return LuaEntityPrototype?
local function get_resource_from_entity(data, entity)
    local position = entity.position
    local range = data.mining_range
    local offset = data.mining_range_offsets[entity.direction]

    local area = {
        { position.x - range + offset.x, position.y - range + offset.y },
        { position.x + range + offset.x, position.y + range + offset.y }
    }

    local resources = entity.surface.find_entities_filtered { area = area, type = "resource", name = supported_resources }
    local compatible_resources = {} ---@type table<string, LuaEntityPrototype>
    for _, resource in ipairs(resources) do
        local prototype = resource.prototype
        compatible_resources[prototype.name] = prototype
    end

    for _, prototype in pairs(compatible_resources) do
        return prototype
    end
end

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

---@param entity LuaEntity
---@return { food: LuaItemPrototype, quality: LuaQualityPrototype}?
local function get_food_from_entity(entity)
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

    return { food = food, quality = food_quality }
end

---@param conf Rates.Configuration.PyDigsite
logic.get_id = function(conf)
    local id = (conf.resource and conf.resource.name or "<no-resource>")
    local food = conf.food and conf.food.name or "?"
    local food_quality = conf.food_quality and conf.food_quality.name or "?"
    return id .. "/" .. food .. "(" .. food_quality .. ")"
end

---@param conf Rates.Configuration.PyDigsite
logic.gui_recipe = function(conf)
    if (conf.resource) then
        ---@type Rates.Gui.NodeDescription
        return {
            element = { type = "entity", name = conf.resource.name }
        }
    end

    ---@type Rates.Gui.NodeDescription
    return {
        icon = { sprite = "utility/resources_depleted_icon" }
    }
end

---@param conf Rates.Configuration.PyDigsite
logic.get_production = function(conf, result, options)
    configuration.calculate_energy_source(result, conf.entity, conf.entity.energy_usage, options)

    if (conf.resource == nil) then
        return
    end

    if (conf.food == nil or conf.food_quality == nil) then
        if (options.annotations) then
            options.annotations[#options.annotations + 1] = { type = "py-digsite/food-unknown" }
        end
        return
    end

    if (options.annotations) then
        options.annotations[#options.annotations + 1] = { type = "py-digsite/speed-inaccurate" }
    end

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
        node = node.create.map_entity(conf.resource, prototypes.quality.normal),
        amount = -resource
    }
    result[#result + 1] = {
        tag = "ingredient",
        tag_number = 1,
        node = node.create.item(conf.food, conf.food_quality),
        amount = -food
    }
    local mineable = conf.resource.mineable_properties
    if (mineable.products) then
        configuration.calculate_products(result, prototypes.quality.normal, mineable.products, ore, 0)
    end
end

logic.gui_annotation = function(annotation, conf)
    if (annotation.type == "py-digsite/speed-inaccurate") then
        return {
            severity = "information",
            text = { "sw-rates-annotation.py-digsite-speed-inaccurate" }
        }
    elseif (annotation.type == "py-digsite/food-unknown") then
        return {
            severity = "error",
            text = { "sw-rates-annotation.py-digsite-food-unknown" }
        }
    end
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

logic.modify_from_entity = function(entity, conf, options)
    if (conf.type ~= "crafting-machine") then
        return
    end

    local entity_data = mod_data.dig_sites[conf.entity.name]
    if (not entity_data) then
        return
    end

    local resource = get_resource_from_entity(entity_data, entity)
    local food = get_food_from_entity(entity)
    if (food == nil and options.analyzer_inputs) then
        local items = options.analyzer_inputs.items
        if (items) then
            for _, item in pairs(items) do
                if (food_types[item.item.name]) then
                    food = { food = item.item, quality = item.quality }
                    break
                end
            end
        end
    end

    conf.recipe = nil
    conf.recipe_quality = nil
    ---@cast conf Rates.Configuration.PyDigsite
    conf.type = "py-digsite"
    conf.module_effects.beacons = nil
    conf.resource = resource
    if (food) then
        conf.food = food.food
        conf.food_quality = food.quality
    end
    return conf
end

logic.analyze_flow = function(entity, prototype, inputs)
    local site_data = mod_data.dig_sites[prototype.name]

    if (not site_data) then
        return
    end

    ---@type Rates.Analyzer.EntityOutputs
    local result = {
        items = {},
        required_items = "once",
    }

    local resource = get_resource_from_entity(site_data, entity)
    if (resource and resource.mineable_properties) then
        ---@type Rates.Configuration.Amount[]
        local products = {}
        configuration.calculate_products(products, prototypes.quality.normal, resource.mineable_properties.products, 1, 0)
        for _, product in ipairs(products) do
            local node = product.node
            if (node.type == "item") then
                configuration.add_item_to_set(result.items, node.item, node.quality)
            end
        end
    end

    return result
end

return logic
