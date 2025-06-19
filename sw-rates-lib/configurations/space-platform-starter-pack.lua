local progression = require("scripts.progression")

local logic = { type = "space-platform-starter-pack" } ---@type Rates.Configuration.Type

local planets = {} ---@type table<string, LuaSpaceLocationPrototype>
for name, space in pairs(prototypes.space_location) do
    if (space.type == "planet") then
        planets[name] = space
    end
end

local items = prototypes.get_item_filtered { { filter = "type", type = "space-platform-starter-pack" } }

logic.fill_progression_locations = function(result, options)
    for _, item in pairs(items) do
        local surface = item.surface
        if (surface) then
            result[#result + 1] = "space-" .. surface.name
        end
    end
end

logic.fill_progression = function(result, options)
    for _, planet in pairs(planets) do
        local loc1 = progression.location.planet(planet.name)
        for _, item in pairs(items) do
            local surface = item.surface
            if (surface) then
                local loc2 = progression.location.space(surface.name)
                local id = "space-platform-starter-pack/" .. item.name .. "/" .. loc1
                result[id] = {
                    pre = {
                        progression.create.send_to_platform(loc1),
                        progression.create.item(item.name, loc1)
                    },
                    post = {
                        progression.create.space_travel(planet.name, loc2)
                    }
                }
            end
        end
    end
end

return logic
