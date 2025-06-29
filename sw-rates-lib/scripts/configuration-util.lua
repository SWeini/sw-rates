local node = require("node")
local math2d = require("math2d")
local location = require("location")
local energy_source = require("energy-source")

local util = {
}

---@param fluids table<string, table<number, true>>
---@param fluid LuaFluidPrototype
---@param temperature number?
function util.add_fluid_temperature(fluids, fluid, temperature)
    local temps = fluids[fluid.name]
    if (temps == nil) then
        temps = {}
        fluids[fluid.name] = temps
    end
    temps[temperature or fluid.default_temperature] = true
end

---@param entity LuaEntity
---@param use_ghosts boolean
---@return { entity: LuaEntityPrototype, quality: LuaQualityPrototype }?
function util.get_useful_entity_data(entity, use_ghosts)
    if (use_ghosts) then
        if (entity.to_be_deconstructed()) then
            return
        end

        if (entity.type == "entity-ghost") then
            return {
                entity = entity.ghost_prototype,
                quality = entity.quality
            }
        end

        local upgrade_target, upgrade_quality = entity.get_upgrade_target()
        return {
            entity = upgrade_target or entity.prototype,
            quality = upgrade_quality or entity.quality
        }
    else
        if (entity.type == "entity-ghost") then
            return
        end

        return {
            entity = entity.prototype,
            quality = entity.quality
        }
    end
end

---@param type string
---@return table<string, LuaEntityPrototype>
function util.get_all_entities(type)
    local result = {} ---@type table<string, LuaEntityPrototype>
    for name, entity in pairs(prototypes.get_entity_filtered { { filter = "type", type = type } }) do
        result[name] = entity
    end

    return result
end

---@param result Rates.Configuration.Amount[]
---@param entity LuaEntityPrototype
---@param energy_usage number
---@param options Rates.Configuration.ProductionOptions
---@param pollution_multiplier number?
function util.calculate_energy_source(result, entity, energy_usage, options, pollution_multiplier)
    local pollutant ---@type LuaAirbornePollutantPrototype?
    if (options.use_pollution) then
        local surface = options.surface
        pollutant = surface and location.get_pollutant_type(surface)
    end

    energy_source.get_production(result, entity, energy_usage, pollutant, pollution_multiplier or 1)
end

---@param result Rates.Configuration.Amount[]
---@param entity LuaEntityPrototype
---@param surface Rates.Location?
function util.calculate_constant_pollution(result, entity, surface)
    if (not surface) then
        return
    end

    local pollutant = location.get_pollutant_type(surface)
    if (not pollutant) then
        return
    end

    local emission = entity.emissions_per_second[pollutant.name]
    if (not emission or emission == 0) then
        return
    end

    result[#result + 1] = {
        tag = "pollution",
        tag_extra = "drain",
        node = node.create.pollution(pollutant),
        amount = emission
    }
end

---@param result Rates.Configuration.Amount[]
---@param quality LuaQualityPrototype
---@param ingredients Ingredient[]
---@param frequency number
function util.calculate_ingredients(result, quality, ingredients, frequency)
    for i, ingredient in ipairs(ingredients) do
        if (ingredient.type == "item") then
            result[#result + 1] = {
                tag = "ingredient",
                tag_extra = i,
                node = node.create.item(prototypes.item[ingredient.name], quality),
                amount = -ingredient.amount * frequency
            }
        elseif (ingredient.type == "fluid") then
            local temperature = { min = ingredient.minimum_temperature, max = ingredient.maximum_temperature }
            result[#result + 1] = {
                tag = "ingredient",
                tag_extra = i,
                node = node.create.fluid(prototypes.fluid[ingredient.name], temperature),
                amount = -ingredient.amount * frequency
            }
        end
    end
end

