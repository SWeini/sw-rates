do
    --- An item of specific quality.
    ---@class (exact) Rates.Node.AsteroidChunk : Rates.Node.Base
    ---@field type "asteroid-chunk"
    ---@field asteroid LuaAsteroidChunkPrototype
end

local creator = {} ---@class Rates.Node.Creator
local result = { type = "asteroid-chunk", creator = creator } ---@type Rates.Node.Type

---@param asteroid LuaAsteroidChunkPrototype
---@return Rates.Node.AsteroidChunk
creator.asteroid_chunk = function(asteroid)
    return {
        asteroid = asteroid
    }
end

---@param node Rates.Node.AsteroidChunk
result.get_id = function(node)
    return node.asteroid.name
end

---@param node Rates.Node.AsteroidChunk
result.gui_default = function(node)
    ---@type Rates.Gui.NodeDescription
    return {
        element = { type = "asteroid-chunk", name = node.asteroid.name },
    }
end

return result
