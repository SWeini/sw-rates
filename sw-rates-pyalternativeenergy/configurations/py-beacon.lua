local logic = { type = "py-beacon", stats = { priority = 100 } } ---@type Rates.Configuration.Type

---@param beacons Rates.Configuration.Beacon[]?
local function has_beacon_signal_interference(beacons)
    if (beacons == nil or #beacons == 0) then
        return
    end

    if (#beacons == 1 and beacons[1].count == 1) then
        return
    end

    local setting = settings.startup["future-beacons"]
    if (setting == nil) then
        return
    end

    local future_beacons = setting.value --[[@as boolean]]

    if (future_beacons) then
        local ams = {}
        local fms = {}

        for _, beacon in ipairs(beacons) do
            local name = beacon.beacon.name
            start, _, am, fm = string.find(name, "^.+[-]AM(%d)[-]FM(%d)$")
            if (start) then
                if (beacon.count > 1) then
                    return true
                end

                if (ams[am] or fms[fm]) then
                    return true
                else
                    ams[am] = true
                    fms[fm] = true
                end
            end
        end
    else
        local amfms = {}

        for _, beacon in ipairs(beacons) do
            local name = beacon.beacon.name
            start, _, am, fm = string.find(name, "^.+[-]AM(%d)[-]FM(%d)$")
            if (start) then
                local amfm = am .. "-" .. fm
                if (beacon.count > 1) then
                    return true
                end

                if (amfms[amfm]) then
                    return true
                else
                    amfms[amfm] = true
                end
            end
        end
    end

    return false
end

logic.gui_annotation = function(annotation, conf)
    if (annotation.type == "py-beacon/signal-interference") then
        ---@type Rates.Gui.AnnotationDescription
        return {
            severity = "error",
            text = { "sw-rates-annotation.py-beacon-signal-interference" },
            icon = { sprite = "beacon-interference" }
        }
    end
end

logic.get_annotations = function(conf)
    if (conf.type == "meta") then
        conf = conf.children[1]
    end

    if (conf.module_effects == nil) then
        return
    end

    local beacons = conf.module_effects.beacons

    if (has_beacon_signal_interference(beacons)) then
        return { { type = "py-beacon/signal-interference" } }
    end
end

return logic
