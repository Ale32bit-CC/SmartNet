--[[
    Dummy module
    Config: 
        outputSide: string -- Redstone output side
]]

local device, config
local status = false

local function init(dev)
    device = dev
    config = device.config

    return {
        setter = "boolean", -- type of value for setting values remotely, nil otherwise
        getter = "boolean", -- type of value for getting values remotely, nil otherwise
    }
end

local function get() -- optional get request
    return status
end

local function set(v) -- optional set request
    status = v
    rs.setOutput(config.module.outputSide, status)
end

local function run() -- optional parallel function for arbitrary code

end

return {
    init = init,
    get = get,
    set = set,
    run = run,
}