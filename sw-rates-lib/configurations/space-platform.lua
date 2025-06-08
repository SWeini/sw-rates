local progression = require("scripts.progression")

local logic = { type = "space-platform" } ---@type Rates.Configuration.Type

logic.fill_progression = function(result, options)
    local space_platforms = {} ---@type string[]
    for _, loc in ipairs(options.locations) do
        if (progression.is_space_platform(loc)) then
            space_platforms[#space_platforms + 1] = loc
        end
    end

    do
        local id = "space-platform/build/*"
        result[id] = {
            pre = {},
            post = {
                progression.create.can_build("*")
            },
            multi = space_platforms
        }
    end

    do
        -- TODO: space platforms need weapons
        local id = "space-platform/fight/*"
        result[id] = {
            pre = {},
            post = {
                progression.create.damage("*")
            },
            multi = space_platforms
        }
    end
end

return logic
