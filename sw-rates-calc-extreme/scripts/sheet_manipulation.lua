local api = require("__sw-rates-lib__.api-usage")

local lib = {}

---@param sheet Rates.Data.Sheet
---@param id string
---@param location Rates.Data.LocationIndex
---@return boolean
local function has_configuration(sheet, id, location)
    for _, conf in ipairs(sheet.configurations) do
        if (conf.location == location and api.configuration.get_id(conf.configuration) == id) then
            return true
        end
    end

    return false
end

---@param sheet Rates.Data.Sheet
---@param id string
---@param location Rates.Data.LocationIndex
---@return boolean
local function remove_configuration(sheet, id, location)
    local configurations = sheet.configurations
    for i, conf in ipairs(configurations) do
        if (conf.location == location and api.configuration.get_id(conf.configuration) == id) then
            table.remove(configurations, i)
            return true
        end
    end

    return false
end

---@param sheet Rates.Data.Sheet
---@param item_name string
---@param quality_name string
---@param location Rates.Data.LocationIndex
---@return boolean
function lib.has_item_spoilage(sheet, item_name, quality_name, location)
    local id = "item-spoil/" .. item_name .. "(" .. quality_name .. ")"
    return has_configuration(sheet, id, location)
end

---@param sheet Rates.Data.Sheet
---@param item_name string
---@param quality_name string
---@param location Rates.Data.LocationIndex
---@return boolean
function lib.has_item_fuel(sheet, item_name, quality_name, location)
    local id = "item-fuel/" .. item_name .. "(" .. quality_name .. ")+burnt"
    return has_configuration(sheet, id, location)
end

---@param sheet Rates.Data.Sheet
---@param item_name string
---@param quality_name string
---@param location Rates.Data.LocationIndex
---@return boolean
function lib.has_item_send_to_orbit(sheet, item_name, quality_name, location)
    local id = "send-to-orbit/" .. item_name .. "(" .. quality_name .. ")"
    return has_configuration(sheet, id, location)
end

---@param sheet Rates.Data.Sheet
---@param fluid_name string
---@param temperature number
---@param location Rates.Data.LocationIndex
---@return boolean
function lib.has_fluid_fuel(sheet, fluid_name, temperature, location)
    local id = "fluid-fuel/" .. fluid_name .. "(" .. temperature .. ")"
    return has_configuration(sheet, id, location)
end

---@param sheet Rates.Data.Sheet
---@param conf Rates.Configuration
---@param location Rates.Data.LocationIndex
---@return boolean
function lib.has_configuration(sheet, conf, location)
    return has_configuration(sheet, api.configuration.get_id(conf), location)
end

---@param sheet Rates.Data.Sheet
---@param conf Rates.Configuration
---@param location Rates.Data.LocationIndex
---@param force LuaForce
---@return boolean
function lib.toggle_configuration(sheet, conf, location, force)
    local id = api.configuration.get_id(conf)

    if (remove_configuration(sheet, id, location)) then
        return false
    end

    local configurations = sheet.configurations
    configurations[#configurations + 1] = {
        configuration = conf,
        location = location,
        force = force,
    }
    return true
end

---@param sheet Rates.Data.Sheet
---@param node string
---@param location Rates.Data.LocationIndex
---@param link boolean
---@return boolean
function lib.configure_node(sheet, node, location, link)
    local key = location .. "/" .. node
    local nodes = sheet.nodes
    local entry = nodes[key]
    if (entry and entry.linked == link) then
        return false
    end

    nodes[key] = { linked = link }
    return true
end

return lib
