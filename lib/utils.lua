local function enum(t)
    local out = {}

    for k, v in ipairs(t) do
        out[k] = v
        out[v] = k
    end

    return out
end

local function getEnum(e, v)
    if type(v) == "number" then
        return v
    else
        return e[v]
    end
end

return {
    enum = enum,
    getEnum = getEnum,
}