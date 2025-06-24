local bigpack = require("__big-data-string2__.pack")

---@class (exact) Rates.ExtraData
---@field fusion_reactor table<data.EntityID, { max_fluid_usage: data.FluidAmount }>

---@type Rates.ExtraData
local store = {
    fusion_reactor = {},
}

for _, entity in pairs(data.raw["fusion-reactor"] or {}) do
    store.fusion_reactor[entity.name] = {
        max_fluid_usage = entity.max_fluid_usage,
    }
end

local dump = serpent.dump(store)
data:extend { bigpack("sw-rates-lib", dump) }
