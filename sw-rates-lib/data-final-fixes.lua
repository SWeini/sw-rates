local bigpack = require("__big-data-string2__.pack")

---@class (exact) Rates.ExtraData.DyingEffect
---@field type "entity" | "asteroid-chunk"
---@field name string
---@field repeat_count integer
---@field probability number
---@field count? integer

---@class (exact) Rates.ExtraData
---@field asteroid_dying table<data.EntityID, Rates.ExtraData.DyingEffect[]>
---@field fusion_reactor table<data.EntityID, { max_fluid_usage: data.FluidAmount, neighbour_connectable: data.NeighbourConnectable? }>

---@type Rates.ExtraData
local store = {
    asteroid_dying = {},
    fusion_reactor = {},
}

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

for _, entity in pairs(data.raw["fusion-reactor"] or {}) do
    store.fusion_reactor[entity.name] = {
        max_fluid_usage = entity.max_fluid_usage,
        neighbour_connectable = entity.neighbour_connectable
    }
end

local dump = serpent.dump(store)
data:extend { bigpack("sw-rates-lib", dump) }
