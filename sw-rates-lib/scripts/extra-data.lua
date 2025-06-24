local bigunpack = require("__big-data-string2__.unpack")

local dump = bigunpack("sw-rates-lib")
local success, store = serpent.load(dump, { safe = true })

if (not success) then
    error("failed to load big-data: " .. tostring(store))
end

---@cast store Rates.ExtraData

---@param entity LuaEntityPrototype
---@return number
local function fusion_reactor_max_fluid_usage(entity)
    return store.fusion_reactor[entity.name].max_fluid_usage
end

return {
    store = store,
    fusion_reactor_max_fluid_usage = fusion_reactor_max_fluid_usage,
}
