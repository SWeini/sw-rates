local registry = require("configuration-registry")

local temperatures = {}

local cached_fluids = {} ---@type table<string, number[]>
local cached_heat = {} ---@type number[]

---@param values table<number, true>
---@return number[]
local function to_array(values)
    local result = {}
    for value, _ in pairs(values) do
        result[#result + 1] = value
    end

    table.sort(result)
    return result
end

---@param values number[]
---@return table<number, true>
local function from_array(values)
    local result = {}
    for _, value in ipairs(values) do
        result[value] = true
    end

    return result
end

---@param a number[]
---@param b table<number, true>
---@return number[]
local function merge(a, b)
    local result = from_array(a)
    for value, _ in pairs(b) do
        result[value] = true
    end
    return to_array(result)
end

---@param temps Rates.GeneratedTemperatures
local function add_temperatures(temps)
    for name, values in pairs(temps.fluids) do
        cached_fluids[name] = merge(cached_fluids[name] or {}, values)
    end

    cached_heat = merge(cached_heat, temps.heat)
end

local function fill_cache()
    for _, entry in ipairs(registry.get_all_types()) do
        if (entry.logic) then
            if (entry.logic.fill_generated_temperatures) then
                local result = { fluids = {}, heat = {} } ---@type Rates.GeneratedTemperatures
                entry.logic.fill_generated_temperatures(result)
                add_temperatures(result)
            end
        else
            local interface = "sw-rates/configuration/" .. entry.type
            if (remote.interfaces[interface].fill_generated_temperatures) then
                local result = remote.call(interface, "fill_generated_temperatures") --[[@as Rates.GeneratedTemperatures]]
                add_temperatures(result)
            end
        end
    end

    fill_cache = function()
    end
end

---@param all number[]
---@param min? number
---@param max? number
---@return number[]
local function filter_minmax(all, min, max)
    local result = {} ---@type number[]
    for _, value in ipairs(all) do
        if (not min or value >= min) then
            if (not max or value <= max) then
                result[#result + 1] = value
            end
        end
    end

    return result
end

---@param all number[]
---@param fun fun(value: number): boolean
---@return number[]
local function filter_fun(all, fun)
    local result = {} ---@type number[]
    for _, value in ipairs(all) do
        if (fun(value)) then
            result[#result + 1] = value
        end
    end

    return result
end

---@param all number[]
---@param filter? Rates.TemperatureFilter
---@return number[]
local function filter_any(all, filter)
    if (not filter) then
        return all
    end

    if (type(filter) == "table") then
        return filter_minmax(all, filter.min, filter.max)
    end

    return filter_fun(all, filter)
end

---@alias Rates.TemperatureFilter { min: number?, max: number? } | fun(temperature: number): boolean

---@param fluid LuaFluidPrototype | string
---@param filter? Rates.TemperatureFilter
---@return number[]
function temperatures.get_generated_fluid_temperatures(fluid, filter)
    fill_cache()
    local name = type(fluid) == "string" and fluid or fluid.name
    local all = cached_fluids[name] or {}
    return filter_any(all, filter)
end

---@return number[]
---@param filter? Rates.TemperatureFilter
function temperatures.get_generated_heat_temperatures(filter)
    fill_cache()
    local all = cached_heat or {}
    return filter_any(all, filter)
end

return temperatures
