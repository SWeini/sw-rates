local progression = require("scripts.progression")

local logic = { type = "ammo" } ---@type Rates.Configuration.Type

---@param effect? TriggerEffectItem | TriggerEffectItem[]
---@return LuaEntityPrototype?
local function get_capture_robot_trigger_effect(effect)
    if (not effect) then
        return
    end

    if (not effect.type) then
        for _, eff in ipairs(effect) do
            local result = get_capture_robot_trigger_effect(eff)
            if (result) then
                return result
            end
        end

        return
    end

    if (effect.type == "create-entity") then
        local entity = prototypes.entity[effect.entity_name]
        if (entity and entity.type == "capture-robot") then
            return entity
        end
    end
end

---@param delivery? TriggerDelivery | TriggerDelivery[]
---@return LuaEntityPrototype?
local function get_capture_robot_trigger_delivery(delivery)
    if (not delivery) then
        return
    end

    if (not delivery.type) then
        for _, del in ipairs(delivery) do
            local result = get_capture_robot_trigger_delivery(del)
            if (result) then
                return result
            end
        end

        return
    end

    if (delivery.type == "projectile" and delivery.projectile) then
        local projectile = prototypes.entity[delivery.projectile]
        return get_capture_robot_trigger_item(projectile.attack_result)
    elseif (delivery.type == "instant") then
        local result = get_capture_robot_trigger_effect(delivery.target_effects)
        if (result) then
            return result
        end
    end
end

---@param trigger? TriggerItem | TriggerItem[]
---@return LuaEntityPrototype?
function get_capture_robot_trigger_item(trigger)
    if (not trigger) then
        return
    end

    if (not trigger.type) then
        for _, trig in ipairs(trigger) do
            local result = get_capture_robot_trigger_item(trig)
            if (result) then
                return result
            end
        end

        return
    end

    if (trigger.type == "direct") then
        return get_capture_robot_trigger_delivery(trigger.action_delivery)
    end
end

logic.fill_progression = function(result, options)
    for _, item in pairs(prototypes.get_item_filtered { { filter = "type", type = "ammo" } }) do
        local category = item.ammo_category.name
        local ammo_type = item.get_ammo_type("default")
        if (ammo_type and ammo_type.target_type == "entity") then
            local capture_robot = get_capture_robot_trigger_item(ammo_type.action)
            if (capture_robot) then
                local id = "ammo/" .. item.name .. "/*"
                result[id] = {
                    pre = {
                        progression.create.item(item.name, "*"),
                        progression.create.ammo(category, "*")
                    },
                    post = {
                        progression.create.map_entity(capture_robot.name, "*")
                    },
                    multi = options.locations
                }
            end
        end
    end
end

return logic
