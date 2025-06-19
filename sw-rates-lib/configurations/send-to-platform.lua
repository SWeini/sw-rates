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

local rocket_lift_weight = prototypes.utility_constants["rocket_lift_weight"] --[[@as number]]

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
