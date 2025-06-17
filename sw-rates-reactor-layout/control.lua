local api = require("__sw-rates-lib__.api-usage")
local fusion_generator = require("__sw-rates-lib__.configurations.fusion-generator")

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

---@param fluids table<string, { fluid: LuaFluidPrototype, weighted_temperature: number, amount: number }>
---@param fluid LuaFluidPrototype
---@param temperature number
---@param amount number
local function add_fluid_production(fluids, fluid, temperature, amount)
    local entry = fluids[fluid.name]
    if (not entry) then
        entry = { fluid = fluid, weighted_temperature = 0, amount = 0 }
        fluids[fluid.name] = entry
    end

    entry.weighted_temperature = entry.weighted_temperature + temperature * amount
    entry.amount = entry.amount + amount
end

---@param amount Rates.Configuration.Amount
---@return LocalisedString
local function dump_amount(amount)
    local node = amount.node
    local gui = api.node.gui_default(node)
    local message = { "" } ---@type LocalisedString
    if (amount.amount > 0) then
        message[#message + 1] = { "tooltip-category.generates" }
    elseif (amount.amount < 0) then
        message[#message + 1] = { "tooltip-category.consumes" }
    else
        return
    end

    message[#message + 1] = " "
    message[#message + 1] = api.gui.gui_message(gui, math.abs(amount.amount))

    local fuel_categories = nil
    if (node.type == "item-fuel") then
        fuel_categories = { node.category }
    elseif (node.type == "any" and node.details) then
        local details = node.details
        if (details.type == "any-item-fuel") then
            fuel_categories = details.categories
        end
    end

    if (fuel_categories) then
        for _, category in ipairs(fuel_categories) do
            for _, item in pairs(prototypes.get_item_filtered { { filter = "fuel-category", ["fuel-category"] = category.name } }) do
                local per_second = math.abs(amount.amount) * 1e6 / item.fuel_value
                local item_node = api.node.create.item(item, prototypes.quality.normal)
                message[#message + 1] = "\n    "
                message[#message + 1] = api.gui.gui_message(api.node.gui_default(item_node), per_second)
            end
        end
    end

    return message
end

---@alias EntityCounts table<string, { configuration: Rates.Configuration, count: integer }>

---@param player LuaPlayer
---@param entities { configuration: Rates.Configuration.Reactor, count: integer }[]
local function analyze_reactor(player, entities)
    table.sort(entities, function(a, b)
        return a.configuration.id < b.configuration.id
    end)
    local message = { "", "Reactor layout:" } ---@type LocalisedString
    local amounts = {} ---@type table<string, { node: Rates.Node, amount: number }>
    for _, entry in ipairs(entities) do
        local conf = entry.configuration
        local entity_rich_text = "[entity=" .. conf.entity.name .. ",quality=" .. conf.quality.name .. "]"
        local entity_line = entry.count .. " x " .. entity_rich_text .. " (" .. conf.neighbours .. " neighbours)"
        message[#message + 1] = "\n"
        message[#message + 1] = entity_line
        local production = api.configuration.get_production(conf, {
            force = player.force --[[@as LuaForce]]
        })
        for _, amount in ipairs(production) do
            local node_id = api.node.get_id(amount.node)
            local am = amounts[node_id]
            if (not am) then
                am = { node = amount.node, amount = 0 }
                amounts[node_id] = am
            end

            am.amount = am.amount + amount.amount * entry.count
        end
    end

    local amounts = to_value_array(amounts)
    table.sort(amounts, function(a, b)
        return a.amount < b.amount
    end)

    for _, amount in ipairs(amounts) do
        message[#message + 1] = "\n"
        message[#message + 1] = dump_amount(amount)
    end

    player.print(api.gui.compress_string(message))
end

---@param player LuaPlayer
---@param entities { configuration: Rates.Configuration.FusionReactor | Rates.Configuration.FusionGenerator, count: integer }[]
---@return table<string, { fluid: LuaFluidPrototype, temperature: number, amount: number }>
local function analyze_fusion_reactor(player, entities)
    table.sort(entities, function(a, b)
        return a.configuration.id < b.configuration.id
    end)
    local message = { "", "Fusion reactor layout:" } ---@type LocalisedString
    local amounts = {} ---@type table<string, { node: Rates.Node, amount: number }>
    for _, entry in ipairs(entities) do
        local conf = entry.configuration
        if (conf.type == "fusion-reactor") then
            local entity_rich_text = "[entity=" .. conf.entity.name .. ",quality=" .. conf.quality.name .. "]"
            local entity_line = entry.count .. " x " .. entity_rich_text .. " (" .. conf.neighbours .. " neighbours)"

            message[#message + 1] = "\n"
            message[#message + 1] = entity_line
            local production = api.configuration.get_production(conf, {
                force = player.force --[[@as LuaForce]]
            })
            for _, amount in ipairs(production) do
                local node_id = api.node.get_id(amount.node)
                local am = amounts[node_id]
                if (not am) then
                    am = { node = amount.node, amount = 0 }
                    amounts[node_id] = am
                end

                am.amount = am.amount + amount.amount * entry.count
            end
        end
    end

    local amounts = to_value_array(amounts) ---@type { node: Rates.Node, amount: number }[]
    table.sort(amounts, function(a, b)
        return a.amount < b.amount
    end)

    local fluids = {} ---@type table<string, { fluid: LuaFluidPrototype, weighted_temperature: number, amount: number }>
    for _, amount in ipairs(amounts) do
        local node = amount.node
        if (node.type == "fluid" and amount.amount > 0) then
            add_fluid_production(fluids, node.fluid, node.temperature, amount.amount)
        else
            message[#message + 1] = "\n"
            message[#message + 1] = dump_amount(amount)
        end
    end

    for _, fluid in pairs(fluids) do
        message[#message + 1] = "\n"
        local temperature = fluid.weighted_temperature / fluid.amount
        local node = api.node.create.fluid(fluid.fluid, temperature)
        message[#message + 1] = dump_amount({ tag = "product", node = node, amount = fluid.amount })
        local energy = temperature * fluid.amount * fluid.fluid.heat_capacity
        message[#message + 1] = "\n    corresponds to " .. api.gui.format_number(energy) .. "W"
    end

    player.print(api.gui.compress_string(message))

    local result = {} ---@type table<string, { fluid: LuaFluidPrototype, temperature: number, amount: number }>
    for key, entry in pairs(fluids) do
        result[key] = {
            fluid = entry.fluid,
            temperature = entry.weighted_temperature / entry.amount,
            amount = entry.amount
        }
    end

    return result
end

---@param player LuaPlayer
---@param entities { configuration: Rates.Configuration.FusionReactor | Rates.Configuration.FusionGenerator, count: integer }[]
---@param fluids table<string, { fluid: LuaFluidPrototype, temperature: number, amount: number }>
local function analyze_fusion_generator(player, entities, fluids)
    local message = { "", "Fusion generator layout:" } ---@type LocalisedString
    local amounts = {} ---@type table<string, { node: Rates.Node, amount: number }>
    for _, entry in ipairs(entities) do
        local conf = entry.configuration
        if (conf.type == "fusion-generator") then
            local entity_rich_text = "[entity=" .. conf.entity.name .. ",quality=" .. conf.quality.name .. "]"
            local entity_line = entry.count .. " x " .. entity_rich_text

            local input_fluid = fusion_generator.get_input_fluid(conf)
            local configured_fluid = fluids[input_fluid.name]
            if (configured_fluid) then
                conf.temperature = configured_fluid.temperature
            end

            message[#message + 1] = "\n"
            message[#message + 1] = entity_line
            local production = api.configuration.get_production(conf, {
                force = player.force --[[@as LuaForce]]
            })
            for _, amount in ipairs(production) do
                local node_id = api.node.get_id(amount.node)
                local am = amounts[node_id]
                if (not am) then
                    am = { node = amount.node, amount = 0 }
                    amounts[node_id] = am
                end

                am.amount = am.amount + amount.amount * entry.count
            end
        end
    end

    local amounts = to_value_array(amounts) ---@type { node: Rates.Node, amount: number }[]
    table.sort(amounts, function(a, b)
        return a.amount < b.amount
    end)

    for _, amount in ipairs(amounts) do
        message[#message + 1] = "\n"
        message[#message + 1] = dump_amount(amount)
        local node = amount.node
        if (node.type == "fluid" and amount.amount < 0) then
            local energy = node.temperature * -amount.amount * node.fluid.heat_capacity
            message[#message + 1] = "\n    corresponds to " .. api.gui.format_number(energy) .. "W"
        end
    end

    player.print(api.gui.compress_string(message))
end

---@param entities EntityCounts
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
    if (e.item ~= "sw-rates-reactor-layout-tool") then
        return
    end

    local player = game.players[e.player_index]

    local fusion_reactor_entities = {} ---@type EntityCounts
    local fusion_generator_entities = {} ---@type EntityCounts
    local reactor_entities = {} ---@type EntityCounts
    for _, entity in ipairs(e.entities) do
        local conf = api.configuration.get_from_entity(entity, { use_ghosts = true })
        if (conf) then
            while (conf.type == "meta") do
                conf = conf.children[1]
            end

            if (conf.type == "fusion-reactor") then
                add_entity(fusion_reactor_entities, conf)
            elseif (conf.type == "fusion-generator") then
                local input_fluid = fusion_generator.get_input_fluid(conf)
                conf.temperature = input_fluid.default_temperature
                conf.id = api.configuration.get_id(conf)
                add_entity(fusion_generator_entities, conf)
            elseif (conf.type == "reactor") then
                add_entity(reactor_entities, conf)
            end
        end
    end

    local fusion_reactor_entities = to_value_array(fusion_reactor_entities)
    local fusion_generator_entities = to_value_array(fusion_generator_entities)
    local reactor_entities = to_value_array(reactor_entities)
    local fluids = {}

    if (#fusion_reactor_entities > 0) then
        fluids = analyze_fusion_reactor(player, fusion_reactor_entities)
    end

    if (#fusion_generator_entities > 0) then
        analyze_fusion_generator(player, fusion_generator_entities, fluids)
    end

    if (#reactor_entities > 0) then
        analyze_reactor(player, reactor_entities)
    end
end

script.on_event({ defines.events.on_player_selected_area, defines.events.on_player_alt_selected_area },
    on_player_selected_area)
