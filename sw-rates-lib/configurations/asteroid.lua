local progression = require("scripts.progression")

local logic = { type = "asteroid" } ---@type Rates.Configuration.Type

logic.fill_progression = function(result, options)
    for _, entity in pairs(prototypes.get_entity_filtered { { filter = "type", type = "asteroid" } }) do
        local generated ---@type Rates.Progression.SingleItem?
        if (string.match(entity.name, "^huge%-.+%-asteroid$")) then
            generated = progression.create.map_entity("big" .. string.sub(entity.name, 5), "*")
        elseif (string.match(entity.name, "^big%-.+%-asteroid$")) then
            generated = progression.create.map_entity("medium" .. string.sub(entity.name, 4), "*")
        elseif (string.match(entity.name, "^medium%-.+%-asteroid$")) then
            generated = progression.create.map_entity("small" .. string.sub(entity.name, 7), "*")
        elseif (string.match(entity.name, "^small%-.+%-asteroid$")) then
            generated = progression.create.space_asteroid(string.sub(entity.name, 7) .. "-chunk", "*")
        end
        if (generated) then
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
