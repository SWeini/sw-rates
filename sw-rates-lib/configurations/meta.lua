do
    ---@class (exact) Rates.Configuration.Meta : Rates.Configuration.Base
    ---@field type "meta"
    ---@field children Rates.Configuration[]
    ---@field children_suggested_factors? number[]
    ---@field fuel? Rates.Configuration.Fuel
    ---@field selection? table<string, string>
    ---@field suggested? Rates.Configuration[]
end

local configuration = require("scripts.configuration")
local node_util = require("scripts.node")
local energy_source = require("scripts.energy-source")

local logic = { type = "meta" } ---@type Rates.Configuration.Type

---@param conf Rates.Configuration.Meta
logic.get_id = function(conf)
    local result = "children=("
    local child_ids = {} ---@type string[]
    for i, child in ipairs(conf.children) do
        child_ids[i] = configuration.get_id(child)
    end
    result = result .. table.concat(child_ids, "|") .. ")"

    if (conf.fuel) then
        result = result .. ",fuel=" .. configuration.get_id(conf.fuel)
    end

    for tag, id in pairs(conf.selection or {}) do
        result = result .. "," .. tag .. "=" .. id
    end

    return result
end

---@param conf Rates.Configuration.Meta
logic.gui_recipe = function(conf)
    return configuration.gui_recipe(conf.children[1])
end

---@param conf Rates.Configuration.Meta
logic.gui_entity = function(conf)
    return configuration.gui_entity(conf.children[1])
end

---@param tag string
---@param tag_extra number | string
local function format_tag(tag, tag_extra)
    if (tag_extra) then
        return tag .. "-" .. tag_extra
    end

    return tag
end

---@param conf Rates.Configuration
---@return LuaEntityPrototype?
local function get_entity(conf)
    while (conf.type == "meta") do
        conf = conf.children[1]
    end

    return conf.entity
end

---@param conf Rates.Configuration.Meta
logic.get_production = function(conf, result, options)
    for i, child in ipairs(conf.children) do
        local factor = conf.children_suggested_factors and conf.children_suggested_factors[i] or (1 / #conf.children)
        if (factor > 0) then
            local amounts = configuration.get_production(child, options)
            local fuel = conf.fuel
            if (fuel) then
                local entity = get_entity(child)
                if (entity) then
                    local fuel_amounts = configuration.get_production(fuel, options)
                    energy_source.apply_fuel_to_production(amounts, fuel_amounts, entity, fuel, options)
                end
            end

            if (conf.selection) then
                for _, amount in ipairs(amounts) do
                    local node = amount.node
                    if (node.type == "any") then
                        local selection = conf.selection[format_tag(amount.tag, amount.tag_extra)]
                        if (selection) then
                            for _, child in ipairs(node.children) do
                                if (node_util.get_id(child) == selection) then
                                    amount.node = child
                                end
                            end
                        end
                    end
                end
            end

            for _, amount in ipairs(amounts) do
                amount.amount = amount.amount * factor
                result[#result + 1] = amount
            end
        end
    end
end

---@param conf Rates.Configuration
---@param selection table<string, string>
---@return Rates.Configuration.Meta
local function with_selection(conf, selection)
    local result ---@type Rates.Configuration.Meta
    if (conf.type == "meta") then
        result = {
            type = "meta",
            children = conf.children,
            fuel = conf.fuel,
            selection = selection,
            suggested = conf.suggested
        }
    else
        result = {
            type = "meta",
            children = { conf },
            selection = selection
        }
    end

    return result
end

---@param conf Rates.Configuration
---@param fuel Rates.Configuration.Fuel
local function with_fuel(conf, fuel)
    local result ---@type Rates.Configuration.Meta
    if (conf.type == "meta") then
        result = {
            type = "meta",
            children = conf.children,
            fuel = fuel,
            selection = conf.selection,
            suggested = conf.suggested
        }
    else
        result = {
            type = "meta",
            children = { conf },
            fuel = fuel
        }
    end

    return result
end

return {
    types = { logic },
    with_selection = with_selection,
    with_fuel = with_fuel
}
