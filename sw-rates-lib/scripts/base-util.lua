---@param entity LuaEntity
---@return string
local function get_entity_type(entity)
    local type = entity.type
    if (type == "entity-ghost") then
        return entity.ghost_type
    end

    return type
end

---@param entity LuaEntity
---@return string
local function get_entity_name(entity)
    if (entity.type == "entity-ghost") then
        return entity.ghost_name
    else
        local upgrade_prototype = entity.get_upgrade_target()
        return upgrade_prototype and upgrade_prototype.name or entity.name
    end
end

---@param entity LuaEntity
---@return LuaEntityPrototype
local function get_entity_prototype(entity)
    if (entity.type == "entity-ghost") then
        return entity.ghost_prototype --[[@as LuaEntityPrototype]]
    else
        local upgrade_prototype = entity.get_upgrade_target()
        return upgrade_prototype or entity.prototype
    end
end

return {
    get_entity_type = get_entity_type,
    get_entity_name = get_entity_name,
    get_entity_prototype = get_entity_prototype
}
