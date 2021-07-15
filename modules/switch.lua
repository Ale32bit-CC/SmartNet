--[[
    Button module
    Config:
        inputSide: string -- Side of redstone input
        targets: {id1, id2, ...} -- Targetted devices to control. * is all devices that support boolean input
]]

local device, config
local status = false

local function broadcastSet(val)
    for k, v in ipairs(config.module.targets) do
        device.set(v, val)
    end
end

local function switch()
    status = not status
    broadcastSet(status)
end

local function init(dev)
    device = dev
    config = device.config

    return {
        setter = "boolean",
        getter = "boolean",
    }
end

local function get() -- optional get request
    return status
end

local function set(v) -- optional set request
    status = not v
    switch()
end

local function run() -- optional parallel function for arbitrary code
    while true do
        os.pullEvent("redstone")
        if rs.getInput(config.module.inputSide) then
            switch()
        end
    end
end

return {
    init = init,
    get = get,
    set = set,
    run = run,
}