---@param element LuaGuiElement
---@param name string
---@return LuaGuiElement
local function find_child(element, name)
    local next = {} ---@type LuaGuiElement[]
    next[1] = element
    while (#next > 0) do
        local current = next
        next = {}
        for _, ele in ipairs(current) do
            if (ele.name == name) then
                return ele
            end
            for _, ch in ipairs(ele.children) do
                next[#next + 1] = ch
            end
        end
    end

    error("no child with name " .. name)
end

---@param element LuaGuiElement
---@param name string
---@return LuaGuiElement
local function find_parent(element, name)
    while (element) do
        if (element.name == name) then
            return element
        end

        element = element.parent
    end

    error("no parent with name " .. name)
end

---@param element LuaGuiElement
---@return LuaGuiElement
local function find_top(element)
    local player = game.get_player(element.player_index) ---@cast player -nil
    local screen = player.gui.screen
    while (true) do
        local parent = element.parent
        if (not parent or parent == screen) then
            return element
        end

        element = parent
    end
end

---@param element LuaGuiElement
---@param tag_name string
---@return AnyBasic
local function find_tag(element, tag_name)
    while (element) do
        local tag = element.tags[tag_name]
        if (tag) then
            return tag
        end

        element = element.parent
    end

    error("no tag with name " .. tag_name)
end

return {
    find_child = find_child,
    find_parent = find_parent,
    find_top = find_top,
    find_tag = find_tag,
}
