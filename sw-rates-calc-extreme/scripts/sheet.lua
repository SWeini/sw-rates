local api = require("__sw-rates-lib__.api-usage")
local analyzer = require("__sw-rates-lib__.scripts.flow-analyzer")
local simplex = require("scripts.simplex")

---@class (exact) Rates.Sheet
---@field data Rates.Data.Sheet
---@field selected_configurations Rates.Sheet.Configuration[]
---@field configurations Rates.Sheet.Configuration[]
---@field nodes table<string, Rates.Sheet.Node>

---@class (exact) Rates.Sheet.Configuration
---@field id string
---@field configuration Rates.Configuration
---@field annotations Rates.Configuration.Annotation[]
---@field location Rates.Data.LocationIndex
---@field force LuaForce
---@field amounts Rates.Configuration.Amount[]
---@field count_max number
---@field count_groups? table<string, number>
---@field count_infinite? true
---@field count_effective? number

---@class (exact) Rates.Sheet.Node
---@field id string
---@field node Rates.Node
---@field location Rates.Data.LocationIndex
---@field has_positive? true
---@field has_negative? true
---@field min? number
---@field max? number
---@field any_produced? table<string, number>
---@field any_consumed? table<string, number>

---@type table<string, true>
local item_placer_types = {
    ["inserter"] = true,
    ["loader"] = true,
    ["loader-1x1"] = true
}

---@type table<string, true>
local vector_to_place_result_types = {
    ["mining-drill"] = true,
    ["assembling-machine"] = true,
    ["furnace"] = true
}

---@param conf Rates.Configuration
---@param location Rates.Data.LocationIndex
---@param force LuaForce
---@return string
local function get_full_configuration_id(conf, location, force)
    return location .. "/" .. force.name .. "/" .. api.configuration.get_id(conf)
end

