return {
    id = "dummy_0", -- Unique ID of the device
    role = "dummy", -- Role of the device (will resolve to modules/<role>.lua)
    label = "Dummy", -- Friendly name for our device :)

    modemSide = "auto", -- side of the modem or "auto"
    debug = false, -- Debug logging

    -- A SmartNet network has to match both token and channel
    token = "123", -- Network Token
    channel = 1, -- Network Channel

    module = { -- Module related config

    },
}