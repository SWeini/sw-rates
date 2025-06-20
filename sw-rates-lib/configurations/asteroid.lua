local progression = require("scripts.progression")

local logic = { type = "asteroid" } ---@type Rates.Configuration.Type

logic.fill_progression = function(result, options)
    for _, entity in pairs(prototypes.get_entity_filtered { { filter = "type", type = "asteroid" } }) do
        local generated = {} ---@type Rates.Progression.MultiItemPost
        for _, effect in ipairs(entity.dying_trigger_effect or {}) do
            if (effect.type == "create-asteroid-chunk") then
                generated[#generated + 1] = progression.create.space_asteroid(effect.asteroid_name, "*") ---@diagnostic disable-line:undefined-field
            elseif (effect.type == "create-entity") then
                generated[#generated + 1] = progression.create.map_entity(effect.entity_name, "*") ---@diagnostic disable-line:undefined-field
            end
        end
        if (#generated > 0) then
            local id = "entity-with-health/dying/" .. entity.name .. "/*"
            result[id] = {
                pre = {
                    progression.create.map_entity(entity.name, "*"),
                    progression.create.damage("*")
                },
                post = {
                    generated
                },
                multi = options.locations
            }
        end
    end
end

return logic
