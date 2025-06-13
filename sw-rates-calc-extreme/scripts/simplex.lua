---@class Simplex
---@field variables Simplex.Variable[]
---@field constraints Simplex.Constraint[]
---@field objective Simplex.Objective
---@field options Simplex.Options
local Simplex = { n_variables = 0, n_constraints = 0 }
local simplex_mt = { __index = Simplex }

---@class Simplex.Variable
---@field owner Simplex
---@field name string
---@field lower_bound number?
---@field upper_bound number?
local Variable = {}
local variable_mt = { __index = Variable }

---@class Simplex.Constraint
---@field owner Simplex
---@field name string
---@field lower_bound number?
---@field upper_bound number?
---@field coeffs {[Simplex.Variable]: number}
local Constraint = {}
local constraint_mt = { __index = Constraint }

---@class Simplex.Objective
---@field owner Simplex
---@field coeffs {[Simplex.Variable]: number}
---@field type "minimize" | "maximize"
local Objective = { type = "minimize" }
local objective_mt = { __index = Objective }

---@class Simplex.Options
local Options = { tolerance_feasability = 1e-9 }
local options_mt = { __index = Options }

---@class Simplex.Tableau
---@field owner Simplex
---@field n_rows integer
---@field n_cols integer
---@field a number[][]
---@field b number[]
---@field c number[]
---@field c2 number[]?
---@field obj number
---@field obj2 number?
---@field var_basic integer[]
---@field var_free integer[]
---@field upper_bound { [integer]: { u: number, swapped: boolean } }
local Tableau = {}
local tableau_mt = { __index = Tableau }

---@class Simplex.Result
---@field result "success" | "not_feasible" | "unbound"
---@field objective number?
---@field variable_values {[Simplex.Variable]: number}

---@return Simplex
function Simplex.new()
    local objective = setmetatable({
        coeffs = {}
    }, objective_mt) --[[@as Simplex.Objective]]

    local result = setmetatable({
        variables = {},
        constraints = {},
        objective = objective,
        options = setmetatable({}, options_mt)
    }, simplex_mt) --[[@as Simplex]]

    objective.owner = result

    return result
end

---@param name string
---@param lower number?
---@param upper number?
---@return Simplex.Variable
function Simplex:make_variable(name, lower, upper)
    local result = setmetatable({
        owner = self,
        name = name,
        lower_bound = lower,
        upper_bound = upper
    }, variable_mt) --[[@as Simplex.Variable]]

    result:set_bounds(lower, upper)

    local n = self.n_variables + 1
    self.n_variables = n
    self.variables[n] = result

    return result;
end

---@param name string
---@param lower number?
---@param upper number?
---@return Simplex.Constraint
function Simplex:make_constraint(name, lower, upper)
    local result = setmetatable({
        owner = self,
        name = name,
        lower_bound = lower,
        upper_bound = upper,
        coeffs = {}
    }, constraint_mt) --[[@as Simplex.Constraint]]

    result:set_bounds(lower, upper)

    local n = self.n_constraints + 1
    self.n_constraints = n
    self.constraints[n] = result

    return result
end

---@param self Simplex.Variable
function variable_mt:__tostring()
    return "VAR/" .. self.name
end

---@param lower number?
---@param upper number?
function Variable:set_bounds(lower, upper)
    if (lower and upper and lower > upper) then
        error("invalid bounds for variable " .. self.name .. ": " .. tostring(lower) .. " / " .. tostring(upper))
    end

    self.lower_bound = lower
    self.upper_bound = upper
end

---@param self Simplex.Constraint
function constraint_mt:__tostring()
    return "CON/" .. self.name
end

---@param lower number?
---@param upper number?
function Constraint:set_bounds(lower, upper)
    if (lower and upper and lower > upper) then
        error("invalid bounds for constraint " .. self.name .. ": " .. tostring(lower) .. " / " .. tostring(upper))
    end

    self.lower_bound = lower
    self.upper_bound = upper
