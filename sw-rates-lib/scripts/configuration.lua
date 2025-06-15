---A single entity or concept consuming and producing some nodes.
---@class Rates.Configuration.Base
---@field type string
---@field id string
---@field entity? LuaEntityPrototype
---@field quality? LuaQualityPrototype
---@field module_effects? Rates.Configuration.ModuleEffects

---Description for a type of configuration.
---@class (exact) Rates.Configuration.Type
---@field type string must be unique, please use a mod-specific prefix like "my-mod-"
---@field stats? Rates.Configuration.Type.Stats
---
---Generates the id field (the fields in Rates.Configuration.Base are added on top)
---@field get_id? fun(conf: Rates.Configuration): string
---Used to provide GUI in the recipe column
---@field gui_recipe? fun(conf: Rates.Configuration): Rates.Gui.NodeDescription
---Used to provide GUI in the entity column
---@field gui_entity? fun(conf: Rates.Configuration): Rates.Gui.NodeDescription
---Calculates the production rates of a configuration
---@field get_production? fun(conf: Rates.Configuration, result: Rates.Configuration.Amount[], options: Rates.Configuration.ProductionOptions)
---
---Used to divide fluids and heat into different temperatures
---@field fill_generated_temperatures? fun(result: Rates.GeneratedTemperatures)
---Used to provide scripted locations (need to provide the transport methods yourself)
---@field fill_progression_locations? fun(result: string[], options: Rates.Progression.Options)
---Used to provide scripted elements that are relevant for milestone calculations
---@field fill_progression? fun(result: Rates.Progression.Rules, options: Rates.Progression.Options)
---Used to provide Factoriopedia-like information
---@field fill_basic_configurations? fun(result: Rates.Configurations, options: Rates.Configuration.FillBasicOptions)
---Used to give the best possible description of an existing entity
---@field get_from_entity? fun(entity: LuaEntity, options: Rates.Configuration.FromEntityOptions.Internal): Rates.Configuration?

---@class (exact) Rates.Configuration.Type.Stats
---@field priority? number defaults to 0

---@class (exact) Rates.GeneratedTemperatures
---@field fluids table<string, table<number, true>>
---@field heat table<number, true>

---@class (exact) Rates.Progression.Options
---@field locations string[]
---@field blocked_types? string[]

---@alias Rates.Progression.Rules table<string, Rates.Progression.Rule>

---@class (exact) Rates.Progression.Rule
---@field pre Rates.Progression.Pre
---@field post Rates.Progression.Post
---@field multi? string[] will generate multiple rules by replacing a trailing * with each of these strings

---@class Rates.Progression.SingleItem : string

---@alias Rates.Progression.Pre (Rates.Progression.SingleItem | Rates.Progression.MultiItemPre)[]
---@alias Rates.Progression.Post (Rates.Progression.SingleItem | Rates.Progression.MultiItemPost)[]
---@alias Rates.Progression.MultiItemPre Rates.Progression.SingleItem[] any of the items fulfills the precondition
---@alias Rates.Progression.MultiItemPost Rates.Progression.SingleItem[] this will mark all postconditions as fulfilled

---@class (exact) Rates.Configuration.FillBasicOptions

---@class (exact) Rates.Configuration.FromEntityOptions
---@field use_ghosts? boolean defaults to true (use ghosts and everything else that will be built eventually)

---@class (exact) Rates.Configuration.FromEntityOptions.Internal
---@field use_ghosts boolean
---@field type string type of the entity
---@field entity LuaEntityPrototype prototype of the entity
---@field quality LuaQualityPrototype quality of the entity

