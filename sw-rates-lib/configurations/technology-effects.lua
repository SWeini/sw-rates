local progression = require("scripts.progression")

local logic = { type = "technology-effects" } ---@type Rates.Configuration.Type

logic.fill_progression = function(result, options)
    for _, technology in pairs(prototypes.technology) do
        local post = {} ---@type Rates.Progression.Post
        for _, effect in ipairs(technology.effects) do
            if (effect.type == "unlock-recipe") then
                post[#post + 1] = progression.create.unlock_recipe(effect.recipe)
            elseif (effect.type == "give-item") then
                post[#post + 1] = progression.create.item(effect.item, progression.location.planet("nauvis"))
            elseif (effect.type == "unlock-quality") then
                post[#post + 1] = progression.create.unlock_quality(effect.quality --[[@as string]])
            elseif (effect.type == "unlock-space-location") then
                post[#post + 1] = progression.create.unlock_location(effect.space_location --[[@as string]])
            elseif (effect.type == "unlock-space-platforms") then
                post[#post + 1] = progression.create.unlock_space()
            elseif (effect.type == "mining-with-fluid") then
                -- TODO: mining with fluid
            end
        end

        local id = "technology/effects/" .. technology.name
        result[id] = {
            pre = {
                progression.create.unlock_technology(technology.name)
            },
            post = post
        }
    end
end

return logic
