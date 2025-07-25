do
    ---@class (exact) Rates.Configuration.ItemFuel : Rates.Configuration.Base
    ---@field type "item-fuel"
    ---@field item LuaItemPrototype
    ---@field quality LuaQualityPrototype
end

local configuration = require("scripts.configuration-util")
local node = require("scripts.node")
local progression = require("scripts.progression")

local logic = { type = "item-fuel" } ---@type Rates.Configuration.Type

local items = prototypes.get_item_filtered { { filter = "fuel-value", comparison = ">", value = 0 } }

---@param conf Rates.Configuration.ItemFuel
logic.get_id = function(conf)
    return conf.item.name .. "(" .. conf.quality.name .. ")"
end

---@param conf Rates.Configuration.ItemFuel
logic.gui_recipe = function(conf)
    local category = conf.item.fuel_category ---@cast category -nil
    local sprite = "tooltip-category-" .. category
    if (not helpers.is_valid_sprite_path(sprite)) then
        sprite = "tooltip-category-fuel"
    end

    ---@type Rates.Gui.NodeDescription
    return {
        icon = { sprite = sprite },
        name = prototypes.fuel_category[category].localised_name
    }
end

---@param conf Rates.Configuration.ItemFuel
logic.gui_entity = function(conf)
    ---@type Rates.Gui.NodeDescription
    return {
        element = { type = "item-with-quality", name = conf.item.name, quality = conf.quality.name }
    }
end

---@param conf Rates.Configuration.ItemFuel
logic.get_production = function(conf, result, options)
    result[#result + 1] = {
        tag = "energy-source-input",
        node = node.create.item(conf.item, conf.quality),
        amount = -1
    }

    local burnt_result = conf.item.burnt_result
    if (burnt_result) then
        result[#result + 1] = {
            tag = "energy-source-output",
            node = node.create.item(burnt_result, conf.quality),
            amount = 1
        }
    end

    result[#result + 1] = {
        tag = "product",
        node = node.create.item_fuel(prototypes.fuel_category[conf.item.fuel_category]),
        amount = conf.item.fuel_value
    }
end

logic.fill_progression = function(result, options)
    for _, item in pairs(items) do
        local id = "item/fuel/" .. item.name .. "/*"
        result[id] = {
            pre = {
                progression.create.item(item.name, "*")
            },
            post = {
                progression.create.item_fuel(item.fuel_category, "*")
            },
            multi = options.locations
        }

        if (item.burnt_result) then
            id = "item/burnt-result/" .. item.name .. "/*"
            result[id] = {
                pre = {
                    progression.create.item(item.name, "*"),
                    progression.create.burner(item.fuel_category, "*")
                },
                post = {
                    progression.create.item(item.burnt_result.name, "*")
                },
                multi = options.locations
            }
        end
    end
end

---@param result Rates.Configuration.ItemFuel[]
logic.fill_basic_configurations = function(result, options)
    for _, item in pairs(items) do
        result[#result + 1] = {
            type = nil, ---@diagnostic disable-line: assign-type-mismatch
            item = item,
            quality = prototypes.quality.normal
        }
    end
end

return logic
