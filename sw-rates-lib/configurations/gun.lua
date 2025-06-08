local progression = require("scripts.progression")

local logic = { type = "gun" } ---@type Rates.Configuration.Type

logic.fill_progression = function(result, options)
    for _, item in pairs(prototypes.get_item_filtered { { filter = "type", type = "gun" } }) do
        if (item.attack_parameters) then
            local post = {} ---@type string[]
            for _, category in ipairs(item.attack_parameters.ammo_categories or {}) do
                post[#post + 1] = progression.create.ammo(category, "*")
            end

            local id = "gun/" .. item.name .. "/*"
            result[id] = {
                pre = {
                    progression.create.item(item.name, "*")
                },
                post = post,
                multi = options.locations
            }
        end
    end
end

return logic