end

---@param var Simplex.Variable
---@return number
function Constraint:get_coefficient(var)
    if (var.owner ~= self.owner) then
        error("variable does not belong to the correct simplex instance")
    end

    return self.coeffs[var] or 0
end

---@param var Simplex.Variable
---@param coeff number
function Constraint:set_coefficient(var, coeff)
    if (var.owner ~= self.owner) then
        error("variable does not belong to the correct simplex instance")
    end

    self.coeffs[var] = coeff
end

---@param var Simplex.Variable
---@return number
function Objective:get_coefficient(var)
    if (var.owner ~= self.owner) then
        error("variable does not belong to the correct simplex instance")
    end

    return self.coeffs[var] or 0
end

---@param var Simplex.Variable
---@param coeff number
function Objective:set_coefficient(var, coeff)
    if (var.owner ~= self.owner) then
        error("variable does not belong to the correct simplex instance")
    end

    self.coeffs[var] = coeff
end

function Tableau:dump()
    -- log(serpent.block(self))
    local result = {}
    for i = 1, self.n_rows do
        local var = self.var_basic[i]
        local name
        if (var > 0) then
            result[tostring(self.owner.variables[var])] = self.b[i]
        else
            local b = self.b[i]
            if (b > 0) then
                result[tostring(self.owner.constraints[-var])] = b
            end
        end
    end
    -- log(serpent.block({ obj = self.obj, obj2 = self.obj2, variable_values = result }))
end

---@param s Simplex
---@return Simplex.Tableau
local function generate_tableau(s)
    for _, var in ipairs(s.variables) do
        if (var.lower_bound ~= 0) then
            error("lower bound ~= 0 not supported")
        end
    end

    for i = #s.constraints, 1, -1 do
        local c = s.constraints[i]
        if (c.lower_bound == nil and c.upper_bound == nil) then
            table.remove(s.constraints, i)
            s.n_constraints = s.n_constraints - 1
        end
    end

    for _, con in ipairs(s.constraints) do
        if (con.lower_bound == nil or con.upper_bound ~= con.lower_bound) then
            error("inequalities not supported")
        end

        if (con.lower_bound < 0) then
            for k, v in con.coeffs do
                con.coeffs[k] = -v
            end
            con.lower_bound = -con.lower_bound
            con.upper_bound = -con.upper_bound
        end
    end

    local n_rows = s.n_constraints
    local n_cols = s.n_variables
    local a = {}
    local b = {}
    local c = {}
    local c2 = {}
    local obj = 0.0
    local obj2 = 0.0
    local var_basic = {}
    local var_free = {}
    local upper_bound = {}

    for i, var in ipairs(s.variables) do
        local col = {}
        a[i] = col
        local c_sum = 0.0
        for j, con in ipairs(s.constraints) do
            local coeff = con:get_coefficient(var)
            col[j] = coeff
            c_sum = c_sum + coeff
        end

        var_free[i] = i
        c[i] = c_sum
        c2[i] = -s.objective:get_coefficient(var)

        if (var.upper_bound ~= nil) then
            upper_bound[i] = { u = var.upper_bound, swapped = false }
        end
    end

    for i, con in ipairs(s.constraints) do
        local val = con.lower_bound
        b[i] = val
        obj = obj + val
        var_basic[i] = -i
    end

    local result = {
        owner = s,
        n_rows = n_rows,
        n_cols = n_cols,
        a = a,
        b = b,
        c = c,
        c2 = c2,
        obj = obj,
        obj2 = obj2,
        var_basic = var_basic,
        var_free = var_free,
        upper_bound = upper_bound
    }
    return setmetatable(result, tableau_mt) --[[@as Simplex.Tableau]]
end

