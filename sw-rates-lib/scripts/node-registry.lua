local registry = {} ---@type table<string, Rates.Node.Type>
local creators = {} ---@type table<string, fun(...): Rates.Node>

---@param types table<any, Rates.Node.Type | { types: Rates.Node.Type[] }>
---@return Rates.Node.Type[]
local function flatten(types)
    local result = {} ---@type Rates.Node.Type[]
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

---@param types table<any, Rates.Node.Type | { types: Rates.Node.Type[] }>
local function register(types)
    for _, type in ipairs(flatten(types)) do
        if (registry[type.type] == nil) then
            registry[type.type] = type
            for k, v in pairs(type.creator or {}) do
                creators[k] = function(...)
                    local result = v(...)
                    if (result.type == nil) then
                        result.type = type.type
                    end
                    if (result.id == nil) then
                        local logic = registry[result.type]
                        local id = logic.get_id and logic.get_id(result)
                        if (id) then
                            id = type.type .. "/" .. id
                        else
                            id = type.type
                        end
                        result.id = id
                    end

                    return result
                end
            end
        end
    end
end

---@param type string
---@return Rates.Node.Type?
local function get(type)
    return registry[type]
end

return {
    register = register,
    flatten = flatten,
    create = creators,
    get = get
}
