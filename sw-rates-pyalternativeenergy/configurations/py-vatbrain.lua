local math2d = require("math2d")
local configuration = require("__sw-rates-lib__.scripts.configuration-util")

local logic = { type = "py-vatbrain", stats = { priority = 100 } } ---@type Rates.Configuration.Type

logic.affects_entity = function(prototype)
    return prototype.type == "lab"
end

local vatbrain_machine_name = "vat-brain"
local vatbrain_beacon_name = "hidden-beacon-vatbrain"

local vatbrain_beacon = prototypes.entity[vatbrain_beacon_name]
local vatbrain_distance = vatbrain_beacon.get_supply_area_distance(prototypes.quality.normal)

---@param entity LuaEntity
---@return string?
local function get_associated_module(entity)
    local recipe, quality = entity.get_recipe()
    if (not recipe) then
        return
    end

    local name = recipe.name

    if (name:sub(1, 12) ~= "brain-food-0") then
        return
    end

    local tier = tonumber(name:sub(13, 13))
    return "vatbrain-" .. tier
end

logic.modify_from_entity = function(entity, conf, options)
    if (conf.type ~= "lab") then
        return
    end

    local beacons = conf.module_effects.beacons
    if (beacons) then
        for i = #beacons, 1, -1 do
            local beacon = beacons[i]
            if (beacon.beacon.name == vatbrain_beacon_name) then
                table.remove(beacons, i)
            end
        end
    end

    local use_ghosts = options.use_ghosts

    local entity_box = entity.bounding_box
    local max_distance = vatbrain_distance + 1
    local diagonal = { x = max_distance, y = max_distance }
    local search_box = {
        left_top = math2d.position.subtract(entity_box.left_top, diagonal),
        right_bottom = math2d.position.add(entity_box.right_bottom, diagonal)
    }

    local candidates = {} ---@type LuaEntity[]
    for _, entity in ipairs(entity.surface.find_entities_filtered { name = vatbrain_machine_name, area = search_box }) do
        candidates[#candidates + 1] = entity
    end
    if (use_ghosts) then
        for _, ghost in ipairs(entity.surface.find_entities_filtered { type = "entity-ghost", ghost_name = vatbrain_machine_name, area = search_box }) do
            candidates[#candidates + 1] = ghost
        end
    end

    local modules = {} ---@type table<string, integer>
    for _, candidate in ipairs(candidates) do
        local data = configuration.get_useful_entity_data(candidate, use_ghosts)
        if (data) then
            local module_name = get_associated_module(candidate)
            if (module_name) then
                local position = candidate.position
                local beacon_box = vatbrain_beacon.collision_box
                local diagonal = { x = vatbrain_distance, y = vatbrain_distance }
                ---@type BoundingBox.0
                local supply_box = {
                    left_top = math2d.position.add(position, math2d.position.subtract(beacon_box.left_top, diagonal)),
                    right_bottom = math2d.position.add(position, math2d.position.add(beacon_box.right_bottom, diagonal))
                }

                if (configuration.bbox_collide(supply_box, entity_box)) then
                    modules[module_name] = (modules[module_name] or 0) + 1
                end
            end
        end
    end

    ---@type { name: string, count: integer }[]
    local module_table = {}
    for module_name, count in pairs(modules) do
        module_table[#module_table + 1] = { name = module_name, count = count }
    end

    table.sort(module_table, function(a, b)
        return a.name < b.name
    end)

    for _, module in ipairs(module_table) do
        if (not beacons) then
            beacons = {}
        end
        beacons[#beacons + 1] = {
            beacon = vatbrain_beacon,
            quality = prototypes.quality.normal,
            count = module.count,
            per_beacon_modules = {
                {
                    module = prototypes.item[module.name],
                    quality = prototypes.quality.normal,
                    count = 1
                }
            }
        }
    end

    if (beacons and #beacons == 0) then
        beacons = nil
    end

    conf.module_effects.beacons = beacons

    return conf
end

return logic
