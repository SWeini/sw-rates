local progression = require("scripts.progression")
local extra_data = require("scripts.extra-data")

local logic = { type = "capture-robot" } ---@type Rates.Configuration.Type

logic.fill_progression = function(result, options)
    local entity = prototypes.entity["capture-robot"]

    if (not entity) then
        return
    end

    do
        local id = "capture-robot/launch/" .. entity.name .. "/*"
        result[id] = {
            pre = {
                progression.create.item("capture-robot-rocket", "*"),
                progression.create.item("rocket-launcher", "*")
            },
            post = {
                progression.create.map_entity(entity.name, "*")
            },
            multi = options.locations
        }
    end

    for _, entity in pairs(prototypes.get_entity_filtered { { filter = "type", type = "capture-robot" } }) do
        for _, spawner in pairs(prototypes.get_entity_filtered { { filter = "type", type = "unit-spawner" } }) do
            local captive_spawner = extra_data.unit_spawner_captured_spawner_entity(spawner)
            if (captive_spawner) then
                local id = "capture-robot/capture/" .. entity.name .. "/" .. spawner.name .. "/*"
                result[id] = {
                    pre = {
                        progression.create.map_entity(spawner.name, "*"),
                        progression.create.map_entity(entity.name, "*")
                    },
                    post = {
                        progression.create.map_entity(captive_spawner.name, "*")
                    },
                    multi = options.locations
                }
            end
        end
    end
end

return logic