---@param tableau Simplex.Tableau
local function switch_phase(tableau)
    log("phase 1 done, move to phase 2")
    tableau.c = tableau.c2
    tableau.c2 = nil
    tableau.obj = tableau.obj2
    tableau.obj2 = nil
    for i = 1, tableau.n_rows do
        local var = tableau.var_basic[i]
        if (var < 0) then
            tableau.upper_bound[var] = { u = 0, swapped = false }
        end
    end

    tableau:dump()
end

---@param tableau Simplex.Tableau
---@return 0 | 1 | 2 | 3 | 4, integer?, integer? -- 0 = no pivot column, 1 = no pivot row, 2 = normal, 3 = basic variable at limit, 4 = free variable at limit
local function find_pivot_element(tableau)
    ---@type integer?
    local pc
    do
        ---@type number?
        local max
        for i, c in ipairs(tableau.c) do
            if (c > 0) then
                if (max == nil or c > max) then
                    max, pc = c, i
                end
            end
        end
    end

    if (pc == nil) then
        return 0
    end

    ---@type integer?
    local pr
    ---@type (0 | 1 | 2 | 3 | 4)
    local type = 1
    ---@type number?
    local min
    do
        local upper_bound = tableau.upper_bound
        local upper = upper_bound[tableau.var_free[pc]]
        if (upper) then
            type, min = 4, upper.u
        end

        for i, a in ipairs(tableau.a[pc]) do
            if (a > 0) then
                local ratio = tableau.b[i] / a
                if (min == nil or ratio < min) then
                    type, min, pr = 2, ratio, i
                end
            elseif (a < 0) then
                local u = upper_bound[tableau.var_basic[i]]
                if (u) then
                    local ratio = (tableau.b[i] - u.u) / a
                    if (min == nil or ratio < min) then
                        type, min, pr = 3, ratio, i
                    end
                end
            end
        end
    end

    return type, pc, pr
end

---@param t Simplex.Tableau
---@param pc integer
---@param pr integer
local function pivot(t, pc, pr)
    local var_enter = t.var_free[pc]
    local var_leave = t.var_basic[pr]
    t.var_free[pc] = var_leave
    t.var_basic[pr] = var_enter
    -- log(serpent.line {
    --     pivot_col = pc,
    --     pivot_row = pr,
    --     variable_enter = var_enter,
    --     variable_leave = var_leave
    -- })

    local a = t.a
    local a_s = a[pc]
    local a_rs = a_s[pr]
    local b = t.b
    local b_r = b[pr]
    local c = t.c
    local c_s = c[pc]
    local c2 = t.c2
    local c2_s = c2 and c2[pc]
    for j = 1, t.n_cols do
        if (j ~= pc) then
            local a_j = a[j]
            local a_rj = a_j[pr]
            for i = 1, t.n_rows do
                if (i ~= pr) then
                    a_j[i] = a_j[i] - (a_rj * a_s[i]) / a_rs
                end
            end

            a_j[pr] = a_rj / a_rs
            c[j] = c[j] - (a_rj * c_s) / a_rs
            if (c2) then
                c2[j] = c2[j] - (a_rj * c2_s) / a_rs
            end
        end
    end

    t.obj = t.obj - (b_r * c_s) / a_rs
    if (c2) then
        t.obj2 = t.obj2 - (b_r * c2_s) / a_rs
    end
    for i = 1, t.n_rows do
        if (i ~= pr) then
            b[i] = b[i] - (b_r * a_s[i]) / a_rs
        end

        b[pr] = b_r / a_rs
    end

    for i = 1, t.n_rows do
        if (i ~= pr) then
            a_s[i] = -a_s[i] / a_rs
        end
    end

    c[pc] = -c_s / a_rs
    if (c2) then
        c2[pc] = -c2_s / a_rs
    end

    a_s[pr] = 1 / a_rs
end

