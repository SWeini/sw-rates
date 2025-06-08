do
    ---@class Rates.Configuration.PyPower : Rates.Configuration.Base
    ---@field type "py-power"
    ---@field entity LuaEntityPrototype
    ---@field quality LuaQualityPrototype
end

local api = require("__sw-rates-lib__.api-configuration")
local configuration = api.configuration
local node = api.node
local progression = api.progression

local logic = { type = "py-power" } ---@type Rates.Configuration.Type

local turbines = {
    ["multiblade-turbine-mk01"] = 550 * 1e3,
    ["multiblade-turbine-mk03"] = 34 * 1e6,

    ["hawt-turbine-mk01"] = 5 * 1e6,
    ["hawt-turbine-mk02"] = 25 * 1e6,
    ["hawt-turbine-mk03"] = 50 * 1e6,
    ["hawt-turbine-mk04"] = 80 * 1e6,

    ["vawt-turbine-mk01"] = 4 * 1e6,
    ["vawt-turbine-mk02"] = 20 * 1e6,
    ["vawt-turbine-mk03"] = 50 * 1e6,
    ["vawt-turbine-mk04"] = 85 * 1e6,

    ["tidal-mk01"] = 6 * 1e6,
    ["tidal-mk02"] = 30 * 1e6,
    ["tidal-mk03"] = 55 * 1e6,
    ["tidal-mk04"] = 75 * 1e6
}

---@param conf Rates.Configuration.PyPower
logic.gui_recipe = function(conf)
    return { sprite = "tooltip-category-electricity" }
end

---@param conf Rates.Configuration.PyPower
logic.get_production = function(conf, result, options)
    local amount = turbines[conf.entity.name]
    if (amount) then
        result[#result + 1] = {
            tag = "product",
            node = node.create.electric_power(),
            amount = amount / configuration.energy_factor
        }
    end
end

logic.fill_progression = function(result, options)
    for name, _ in pairs(turbines) do
        local entity = prototypes.entity[name]
        for _, loc in ipairs(options.locations) do
            local id = "py-power/" .. entity.name .. "/" .. loc
            result[id] = {
                pre = {
                    progression.create.map_entity(entity.name, loc)
                },
                post = {
                    progression.create.electric_power(loc)
                }
            }
        end
    end
end

---@param result Rates.Configuration.PyPower[]
logic.fill_basic_configurations = function(result, options)
    for name, _ in pairs(turbines) do
        result[#result + 1] = {
            type = nil, ---@diagnostic disable-line: assign-type-mismatch
            id = nil, ---@diagnostic disable-line: assign-type-mismatch
            entity = prototypes.entity[name],
            quality = prototypes.quality.normal
        }
    end
end

logic.get_from_entity = function(entity, options)
    if (options.type ~= "electric-energy-interface") then
        return
    end

    local prototype = options.entity

    if (prototype.name:sub(#prototype.name - 5) == "-blank") then
        prototype = prototypes.entity[prototype.name:sub(1, #prototype.name - 6)]
        if (not prototype) then
            return
        end
    end

    if (turbines[prototype.name])
    then
        ---@type Rates.Configuration.PyPower
        return {
            type = nil, ---@diagnostic disable-line: assign-type-mismatch
            id = nil, ---@diagnostic disable-line: assign-type-mismatch
            entity = prototype,
            quality = options.quality
        }
    end
end

return logic
