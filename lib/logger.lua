--[[
    Logger module for ComputerCraft by AlexDevs
    (c) 2021 AlexDevs

    Usage:
        -- Load module
        local Logger = require("logger")

        -- Create new Logger instance
        local logger = Logger(name: string, options: table): logger table

        options:
            outputPath: string = nil -- File path to save logs
            dateFormat: string = "%X" -- Date format for os.date
            format: string = "[%date%] <%name%> [%level%] %log%" -- Template for logs
            colored: boolean = true -- Use colored outputs. Uses term.setTextColor
            stdout: function = print -- Function to use to print logs
            enableDebug: boolean = false -- Enable debug logs output

            colors:
                debug: number = colors.gray -- Color for debug logs
                info: number = colors.white -- Color for info logs
                warn: number = colors.yellow -- Color for warn logs
                error: number = colors.red -- Color for error logs
                default: number = info -- Color for custom logs

        Methods:
            logger:debug(...): boolean -- Log debug, returns true if debug logging is enabled, false if otherwise
            logger:info(...): void -- Log information
            logger:warn(...): void -- Log warnings
            logger:error(...): void -- Log errors
            logger:log(level: string, ...): void -- Log with custom level
            logger:open(): void -- Open file handle of output path (open by default is outputPath is used)
            logger:close(): void -- Close file handle of output path (run this after you finished using the logger)
]]
---@class Logger
---@field name string
---@field outputPath string
---@field dateFormat string
---@field format string
---@field colored boolean
---@field stdout function
---@field enableDebug boolean
---@field colors table
local Logger = {}

-- Logger constructor
---@type Logger
---@param name string
---@param o any
---@return Logger
local function new(name, o)
    o = o or {}
    local options = {}
    options.name = name or ""
    options.outputPath = o.outputPath
    options.dateFormat = o.dateFormat or "%X"
    options.format = o.format or "[%date%] <%name%> [%level%] %log%"
    options.colored = o.colored or true

    options.stdout = o.stdout or print
    options.enableDebug = o.enableDebug or false

    o.colors = o.colors or {}
    options.colors = {}
    options.colors.debug = o.colors.debug or colors.gray
    options.colors.info = o.colors.info or colors.white
    options.colors.warn = o.colors.warn or colors.yellow
    options.colors.error = o.colors.error or colors.red
    options.colors.default = o.colors.default or options.colors.info

    local logger = setmetatable(options, {__index = Logger})

    if options.outputPath then
        logger.fileHandle = fs.open(options.outputPath, "a")
    end

    return logger
end

local function formatDate(format)
    return os.date(format)
end

local function format(template, date, name, level, log)
    return template
    :gsub("%%date%%", formatDate(date))
    :gsub("%%name%%", tostring(name))
    :gsub("%%level%%", tostring(level))
    :gsub("%%log%%", tostring(log))
end

local function serialize(...)
    local out = {}
    local args = table.pack(...)
    for i = 1, args.n do
        table.insert(out, tostring(args[i]))
    end

    return table.concat(out, " ")
end

-- Debug log
---@return boolean
function Logger:debug(...)
    if not self.enableDebug then
        return false
    end

    local output = format(self.format, self.dateFormat, tostring(self.name), "DEBUG", serialize(...))

    local oldColor
    if self.colored then
        oldColor = term.getTextColor()
        term.setTextColor(self.colors.debug)
    end

    if self.fileHandle then
        self.fileHandle.write(output .. "\n")
        self.fileHandle.flush()
    end

    self.stdout(output)

    if self.colored then
        term.setTextColor(oldColor)
    end

    return true
end

-- Log info
function Logger:info(...)
    local output = format(self.format, self.dateFormat, tostring(self.name), "INFO", serialize(...))

    local oldColor
    if self.colored then
        oldColor = term.getTextColor()
        term.setTextColor(self.colors.info)
    end

    if self.fileHandle then
        self.fileHandle.write(output .. "\n")
        self.fileHandle.flush()
    end

    self.stdout(output)

    if self.colored then
        term.setTextColor(oldColor)
    end
end

-- Log warnings
function Logger:warn(...)
    local output = format(self.format, self.dateFormat, tostring(self.name), "WARN", serialize(...))

    local oldColor
    if self.colored then
        oldColor = term.getTextColor()
        term.setTextColor(self.colors.warn)
    end

    if self.fileHandle then
        self.fileHandle.write(output .. "\n")
        self.fileHandle.flush()
    end

    self.stdout(output)

    if self.colored then
        term.setTextColor(oldColor)
    end
end

-- Log errors
function Logger:error(...)
    local output = format(self.format, self.dateFormat, tostring(self.name), "ERROR", serialize(...))

    local oldColor
    if self.colored then
        oldColor = term.getTextColor()
        term.setTextColor(self.colors.error)
    end

    if self.fileHandle then
        self.fileHandle.write(output .. "\n")
        self.fileHandle.flush()
    end

    self.stdout(output)

    if self.colored then
        term.setTextColor(oldColor)
    end
end

-- Log info with custom level
---@param label string
function Logger:log(label, ...)
    local output = format(self.format, self.dateFormat, tostring(self.name), tostring(label), serialize(...))

    local oldColor
    if self.colored then
        oldColor = term.getTextColor()
        term.setTextColor(self.colors.default)
    end

    if self.fileHandle then
        self.fileHandle.write(output .. "\n")
        self.fileHandle.flush()
    end

    self.stdout(output)

    if self.colored then
        term.setTextColor(oldColor)
    end
end

-- Open file handle
function Logger:open()
    if not self.fileHandle then
        self.fileHandle = fs.open(self.outputPath, "a")
    end
end

-- Close file handle
function Logger:close()
    if self.fileHandle then
        self.fileHandle.close()
        self.fileHandle = nil
    end
end

return new
