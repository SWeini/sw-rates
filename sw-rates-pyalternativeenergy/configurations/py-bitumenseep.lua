local api = require("__sw-rates-lib__.api-configuration")
local progression = api.progression
local mining = require("__sw-rates-lib__.configurations.mining-drill")

local logic = { type = "py-bitumenseep", stats = { priority = 100 } } ---@type Rates.Configuration.Type

local drills = {
    ["oil-derrick-mk01"] = "oil-mk01",
    ["oil-derrick-mk02"] = "oil-mk02",
    ["oil-derrick-mk03"] = "oil-mk03",
    ["oil-derrick-mk04"] = "oil-mk04",
    ["tar-extractor-mk01"] = "tar-patch",
    ["tar-extractor-mk02"] = "tar-patch",
    ["tar-extractor-mk03"] = "tar-patch",
    ["tar-extractor-mk04"] = "tar-patch",
    ["natural-gas-derrick-mk01"] = "natural-gas-mk01",
    ["natural-gas-derrick-mk02"] = "natural-gas-mk02",
    ["natural-gas-derrick-mk03"] = "natural-gas-mk03",
    ["natural-gas-derrick-mk04"] = "natural-gas-mk04",
}

local drilling_fluids = {
    ["drilling-fluid-0"] = true,
    ["drilling-fluid-1"] = true,
    ["drilling-fluid-2"] = true,
    ["drilling-fluid-3"] = true,
}

logic.fill_progression = function(result, options)
    local seep = prototypes.entity["bitumen-seep"]
    for name, resource in pairs(drills) do
        local entity = prototypes.entity[name]
        local fluid_nodes = {} ---@type Rates.Progression.Pre
        for fluid, _ in pairs(drilling_fluids) do
            fluid_nodes[#fluid_nodes + 1] = progression.create.fluid(fluid, {}, "*")
        end

        local id = "mining-drill/" .. entity.name .. "/" .. seep.name .. "/*"
        result[id] = {
            pre = {
                progression.create.map_entity(entity.name, "*"),
                progression.create.map_entity(seep.name, "*"),
                fluid_nodes,
                progression.create.energy_source(entity, "*")
            },
            post = {
                progression.create.map_entity(resource, "*")
            },
            multi = options.locations
        }
    end
end

logic.get_from_entity = function(entity, options)
    if (not options.use_ghosts) then
        return
    end

    if (options.type ~= "mining-drill") then
        return
    end

    local drill = drills[options.entity.name]
    if (not drill) then
        return
    end

    local temp = mining.get_from_entity(entity, options)
    if (not temp) then
        return
    end

    if (not temp.resource or temp.resource.name ~= "bitumen-seep") then
        return
    end

    local resource = prototypes.entity[drill]
    temp.type = "mining-drill"
    temp.id = nil
    temp.resource = resource
    return temp
end

return logic
