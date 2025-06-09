local api = require("__sw-rates-lib__.api-usage")
local flib_format = require("__flib__.format")

---@generic T : any
---@param map table<any, T>
---@return T[]
local function to_value_array(map)
    local result = {}
    for _, value in pairs(map) do
        result[#result + 1] = value
    end

    return result
end

---@param str LocalisedString
---@return LocalisedString
local function compress_string(str)
    local type = type(str)
    if (type ~= "table") then
        return str
    end

    for i = 2, #str do
        str[i] = compress_string(str[i])
    end

    if (#str > 20 and str[1] == "") then
        local new_str = { "" } ---@type LocalisedString
        local i = 2
        while i <= #str do
            local part = { "" } ---@type LocalisedString
            for j = 0, 19 do
                part[#part + 1] = str[i + j]
            end
            new_str[#new_str + 1] = part
            i = i + 20
        end

        return new_str
    end

    return str
end

---@param amount Rates.Configuration.Amount
---@return LocalisedString
local function dump_amount(amount)
    local node = amount.node
    local message = { "" } ---@type LocalisedString
    if (amount.tag == "infrastructure" and amount.amount < 0) then
        message[#message + 1] = flib_format.number(math.abs(amount.amount))
        message[#message + 1] = " x "
        message[#message + 1] = api.node.gui_text(node)
        return message
    elseif (amount.amount > 0) then
        message[#message + 1] = { "tooltip-category.generates" }
    elseif (amount.amount < 0) then
        message[#message + 1] = { "tooltip-category.consumes" }
    else
        return
    end

    message[#message + 1] = " "
    message[#message + 1] = api.node.gui_text(node)
    message[#message + 1] = ": "
    local format = api.node.gui_number_format(node)
    if (amount.tag == "infrastructure") then
        message[#message + 1] = flib_format.number(math.abs(amount.amount) * format.factor)
    elseif (format.unit == nil) then
        local per_second = math.abs(amount.amount) * format.factor
        if (per_second < 0.1) then
            message[#message + 1] = flib_format.number(per_second * 60)
            message[#message + 1] = { "per-minute-suffix" }
        else
            message[#message + 1] = flib_format.number(per_second)
            message[#message + 1] = { "per-second-suffix" }
        end
    else
        message[#message + 1] = flib_format.number(math.abs(amount.amount) * format.factor, true) .. format.unit
    end

    return message
end

---@param conf Rates.Configuration
---@return LocalisedString
local function dump_entity(conf)
    while (conf.type == "meta") do
        conf = conf.children[1]
    end

    if (conf.entity and conf.quality) then
        return "[entity=" .. conf.entity.name .. ",quality=" .. conf.quality.name .. "]"
    end
end

---@param conf Rates.Configuration
---@return LocalisedString
local function dump_recipe(conf)
    while (conf.type == "meta") do
        conf = conf.children[1]
    end

    if (conf.type ~= "crafting-machine") then
        return
    end

    if (conf.entity.fixed_recipe) then
        return
    end

    return "\n[recipe=" .. conf.recipe.name .. ",quality=" .. conf.recipe_quality.name .. "]"
end

---@param conf Rates.Configuration
---@return LocalisedString
local function dump_modules(conf)
    if (not conf.module_effects) then
        return
    end

    local result = { "" } ---@type LocalisedString
    for _, module in ipairs(conf.module_effects.modules or {}) do
        result[#result + 1] = "\n" ..
            module.count .. " x [item=" .. module.module.name .. ",quality=" .. module.quality.name .. "]"
    end

    for _, beacon in ipairs(conf.module_effects.beacons or {}) do
        result[#result + 1] = "\n" ..
            beacon.count .. " x [entity=" .. beacon.beacon.name .. ",quality=" .. beacon.quality.name .. "]: "
        for i, module in ipairs(beacon.total_modules) do
            if (i > 1) then
                result[#result + 1] = ", "
            end
            result[#result + 1] = module.count ..
                " x [item=" .. module.module.name .. ",quality=" .. module.quality.name .. "]"
        end
    end

    return result
end


---@param conf Rates.Configuration
---@param options Rates.Configuration.ProductionOptions
---@param count number
---@return LocalisedString
local function dump_production(conf, options, count)
    local production = api.configuration.get_production(conf, options)
    local result = { "" } ---@type LocalisedString
    for _, amount in ipairs(production) do
        amount.amount = amount.amount * count
        result[#result + 1] = "\n  "
        result[#result + 1] = dump_amount(amount)
    end

    return result
end

---@param player LuaPlayer
---@param surface LuaSurface
---@param entities { configuration: Rates.Configuration, count: integer }[]
local function analyze_entities(player, surface, entities)
    table.sort(entities, function(a, b)
        return a.configuration.id < b.configuration.id
    end)

    ---@type Rates.Configuration.ProductionOptions
    local options = {
        force = player.force --[[@as LuaForce]],
        surface = surface,
        apply_quality = true
    }

    for _, conf in ipairs(entities) do
        local message = { "" } ---@type LocalisedString
        message[#message + 1] = conf.count .. " x "
        message[#message + 1] = dump_entity(conf.configuration)
        message[#message + 1] = dump_modules(conf.configuration)
        message[#message + 1] = dump_recipe(conf.configuration)
        message[#message + 1] = dump_production(conf.configuration, options, conf.count)

        player.print(compress_string(message))
    end
end

---@param entities table<string, { configuration: Rates.Configuration, count: integer }>
---@param conf Rates.Configuration
local function add_entity(entities, conf)
    local entry = entities[conf.id]
    if (not entry) then
        entry = { configuration = conf, count = 0 }
        entities[conf.id] = entry
    end

    entry.count = entry.count + 1
end

---@param e EventData.on_player_selected_area | EventData.on_player_alt_selected_area
local function on_player_selected_area(e)
    if (e.item ~= "sw-rates-calc-tool") then
        return
    end

    local player = game.players[e.player_index]

    local entities = {} ---@type table<string, { configuration: Rates.Configuration, count: integer }>
    for _, entity in ipairs(e.entities) do
        local conf = api.configuration.get_from_entity(entity, { use_ghosts = true })
        if (conf) then
            add_entity(entities, conf)
        end
    end

    local entities = to_value_array(entities)

    if (#entities > 0) then
        analyze_entities(player, e.surface, entities)
    end
end

script.on_event({ defines.events.on_player_selected_area, defines.events.on_player_alt_selected_area },
    on_player_selected_area)
