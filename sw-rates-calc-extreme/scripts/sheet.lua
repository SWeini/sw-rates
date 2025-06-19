---@class Rates.Row
---@field block? Rates.Block
---@field configuration? Rates.Configuration
---@field count_groups? table<string, number>
---@field count_max? integer
---@field count_effective? number
---@field entity_ids integer[]
---@field amounts? Rates.Configuration.Amount[]

---@class Rates.Block
---@field name? string
---@field location? LuaSurface
---@field rows Rates.Row[]
---@field any_amounts? { node: Rates.Node, produced: number, consumed: number }[]

---@class Rates.Constraint
---@field min? number
---@field max? number

---@class Rates.Sheet
---@field block Rates.Block
---@field constraints table<string, Rates.Constraint>

local api = require("__sw-rates-lib__.api-usage")
local simplex = require("simplex")

---@param amounts Rates.Configuration.Amount[]
---@return table<string, { node: Rates.Node, amount: number }>
local function sum_amounts(amounts)
    local result = {} ---@type table<string, { node: Rates.Node, amount: number }>
    for _, amount in ipairs(amounts) do
        local node_id = api.node.get_id(amount.node)
        local entry = result[node_id]
        if (not entry) then
            entry = { node = amount.node, amount = 0 }
            result[node_id] = entry
        end

        entry.amount = entry.amount + amount.amount
    end

    return result
end

