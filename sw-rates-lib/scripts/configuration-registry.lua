local registry = {} ---@type table<string, Rates.Configuration.Type>
local static = {} ---@type  { type: string, priority: number, module: Rates.Configuration.Type? }[]

local function sort_static()
    table.sort(static, function(a, b)
        if (a.priority ~= b.priority) then
            return a.priority > b.priority
        else
            return a.type < b.type
        end
    end)
end

---@param types table<any, Rates.Configuration.Type | { types: Rates.Configuration.Type[] }>
---@return Rates.Configuration.Type[]
local function flatten(types)
    local result = {} ---@type Rates.Configuration.Type[]
    for _, entry in pairs(types) do
        if (entry.type) then
            result[#result + 1] = entry
        elseif (entry.types) then
            for _, type in ipairs(entry.types) do
                result[#result + 1] = type
            end
        end
    end
    return result
end

---@param types table<any, Rates.Configuration.Type | { types: Rates.Configuration.Type[] }>
local function register(types)
    for _, type in pairs(flatten(types)) do
        if (registry[type.type]) then
            error("registering duplicate sw-rates module: " .. type.type)
        end
        registry[type.type] = type
        if (script.mod_name == "sw-rates-lib") then
            type.stats = type.stats or {}
            type.stats.priority = type.stats.priority or 0
            static[#static + 1] = { type = type.type, priority = type.stats.priority, module = type }
        end
    end
    if (script.mod_name == "sw-rates-lib") then
        sort_static()
    end
end

if (script.mod_name == "sw-rates-lib") then
    ---@param type string
    ---@param priority number?
    local function register_type(type, priority)
        static[#static + 1] = { type = type, priority = priority or 0 }
        sort_static()
    end

    ---@return string[]
    local function get_types()
        local result = {}
        for _, entry in ipairs(static) do
            result[#result + 1] = entry.type
        end
        return result
    end

    remote.add_interface("sw-rates/configuration", {
        register_type = register_type,
        get_types = get_types
    })
end

---@param type string
---@return Rates.Configuration.Type?
local function get(type)
    return registry[type]
end

---@return { type: string, logic: Rates.Configuration.Type? }[]
local function get_all_types()
    local result = {}
    for _, type in ipairs(remote.call("sw-rates/configuration", "get_types")) do
        result[#result + 1] = { type = type, logic = registry[type] }
    end

    return result
end

return {
    register = register,
    get = get,
    get_all_types = get_all_types
}
