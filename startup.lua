local VERSION = "1.1"

local config = require("config")

local chacha20 = require("lib.chacha20")
local sha256 = require("lib.sha256")
local Logger = require("lib.logger")
local utils = require("lib.utils")
local enum = utils.enum

local OP = enum {
    "PING", -- normal pings
    "DISCOVER_REQUEST", -- when a device requests a discover
    "DISCOVER", -- let people know you exist
    "GET", -- a device asked for your value
    "SET", -- a device wants to set you a value
    "RESPONSE", -- a device answered your get request
    "MODULE", -- generic message for custom stuff
    "COLLISION", -- in case you forgot to change ids when copying configs
    "COLLISION_ACK"
}

local logger = Logger(
    config.id,
    {
        format = "[%date%][%level%] %log%",
        enableDebug = config.debug
    }
)

local devices = {}

-- Make the UI
local w, h = term.getSize()
term.setBackgroundColor(colors.black)
term.setTextColor(colors.white)
term.clear()

local mainWindow = window.create(term.current(), 1, 2, w, h - 1, true)
local nTerm = term.redirect(mainWindow)
local function redrawBar()
    nTerm.setBackgroundColor(colors.white)
    nTerm.setTextColor(colors.black)
    nTerm.setCursorPos(1, 1)
    nTerm.clearLine()
    nTerm.write("SmartNet " .. VERSION)

    local rightText = string.format("%s (%s)", config.label, config.id)
    nTerm.setCursorPos(w - #rightText + 1, 1)
    nTerm.write(rightText)
end
redrawBar()

logger:info("Welcome to SmartNet v" .. VERSION)
logger:info("(c) 2021 AlexDevs")
logger:info(config.label, "ID is", config.id)
logger:info("Role is set to", config.role)

local module
local ok, par = pcall(require, "modules." .. config.role)
if ok then
    module = par
else
    logger:error(par)
    return
end

local modem
if config.modemSide == "auto" then
    modem = peripheral.find("modem")
else
    modem = peripheral.wrap(config.modemSide)
end

if not modem then
    logger:error("Modem not found")
    return
end

modem.open(config.channel)

local function get_key(token)
    token = tostring(sha256.digest(token))
    return { string.byte(token, 1, -1) }
end

local function gen_nonce()
    local n = {}
    for i = 1, 12 do n[#n+1] = math.random(0, 255) end
    return n
end

local function encrypt(data)
    local nonce = gen_nonce()
    local ctx = chacha20.crypt(data, get_key(config.token), nonce)
    return ctx, nonce
end

local function decrypt(data, nonce)
    return chacha20.crypt(data, get_key(config.token), nonce)
end

local function packMessage(msg, nonce)
    -- nonce is always 12 bytes
    return string.char(unpack(nonce)) .. string.char(unpack(msg))
end

local function unpackMessage(data)
    local nonce = string.sub(data, 1, 12)
    local msg = string.sub(data, 13, -1)

    return {
        nonce = {string.byte(nonce, 1, -1)},
        data = {string.byte(msg, 1, -1)}
    }
end

local function send(op, data)
    data._nonce = os.date() .. os.time()
    data.computerId = os.getComputerID()
    data.id = config.id

    local sData = textutils.serialise(data)
    sData, nonce = encrypt(sData)
    modem.transmit(config.channel, utils.getEnum(OP, op), packMessage(sData, nonce))
end

local function broadcastDiscover()
    logger:debug("Broadcasting discovery")
    send(
        OP.DISCOVER,
        {
            data = {
                id = config.id,
                role = config.role,
                label = config.label,
                setup = config.setup,
                version = VERSION
            }
        }
    )
end

local function requestDiscover()
    logger:debug("Requesting discovery")
    send(
        OP.DISCOVER_REQUEST,
        {
            data = {
                id = config.id,
                role = config.role,
                label = config.label
            }
        }
    )
end

local function ping()
    send(
        OP.PING,
        {
            time = os.epoch("utc")
        }
    )
end

local function request(id)
    logger:debug("Requesting to ", id)
    local nonce = os.epoch("utc")
    send(
        OP.GET,
        {
            target = id,
            nonce = nonce
        }
    )

    local _, rNonce, value
    repeat
        _, rNonce, value = os.pullEvent("smart_response")
    until rNonce == nonce
end

local function get(data)
    if (data.target ~= "*" and data.target ~= config.id) then
        return
    end
    logger:debug(data.id, "getter")
    local nonce = data.nonce
    if module.get and config.setup.getter then
        local value = module.get()
        send(
            OP.RESPONSE,
            {
                target = data.id,
                nonce = nonce,
                value = value,
                valueType = config.setup.getter,
                ok = true
            }
        )
    else
        send(
            OP.RESPONSE,
            {
                target = data.id,
                nonce = nonce,
                ok = false
            }
        )
    end
end

local function set(data)
    if (data.target == "*" or data.target == config.id) and config.setup.setter and module.set then
        if type(data.value) == config.setup.setter or config.setup.setter == "*" then
            logger:debug(data.id, "setter")
            module.set(data.value)
        end
    end
end

local function setInDevice(target, value)
    send(
        OP.SET,
        {
            target = target,
            value = value
        }
    )
end

local luck = 0
local nLuck = 0
local randomLuck = false

local function resolveCollision(id)
    luck = randomLuck and math.random(0, 0xffff) or os.clock()
    logger:warn("ID Collision with computer #" .. tostring(id) .. ".", "My luck is", luck)
    if nLuck > 5 then
        logger:error("Stalemate")
        error(nil, 0)
    end
    send(
        OP.COLLISION,
        {
            luck = luck
        }
    )
end

config.setup =
    module.init(
    {
        logger = logger,
        config = config,
        send = send,
        set = setInDevice,
        get = request,
        devices = devices
    }
)

-- It is polite to introduce yourself
broadcastDiscover()

sleep(0.1)
-- But you also want to know who the others are
requestDiscover()

parallel.waitForAll(
    function()
        while true do
            local ev = {os.pullEventRaw()}
            if ev[1] == "modem_message" then
                if ev[3] == config.channel then
                    if type(ev[5]) == "string" then
                        local nonce = os.date() .. os.time()
                        local unpacked = unpackMessage(ev[5])
                        local sData = decrypt(unpacked.data, unpacked.nonce)
                        if sData then
                            local data = textutils.unserialise(string.char(unpack(sData)))

                            if type(data) == "table" and data._nonce == nonce and type(data.id) == "string" then
                                if ev[4] == OP.PING then
                                    logger:debug("PONG from", data.id)

                                    if data.id == config.id then
                                        resolveCollision(data.computerId)
                                    end

                                    if devices[data.id] then
                                        devices[data.id].lastPing = data.time
                                    else
                                        -- Just in case, every device should introduce themselves upon request
                                        logger:debug("Couldn't find", data.id, "from ping")
                                        requestDiscover()
                                    end

                                    if module.ping then
                                        module.ping(data.id)
                                    end
                                elseif ev[4] == OP.DISCOVER then
                                    logger:debug("Discovered", data.id)
                                    if data.id == config.id then
                                        resolveCollision(data.computerId)
                                    end
                                    devices[data.id] = data.data
                                elseif ev[4] == OP.DISCOVER_REQUEST then
                                    broadcastDiscover()
                                elseif ev[4] == OP.GET then
                                    get(data)
                                elseif ev[4] == OP.SET then
                                    set(data)
                                elseif ev[4] == OP.RESPONSE then
                                    os.queueEvent("smart_response", data.nonce, data.value)
                                elseif ev[4] == OP.MODULE then
                                    if module.request and (data.target == config.id or data.target == "*") then
                                        logger:debug("Received raw request")
                                        module.request(data)
                                    end
                                elseif ev[4] == OP.COLLISION then
                                    if data.id == config.id then
                                        nLuck = nLuck + 1
                                        send(
                                            OP.COLLISION_ACK,
                                            {
                                                luck = luck
                                            }
                                        )
                                        if luck < data.luck then
                                            logger:warn("Collision resolved! I lost")
                                            nLuck = 0
                                            config.id = config.id .. tostring(luck)
                                            redrawBar()
                                        elseif luck > data.luck then
                                            logger:warn("Collision resolved! I won")
                                            nLuck = 0
                                        else -- oh no
                                            randomLuck = true
                                            logger:warn("Retrying attempt", nLuck)
                                            resolveCollision(data.computerId)
                                        end
                                    end
                                elseif ev[4] == OP.COLLISION_ACK then
                                    if data.id == config.id then
                                        logger:warn("Collider luck is", data.luck)
                                    end
                                end
                            end
                        end
                    end
                end
            elseif ev[1] == "terminate" then
                term.redirect(nTerm)

                term.setBackgroundColor(colors.black)
                term.setTextColor(colors.white)
                term.clear()
                term.setCursorPos(1, 1)
                print("Exited from SmartNet")
            end
        end
    end,
    function()
        if module.run then
            module.run()
        end
    end,
    function()
        while true do
            ping()
            sleep(10)
        end
    end
)
