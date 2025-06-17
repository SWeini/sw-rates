do
    ---@class (exact) Rates.Configuration.Meta : Rates.Configuration.Base
    ---@field type "meta"
    ---@field children Rates.Configuration[]
    ---@field children_suggested_factors? number[]
    ---@field fuel? Rates.Configuration.ItemFuel | Rates.Configuration.FluidFuel
    ---@field selection? table<string, string>
    ---@field suggested? Rates.Configuration[]
end

local configuration = require("scripts.configuration")
local node_util = require("scripts.node")

local logic = { type = "meta" } ---@type Rates.Configuration.Type

---@param conf Rates.Configuration.Meta
logic.get_id = function(conf)
    local result = "children=("
    for i, child in ipairs(conf.children) do
        if (i > 1) then
            result = result .. "|"
        end
        result = result .. child.id
    end
    result = result .. ")"

    if (conf.fuel) then
        result = result .. ",fuel=" .. conf.fuel.id
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

---@param conf Rates.Configuration.Meta
logic.get_production = function(conf, result, options)
    for i, child in ipairs(conf.children) do
        local factor = conf.children_suggested_factors and conf.children_suggested_factors[i] or (1 / #conf.children)
        if (factor > 0) then
            local amounts = configuration.get_production(child, options)
            if (conf.fuel) then
                local fuel_amounts = configuration.get_production(conf.fuel, options)
                local i = 1
                while (amounts[i].tag ~= "energy-source-input") do
                    i = i + 1
                end

                local j = 1
                while (fuel_amounts[j].tag ~= "product") do
                    j = j + 1
                end

                local energy_usage = amounts[i].amount
                local fuel_usage = -energy_usage / fuel_amounts[j].amount

                table.remove(amounts, i)

                for k, amount in ipairs(fuel_amounts) do
                    if (k ~= j) then
                        table.insert(amounts, i, {
                            tag = amount.tag,
                            tag_extra = amount.tag_extra,
                            node = amount.node,
                            amount = amount.amount * fuel_usage
                        })
                        i = i + 1
                    end
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
    if (not conf.id) then
        conf.id = configuration.get_id(conf)
    end

    local result ---@type Rates.Configuration.Meta
    if (conf.type == "meta") then
        result = {
            type = "meta",
            id = nil, ---@diagnostic disable-line: assign-type-mismatch
            children = conf.children,
            fuel = conf.fuel,
            selection = selection,
            suggested = conf.suggested
        }
    else
        result = {
            type = "meta",
            id = nil, ---@diagnostic disable-line: assign-type-mismatch
            children = { conf },
            selection = selection
        }
    end

    result.id = configuration.get_id(result)
    return result
end

---@param conf Rates.Configuration
---@param fuel Rates.Configuration.ItemFuel | Rates.Configuration.FluidFuel
local function with_fuel(conf, fuel)
    if (not conf.id) then
        conf.id = configuration.get_id(conf)
    end

    local result ---@type Rates.Configuration.Meta
    if (conf.type == "meta") then
        result = {
            type = "meta",
            id = nil, ---@diagnostic disable-line: assign-type-mismatch
            children = conf.children,
            fuel = fuel,
            selection = conf.selection,
            suggested = conf.suggested
        }
    else
        result = {
            type = "meta",
            id = nil, ---@diagnostic disable-line: assign-type-mismatch
            children = { conf },
            fuel = fuel
        }
    end

    result.id = configuration.get_id(result)
    return result
end

return {
    types = { logic },
    with_selection = with_selection,
    with_fuel = with_fuel
}