---@param location LuaSurface
---@param entities LuaEntity[]
---@return Rates.Sheet
local function build_from_entities(location, entities)
    local rows = {} ---@type table<string, Rates.Row>
    local nodes = {} ---@type table<string, { node: Rates.Node, has_positive: true?, has_negative: true? }>

    ---@param amounts Rates.Configuration.Amount[]
    local function record_positive_negative(amounts)
        local sum = sum_amounts(amounts)
        for name, amount in pairs(sum) do
            local entry = nodes[name]
            if (not entry) then
                entry = { node = amount.node }
                nodes[name] = entry
            end

            if (amount.amount > 0) then
                entry.has_positive = true
            elseif (amount.amount < 0) then
                entry.has_negative = true
            end
        end
    end

    ---@param conf Rates.Configuration
    ---@param force LuaForce
    ---@return Rates.Row
    local function add_row(conf, force)
        local name = api.configuration.get_id(conf)
        local row = rows[name]
        if (row == nil) then
            local amounts = api.configuration.get_production(conf, {
                force = force,
                surface = location,
                apply_quality = true
            })

            record_positive_negative(amounts)

            row = { entity_ids = {}, configuration = conf, count_max = 0, amounts = amounts }
            rows[name] = row
        end

        return row
    end

    for _, entity in ipairs(entities) do
        local conf = api.configuration.get_from_entity(entity, { use_ghosts = true })
        if (conf) then
            local force = entity.force --[[@as LuaForce]]
            if (conf.type == "meta" and #conf.children > 1) then
                local meta_id = api.configuration.get_id(conf)
                for _, child in ipairs(conf.children) do
                    -- TODO: apply fuel/selection of meta to child
                    local row = add_row(child, force)
                    row.count_groups = row.count_groups or {}
                    row.count_groups[meta_id] = (row.count_groups[meta_id] or 0) + 1
                    row.entity_ids[#row.entity_ids + 1] = entity.unit_number
                end
            else
                local row = add_row(conf, force)
                row.count_max = row.count_max + 1
                row.entity_ids[#row.entity_ids + 1] = entity.unit_number
            end
        end
    end

    local has_constraints = {} ---@type table<string, true>
    for name, node in pairs(nodes) do
        if (node.node.type == "any") then
            for _, child in ipairs(node.node.children) do
                local entry = nodes[api.node.get_id(child)]
                if (entry) then
                    entry.has_negative = true
                    node.has_positive = true
                end
            end
        end
    end

    for name, node in pairs(nodes) do
        if (node.node.type == "electric-power" or node.node.type == "pollution") then
        elseif (node.has_positive and node.has_negative) then
            has_constraints[name] = true
        end
    end

    local constraints = {} ---@type table<string, Rates.Constraint>
    for name, _ in pairs(has_constraints) do
        constraints[name] = { min = 0, max = 0 }
    end

    local rows_array = {} ---@type Rates.Row[]
    for _, row in pairs(rows) do
        rows_array[#rows_array + 1] = row
    end

    ---@type Rates.Block
    local block = {
        rows = rows_array,
        location = location
    }

    ---@type Rates.Sheet
    local sheet = {
        block = block,
        constraints = constraints
    }

    return sheet
end

---@param sheet Rates.Sheet
local function solve_sheet(sheet)
    local s = simplex.new()
    local constraints = {} ---@type table<string, Simplex.Constraint>

    for name, constraint in pairs(sheet.constraints) do
        local c = s:make_constraint(name, constraint.min, constraint.max)
        constraints[name] = c
    end

    local variables = {} ---@type table<string, Simplex.Variable>
    local processed_any_nodes = {} ---@type table<string, Rates.Node.Any>

    local group_constraints = {} ---@type table<string, Simplex.Constraint>
    for _, row in ipairs(sheet.block.rows) do
        local name = api.configuration.get_id(row.configuration)
        local v = s:make_variable(name, 0, row.count_max)
        if (row.count_groups) then
            v:set_bounds(0, nil)
            local con = s:make_constraint(name, 0, 0)
            con:set_coefficient(v, -1)

            if (row.count_max > 0) then
                local v_normal = s:make_variable(name .. "@explicit", 0, row.count_max)
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

        variables[name] = v
        s.objective:set_coefficient(v, -1)
        for _, amount in ipairs(row.amounts) do
            local node = amount.node
            local node_id = api.node.get_id(node)
            local c = constraints[node_id]
            if (c) then
                c:set_coefficient(v, amount.amount + c:get_coefficient(v))
                if (node.type == "any") then
                    if (not processed_any_nodes[node_id]) then
                        processed_any_nodes[node_id] = node
                        for _, child in ipairs(node.children) do
                            local child_id = api.node.get_id(child)
                            local any_c = constraints[child_id]
                            if (any_c) then
                                local any_name = node_id .. " <-- " .. child_id
                                local any_v = s:make_variable(any_name, 0, nil)
                                variables[any_name] = any_v
                                c:set_coefficient(any_v, 1)
                                any_c:set_coefficient(any_v, -1)
                            end
                        end
                    end
                end
            end
        end
    end

    local solution = s:solve()

    for _, row in ipairs(sheet.block.rows) do
        local value = solution.variable_values[variables[row.configuration.id]] or 0
        row.count_effective = value
    end

    local any_amounts_builder = {} ---@type table<string, { node: Rates.Node, produced: number, consumed: number }>

    ---@param node Rates.Node
    ---@param amount number
    local function add_amount(node, amount)
        local node_id = api.node.get_id(node)
        local entry = any_amounts_builder[node_id]
        if (not entry) then
            entry = { node = node, produced = 0, consumed = 0 }
            any_amounts_builder[node_id] = entry
        end

        if (amount > 0) then
            entry.produced = entry.produced + amount
        elseif (amount < 0) then
            entry.consumed = entry.consumed + amount
        end
    end

    for _, node in pairs(processed_any_nodes) do
        local node_id = api.node.get_id(node)
        for _, child in ipairs(node.children) do
            local child_id = api.node.get_id(child)
            local any_name = node_id .. " <-- " .. child_id
            local variable = variables[any_name]
            if (variable) then
                local value = solution.variable_values[variable] or 0
                add_amount(node, value)
                add_amount(child, -value)
            end
        end
    end

    local any_amounts = {} ---@type { node: Rates.Node, produced: number, consumed: number }[]
    for _, amount in pairs(any_amounts_builder) do
        any_amounts[#any_amounts + 1] = amount
    end

    sheet.block.any_amounts = any_amounts
end

---@param sheet Rates.Sheet
---@param surface LuaSurface
---@param force LuaForce
---@return table<string, { node: Rates.Node, produced: number, consumed: number }>
local function get_total_production(sheet, surface, force)
    local result = {} ---@type table<string, { node: Rates.Node, produced: number, consumed: number }>

    local function add(node, produced, consumed)
        local node_id = api.node.get_id(node)
        local entry = result[node_id]
        if (not entry) then
            entry = { node = node, produced = 0, consumed = 0 }
            result[node_id] = entry
        end

        entry.produced = entry.produced + produced
        entry.consumed = entry.consumed + consumed
    end

    for _, row in ipairs(sheet.block.rows) do
        local load = row.count_effective / row.count_max
        local amounts = api.configuration.get_production(row.configuration, {
            force = force --[[@as LuaForce]],
            surface = surface,
            apply_quality = true,
            load = load
        })
        for _, amount in ipairs(amounts) do
            if (amount.amount > 0) then
                add(amount.node, amount.amount * row.count_effective, 0)
            elseif (amount.amount < 0) then
                add(amount.node, 0, amount.amount * row.count_effective)
            end
        end
    end

    for _, amount in ipairs(sheet.block.any_amounts) do
        add(amount.node, amount.produced, amount.consumed)
    end

    return result
end

return {
    build_from_entities = build_from_entities,
    solve_sheet = solve_sheet,
    get_total_production = get_total_production,
}