---@param entities table<integer, Rates.Data.Sheet.SelectedEntity>
---@return Rates.Analyzer.Context, Rates.Data.Sheet.SelectedEntity[]
local function analyze_flow(entities)
    local context = analyzer.create_context()
    local buildings = {} ---@type Rates.Data.Sheet.SelectedEntity[]
    for _, selected_entity in pairs(entities) do
        local entity = selected_entity.entity
        if (entity.valid) then
            local type = entity.type
            if (type == "entity-ghost") then
                type = entity.ghost_type
            end
            if (item_placer_types[type]) then
                analyzer.add_item_placer(context, entity)
            else
                analyzer.add_required_entity(context, entity)
                buildings[#buildings + 1] = selected_entity
                if (vector_to_place_result_types) then
                    analyzer.add_item_placer(context, entity)
                end
            end
        end
    end

    analyzer.analyze_full(context)

    return context, buildings
end

---@param amounts Rates.Configuration.Amount[]
---@param location Rates.Data.LocationIndex
---@return table<string, { node: Rates.Node, location: Rates.Data.LocationIndex, amount: number }>
local function sum_amounts(amounts, location)
    local result = {} ---@type table<string, { node: Rates.Node, location: Rates.Data.LocationIndex, amount: number }>
    for _, amount in ipairs(amounts) do
        local loc = location
        if (amount.tag == "import") then
            loc = amount.tag_extra --[[@as Rates.Data.LocationIndex]]
        end
        local node_id = loc .. "/" .. api.node.get_id(amount.node)
        local entry = result[node_id]
        if (not entry) then
            entry = { node = amount.node, location = loc, amount = 0 }
            result[node_id] = entry
        end

        entry.amount = entry.amount + amount.amount
    end

    return result
end

---@param configurations Rates.Sheet.Configuration[]
---@param nodes table<string, Rates.Data.Sheet.Node>
---@return table<string, Rates.Sheet.Node>
local function build_nodes(configurations, nodes)
    ---@type table<string, Rates.Sheet.Node>
    local result = {}

    for _, conf in ipairs(configurations) do
        local sum = sum_amounts(conf.amounts, conf.location)
        for id, amount in pairs(sum) do
            local entry = result[id]
            if (not entry) then
                entry = { id = id, node = amount.node, location = amount.location }
                result[id] = entry
            end

            if (amount.amount > 0) then
                entry.has_positive = true
            end
            if (amount.amount < 0) then
                entry.has_negative = true
            end
        end
    end

    for _, node in pairs(result) do
        if (node.node.type == "any") then
            for _, child in ipairs(node.node.children) do
                local id = node.location .. "/" .. api.node.get_id(child)
                local entry = result[id]
                if (entry and entry.has_positive) then
                    entry.has_negative = true
                    node.has_positive = true
                end
            end
        end
    end

    for name, node in pairs(result) do
        local data = nodes[name]
        if (data and data.linked ~= nil) then
            if (data.linked) then
                node.min = 0
                node.max = 0
            end
        elseif (node.node.type == "electric-power" or node.node.type == "pollution") then
            -- electric power and pollution not linked by default
        elseif (node.has_positive and node.has_negative) then
            node.min = 0
            node.max = 0
        end
    end

    return result
end

---@param configurations table<string, Rates.Sheet.Configuration>
---@param conf Rates.Configuration
---@param locations Rates.Location[]
---@param location_index Rates.Data.LocationIndex
---@param force LuaForce
---@return Rates.Sheet.Configuration
local function add_configuration(configurations, conf, locations, location_index, force)
    local location = locations[location_index]
    local id = get_full_configuration_id(conf, location_index, force)
    local row = configurations[id]
    if (row == nil) then
        local annotations = api.configuration.get_annotations(conf)
        local amounts = api.configuration.get_production(conf, {
            force = force,
            surface = location,
            use_pollution = game.map_settings.pollution.enabled,
            annotations = annotations
        })

        row = {
            id = id,
            force = force,
            location = location_index,
            configuration = conf,
            count_max = 0,
            amounts = amounts,
            annotations = annotations,
        }
        configurations[id] = row
    end

    return row
end

---@param sheet Rates.Data.Sheet
---@param surface LuaSurface
---@return integer
local function get_location_index(sheet, surface)
    for i, location in ipairs(sheet.locations) do
        if (location.name == surface.name) then
            return i
        end
    end

    sheet.locations[#sheet.locations + 1] = surface
    return #sheet.locations
end

---@param sheet Rates.Data.Sheet
---@return Rates.Sheet.Configuration[]
local function build_selected_configurations(sheet)
    local analyzer_context, entities = analyze_flow(sheet.selection.entities)

    ---@type table<string, Rates.Sheet.Configuration>
    local entries = {}

    local remove_fuel = not sheet.selection.use_fuel

    for _, selected_entity in ipairs(entities) do
        local entity = selected_entity.entity
        local location_index = get_location_index(sheet, entity.surface)
        local count = selected_entity.count
        local inputs = analyzer.get_entity_inputs(analyzer_context, entity)
        local conf = api.configuration.get_from_entity(entity,
            {
                use_ghosts = sheet.selection.use_ghosts,
                analyzer_inputs = inputs,
            })
        if (conf) then
            local force = entity.force --[[@as LuaForce]]

            if (remove_fuel and conf.type == "meta") then
                ---@cast conf Rates.Configuration.Meta
                conf.fuel = nil
                conf.id = nil

                if (#conf.children == 1 and (not conf.selection or table_size(conf.selection) == 0)) then
                    conf = conf.children[1]
                end
            end

            if (conf.type == "meta" and #conf.children > 1) then
                local meta_id = api.configuration.get_id(conf)
                for _, child in ipairs(conf.children) do
                    local entry = add_configuration(entries, child, sheet.locations, location_index, force)
                    entry.count_groups = entry.count_groups or {}
                    entry.count_groups[meta_id] = (entry.count_groups[meta_id] or 0) + count
                end
            else
                local entry = add_configuration(entries, conf, sheet.locations, location_index, force)
                entry.count_max = entry.count_max + count
            end
        end
    end

    ---@type Rates.Sheet.Configuration[]
    local result = {}
    for _, value in pairs(entries) do
        result[#result + 1] = value
    end

    return result
end

---@param selected Rates.Sheet.Configuration[]
---@param configured Rates.Data.Sheet.Configuration[]
---@param adjustments table<string, Rates.Data.Sheet.ConfigurationAdjustment>
---@param locations Rates.Location[]
---@return Rates.Sheet.Configuration[]
local function build_configurations(selected, configured, adjustments, locations)
    ---@type Rates.Sheet.Configuration[]
    local result = {}

    ---@type table<string, Rates.Sheet.Configuration>
    local entries = {}

    for _, value in pairs(selected) do
        local id = get_full_configuration_id(value.configuration, value.location, value.force)
        entries[id] = {
            id = value.id,
            configuration = value.configuration,
            annotations = value.annotations,
            location = value.location,
            force = value.force,
            amounts = value.amounts,
            count_max = value.count_max,
            count_groups = table.deepcopy(value.count_groups),
        }
    end

    for _, conf in ipairs(configured) do
        local entry = add_configuration(entries, conf.configuration, locations, conf.location, conf.force)
        entry.count_max = entry.count_max + (conf.count_max or math.huge)
    end

    for id, adjustment in pairs(adjustments) do
        local entry = entries[id]
        if (entry) then
            if (adjustment.count_infinite == true) then
                entry.count_infinite = true
            end
        end
    end

    for _, row in pairs(entries) do
        result[#result + 1] = row
    end

    table.sort(result, function(a, b)
        return a.id < b.id
    end)

    return result
end

---@param sheet Rates.Sheet
---@param player LuaPlayer
local function solve(sheet, player)
    local s = simplex.new()
    local setting_pivot = settings.get_player_settings(player)["sw-rates-calc-extreme-simplex-min-pivot-element"]
    s.options.tolerance_pivot = setting_pivot.value --[[@as number]]

    local constraints = {} ---@type table<string, Simplex.Constraint>
    local group_constraints = {} ---@type table<string, Simplex.Constraint>
    local variables = {} ---@type table<string, Simplex.Variable>
    local any_nodes = {} ---@type table<string, Rates.Node.Any>

    for name, node in pairs(sheet.nodes) do
        if (node.min or node.max) then
            local c = s:make_constraint(name, node.min, node.max)
            constraints[name] = c
        end
    end

    for _, row in ipairs(sheet.configurations) do
        local name = row.id
        local count_max = row.count_infinite and math.huge or row.count_max
        local v = s:make_variable(name, 0, count_max)
        variables[name] = v
        if (count_max == math.huge) then
            v:set_bounds(0, nil)
        else
            s.objective:set_coefficient(v, -1)

            if (row.count_groups) then
                v:set_bounds(0, nil)
                local con = s:make_constraint(name, 0, 0)
                con:set_coefficient(v, -1)

                if (count_max > 0) then
                    local v_normal = s:make_variable(name .. "@explicit", 0, count_max)
                    con:set_coefficient(v_normal, 1)
                end

                for group_name, group_count_max in pairs(row.count_groups) do
                    local v_part = s:make_variable(name .. "@" .. group_name, 0, nil)
                    con:set_coefficient(v_part, 1)

                    local group_constraint = group_constraints[group_name]
                    if (not group_constraint) then
                        group_constraint = s:make_constraint(group_name, 0, group_count_max)
                        group_constraints[group_name] = group_constraint
                    end

                    group_constraint:set_coefficient(v_part, 1)
                end
            end
        end

        for _, amount in ipairs(row.amounts) do
            local loc = row.location
            if (amount.tag == "import") then
                loc = amount.tag_extra --[[@as Rates.Data.LocationIndex]]
            end
            local prefix = loc .. "/"
            local node = amount.node
            local node_id = prefix .. api.node.get_id(node)
            local c = constraints[node_id]
            if (c) then
                c:set_coefficient(v, amount.amount + c:get_coefficient(v))
            end
            if (node.type == "any") then
                if (not any_nodes[node_id]) then
                    any_nodes[node_id] = node
                    for _, child in ipairs(node.children) do
                        local child_id = api.node.get_id(child)
                        local entry = sheet.nodes[prefix .. child_id]
                        local any_c = constraints[prefix .. child_id]
                        if (entry and entry.has_positive) then
                            local any_name = node_id .. " <-- " .. child_id
                            local any_v = s:make_variable(any_name, 0, nil)
                            variables[any_name] = any_v
                            if (c) then
                                c:set_coefficient(any_v, 1)
                            end
                            if (any_c) then
                                any_c:set_coefficient(any_v, -1)
                            end
                        end
                    end
                end
            end
        end
    end

    local solution = s:solve()

    for _, row in ipairs(sheet.configurations) do
        local value = solution.variable_values[variables[row.id]]
        row.count_effective = value
    end

    local any_amounts_builder = sheet.nodes

    ---@param node Rates.Node
    ---@param other_node Rates.Node
    ---@param location Rates.Data.LocationIndex
    ---@param amount number
    local function add_amount(node, other_node, location, amount)
        local node_id = location .. "/" .. api.node.get_id(node)
        local entry = any_amounts_builder[node_id]
        if (not entry) then
            entry = {
                id = node_id,
                node = node,
                location = location
            }
            any_amounts_builder[node_id] = entry
        end

        if (amount > 0) then
            local any = entry.any_produced
            if (not any) then
                any = {}
                entry.any_produced = any
            end
            any[location .. "/" .. api.node.get_id(other_node)] = amount
        elseif (amount < 0) then
            local any = entry.any_consumed
            if (not any) then
                any = {}
                entry.any_consumed = any
            end
            any[location .. "/" .. api.node.get_id(other_node)] = -amount
        end
    end

    for node_id, node in pairs(any_nodes) do
        local idx = node_id:find("/", nil, true)
        local location = tonumber(node_id:sub(1, idx - 1)) --[[@as Rates.Data.LocationIndex]]
        for _, child in ipairs(node.children) do
            local child_id = api.node.get_id(child)
            local any_name = node_id .. " <-- " .. child_id
            local variable = variables[any_name]
            if (variable) then
                local value = solution.variable_values[variable] or 0
                add_amount(node, child, location, value)
                add_amount(child, node, location, -value)
            end
        end
    end
end

---@param sheet Rates.Sheet
local function adjust_for_load(sheet)
    for _, conf in ipairs(sheet.configurations) do
        local amounts = api.configuration.get_production(conf.configuration, {
            force = conf.force,
            surface = sheet.data.locations[conf.location],
            use_pollution = game.map_settings.pollution.enabled,
            load = (conf.count_effective or 0) / conf.count_max,
        })
        conf.amounts = amounts
    end
end

---@param player LuaPlayer
---@param sheet Rates.Data.Sheet
---@param selected_configurations Rates.Sheet.Configuration[]?
---@return Rates.Sheet
local function calculate(player, sheet, selected_configurations)
    if (selected_configurations == nil) then
        selected_configurations = build_selected_configurations(sheet)
    end
    local configurations = build_configurations(selected_configurations, sheet.configurations,
        sheet.configuration_adjustments, sheet.locations)
    local nodes = build_nodes(configurations, sheet.nodes)
    ---@type Rates.Sheet
    local result = {
        data = sheet,
        selected_configurations = selected_configurations,
        configurations = configurations,
        nodes = nodes,
    }
    solve(result, player)
    adjust_for_load(result)
    return result
end

return {
    calculate = calculate,
    get_full_configuration_id = get_full_configuration_id,
}
