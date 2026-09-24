do
    ---@class (exact) Rates.Configuration.ItemFuel : Rates.Configuration.Base
    ---@field type "item-fuel"
    ---@field item LuaItemPrototype
    ---@field quality LuaQualityPrototype
    ---@field produce_burnt_result boolean
end

local configuration = require("scripts.configuration-util")
local node = require("scripts.node")
local progression = require("scripts.progression")

local logic = { type = "item-fuel" } ---@type Rates.Configuration.Type

local items = prototypes.get_item_filtered { { filter = "fuel-value", comparison = ">", value = 0 } }

---@param conf Rates.Configuration.ItemFuel
logic.get_id = function(conf)
    return conf.item.name .. "(" .. conf.quality.name .. ")" .. (conf.produce_burnt_result and "+burnt" or "")
end

---@param conf Rates.Configuration.ItemFuel
logic.gui_recipe = function(conf)
    local categories = conf.item.fuel_categories ---@cast categories -nil
    local sprite = "tooltip-category-" .. (#categories == 1 and categories[1] or "")
    if (not helpers.is_valid_sprite_path(sprite)) then
        sprite = "tooltip-category-fuel"
    end

    local name = { "" } ---@type LocalisedString
    for i, category in ipairs(categories) do
        if (i > 1) then
            name[#name + 1] = "/"
        end

        name[#name + 1] = prototypes.fuel_category[category].localised_name
    end

    ---@type Rates.Gui.NodeDescription
    return {
        icon = { sprite = sprite },
        name = name
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

    if (conf.produce_burnt_result) then
        local burnt_result = conf.item.burnt_result
        if (burnt_result) then
            result[#result + 1] = {
                tag = "energy-source-output",
                node = node.create.item(burnt_result, conf.quality),
                amount = 1
            }
        end
    end

    local categories = {} ---@type LuaFuelCategoryPrototype[]
    for i, category in ipairs(conf.item.fuel_categories) do
        categories[i] = prototypes.fuel_category[category]
    end
    result[#result + 1] = {
        tag = "product",
        node = node.create.item_fuels(categories),
        amount = conf.item.fuel_value
    }
end

logic.fill_progression = function(result, options)
    for _, item in pairs(items) do
        for _, category in pairs(item.fuel_categories) do
            local fuel_category = prototypes[category]
            local id = "item/fuel/" .. item.name .. "/" .. category .. "/*"
            result[id] = {
                pre = {
                    progression.create.item(item.name, "*")
                },
                post = {
                    progression.create.item_fuel(fuel_category, "*")
                },
                multi = options.locations
            }

            if (item.burnt_result) then
                id = "item/burnt-result/" .. item.name .. "/*"
                result[id] = {
                    pre = {
                        progression.create.item(item.name, "*"),
                        progression.create.burner(fuel_category, "*")
                    },
                    post = {
                        progression.create.item(item.burnt_result.name, "*")
                    },
                    multi = options.locations
                }
            end
        end
    end
end

---@param result Rates.Configuration.ItemFuel[]
logic.fill_basic_configurations = function(result, options)
    for _, item in pairs(items) do
        result[#result + 1] = {
            type = nil, ---@diagnostic disable-line: assign-type-mismatch
            item = item,
            quality = prototypes.quality.normal,
            produce_burnt_result = true
        }
    end
end

return logic