---@param result Rates.Configuration.Amount[]
---@param quality LuaQualityPrototype
---@param products (ItemProduct | FluidProduct | ResearchProgressProduct)[]
---@param frequency number
---@param productivity_bonus number
---@param quality_distribution? { quality: LuaQualityPrototype, multiplier: number }[]
function util.calculate_products(result, quality, products, frequency, productivity_bonus, quality_distribution)
    for i, product in ipairs(products) do
        local amount = (product.amount or (product.amount_min + product.amount_max) / 2) * product.probability +
            (product.extra_count_fraction or 0)
        local with_productivity = math.max(0, amount - (product.ignored_by_productivity or 0))
        amount = amount + with_productivity * productivity_bonus
        if (product.type == "item") then
            if (quality_distribution) then
                for j, q in ipairs(quality_distribution) do
                    result[#result + 1] = {
                        tag = "product",
                        tag_extra = i .. "q" .. j,
                        node = node.create.item(prototypes.item[product.name], q.quality),
                        amount = amount * frequency * q.multiplier
                    }
                end
            else
                result[#result + 1] = {
                    tag = "product",
                    tag_extra = i,
                    node = node.create.item(prototypes.item[product.name], quality),
                    amount = amount * frequency
                }
            end
        elseif (product.type == "fluid") then
            local fluid = prototypes.fluid[product.name]
            result[#result + 1] = {
                tag = "product",
                tag_extra = i,
                node = node.create.fluid(fluid, product.temperature or fluid.default_temperature),
                amount = amount * frequency
            }
        end
    end
end

