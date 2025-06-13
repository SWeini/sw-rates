---@class Rates.Row
---@field block? Rates.Block
---@field configuration? Rates.Configuration
---@field count_max? integer
---@field count_effective? number
---@field entity_ids integer[]
---@field amounts? Rates.Configuration.Amount[]

---@class Rates.Block
---@field name? string
---@field location? LuaSurface
---@field rows Rates.Row[]
---@field any_amounts? { node: Rates.Node, amount: number }[]

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
        local entry = result[amount.node.id]
        if (not entry) then
            entry = { node = amount.node, amount = 0 }
            result[amount.node.id] = entry
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

    for _, entity in ipairs(entities) do
        local conf = api.configuration.get_from_entity(entity, { use_ghosts = true })
        if (conf) then
            local name = conf.id
            local row = rows[name]
            if (row == nil) then
                -- TODO: do this for all meta children separately
                local amounts = api.configuration.get_production(conf, {
                    force = entity.force --[[@as LuaForce]],
                    surface = location,
                    apply_quality = true
                })

                record_positive_negative(amounts)

                row = { entity_ids = {}, configuration = conf, count_max = 0, amounts = amounts }
                rows[name] = row
            end

            row.count_max = row.count_max + 1
            row.entity_ids[#row.entity_ids + 1] = entity.unit_number
        end
    end

    local has_constraints = {} ---@type table<string, true>
    for name, node in pairs(nodes) do
        if (node.node.type == "any") then
            for _, child in ipairs(node.node.children) do
                local entry = nodes[child.id]
                if (entry) then
                    entry.has_negative = true
                    node.has_positive = true
                end
            end
        end
    end

    for name, node in pairs(nodes) do
        if (node.node.type == "electric-power") then
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

    for _, row in ipairs(sheet.block.rows) do
        local name = row.configuration.id
        local v = s:make_variable(name, 0, row.count_max)
        variables[name] = v
        s.objective:set_coefficient(v, -1)
        for _, amount in ipairs(row.amounts) do
            local node = amount.node
            local c = constraints[node.id]
            if (c) then
                c:set_coefficient(v, amount.amount + c:get_coefficient(v))
                if (node.type == "any") then
                    if (not processed_any_nodes[node.id]) then
                        processed_any_nodes[node.id] = node
                        for _, child in ipairs(node.children) do
                            local any_c = constraints[child.id]
                            if (any_c) then
                                local any_name = node.id .. " <-- " .. child.id
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

    local any_amounts_builder = {} ---@type table<string, { node: Rates.Node, amount: number }>
    ---@param node Rates.Node
    ---@param amount number
    local function add_amount(node, amount)
        local entry = any_amounts_builder[node.id]
        if (not entry) then
            entry = { node = node, amount = 0 }
            any_amounts_builder[node.id] = entry
        end

        entry.amount = entry.amount + amount
    end

    for _, node in pairs(processed_any_nodes) do
        for _, child in ipairs(node.children) do
            local any_name = node.id .. " <-- " .. child.id
            local variable = variables[any_name]
            if (variable) then
                local value = solution.variable_values[variable] or 0
                add_amount(node, value)
                add_amount(child, -value)
            end
        end
    end

    local any_amounts = {} ---@type { node: Rates.Node, amount: number }[]
    for _, amount in pairs(any_amounts_builder) do
        any_amounts[#any_amounts + 1] = amount
    end

    sheet.block.any_amounts = any_amounts
end

---@param sheet Rates.Sheet
---@param surface LuaSurface
---@param force LuaForce
---@return table<string, { node: Rates.Node, amount: number }>
local function get_total_production(sheet, surface, force)
    local result = {} ---@type table<string, { node: Rates.Node, amount: number }>

    local function add(node, amount)
        local entry = result[node.id]
        if (not entry) then
            entry = { node = node, amount = 0 }
            result[node.id] = entry
        end

        entry.amount = entry.amount + amount
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
            add(amount.node, amount.amount * row.count_effective)
        end
    end

    for _, amount in ipairs(sheet.block.any_amounts) do
        add(amount.node, amount.amount)
    end

    return result
end

return {
    build_from_entities = build_from_entities,
    solve_sheet = solve_sheet,
    get_total_production = get_total_production,
}
