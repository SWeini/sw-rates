---@diagnostic disable: undefined-doc-name

---@alias Rates.Location
--- | LuaSurface
--- | Rates.Location.Base
--- | Rates.Location.Extension alias this type in your mod to extend Rates.Location to your own types

---@diagnostic enable: undefined-doc-name

---Description for a location.
---@class Rates.Location.Base
---@field type string
---@field id string

---@param location Rates.Location
---@return ModuleEffects?
local function get_global_effect(location)
    ---@diagnostic disable-next-line: param-type-mismatch
    if (location.object_name == "LuaSurface") then ---@cast location LuaSurface
        return location.global_effect
    end

    error("invalid location")
end

---@param location Rates.Location
---@param property LuaSurfacePropertyPrototype
---@return number
local function get_property(location, property)
    ---@diagnostic disable-next-line: param-type-mismatch
    if (location.object_name == "LuaSurface") then ---@cast location LuaSurface
        return location.get_property(property)
    end

    error("invalid location")
end

---@param location Rates.Location
---@param property LuaSurfacePropertyPrototype
---@return number
local function get_solar_power(location, property)
    ---@diagnostic disable-next-line: param-type-mismatch
    if (location.object_name == "LuaSurface") then ---@cast location LuaSurface
        local planet = location.planet
        if (planet) then
            return location.get_property(property) * location.solar_power_multiplier
        end

        local platform = location.platform
        if (platform) then
            if (platform.space_location) then
                return platform.space_location.solar_power_in_space * location.solar_power_multiplier
            elseif (platform.space_connection) then
                local from, to = platform.space_connection.from, platform.space_connection.to
                return (from.solar_power_in_space + to.solar_power_in_space) / 2 * location.solar_power_multiplier
            end
        end
    end

    error("invalid location")
end

---@param location Rates.Location
---@return LuaSurface.daytime_parameters
local function get_daytime_parameters(location)
    ---@diagnostic disable-next-line: param-type-mismatch
    if (location.object_name == "LuaSurface") then ---@cast location LuaSurface
        return location.daytime_parameters
    end

    error("invalid location")
end

return {
    get_global_effect = get_global_effect,
    get_property = get_property,
    get_solar_power = get_solar_power,
    get_daytime_parameters = get_daytime_parameters,
}
