local node = require("node")
local math2d = require("math2d")
local location = require("location")

local util = {
    energy_factor = 1000000.0
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
function util.calculate_energy_source(result, entity, energy_usage)
    local burner = entity.burner_prototype
    if (burner ~= nil) then
        local amount = energy_usage * 60 / burner.effectivity / util.energy_factor

        local categories = {} ---@type LuaFuelCategoryPrototype[]
        for category, _ in pairs(burner.fuel_categories) do
            categories[#categories + 1] = prototypes.fuel_category[category]
        end
        result[#result + 1] = {
            tag = "energy-source-input",
            node = node.create.item_fuels(categories),
            amount = -amount
        }

        return
    end

    local fluid = entity.fluid_energy_source_prototype
    if (fluid ~= nil) then
        local filter = fluid.fluid_box.filter
        if (filter == nil) then
            local amount = energy_usage * 60 / fluid.effectivity / util.energy_factor

            result[#result + 1] = {
                tag = "energy-source-input",
                node = node.create.fluid_fuel(),
                amount = -amount
            }
        elseif (fluid.burns_fluid) then
            result[#result + 1] = {
                tag = "energy-source-input",
                node = node.create.fluid(filter, {}),
                amount = -energy_usage * 60 / fluid.effectivity / filter.fuel_value
            }
        else
            local fluid_usage_per_tick = entity.fluid_usage_per_tick
            if (fluid_usage_per_tick ~= nil) then
                result[#result + 1] = {
                    tag = "energy-source-input",
                    node = node.create.fluid(filter, {}),
                    amount = -fluid_usage_per_tick * 60
                }
            else
                result[#result + 1] = {
                    tag = "energy-source-input",
                    node = node.create.fluid(filter, {}),
                    amount = -1
                }
            end
        end

        return
    end

    local heat = entity.heat_energy_source_prototype
    if (heat ~= nil) then
        result[#result + 1] = {
            tag = "energy-source-input",
            node = node.create.heat({ min = heat.min_working_temperature }),
            amount = -energy_usage * 60 / util.energy_factor
        }

        return
    end

    local electric = entity.electric_energy_source_prototype
    if (electric) then
        result[#result + 1] = {
            tag = "energy-source-input",
            node = node.create.electric_power(),
            amount = -(energy_usage + electric.drain) * 60 / util.energy_factor
        }

        return
    end
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
        local prob_next = quality_next and (force == nil or force.is_quality_unlocked(quality_next)) and quality.next_probability or 0
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
                amount = day / util.energy_factor
            }
        else
            if (day == night) then
                result[#result + 1] = {
                    tag = "product",
                    node = node.create.electric_power(),
                    amount = day / util.energy_factor
                }
            elseif (day > night) then
                if (night > 0) then
                    result[#result + 1] = {
                        tag = "product",
                        node = node.create.electric_power(),
                        amount = night / util.energy_factor
                    }
                end
                result[#result + 1] = {
                    tag = "product",
                    node = node.create.electric_power(true),
                    amount = (day - night) / util.energy_factor
                }
            elseif (night > day) then
                if (day > 0) then
                    result[#result + 1] = {
                        tag = "product",
                        node = node.create.electric_power(),
                        amount = day / util.energy_factor
                    }
                end
                result[#result + 1] = {
                    tag = "product",
                    node = node.create.electric_power(false),
                    amount = (night - day) / util.energy_factor
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
                amount = -energy_buffer / util.energy_factor
            }
        end
        result[#result + 1] = {
            tag = "product",
            node = node.create.electric_power(),
            amount = average / util.energy_factor
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

---@type { [defines.inventory]: true }
local module_inventories = {
    [defines.inventory.assembling_machine_modules] = true,
    [defines.inventory.beacon_modules] = true,
    [defines.inventory.furnace_modules] = true,
    [defines.inventory.lab_modules] = true,
    [defines.inventory.mining_drill_modules] = true,
    [defines.inventory.rocket_silo_modules] = true
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
    if (a.module.name ~= b.module.name) then
        return a.module.name < b.module.name
    end

    return a.quality.name < b.quality.name
end

---@param a Rates.Configuration.Beacon
---@param b Rates.Configuration.Beacon
---@return boolean
local function compare_beacon(a, b)
    if (a.beacon.name ~= b.beacon.name) then
        return a.beacon.name < b.beacon.name
    end

    return a.quality.name < b.quality.name
end

---@param modules Rates.Configuration.Module[]
function util.sort_modules(modules)
    table.sort(modules, compare_module)
end

---@param beacons Rates.Configuration.Beacon[]
function util.sort_beacons(beacons)
    table.sort(beacons, compare_beacon)
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
function util.filter_beacons(beacons, accept)
    for _, beacon in ipairs(beacons) do
        beacon.total_modules = util.filter_modules(beacon.total_modules, accept)
    end
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

    local requester
    if (entity.type == "entity-ghost") then
        requester = entity
    else
        requester = entity.item_request_proxy
        if (requester) then
            for _, plan in ipairs(requester.removal_plan) do
                for _, pos in pairs(plan.items.in_inventory or {}) do
                    if (module_inventories[pos.inventory]) then
                        result[pos.stack + 1] = nil
                    end
                end
            end
        end
    end

    if (requester) then
        for _, plan in ipairs(requester.insert_plan) do
            for _, pos in pairs(plan.items.in_inventory or {}) do
                if (module_inventories[pos.inventory]) then
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
    ---@type BoundingBox
    local supply_box = {
        left_top = math2d.position.subtract(beacon_box.left_top, diagonal),
        right_bottom = math2d.position.add(beacon_box.right_bottom, diagonal)
    }

    return math2d.bounding_box.collides_with(supply_box, entity_box)
end

---@param map table<string, { beacon: LuaEntityPrototype, quality: LuaQualityPrototype, count: integer, modules: table<string, Rates.Configuration.Module> }>
---@param beacon LuaEntityPrototype
---@param beacon_quality LuaQualityPrototype
---@return table<string, Rates.Configuration.Module>
local function add_beacon(map, beacon, beacon_quality)
    local key = beacon.name .. "/" .. beacon_quality.name
    local entry = map[key]
    if (not entry) then
        entry = {
            beacon = beacon,
            quality = beacon_quality,
            count = 0,
            modules = {}
        }
        map[key] = entry
    end

    entry.count = entry.count + 1
    return entry.modules
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
    local max_distance = prototypes.max_beacon_supply_area_distance + 64
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

    local map = {} ---@type table<string, { beacon: LuaEntityPrototype, quality: LuaQualityPrototype, count: integer, modules: table<string, Rates.Configuration.Module> }>
    for _, beacon in ipairs(useful_beacons) do
        if (is_beacon_in_range(entity, beacon.entity, beacon.prototype, beacon.quality)) then
            local beacon_data = add_beacon(map, beacon.prototype, beacon.quality)
            local module_slots = util.collect_modules(beacon.entity, use_ghosts)
            for _, module in pairs(module_slots) do
                add_module(beacon_data, module.module, module.quality)
            end
        end
    end

    local result = {} ---@type Rates.Configuration.Beacon[]
    for _, beacon in pairs(map) do
        local modules = {} ---@type Rates.Configuration.Module[]
        for _, module in pairs(beacon.modules) do
            modules[#modules + 1] = module
        end

        util.sort_modules(modules)
        result[#result + 1] = {
            beacon = beacon.beacon,
            quality = beacon.quality,
            count = beacon.count,
            total_modules = modules
        }
    end

    util.sort_beacons(result)
    return result
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
        util.filter_beacons(effects.beacons, accept)
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
                local positive = effect > 0
                if (not positive_module_effect[property]) then
                    positive = not positive
                end

                if (positive) then
                    game.print("effect " .. property .. " not allowed: " .. effect)
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

---@param effects ModuleEffects
---@param multiplier number
---@param quality number
---@return ModuleEffects
function util.module_mult(effects, multiplier, quality)
    local result = {}
    for _, property in ipairs(all_module_effects) do
        local value = effects[property]
        if (value) then
            local positive = value > 0
            if (not positive_module_effect[property]) then
                positive = not positive
            end

            result[property] = value * multiplier * (positive and quality or 1)
        end
    end
    return result
end

---@param effects ModuleEffects[]
---@return ModuleEffects
function util.module_add(effects)
    local result = {}
    for _, property in ipairs(all_module_effects) do
        local sum = 0
        for _, effects in ipairs(effects) do
            local value = effects[property]
            if (value) then
                sum = sum + value
            end
        end

        if (sum ~= 0) then
            result[property] = sum
        end
    end
    return result
end

---@param modules Rates.Configuration.Module[]
---@param module_check fun(module: LuaItemPrototype): boolean)
---@return ModuleEffects
function util.get_module_effects(modules, module_check)
    ---@type ModuleEffects[]
    local result = {}
    for _, module in ipairs(modules or {}) do
        if (module_check(module.module)) then
            local quality = 1 + module.quality.level * 0.3
            local effects = util.module_mult(module.module.module_effects, module.count, quality)
            table.insert(result, effects)
        end
    end

    return util.module_add(result)
end

---@param beacons Rates.Configuration.Beacon[]
---@param module_check fun(module: LuaItemPrototype): boolean)
---@return ModuleEffects
function util.get_beacon_effects(beacons, module_check)
    if (not beacons) then
        return {}
    end

    local beacon_count = 0
    local beacon_counts = {} ---@type table<string, integer>
    for _, beacon in ipairs(beacons) do
        beacon_count = beacon_count + beacon.count
        local name = beacon.beacon.name
        beacon_counts[name] = (beacon_counts[name] or 0) + beacon.count
    end

    ---@type ModuleEffects[]
    local result = {}
    for _, beacon in ipairs(beacons) do
        local profile = beacon.beacon.profile
        if (not profile or #profile == 0) then
            profile = { 1 }
        end
        local count
        if (beacon.beacon.beacon_counter == "total") then
            count = beacon_count
        else
            count = beacon_counts[beacon.beacon.name]
        end
        local idx = math.min(count, #profile)
        local profile_multiplier = profile[idx]
        local effectivity = beacon.beacon.distribution_effectivity
        local effectivity_per_level = beacon.beacon.distribution_effectivity_bonus_per_quality_level or 0
        local total_effectivity = (effectivity + beacon.quality.level * effectivity_per_level) * profile_multiplier
        for _, module in ipairs(beacon.total_modules) do
            if (module_check(module.module)) then
                local quality = 1 + module.quality.level * 0.3
                local effects = util.module_mult(module.module.module_effects, module.count * total_effectivity, quality)
                table.insert(result, effects)
            end
        end
    end

    return util.module_add(result)
end

---@param effects ModuleEffects
---@return ModuleEffects
function util.get_effective_values(effects)
    return {
        consumption = math.max(0.2, 1 + (effects.consumption or 0)),
        speed = math.max(0.2, 1 + (effects.speed or 0)),
        productivity = math.max(0, effects.productivity or 0),
        pollution = math.max(0.2, 1 + (effects.pollution or 0)),
        quality = math.max(0, effects.quality or 0)
    }
end

return util
