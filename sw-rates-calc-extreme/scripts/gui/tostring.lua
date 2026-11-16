local tostring = {}

---@param ticks uint32
---@return string
function tostring.ticks_to_time(ticks)
    local result = ""
    local t = ticks
    local s = math.floor(t / 60)
    local m = math.floor(s / 60)
    s = s - m * 60
    local h = math.floor(m / 60)
    m = m - h * 60
    result = (h > 0 and h .. "h" or "") .. (m > 0 and m .. "m" or "") .. (s > 0 and s .. "s" or "")
    if (result == 0) then
        result = ticks .. " ticks"
    end

    return result
end

return tostring