---@param quality LuaQualityPrototype
---@param bonus number
---@param force LuaForce?
---@return { quality: LuaQualityPrototype, multiplier: number }[]?
function util.calculate_quality_distribution(quality, bonus, force)
    if (bonus <= 0) then
        return
    end

    local result = {} ---@type { quality: LuaQualityPrototype, multiplier: number }[]

    local left = 1
    while (left > 0) do
        local quality_next = quality.next
        local prob_next = quality_next and (force == nil or force.is_quality_unlocked(quality_next)) and
            quality.next_probability or 0
        local bonus_next = prob_next * bonus
        if (bonus_next < 1) then
            local stay_probability = left - bonus_next
            result[#result + 1] = { quality = quality, multiplier = stay_probability }
            left = bonus_next
        end

        bonus = bonus_next
        quality = quality_next
    end

    return result
end

---@param result Rates.Configuration.Amount[]
---@param day number
---@param night number
---@param solar_panel_mode "average-and-buffer" | "day-and-night"
---@param property LuaSurfacePropertyPrototype
---@param surface Rates.Location
function util.calculate_solar_power(result, day, night, solar_panel_mode, property, surface)
    local day_night_cycle_property = prototypes.surface_property["day-night-cycle"]

    local solar_power
    local day_night_cycle
    if (surface) then
        solar_power = location.get_solar_power(surface, property)
        day_night_cycle = location.get_property(surface, day_night_cycle_property)
    else
        solar_power = property.default_value
        day_night_cycle = day_night_cycle_property.default_value
    end

    day = day * (solar_power / 100)
    night = night * (solar_power / 100)

    if (solar_panel_mode == "day-and-night") then
        if (day_night_cycle == 0) then
            result[#result + 1] = {
                tag = "product",
                node = node.create.electric_power(),
                amount = day
            }
        else
            if (day == night) then
                result[#result + 1] = {
                    tag = "product",
                    node = node.create.electric_power(),
                    amount = day
                }
            elseif (day > night) then
                if (night > 0) then
                    result[#result + 1] = {
                        tag = "product",
                        node = node.create.electric_power(),
                        amount = night
                    }
                end
                result[#result + 1] = {
                    tag = "product",
                    node = node.create.electric_power(true),
                    amount = day - night
                }
            elseif (night > day) then
                if (day > 0) then
                    result[#result + 1] = {
                        tag = "product",
                        node = node.create.electric_power(),
                        amount = day
                    }
                end
                result[#result + 1] = {
                    tag = "product",
                    node = node.create.electric_power(false),
                    amount = night - day
                }
            end
        end
    else
        local average, accumulator_ratio
        if (day_night_cycle == 0) then
            average = day
            accumulator_ratio = 0
        else
            -- TODO: use LuaSurface.daytime_parameters for solar panel calculations
            average = 0.7 * day + 0.3 * night
            accumulator_ratio = 0.168 * math.abs(day - night)
        end
        if (accumulator_ratio ~= 0) then
            local energy_buffer = day_night_cycle * accumulator_ratio / 60
            result[#result + 1] = {
                tag = "ingredient",
                node = node.create.electric_buffer(),
                amount = -energy_buffer
            }
        end
        result[#result + 1] = {
            tag = "product",
            node = node.create.electric_power(),
            amount = average
        }
    end
end

---@param surface LuaSurface
---@param conditions SurfaceCondition[]?
---@return boolean
function util.has_surface_conditions(surface, conditions)
    for _, condition in ipairs(conditions or {}) do
        local name = condition.property
        local value = surface.get_property(name)

        if (value < condition.min or value > condition.max) then
            return false
        end
    end

    return true
end

---int16_t in percentages
---@alias Rates.Internal.ModuleEffect integer
---@alias Rates.Internal.EffectType "consumption" | "speed" | "productivity" | "pollution" | "quality"
---@alias Rates.Internal.FloatModuleEffects table<Rates.Internal.EffectType, number>
---@alias Rates.Internal.ModuleEffects table<Rates.Internal.EffectType, Rates.Internal.ModuleEffect>

---@type table<string, defines.inventory>
local module_inventories = {
    ["assembling-machine"] = defines.inventory.crafter_modules,
    ["beacon"] = defines.inventory.beacon_modules,
    ["furnace"] = defines.inventory.crafter_modules,
    ["lab"] = defines.inventory.lab_modules,
    ["mining-drill"] = defines.inventory.mining_drill_modules,
    ["rocket-silo"] = defines.inventory.crafter_modules,
}

local all_module_effects = { "consumption", "speed", "productivity", "pollution", "quality" }
local positive_module_effect = {
    ["consumption"] = false,
    ["speed"] = true,
    ["productivity"] = true,
    ["pollution"] = false,
    ["quality"] = true
}

---@param a Rates.Configuration.Module
---@param b Rates.Configuration.Module
---@return boolean
local function compare_module(a, b)
    if (a.count ~= b.count) then
        return a.count > b.count
    end

    if (a.module.name ~= b.module.name) then
        return a.module.name < b.module.name
    end

    if (a.quality.level ~= b.quality.level) then
        return a.quality.level < b.quality.level
    end

    if (a.quality.name ~= b.quality.name) then
        return a.quality.name < b.quality.name
    end

    -- a and b are equal, order doesn't matter
    return false
end

---@param a Rates.Configuration.Beacon
---@param b Rates.Configuration.Beacon
---@return boolean
local function compare_beacon(a, b)
    if (a.count ~= b.count) then
        return a.count > b.count
    end

    if (a.beacon.hidden ~= b.beacon.hidden) then
        return b.beacon.hidden
    end

    if (a.beacon.name ~= b.beacon.name) then
        return a.beacon.name < b.beacon.name
    end

    if (a.quality.level ~= b.quality.level) then
        return a.quality.level < b.quality.level
    end

    if (a.quality.name ~= b.quality.name) then
        return a.quality.name < b.quality.name
    end

    if (#a.per_beacon_modules ~= #b.per_beacon_modules) then
        return #a.per_beacon_modules > #b.per_beacon_modules
    end

    for i = 1, #a.per_beacon_modules do
        local a_i = a.per_beacon_modules[i]
        local b_i = b.per_beacon_modules[i]

        if (a_i.count ~= b_i.count) then
            return a_i.count > b_i.count
        end

        if (a_i.module.name ~= b_i.module.name) then
            return a_i.module.name < b_i.module.name
        end

        if (a_i.quality.level ~= b_i.quality.level) then
            return a_i.quality.level < b_i.quality.level
        end

        if (a_i.quality.name ~= b_i.quality.name) then
            return a_i.quality.name < b_i.quality.name
        end
    end

    -- a and b are equal, order doesn't matter
    return false
end

---@param beacon Rates.Configuration.Beacon
---@return string
local function get_beacon_id(beacon)
    local parts = {}
    parts[#parts + 1] = beacon.beacon.name
    parts[#parts + 1] = beacon.quality.name
    for _, module in ipairs(beacon.per_beacon_modules) do
        parts[#parts + 1] = module.module.name
        parts[#parts + 1] = module.quality.name
        parts[#parts + 1] = tostring(module.count)
    end

    return table.concat(parts, "/")
end

---@param modules Rates.Configuration.Module[]
function util.sort_modules(modules)
    table.sort(modules, compare_module)
end

---@param beacons Rates.Configuration.Beacon[]
function util.sort_beacons(beacons)
    table.sort(beacons, compare_beacon)
end

---@param beacons Rates.Configuration.Beacon[]
---@param important_beacon_types table<string, true>
---@return Rates.Configuration.Beacon[]
local function remove_empty_beacons(beacons, important_beacon_types)
    local result = {} ---@type Rates.Configuration.Beacon[]
    for _, beacon in ipairs(beacons) do
        if (#beacon.per_beacon_modules > 0 or important_beacon_types[beacon.beacon.name]) then
            result[#result + 1] = beacon
        end
    end

    return result
end

---@param beacons Rates.Configuration.Beacon[]
---@return Rates.Configuration.Beacon[]
function util.cleanup_beacons(beacons)
    local every_beacon_counts = false
    local important_beacon_types = {} ---@type table<string, true>
    for _, beacon in ipairs(beacons) do
        if (#beacon.per_beacon_modules > 0) then
            local profile = beacon.beacon.profile
            if (profile and #profile > 1) then
                if (beacon.beacon.beacon_counter == "total") then
                    every_beacon_counts = true
                    break
                else
                    important_beacon_types[beacon.beacon.name] = true
                end
            end
        end
    end

    if (not every_beacon_counts) then
        beacons = remove_empty_beacons(beacons, important_beacon_types)
    end

    local beacons_by_id = {} ---@type table<string, Rates.Configuration.Beacon>
    for _, beacon in ipairs(beacons) do
        local beacon_id = get_beacon_id(beacon)
        local entry = beacons_by_id[beacon_id]
        if (entry) then
            entry.count = entry.count + beacon.count
        else
            beacons_by_id[beacon_id] = beacon
        end
    end

    local result = {} ---@type Rates.Configuration.Beacon[]
    for _, beacon in pairs(beacons_by_id) do
        result[#result + 1] = beacon
    end

    util.sort_beacons(result)
    return result
end

---@param modules Rates.Configuration.Module[]
---@param accept fun(module: LuaItemPrototype): boolean
---@return Rates.Configuration.Module[]
function util.filter_modules(modules, accept)
    local result = {} ---@type Rates.Configuration.Module[]
    for _, module in ipairs(modules) do
        if (accept(module.module)) then
            result[#result + 1] = module
        end
    end

    return result
end

---@param beacons Rates.Configuration.Beacon[]
---@param accept fun(module: LuaItemPrototype): boolean
---@return Rates.Configuration.Beacon[]
function util.filter_beacons(beacons, accept)
    for _, beacon in ipairs(beacons) do
        beacon.per_beacon_modules = util.filter_modules(beacon.per_beacon_modules, accept)
    end

    return util.cleanup_beacons(beacons)
end

---@param entity LuaEntity
---@param use_ghosts boolean
---@return table<integer, { module: LuaItemPrototype, quality: LuaQualityPrototype }>
function util.collect_modules(entity, use_ghosts)
    local result = {} ---@type table<integer, { module: LuaItemPrototype, quality: LuaQualityPrototype }>
    local modules = entity.get_module_inventory()
    if (modules) then
        for i = 1, #modules do
            local module = modules[i]
            if (module.valid_for_read) then
                result[i] = { module = module.prototype, quality = module.quality }
            end
        end
    end

    if (not use_ghosts) then
        return result
    end

    local module_inventory_index
    local requester
    if (entity.type == "entity-ghost") then
        requester = entity
        module_inventory_index = module_inventories[entity.ghost_type]
    else
        requester = entity.item_request_proxy
        module_inventory_index = module_inventories[entity.type]
        if (requester) then
            for _, plan in ipairs(requester.removal_plan) do
                for _, pos in pairs(plan.items.in_inventory or {}) do
                    if (pos.inventory == module_inventory_index) then
                        result[pos.stack + 1] = nil
                    end
                end
            end
        end
    end

    if (requester) then
        for _, plan in ipairs(requester.insert_plan) do
            for _, pos in pairs(plan.items.in_inventory or {}) do
                if (pos.inventory == module_inventory_index) then
                    local quality = plan.id.quality and prototypes.quality[plan.id.quality] or prototypes.quality.normal
                    result[pos.stack + 1] = { module = prototypes.item[plan.id.name], quality = quality }
                end
            end
        end
    end

    return result
end

---@param modules table<integer, { module: LuaItemPrototype, quality: LuaQualityPrototype }>
---@return Rates.Configuration.Module[]
function util.sum_modules(modules)
    local map = {} ---@type table<string, Rates.Configuration.Module>
    local result = {} ---@type Rates.Configuration.Module[]

    for _, entry in pairs(modules) do
        local key = entry.module.name .. "/" .. entry.quality.name
        local module = map[key]
        if (not module) then
            module = { count = 0, module = entry.module, quality = entry.quality }
            map[key] = module
            result[#result + 1] = module
        end

        module.count = module.count + 1
    end

    util.sort_modules(result)
    return result
end

---@param box1 BoundingBox.0
---@param box2 BoundingBox.0
local function collides_with(box1, box2)
    -- separate implementation because C++ and math2d.lua do not agree on edge case (bounding boxes touch exactly)
    return box1.left_top.x <= box2.right_bottom.x and
        box2.left_top.x <= box1.right_bottom.x and
        box1.left_top.y <= box2.right_bottom.y and
        box2.left_top.y <= box1.right_bottom.y
end

---@param entity LuaEntity
---@param beacon LuaEntity
---@param beacon_prototype LuaEntityPrototype
---@param beacon_quality LuaQualityPrototype
---@return boolean
local function is_beacon_in_range(entity, beacon, beacon_prototype, beacon_quality)
    local entity_box = entity.bounding_box
    local beacon_box = beacon.bounding_box
    local supply_distance = beacon_prototype.get_supply_area_distance(beacon_quality)
    local diagonal = { x = supply_distance, y = supply_distance }
    ---@type BoundingBox.0
    local supply_box = {
        left_top = math2d.position.subtract(beacon_box.left_top, diagonal),
        right_bottom = math2d.position.add(beacon_box.right_bottom, diagonal)
    }

    return collides_with(supply_box, entity_box)
end

---@param map table<string, Rates.Configuration.Module>
---@param module LuaItemPrototype
---@param module_quality LuaQualityPrototype
local function add_module(map, module, module_quality)
    local key = module.name .. "/" .. module_quality.name
    local entry = map[key]
    if (not entry) then
        entry = {
            module = module,
            quality = module_quality,
            count = 0
        }
        map[key] = entry
    end

    entry.count = entry.count + 1
end

---@param entity LuaEntity
---@param use_ghosts boolean
---@return Rates.Configuration.Beacon[]
function util.collect_beacons(entity, use_ghosts)
    local bbox = entity.bounding_box
    local max_distance = prototypes.max_beacon_supply_area_distance + 1
    local diagonal = { x = max_distance, y = max_distance }
    local search_box = {
        left_top = math2d.position.subtract(bbox.left_top, diagonal),
        right_bottom = math2d.position.add(bbox.right_bottom, diagonal)
    }

    local candidates = {} ---@type LuaEntity[]
    for _, entity in ipairs(entity.surface.find_entities_filtered { type = "beacon", area = search_box }) do
        candidates[#candidates + 1] = entity
    end
    if (use_ghosts) then
        for _, ghost in ipairs(entity.surface.find_entities_filtered { type = "entity-ghost", ghost_type = "beacon", area = search_box }) do
            candidates[#candidates + 1] = ghost
        end
    end

    local useful_beacons = {} ---@type { entity: LuaEntity, prototype: LuaEntityPrototype, quality: LuaQualityPrototype }[]
    for _, entity in pairs(candidates) do
        local data = util.get_useful_entity_data(entity, use_ghosts)
        if (data) then
            useful_beacons[#useful_beacons + 1] = {
                entity = entity,
                prototype = data.entity,
                quality = data.quality
            }
        end
    end

    local result = {} ---@type Rates.Configuration.Beacon[]
    for _, beacon in ipairs(useful_beacons) do
        if (is_beacon_in_range(entity, beacon.entity, beacon.prototype, beacon.quality)) then
            local beacon_modules = {} ---@type table<string, Rates.Configuration.Module>
            local module_slots = util.collect_modules(beacon.entity, use_ghosts)
            for _, module in pairs(module_slots) do
                add_module(beacon_modules, module.module, module.quality)
            end

            local modules = {} ---@type Rates.Configuration.Module[]
            for _, entry in pairs(beacon_modules) do
                modules[#modules + 1] = entry
            end

            util.sort_modules(modules)

            ---@type Rates.Configuration.Beacon
            local beacon_data = {
                beacon = beacon.prototype,
                quality = beacon.quality,
                count = 1,
                per_beacon_modules = modules
            }
            result[#result + 1] = beacon_data
        end
    end

    return util.cleanup_beacons(result)
end

---@param entity LuaEntity
---@param use_ghosts boolean
---@return Rates.Configuration.ModuleEffects
function util.get_useful_module_effects(entity, use_ghosts)
    local module_slots = util.collect_modules(entity, use_ghosts)
    local modules = util.sum_modules(module_slots)
    local beacons = util.collect_beacons(entity, use_ghosts)
    return { modules = modules, beacons = beacons }
end

---@param name Rates.Internal.EffectType
---@param x number
---@return boolean
local function is_positive_effect(name, x)
    if (positive_module_effect[name]) then
        return x > 0
    else
        return x < 0
    end
end

---@param effects Rates.Configuration.ModuleEffects
---@param receiver EffectReceiver?
function util.filter_module_effects_receiver(effects, receiver)
    if (not receiver) then
        return
    end

    if (not receiver.uses_module_effects) then
        effects.modules = nil
    end

    if (not receiver.uses_beacon_effects) then
        effects.beacons = nil
    end
end

---@param effects Rates.Configuration.ModuleEffects
---@param categories table<string, true>?
function util.filter_module_effects_category(effects, categories)
    if (not categories) then
        return
    end

    ---@param module LuaItemPrototype
    ---@return boolean
    local accept = function(module)
        return categories[module.category] == true
    end

    if (effects.modules) then
        effects.modules = util.filter_modules(effects.modules, accept)
    end

    if (effects.beacons) then
        effects.beacons = util.filter_beacons(effects.beacons, accept)
    end
end

---@param effects Rates.Configuration.ModuleEffects
---@param allowed table<string, true>?
function util.filter_module_effects_allowed(effects, allowed)
    if (not allowed) then
        return
    end

    ---@param module LuaItemPrototype
    ---@return boolean
    local accept = function(module)
        for _, property in ipairs(all_module_effects) do
            if (not allowed[property]) then
                local effect = module.module_effects and module.module_effects[property] or 0
                if (is_positive_effect(property, effect)) then
                    return false
                end
            end
        end

        return true
    end

    if (effects.modules) then
        effects.modules = util.filter_modules(effects.modules, accept)
    end

    if (effects.beacons) then
        util.filter_beacons(effects.beacons, accept)
    end
end

---@param x number
---@return integer
local function to_integer_percentage(x)
    -- x is supposed to be an integer, converted to float and divided by 100 (directly coming from the API)
    -- x * 100 only has slight rounding errors due to floating point precision
    return math.floor(x * 100 + 0.5)
end

---@param effects Rates.Internal.FloatModuleEffects
---@return Rates.Internal.ModuleEffects
local function to_integer_percentage_effects(effects)
    local result = {} ---@type Rates.Internal.ModuleEffects
    for name, value in pairs(effects) do
        result[name] = to_integer_percentage(value)
    end

    return result
end

---@param x number
---@return integer
local function cast_to_integer(x)
    if (x > 0) then
        return math.floor(x)
    elseif (x < 0) then
        return math.ceil(x)
    else
        return 0
    end
end

---@param x number
---@return integer
local function round_to_integer(x)
    return math.floor(x + 0.5)
end

---@param x integer
---@return integer
local function clamp_to_16_bit(x)
    if (x > 32767) then
        return 32767
    elseif (x < -32768) then
        return -32768
    else
        return x
    end
end

---@param module LuaItemPrototype
---@param quality LuaQualityPrototype
---@return Rates.Internal.ModuleEffects
local function get_effect_of_single_module(module, quality)
    local result = {} ---@type Rates.Internal.ModuleEffects

    local effects = module.module_effects ---@type Rates.Internal.FloatModuleEffects
    if (effects) then
        for name, value in pairs(effects) do
            if (value ~= 0) then
                local percentage = to_integer_percentage(value)
                if (is_positive_effect(name, value)) then
                    -- negative effects are not increased by quality
                    -- multiplier is 1 + 0.3 * quality.level
                    -- just have to be careful because of rounding at the end
                    local bonus = cast_to_integer((3 * quality.level * percentage) / 10)
                    percentage = percentage + bonus
                end

                result[name] = percentage
            end
        end
    end

    return result
end

---@param target Rates.Internal.ModuleEffects
---@param effects Rates.Internal.ModuleEffects
---@param multiplier integer?
local function accumulate_effects(target, effects, multiplier)
    if (not multiplier) then
        multiplier = 1
    end

    for name, value in pairs(effects) do
        target[name] = (target[name] or 0) + value * multiplier
    end
end

---@type EffectReceiver
local default_effect_receiver = {
    base_effect = {},
    uses_beacon_effects = true,
    uses_module_effects = true,
    uses_surface_effects = true
}

---@param receiver EffectReceiver?
---@param effects Rates.Configuration.ModuleEffects?
---@param surface_effect Rates.Internal.FloatModuleEffects?
---@param additional_effects Rates.Internal.FloatModuleEffects[]?
---@param max_effect Rates.Internal.FloatModuleEffects?
---@param module_check fun(module: LuaItemPrototype): boolean)
---@return Rates.Internal.FloatModuleEffects
function util.calculate_effects(receiver, effects, surface_effect, additional_effects, max_effect, module_check)
    local result = {} ---@type Rates.Internal.ModuleEffects

    if (not receiver) then
        receiver = default_effect_receiver
    end

    accumulate_effects(result, to_integer_percentage_effects(receiver.base_effect))

    if (receiver.uses_surface_effects and surface_effect) then
        accumulate_effects(result, to_integer_percentage_effects(surface_effect))
    end

    local modules = effects and effects.modules
    if (receiver.uses_module_effects and modules) then
        for _, module in ipairs(modules) do
            if (module_check(module.module)) then
                local module_effect = get_effect_of_single_module(module.module, module.quality)
                accumulate_effects(result, module_effect, module.count)
            end
        end
    end

    local beacons = effects and effects.beacons
    if (receiver.uses_beacon_effects and beacons) then
        -- beacons are quite complex
        -- the order here is very important because lots of rounding/clamping happens at specific points of the calculation

        local beacon_count = 0
        local beacons_by_prototype = {} ---@type table<string, { beacon: LuaEntityPrototype, count: integer, effects: Rates.Internal.ModuleEffects } >
        for _, beacon in ipairs(beacons) do
            local name = beacon.beacon.name
            local entry = beacons_by_prototype[name]
            if (not entry) then
                entry = { beacon = beacon.beacon, count = 0, effects = {} }
                beacons_by_prototype[name] = entry
            end

            beacon_count = beacon_count + beacon.count
            entry.count = entry.count + beacon.count

            local effectivity = to_integer_percentage(beacon.beacon.distribution_effectivity)
            local effectivity_per_level = to_integer_percentage(beacon.beacon
                .distribution_effectivity_bonus_per_quality_level or 0)
            local total_effectivity = effectivity + beacon.quality.level * effectivity_per_level
            local single_beacon_inserted_effects = {} ---@type Rates.Internal.ModuleEffects
            for _, module in ipairs(beacon.per_beacon_modules) do
                if (module_check(module.module)) then
                    local module_effect = get_effect_of_single_module(module.module, module.quality)
                    accumulate_effects(single_beacon_inserted_effects, module_effect, module.count)
                end
            end

            local single_beacon_distributed_effects = {} ---@type Rates.Internal.ModuleEffects
            for name, value in pairs(single_beacon_inserted_effects) do
                -- order is important: sum all modules in a beacon, then multiply with distribution effectivity and cast to int64_t
                -- using percentages for total_effectivity to reduce issues with floating point precision
                single_beacon_distributed_effects[name] = cast_to_integer((value * total_effectivity) / 100)
            end

            accumulate_effects(entry.effects, single_beacon_distributed_effects, beacon.count)
        end

        for _, beacon in pairs(beacons_by_prototype) do
            local profile = beacon.beacon.profile
            if (not profile or #profile == 0) then
                profile = { 1 }
            end
            local count
            if (beacon.beacon.beacon_counter == "total") then
                count = beacon_count
            else
                count = beacon.count
            end

            local idx = math.min(count, #profile)
            local profile_multiplier = profile[idx]

            local effects_of_beacon_prototype = {} ---@type Rates.Internal.ModuleEffects
            for name, value in pairs(beacon.effects) do
                -- order is important: sum effects of beacons by prototype, then multiply with profile, round to int64_t and clamp to int16_t
                -- I don't know exactly why this clamping happens in the engine, but it does
                effects_of_beacon_prototype[name] = clamp_to_16_bit(round_to_integer(value * profile_multiplier))
            end

            accumulate_effects(result, effects_of_beacon_prototype)
        end
    end

    if (additional_effects) then
        for _, effect in ipairs(additional_effects) do
            -- normally used for per-force bonus effects
            accumulate_effects(result, to_integer_percentage_effects(effect))
        end
    end

    if (max_effect) then
        -- used for max recipe productivity
        local max_effect = to_integer_percentage_effects(max_effect)
        for name, value in pairs(max_effect) do
            if ((result[name] or 0) > value) then
                result[name] = value
            end
        end
    end

    for name, value in pairs(result) do
        -- order is important: at the very end clamp to int16_t
        result[name] = clamp_to_16_bit(value)
    end

    return {
        -- also clamp to allowed minimum value and calculate effective values
        consumption = math.max(20, 100 + (result.consumption or 0)) / 100,
        speed = math.max(20, 100 + (result.speed or 0)) / 100,
        productivity = math.max(0, result.productivity or 0) / 100,
        pollution = math.max(20, 100 + (result.pollution or 0)) / 100,
        quality = math.max(0, result.quality or 0) / 100
    }
end

return util
