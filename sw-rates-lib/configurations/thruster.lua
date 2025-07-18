do
    ---@class (exact) Rates.Configuration.Thruster : Rates.Configuration.Base
    ---@field type "thruster"
    ---@field entity LuaEntityPrototype
    ---@field quality LuaQualityPrototype
end

local configuration = require("scripts.configuration-util")
local node = require("scripts.node")
local progression = require("scripts.progression")

local logic = { type = "thruster" } ---@type Rates.Configuration.Type

local entities = configuration.get_all_entities("thruster")

---@param prototype LuaEntityPrototype
---@return { fuel: LuaFluidPrototype, oxidizer: LuaFluidPrototype }
local function get_fluids(prototype)
    local fluidbox = prototype.fluidbox_prototypes
    local fuel = fluidbox[#fluidbox - 1].filter --[[@as LuaFluidPrototype]]
    local oxidizer = fluidbox[#fluidbox].filter --[[@as LuaFluidPrototype]]
    return { fuel = fuel, oxidizer = oxidizer }
end

---@return { fluid_usage: number, effectivity: number }
local function get_performance(prototype, load)
    local min = prototype.min_performance ---@cast min -nil
    local max = prototype.max_performance ---@cast max -nil
    local fluid_usage = load * max.fluid_usage
    if (fluid_usage >= max.fluid_usage) then
        return { fluid_usage = max.fluid_usage, effectivity = max.effectivity }
    elseif (fluid_usage <= min.fluid_usage) then
        return { fluid_usage = max.fluid_usage, effectivity = min.effectivity }
    else
        local a = (fluid_usage - min.fluid_usage) / (max.fluid_usage - min.fluid_usage)
        local b = 1 - a
        return {
            fluid_usage = max.fluid_usage,
            effectivity = b * min.effectivity + a * max.effectivity
        }
    end
end

---@param conf Rates.Configuration.Thruster
logic.gui_recipe = function(conf)
    ---@type Rates.Gui.NodeDescription
    return {
        icon = { sprite = "tooltip-category-thrust" },
        name = { "sw-rates-node.thrust" }
    }
end

---@param conf Rates.Configuration.Thruster
logic.get_production = function(conf, result, options)
    local load = options.load or 1
    local fluids = get_fluids(conf.entity)
    local energy_usage = conf.entity.get_max_energy_usage(conf.quality)
    local factor = conf.quality.default_multiplier
    local performance = get_performance(conf.entity, load)
    configuration.calculate_energy_source(result, conf.entity, energy_usage, options)
    result[#result + 1] = {
        tag = "ingredient",
        tag_extra = "fuel",
        node = node.create.fluid(fluids.fuel, {}),
        amount = -performance.fluid_usage * 60 * factor
    }
    result[#result + 1] = {
        tag = "ingredient",
        tag_extra = "oxidizer",
        node = node.create.fluid(fluids.oxidizer, {}),
        amount = -performance.fluid_usage * 60 * factor
    }
    local fuel = (fluids.fuel.fuel_value + fluids.oxidizer.fuel_value) * performance.fluid_usage
    result[#result + 1] = {
        tag = "product",
        node = node.create.thrust(),
        amount = fuel * performance.effectivity * 1000 * factor -- as N
    }
end

logic.fill_progression = function(result, options)
    for _, entity in pairs(entities) do
        local fluids = get_fluids(entity)
        local id = "thruster/" .. entity.name .. "/*"
        result[id] = {
            pre = {
                progression.create.map_entity(entity.name, "*"),
                progression.create.fluid(fluids.fuel.name, {}, "*"),
                progression.create.fluid(fluids.oxidizer.name, {}, "*")
            },
            post = {
                progression.create.thrust("*")
            },
            multi = options.locations
        }
    end
end

logic.get_from_entity = function(entity, options)
    if (options.type ~= "thruster") then
        return
    end

    ---@type Rates.Configuration.Thruster
    return {
        type = nil, ---@diagnostic disable-line: assign-type-mismatch
        entity = options.entity,
        quality = options.quality
    }
end

return logic
