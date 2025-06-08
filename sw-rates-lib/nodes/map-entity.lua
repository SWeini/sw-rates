do
    --- An entity on the map. Most importantly used for resources.
    ---@class (exact) Rates.Node.MapEntity : Rates.Node.Base
    ---@field type "map-entity"
    ---@field entity LuaEntityPrototype
    ---@field quality LuaQualityPrototype
end

local creator = {} ---@class Rates.Node.Creator
local result = { type = "map-entity", creator = creator } ---@type Rates.Node.Type

---@param entity LuaEntityPrototype
---@param quality LuaQualityPrototype
---@return Rates.Node.MapEntity
creator.map_entity = function(entity, quality)
    return {
        entity = entity,
        quality = quality
    }
end

---@param node Rates.Node.MapEntity
result.get_id = function(node)
    return node.entity.name .. "(" .. node.quality.name .. ")"
end

---@param node Rates.Node.MapEntity
result.gui_default = function(node)
    return { sprite = "entity/" .. node.entity.name, quality = node.quality }
end

return result
