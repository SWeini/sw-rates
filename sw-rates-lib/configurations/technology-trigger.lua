local progression = require("scripts.progression")

local logic = { type = "technology-trigger" } ---@type Rates.Configuration.Type

logic.fill_progression = function(result, options)
    for _, technology in pairs(prototypes.technology) do
        local trigger = technology.research_trigger
        if (trigger) then
            local pre = {} ---@type Rates.Progression.Pre
            -- TODO: trigger quality, better triggers
            if (trigger.type == "craft-item") then
                pre[#pre + 1] = progression.create.item(trigger.item.name, "*")
            elseif (trigger.type == "mine-entity") then
                pre[#pre + 1] = progression.create.map_entity(trigger.entity --[[@as string]], "*")
            elseif (trigger.type == "craft-fluid") then
                pre[#pre + 1] = progression.create.fluid(trigger.fluid, {}, "*")
            elseif (trigger.type == "send-item-to-orbit") then
                pre[#pre + 1] = progression.create.item(trigger.item.name, "*")
                pre[#pre + 1] = progression.create.send_to_orbit("*")
            elseif (trigger.type == "capture-spawner") then
            elseif (trigger.type == "build-entity") then
                pre[#pre + 1] = progression.create.map_entity(trigger.entity.name, "*")
            elseif (trigger.type == "create-space-platform") then
            end

            for _, prerequisite in pairs(technology.prerequisites) do
                pre[#pre + 1] = progression.create.unlock_technology(prerequisite.name)
            end

            local id = "technology/trigger/" .. technology.name .. "/*"
            result[id] = {
                pre = pre,
                post = {
                    progression.create.unlock_technology(technology.name)
                },
                multi = options.locations
            }
        end
    end
end

return logic
