local bigpack = require("__big-data-string2__.pack")

local utility_constants = data.raw["utility-constants"].default

---@class (exact) Rates.ExtraData.DyingEffect
---@field type "entity" | "asteroid-chunk"
---@field name string
---@field repeat_count integer
---@field probability number
---@field count? integer

---@class (exact) Rates.ExtraData
---@field thruster table<data.EntityID, { min_performance: data.ThrusterPerformancePoint.struct, max_performance: data.ThrusterPerformancePoint.struct }>
---@field send_to_orbit_mode table<data.ItemID, data.SendToOrbitMode>
---@field space_platform_starter_pack table<data.ItemID, data.SurfaceID>
---@field asteroid_dying table<data.EntityID, Rates.ExtraData.DyingEffect[]>
---@field captured_spawner table<data.EntityID, data.EntityID>
---@field fusion_generator table<data.EntityID, { max_fluid_usage: data.FluidAmount }>
---@field fusion_reactor table<data.EntityID, { max_fluid_usage: data.FluidAmount, neighbour_bonus: float?, neighbour_connectable: data.NeighbourConnectable? }>
---@field ["utility-constants"] { rocket_lift_weight: data.Weight }

---@type Rates.ExtraData
local store = {
    thruster = {},
    send_to_orbit_mode = {},
    space_platform_starter_pack = {},
    asteroid_dying = {},
    captured_spawner = {},
    fusion_generator = {},
    fusion_reactor = {},
    ["utility-constants"] = {}
}

store["utility-constants"].rocket_lift_weight = utility_constants.rocket_lift_weight

for type, _ in pairs(defines.prototypes.item) do
    for _, item in pairs(data.raw[type] or {}) do
        if (item.send_to_orbit_mode and item.send_to_orbit_mode ~= "not-sendable") then
            store.send_to_orbit_mode[item.name] = item.send_to_orbit_mode
        end
    end
end

for _, item in pairs(data.raw["space-platform-starter-pack"] or {}) do
    store.space_platform_starter_pack[item.name] = item.surface
end

---@param x data.ThrusterPerformancePoint
---@return data.ThrusterPerformancePoint.struct
local function thruster_performance(x)
    return {
        fluid_volume = x.fluid_volume or x[1],
        fluid_usage = x.fluid_usage or x[2],
        effectivity = x.effectivity or x[3]
    }
end

for _, entity in pairs(data.raw["thruster"] or {}) do
    store.thruster[entity.name] = {
        min_performance = thruster_performance(entity.min_performance),
        max_performance = thruster_performance(entity.max_performance)
    }
end

---@param effect data.TriggerEffect?
---@param result Rates.ExtraData.DyingEffect[]
local function get_dying_spawns(effect, result)
    if (not effect) then
        return
    end

    if (not effect.type) then
        for _, eff in ipairs(effect) do
            get_dying_spawns(eff, result)
        end

        return
    end

    if (effect.type == "create-asteroid-chunk") then
        local repeat_count = effect.repeat_count or 1
        local probability = effect.probability or 1
        local count = effect.offsets and #effect.offsets
        result[#result + 1] = {
            type = "asteroid-chunk",
            name = effect.asteroid_name,
            repeat_count = repeat_count,
            probability = probability,
            count = count
        }
    elseif (effect.type == "create-entity") then
        if (not data.raw["asteroid"][effect.entity_name]) then
            return
        end

        local repeat_count = effect.repeat_count or 1
        local probability = effect.probability or 1
        local count = effect.offsets and #effect.offsets
        result[#result + 1] = {
            type = "entity",
            name = effect.entity_name,
            repeat_count = repeat_count,
            probability = probability,
            count = count
        }
    end
end

for _, asteroid in pairs(data.raw["asteroid"] or {}) do
    local effects = {} ---@types Rates.ExtraData.DyingEffect[]
    get_dying_spawns(asteroid.dying_trigger_effect, effects)
    store.asteroid_dying[asteroid.name] = effects
end

for _, spawner in pairs(data.raw["unit-spawner"] or {}) do
    store.captured_spawner[spawner.name] = spawner.captured_spawner_entity
end

for _, entity in pairs(data.raw["fusion-generator"] or {}) do
    store.fusion_generator[entity.name] = {
        max_fluid_usage = entity.max_fluid_usage
    }
end

for _, entity in pairs(data.raw["fusion-reactor"] or {}) do
    store.fusion_reactor[entity.name] = {
        max_fluid_usage = entity.max_fluid_usage,
        neighbour_bonus = entity.neighbour_bonus,
        neighbour_connectable = entity.neighbour_connectable
    }
end

local dump = serpent.dump(store)
data:extend { bigpack("sw-rates-lib", dump) }
