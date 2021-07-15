-- https://api.github.com/repos/Ale32bit-CC/SmartNet/git/trees/main?recursive=1

print("SmartNet by AlexDevs")

local date
if fs.exists("config.lua") then
    print("Existing config.lua found. Overwrite? [y/N]")
    local ans = read()
    if ans:lower():sub(1,1) ~= "y" then
        date = os.date("%Y%m%d%H%M%S")
        fs.move("config.lua", date .. ".config.lua")
    end
end

print("Fetching files list...")
local h, err = http.get("https://api.github.com/repos/Ale32bit-CC/SmartNet/git/trees/main?recursive=1")
if not h then
    printError(err)
    return false
end

local files = textutils.unserialiseJSON(h.readAll())
h.close()

print("Downloading files...")

for k, v in ipairs(files.tree) do
    if v.type == "blob" then
        print("Downloading " .. v.path)
        local h, err = http.get("https://raw.githubusercontent.com/Ale32bit-CC/SmartNet/main/" .. v.path)
        if h then
            local content = h.readAll()
            h.close()
            local f = fs.open(v.path, "w")
            f.write(content)
            f.close()
        else
            printError(err)
        end
    elseif v.type == "tree" then
        print("Creating directory " .. v.path)
        fs.makeDir(v.path)
    end
end

if date then
    print("Restoring config...")
    fs.delete("config.lua")
    fs.copy(date .. ".config.lua", "config.lua")
    print("Reboot to apply update")
else
    print("Edit config.lua and reboot to apply")
end
