local logic = { type = "py-turd", stats = { priority = 100 } } ---@type Rates.Configuration.Type

logic.modify_from_entity = function(entity, conf, options)
    if (conf.type ~= "crafting-machine") then
        return
    end

    if (entity.type ~= "entity-ghost") then
        -- doesn't hurt to execute the code for non-ghosts, but it costs performance
        return
    end

    local beacons = conf.module_effects.beacons
    if (beacons) then
        for i = #beacons, 1, -1 do
            local beacon = beacons[i]
            if (beacon.beacon.name == "hidden-beacon-turd") then
                table.remove(beacons, i)
            end
        end
    end

    local turd_module = remote.call('pywiki_turd_page', 'get_unlocked_module', entity.force.index, options.entity.name)
    if (turd_module) then
        if (not beacons) then
            beacons = {}
        end

        beacons[#beacons + 1] = {
            beacon = prototypes.entity["hidden-beacon-turd"],
            quality = prototypes.quality.normal,
            count = 1,
            per_beacon_modules = { {
                module = prototypes.item[turd_module],
                quality = prototypes.quality.normal,
                count = 1
            } }
        }
    end

    if (beacons and #beacons == 0) then
        beacons = nil
    end

    conf.module_effects.beacons = beacons

    return conf
end

return logic
