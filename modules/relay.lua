--[[
    Dummy module
    Config: 
        outputSide: string -- Redstone output side
]]

local device, config, logger
local status = false

local function saveState()
    local f = fs.open(".relay.state", "w")
    f.write(textutils.serialise(status))
    f.close()
end

local function loadState()
    if fs.exists(".relay.state") then
        local f = fs.open(".relay.state", "r")
        local c = f.readAll()
        f.close()
        
        local v = textutils.unserialise(c)
        if type(v) == "boolean" then
            status = v
        end
    end
end

local function init(dev)
    device = dev
    config = device.config
    logger = device.logger

    loadState()

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
    logger:debug("Switching redstone " .. (status and "on" or "off")) -- status ? "on" : "off"
    rs.setOutput(config.module.outputSide, status)
    saveState()
end

local function run() -- optional parallel function for arbitrary code

end

return {
    init = init,
    get = get,
    set = set,
    run = run,
}