do
    ---@class (exact) Rates.Configuration.SendToPlatform : Rates.Configuration.Base
    ---@field type "send-to-platform"
    ---@field item LuaItemPrototype
    ---@field quality LuaQualityPrototype
    ---@field need_rocket boolean
    ---@field target Rates.Configuration.LocationId
end

local configuration = require("scripts.configuration-util")
local node = require("scripts.node")
local progression = require("scripts.progression")

local logic = { type = "send-to-platform" } ---@type Rates.Configuration.Type

local planets = {} ---@type table<string, LuaSpaceLocationPrototype>
for name, space in pairs(prototypes.space_location) do
    if (space.type == "planet") then
        planets[name] = space
    end
end

local items = {} ---@type table<string, LuaItemPrototype>
for name, item in pairs(prototypes.item) do
    if (not item.parameter) then
        items[name] = item
    end
end

local characters = prototypes.get_entity_filtered { { filter = "type", type = "character" } }

local rocket_lift_weight = prototypes.utility_constants["default_rocket_lift_weight"] --[[@as number]]

---@param conf Rates.Configuration.SendToPlatform
logic.get_id = function(conf)
    return conf.item.name .. "(" .. conf.quality.name .. ")" ..
        (conf.need_rocket and "R" or "") .. "->" .. serpent.line(conf.target)
end

---@param conf Rates.Configuration.SendToPlatform
logic.gui_recipe = function(conf)
    ---@type Rates.Gui.NodeDescription
    return {
        element = { type = "item-with-quality", name = conf.item.name, quality = conf.quality.name }
    }
end

---@param conf Rates.Configuration.SendToPlatform
logic.gui_entity = function(conf)
    if (conf.need_rocket) then
        ---@type Rates.Gui.NodeDescription
        return {
            icon = { sprite = "utility/space_age_icon" },
            name = { "sw-rates-node.send-to-platform" },
            number_format = { unit = "/s", factor = 1 },
        }
    else
        ---@type Rates.Gui.NodeDescription
        return {
            icon = { sprite = "virtual-signal/signal-output" },
            name = { "sw-rates-node.send-to-platform" },
            number_format = { unit = "/s", factor = 1 },
        }
    end
end

---@param conf Rates.Configuration.SendToPlatform
logic.get_production = function(conf, result, options)
    if (conf.need_rocket) then
        result[#result + 1] = {
            tag = "energy-source-input",
            node = node.create.send_to_platform(),
            amount = -conf.item.weight / rocket_lift_weight
        }
    end
    local node = node.create.item(conf.item, conf.quality)
    result[#result + 1] = {
        tag = "export",
        tag_extra = conf.target,
        node = node,
        amount = -1
    }
    result[#result + 1] = {
        tag = "import",
        tag_extra = conf.target,
        node = node,
        amount = 1
    }
end

logic.fill_progression = function(result, options)
    local space_platforms = {} ---@type string[]
    for _, loc in ipairs(options.locations) do
        if (progression.is_space_platform(loc)) then
            space_platforms[#space_platforms + 1] = loc
        end
    end

    for _, planet in pairs(planets) do
        local loc = progression.location.planet(planet.name)

        for _, item in pairs(items) do
            if (item.weight <= rocket_lift_weight) then
                local id = "item/send-to-platform/" .. item.name .. "/" .. loc .. "/*"
                result[id] = {
                    pre = {
                        progression.create.send_to_platform(loc),
                        progression.create.item(item.name, loc),
                        progression.create.space_travel(planet.name, "*")
                    },
                    post = {
                        progression.create.item(item.name, "*")
                    },
                    multi = space_platforms
                }
            end

            do
                local id = "item/drop-to-planet/" .. item.name .. "/" .. loc .. "/*"
                result[id] = {
                    pre = {
                        progression.create.space_travel(planet.name, "*"),
                        progression.create.item(item.name, "*")
                    },
                    post = {
                        progression.create.item(item.name, loc)
                    },
                    multi = space_platforms
                }
            end
        end

        for _, character in pairs(characters) do
            do
                local id = "character/send-to-platform/" .. character.name .. "/" .. loc .. "/*"
                result[id] = {
                    pre = {
                        progression.create.send_to_platform(loc),
                        progression.create.map_entity(character.name, loc),
                        progression.create.space_travel(planet.name, "*")
                    },
                    post = {
                        progression.create.map_entity(character.name, "*")
                    },
                    multi = space_platforms
                }
            end

            do
                local id = "character/drop-to-planet/" .. character.name .. "/" .. loc .. "/*"
                result[id] = {
                    pre = {
                        progression.create.space_travel(planet.name, "*"),
                        progression.create.map_entity(character.name, "*")
                    },
                    post = {
                        progression.create.map_entity(character.name, loc)
                    },
                    multi = space_platforms
                }
            end
        end
    end
end

return logic