---@class (exact) Rates.Configuration.ProductionOptions
---@field load? number defaults to 1 (full load)
---@field apply_quality? boolean defaults to false (don't create higher quality items)
---@field solar_panel_mode? "day-and-night" | "average-and-buffer" defaults to "average-and-buffer"
---@field force? LuaForce used to calculate force-specific boni
---@field surface? Rates.Location used to add global effects on that surface

---@class (exact) Rates.Configuration.Amount
---@field tag "energy-source-input" | "energy-source-output" | "resource" | "mining-fluid" | "ingredient" | "product" | "infrastructure"
---@field tag_extra? number | string | "drain" | "burnt-result"
---@field node Rates.Node
---@field amount number

---@alias Rates.Configurations Rates.Configuration[]

---@class (exact) Rates.Configuration.ModuleEffects
---@field modules? Rates.Configuration.Module[]
---@field beacons? Rates.Configuration.Beacon[]

---@class (exact) Rates.Configuration.Module
---@field module LuaItemPrototype
---@field quality LuaQualityPrototype
---@field count integer

---@class (exact) Rates.Configuration.Beacon
---@field beacon LuaEntityPrototype
---@field quality LuaQualityPrototype
---@field count integer
---@field per_beacon_modules Rates.Configuration.Module[]

local registry = require("configuration-registry")
local util = require("configuration-util")

---@param type string
---@return string
local function interface_name(type)
    return "sw-rates/configuration/" .. type
end

---@param type Rates.Configuration.Type
local function register_one(type)
    local functions = {
        stats = type.stats and function()
            return type.stats
        end,
        fill_generated_temperatures = type.fill_generated_temperatures and function()
            local result = { fluids = {}, heat = {} } ---@type Rates.GeneratedTemperatures
            type.fill_generated_temperatures(result)
            return result
        end,
        fill_progression_locations = type.fill_progression_locations and function(options)
            local result = {} ---@type string[]
            type.fill_progression_locations(result, options)
            return result
        end,
        fill_progression = type.fill_progression and function(options)
            local result = {} ---@type Rates.Progression.Rules
            type.fill_progression(result, options)
            return result
        end,
        fill_basic_configurations = type.fill_basic_configurations and function(options)
            local result = {} ---@type Rates.Configurations
            type.fill_basic_configurations(result, options)
            return result
        end,
        get_from_entity = type.get_from_entity,
        get_id = type.get_id,
        gui_recipe = type.gui_recipe,
        gui_entity = type.gui_entity,
        get_production = type.get_production and function(conf, options)
            local result = {} ---@type Rates.Configuration.Amount[]
            type.get_production(conf, result, options)
            return result
        end,
    }
    remote.add_interface(interface_name(type.type), functions)
    remote.call("sw-rates/configuration", "register_type", type.type, type.stats and type.stats.priority)
end

---@param types table<any, Rates.Configuration.Type>
local function register(types)
    for _, type in ipairs(types) do
        register_one(type)
    end
end

---@param text string
---@param pattern string
---@return string?
local function replace_end(text, pattern)
    if (string.sub(text, #text - #pattern + 1) == pattern) then
        return string.sub(text, 1, #text - #pattern)
    end
end

---@param node string
---@param replacement string
---@return string
---@overload fun(node: string[], replacement: string): string[]
local function unfold_prog(node, replacement)
    if (type(node) == "string") then
        local text = replace_end(node, "/*")
        if (text) then
            return text .. "/" .. replacement
        else
            return node
        end
    end

    local result = {}
    for _, n in ipairs(node) do
        result[#result + 1] = unfold_prog(n, replacement)
    end

    return result
end

---@param id string
---@param rule Rates.Progression.Rule
---@return Rates.Progression.Rules
local function unfold_rule(id, rule)
    if (not rule.multi) then
        return { [id] = rule }
    end

    local result = {} ---@type Rates.Progression.Rules

    for _, alt in ipairs(rule.multi) do
        local id2 = unfold_prog(id, alt)
        local pre = {}
        for _, node in ipairs(rule.pre) do
            pre[#pre + 1] = unfold_prog(node, alt)
        end

        local post = {}
        for _, node in ipairs(rule.post) do
            post[#post + 1] = unfold_prog(node, alt)
        end

        result[id2] = { pre = pre, post = post }
    end

    return result
end

---@param conf Rates.Configuration
---@return string
local function get_id(conf)
    local logic = registry.get(conf.type)
    local result = ""
    if (logic) then
        if (logic.get_id) then
            result = logic.get_id(conf)
        end
    else
        local interface = interface_name(conf.type)
        if (remote.interfaces[interface].get_id) then
            result = remote.call(interface, "get_id", conf) --[[@as string]]
        end
    end

    if (conf.entity and conf.quality) then
        if (result ~= "") then
            result = conf.entity.name .. "(" .. conf.quality.name .. ")/" .. result
        else
            result = conf.entity.name .. "(" .. conf.quality.name .. ")"
        end
    end

    if (conf.module_effects) then
        for _, module in ipairs(conf.module_effects.modules or {}) do
            result = result .. "/m=" .. module.module.name .. "(" .. module.quality.name .. ")x" .. module.count
        end
        for _, beacon in ipairs(conf.module_effects.beacons or {}) do
            result = result .. "/b=" .. beacon.beacon.name .. "(" .. beacon.quality.name .. ")x" .. beacon.count
            for _, module in ipairs(beacon.per_beacon_modules) do
                result = result .. "/bm=" .. module.module.name .. "(" .. module.quality.name .. ")x" .. module.count
            end
        end
    end

    return conf.type .. "/" .. result
end

---@param conf Rates.Configuration
---@return Rates.Gui.NodeDescription
local function gui_recipe(conf)
    local logic = registry.get(conf.type)
    if (logic) then
        if (logic.gui_recipe) then
            return logic.gui_recipe(conf)
        end
    else
        local interface = interface_name(conf.type)
        if (remote.interfaces[interface].gui_recipe) then
            return remote.call(interface, "gui_recipe", conf) --[[@as Rates.Gui.NodeDescription]]
        end
    end

    return {}
end

---@param conf Rates.Configuration
---@return Rates.Gui.NodeDescription
local function gui_entity(conf)
    local logic = registry.get(conf.type)
    if (logic) then
        if (logic.gui_entity) then
            return logic.gui_entity(conf)
        end
    else
        local interface = interface_name(conf.type)
        if (remote.interfaces[interface].gui_entity) then
            return remote.call(interface, "gui_entity", conf) --[[@as Rates.Gui.NodeDescription]]
        end
    end

    if (conf.entity) then
        ---@type Rates.Gui.NodeDescription
        return {
            element = { type = "entity-with-quality", name = conf.entity.name, quality = conf.quality.name }
        }
    end

    ---@type Rates.Gui.NodeDescription
    return {
        icon = { sprite = "virtual-signal/signal-question-mark" },
        name = conf.id
    }
end

---@param conf Rates.Configuration
---@param options Rates.Configuration.ProductionOptions
---@return Rates.Configuration.Amount[]
local function get_production(conf, options)
    local logic = registry.get(conf.type)
    if (logic) then
        if (logic.get_production) then
            local result = {} ---@type Rates.Configuration.Amount[]
            logic.get_production(conf, result, options)
            return result
        end
    else
        if (remote.interfaces[interface_name(conf.type)].get_production) then
            return remote.call(interface_name(conf.type), "get_production", conf, options) --[[@as Rates.Configuration.Amount[] ]]
        end
    end

    return {}
end

---@param options Rates.Progression.Options
---@return string[]
local function get_progression_locations(options)
    local result = {} ---@type table<string, true>
    for _, entry in ipairs(registry.get_all_types()) do
        if (not options.blocked_types or not options.blocked_types[entry.type]) then
            local locations = {} ---@type string[]
            if (entry.logic) then
                if (entry.logic.fill_progression_locations) then
                    entry.logic.fill_progression_locations(locations, options)
                end
            else
                if (remote.interfaces[interface_name(entry.type)].fill_progression_locations) then
                    locations = remote.call(interface_name(entry.type), "fill_progression_locations", options) --[[@as string[] ]]
                end
            end

            for _, location in ipairs(locations) do
                result[location] = true
            end
        end
    end

    local arr = {} ---@type string[]
    for location, _ in pairs(result) do
        arr[#arr + 1] = location
    end

    return arr
end

---@param options Rates.Progression.Options
---@return Rates.Progression.Rules
local function get_progression(options)
    local result = {} ---@type Rates.Progression.Rules
    for _, entry in ipairs(registry.get_all_types()) do
        if (not options.blocked_types or not options.blocked_types[entry.type]) then
            local rules = {} ---@type Rates.Progression.Rules
            if (entry.logic) then
                if (entry.logic.fill_progression) then
                    entry.logic.fill_progression(rules, options)
                end
            else
                if (remote.interfaces[interface_name(entry.type)].fill_progression) then
                    rules = remote.call(interface_name(entry.type), "fill_progression", options) --[[@as Rates.Progression.Rules]]
                end
            end

            local n = 0
            local m = 0
            for id, rule in pairs(rules or {}) do
                m = m + 1
                for id2, rule2 in pairs(unfold_rule(id, rule)) do
                    n = n + 1
                    if (result[id2]) then
                        log("duplicate rule: " .. id2)
                    else
                        result[id2] = rule2
                    end
                end
            end
            log(entry.type .. ": " .. m .. " (" .. n .. ") rules")
        end
    end

    return result
end

---@param options Rates.Configuration.FillBasicOptions
---@return Rates.Configurations
local function get_basic_configurations(options)
    local result = {} ---@type Rates.Configurations
    for _, entry in ipairs(registry.get_all_types()) do
        local confs = {} ---@type Rates.Configurations
        if (entry.logic) then
            if (entry.logic.fill_basic_configurations) then
                entry.logic.fill_basic_configurations(confs, options)
            end
        else
            if (remote.interfaces[interface_name(entry.type)].fill_basic_configurations) then
                confs = remote.call(interface_name(entry.type), "fill_basic_configurations", options) --[[@as Rates.Configurations]]
            end
        end

        for _, conf in ipairs(confs) do
            result[#result + 1] = conf
        end
    end

    return result
end

---@param entity LuaEntity
---@param options Rates.Configuration.FromEntityOptions
---@return Rates.Configuration?
local function get_from_entity(entity, options)
    local use_ghosts = options.use_ghosts ~= false
    local data = util.get_useful_entity_data(entity, use_ghosts)
    if (not data) then
        return
    end

    ---@type Rates.Configuration.FromEntityOptions.Internal
    local options = {
        use_ghosts = use_ghosts,
        type = data.entity.type,
        entity = data.entity,
        quality = data.quality
    }

    options.type = data.entity.type
    options.entity = data.entity
    options.quality = data.quality

    for _, entry in ipairs(registry.get_all_types()) do
        local result
        if (entry.logic) then
            result = entry.logic.get_from_entity and entry.logic.get_from_entity(entity, options)
        else
            local interface = interface_name(entry.type)
            result = remote.interfaces[interface].get_from_entity and
                remote.call(interface, "get_from_entity", entity, options) --[[@as Rates.Configuration?]]
        end
        if (result) then
            result.type = result.type or entry.type
            result.id = result.id or get_id(result)

            if (result.entity) then
                local fuel = nil
                if (result.entity.burner_prototype) then
                    if (entity.burner) then
                        local filter = entity.burner.inventory.get_filter(1)
                        local burning = entity.burner
                            .currently_burning --[[@as { name: LuaItemPrototype, quality: LuaQualityPrototype }]]
                        if (filter) then
                            fuel = {
                                type = "item-fuel",
                                id = nil, ---@diagnostic disable-line: assign-type-mismatch
                                item = prototypes.item[filter.name],
                                quality = filter.comparator == "=" and prototypes.quality[filter.quality] or
                                    prototypes.quality.normal
                            } --[[@as Rates.Configuration.ItemFuel]]
                        elseif (burning) then
                            fuel = {
                                type = "item-fuel",
                                id = nil, ---@diagnostic disable-line: assign-type-mismatch
                                item = burning.name,
                                quality = burning.quality
                            } --[[@as Rates.Configuration.ItemFuel]]
                        end
                    end
                elseif (result.entity.fluid_energy_source_prototype) then
                    if (entity.type ~= "entity-ghost") then
                        local fluidbox = entity.fluidbox
                        for i = 1, #fluidbox do
                            local proto = fluidbox.get_prototype(i)
                            if (proto.index == 1) then
                                local box = fluidbox[i]
                                if (box) then
                                    fuel = {
                                        type = "fluid-fuel",
                                        id = nil, ---@diagnostic disable-line: assign-type-mismatch
                                        fluid = prototypes.fluid[box.name],
                                        temperature = box.temperature
                                    } --[[@as Rates.Configuration.FluidFuel]]
                                end
                            end
                        end
                    end
                end

                if (fuel) then
                    fuel.id = get_id(fuel)
                    ---@type Rates.Configuration.Meta
                    local meta = {
                        type = "meta",
                        id = nil, ---@diagnostic disable-line: assign-type-mismatch
                        children = { result },
                        fuel = fuel
                    }
                    meta.id = get_id(meta)
                    return meta
                end
            end

            return result
        end
    end
end

return {
    register = register,
    get_id = get_id,
    gui_recipe = gui_recipe,
    gui_entity = gui_entity,
    get_production = get_production,
    get_progression_locations = get_progression_locations,
    get_progression = get_progression,
    get_basic_configurations = get_basic_configurations,
    get_from_entity = get_from_entity,
}
