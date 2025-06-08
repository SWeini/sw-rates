local bigunpack = require("__big-data-string2__.unpack")

local dump = bigunpack("sw-rates-lib")
local success, store = serpent.load(dump, { safe = true })

if (not success) then
    error("failed to load big-data: " .. tostring(store))
end

---@cast store Rates.ExtraData

---@param entity LuaEntityPrototype
---@return data.ThrusterPerformancePoint.struct
local function thruster_min_performance(entity)
    return store.thruster[entity.name].min_performance
end

---@param entity LuaEntityPrototype
---@return data.ThrusterPerformancePoint.struct
local function thruster_max_performance(entity)
    return store.thruster[entity.name].max_performance
end

---@param item LuaItemPrototype
---@return LuaSurfacePrototype?
local function space_platform_starter_pack_surface(item)
    local surface = store.space_platform_starter_pack[item.name]
    if (surface) then
        return prototypes.surface[surface]
    end
end

---@param entity LuaEntityPrototype
---@return LuaEntityPrototype?
local function unit_spawner_captured_spawner_entity(entity)
    local captured = store.captured_spawner[entity.name]
    if (captured) then
        return prototypes.entity[captured]
    end
end

local rocket_lift_weight = store["utility-constants"].rocket_lift_weight

---@param entity LuaEntityPrototype
---@return number
local function fusion_generator_max_fluid_usage(entity)
    return store.fusion_generator[entity.name].max_fluid_usage
end

---@param entity LuaEntityPrototype
---@return number
local function fusion_reactor_max_fluid_usage(entity)
    return store.fusion_reactor[entity.name].max_fluid_usage
end

---@param entity LuaEntityPrototype
---@return number
local function fusion_reactor_neighbour_bonus(entity)
    return store.fusion_reactor[entity.name].neighbour_bonus or 1
end

---@param entity LuaEntityPrototype
---@return data.NeighbourConnectable
local function fusion_reactor_neighbour_connectable(entity)
    return store.fusion_reactor[entity.name].neighbour_connectable or { connections = {} }
end

return {
    store = store,
    thruster_min_performance = thruster_min_performance,
    thruster_max_performance = thruster_max_performance,
    space_platform_starter_pack_surface = space_platform_starter_pack_surface,
    unit_spawner_captured_spawner_entity = unit_spawner_captured_spawner_entity,
    fusion_generator_max_fluid_usage = fusion_generator_max_fluid_usage,
    fusion_reactor_max_fluid_usage = fusion_reactor_max_fluid_usage,
    fusion_reactor_neighbour_bonus = fusion_reactor_neighbour_bonus,
    fusion_reactor_neighbour_connectable = fusion_reactor_neighbour_connectable,
    rocket_lift_weight = rocket_lift_weight
}
