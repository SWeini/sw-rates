---@type table<string, string>
local quality_chain = {}
---@type table<string, integer>
local quality_index = {}

for name, quality in pairs(prototypes.quality) do
    local index = 0
    local q = quality
    while (q.previous) do
        index = index + 1
        q = q.previous
    end

    quality_chain[name] = q.name
    quality_index[name] = index
end

---@param quality LuaQualityPrototype
---@param min LuaQualityPrototype?
---@param max LuaQualityPrototype?
---@param change int8?
---@return LuaQualityPrototype
local function apply_quality_adjustments(quality, min, max, change)
    if (min) then
        ---@cast max -nil
        if (quality_chain[min.name] ~= quality_chain[quality.name]) then
            return min
        end
    end

    if (change) then
        if (change > 0) then
            for i = 1, change do
                local next = quality.next
                if (not next) then
                    break
                end
                quality = next
            end
        elseif (change < 0) then
            for i = 1, -change do
                local previous = quality.previous
                if (not previous) then
                    break
                end
                quality = previous
            end
        end
    end

    local index = quality_index[quality.name]

    if (min) then
        if (index < quality_index[min.name]) then
            return min
        end
        if (index > quality_index[max.name]) then
            return max
        end
    end

    return quality
end

---@param quality Rates.Internal.QualityDistribution
---@param min LuaQualityPrototype?
---@param max LuaQualityPrototype?
---@param change int8?
---@return Rates.Internal.QualityDistribution
local function apply_quality_adjustments_to_distribution(quality, min, max, change)
    local result = {} ---@type table<string, { quality: LuaQualityPrototype, multiplier: number }>
    for _, data in ipairs(quality) do
        local q = apply_quality_adjustments(data.quality, min, max, change)
        local entry = result[q.name]
        if (entry) then
            entry.multiplier = entry.multiplier + data.multiplier
        else
            entry = { quality = q, multiplier = data.multiplier }
            result[q.name] = entry
        end
    end

    local table = {} ---@type Rates.Internal.QualityDistribution
    for _, value in pairs(result) do
        table[#table + 1] = value
    end

    if (#table == 1) then
        table[1].multiplier = 1
    end

    return table
end

return {
    apply_quality_adjustments = apply_quality_adjustments,
    apply_quality_adjustments_to_distribution = apply_quality_adjustments_to_distribution
}