---@param t Simplex.Tableau
---@param col integer
local function remove_free(t, col)
    local var = t.var_free[col]
    log("remove free variable at column " .. col .. ": " .. var)
    t.upper_bound[var] = nil
    local last = t.n_cols
    t.a[col] = t.a[last]
    t.a[last] = nil
    t.c[col] = t.c[last]
    t.c[last] = nil
    if (t.c2) then
        t.c2[col] = t.c2[last]
        t.c2[last] = nil
    end
    t.var_free[col] = t.var_free[last]
    t.var_free[last] = nil
    t.n_cols = last - 1
end

---@param tableau Simplex.Tableau
---@return boolean
local function solve_phase(tableau)
    while (true) do
        local pivot_type, pivot_col, pivot_row = find_pivot_element(tableau)
        if (pivot_type == 0) then
            log("no pivot column found, solution found")
            return true
        end
        ---@cast pivot_col integer

        if (pivot_type == 1) then
            log("no pivot row found, solution unbounded")
            return false
        end

        if (pivot_type == 4) then
            -- error("upper bound of normal variables not implemented")
            log("column " .. pivot_col .. " at upper bound")
            local a_s = tableau.a[pivot_col]
            local var = tableau.var_free[pivot_col]
            local u = tableau.upper_bound[var]
            u.swapped = not u.swapped
            for i = 1, tableau.n_rows do
                tableau.b[i] = tableau.b[i] - a_s[i] * u.u
                a_s[i] = -a_s[i]
            end
            tableau.obj = tableau.obj - tableau.c[pivot_col] * u.u
            tableau.c[pivot_col] = -tableau.c[pivot_col]
            if (tableau.obj2) then
                tableau.obj2 = tableau.obj2 - tableau.c2[pivot_col] * u.u
                tableau.c2[pivot_col] = -tableau.c2[pivot_col]
            end
            tableau:dump()
        end

        ---@cast pivot_col integer
        ---@cast pivot_row integer

        if (pivot_type == 3) then
            local a = tableau.a
            local b = tableau.b
            local var = tableau.var_basic[pivot_row]
            local u = tableau.upper_bound[var]
            u.swapped = not u.swapped
            -- log("basic variable " .. var .. " at limit: " .. u)
            b[pivot_row] = u.u - b[pivot_row]
            for j = 1, tableau.n_cols do
                local a_j = a[j]
                a_j[pivot_row] = -a_j[pivot_row]
            end
        end

        if (pivot_type == 2 or pivot_type == 3) then
            pivot(tableau, pivot_col, pivot_row)
            if (tableau.var_free[pivot_col] < 0) then
                remove_free(tableau, pivot_col)
            end
            tableau:dump()
        end
    end
end

---@return Simplex.Result
function Simplex:solve()
    local tableau = generate_tableau(self)
    tableau:dump()
    solve_phase(tableau)
    if (tableau.obj >= self.options.tolerance_feasability) then
        return {
            result = "not_feasible",
            variable_values = {}
        } --[[@as Simplex.Result]]
    end
    switch_phase(tableau)
    local result2 = solve_phase(tableau)
    local result = {}
    for i = 1, tableau.n_rows do
        local var = tableau.var_basic[i]
        if (var > 0) then
            local variable = self.variables[var]
            local u = tableau.upper_bound[var]
            if (u and u.swapped) then
                result[variable] = u.u - tableau.b[i]
            else
                result[variable] = tableau.b[i]
            end
        elseif (tableau.b[i] ~= 0) then
            local constraint = self.constraints[-var]
            log("constraint " .. constraint.name .. " violated: " .. tableau.b[i])
        end
    end
    for j = 1, tableau.n_cols do
        local var = tableau.var_free[j]
        if (var > 0) then
            local variable = self.variables[var]
            local u = tableau.upper_bound[var]
            if (u and u.swapped) then
                result[variable] = variable.upper_bound
            else
                -- result[variable] = 0
            end
        end
    end
    return {
        result = result and "success" or "unbound",
        variable_values = result,
        objective = tableau.obj
    } --[[@as Simplex.Result]]
end

return Simplex
