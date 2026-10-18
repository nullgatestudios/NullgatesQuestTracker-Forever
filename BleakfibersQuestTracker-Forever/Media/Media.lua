local addonName, ns = ...

local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)

local mediaPath = "Interface\\AddOns\\" .. addonName .. "\\Media\\"
local fontPath = mediaPath .. "Fonts\\"

-- Default Font Constants
ns.DEFAULT_FONT_NAME = "Nata Sans Bold"
ns.DEFAULT_FONT_PATH = fontPath .. "NataSans-Bold.ttf"

ns.DEFAULT_HEADER_FONT_NAME = "Nata Sans Bold"
ns.DEFAULT_HEADER_FONT_PATH = fontPath .. "NataSans-Bold.ttf"

ns.DEFAULT_OBJECTIVE_FONT_NAME = "Nata Sans Regular"
ns.DEFAULT_OBJECTIVE_FONT_PATH = fontPath .. "NataSans-Regular.ttf"

if LSM then
    -- Register Nata Sans Family (Default ADA Compliant / High Legibility)
    LSM:Register("font", "Nata Sans Bold", fontPath .. "NataSans-Bold.ttf")
    LSM:Register("font", "Nata Sans Regular", fontPath .. "NataSans-Regular.ttf")
    LSM:Register("font", "Nata Sans", fontPath .. "NataSans-Regular.ttf")
    LSM:Register("font", "Nata Sans Medium", fontPath .. "NataSans-Medium.ttf")

    -- Register Orbitron Family (Futuristic / Geometric Display)
    LSM:Register("font", "Orbitron Bold", fontPath .. "Orbitron-Bold.ttf")
    LSM:Register("font", "Orbitron Medium", fontPath .. "Orbitron-Medium.ttf")
    LSM:Register("font", "Orbitron Regular", fontPath .. "Orbitron-Regular.ttf")
    LSM:Register("font", "Orbitron", fontPath .. "Orbitron-Regular.ttf")

    -- Register Roboto Condensed Family (Clean / Compact Sans-Serif)
    LSM:Register("font", "Roboto Condensed Bold", fontPath .. "RobotoCondensed-Bold.ttf")
    LSM:Register("font", "Roboto Condensed Medium", fontPath .. "RobotoCondensed-Medium.ttf")
    LSM:Register("font", "Roboto Condensed Regular", fontPath .. "RobotoCondensed-Regular.ttf")
    LSM:Register("font", "Roboto Condensed", fontPath .. "RobotoCondensed-Regular.ttf")

    -- Register Status Bar Textures
    LSM:Register("statusbar", "BleakFlat", "Interface\\Buttons\\WHITE8x8")
    LSM:Register("statusbar", "Blizzard", "Interface\\TargetingFrame\\UI-StatusBar")
    LSM:Register("statusbar", "Blizzard Raid", "Interface\\RaidFrame\\Raid-Bar-Hp-Fill")

    -- Register Custom Audio Files
    local soundPath = mediaPath .. "Sounds\\"
    LSM:Register("sound", "Bleakfiber Beep", soundPath .. "beep.wav")
    LSM:Register("sound", "Bleakfiber Click", soundPath .. "click.wav")
end

local soundPath = mediaPath .. "Sounds\\"
local customSoundSlots = {
    ["beep"] = soundPath .. "beep.wav",
    ["click"] = soundPath .. "click.wav",
    ["custom_beep"] = soundPath .. "beep.wav",
    ["Bleakfiber Beep"] = soundPath .. "beep.wav",
    ["Bleakfiber Click"] = soundPath .. "click.wav",
}
ns.customSoundSlots = customSoundSlots

-- Custom Sounds Management (supports arbitrary filenames like "fart.wav", "cheer.wav", etc.)
-- Reads both Media\CustomSounds.lua (BleakfiberCustomSounds table) and DB profile (db.sound.customSoundsList)
function ns.GetCustomSoundList(onlyDB)
    local list = {}
    local seen = {}

    -- 1. From Media\CustomSounds.lua (BleakfiberCustomSounds table)
    if not onlyDB and type(BleakfiberCustomSounds) == "table" then
        for _, entry in ipairs(BleakfiberCustomSounds) do
            local file = type(entry) == "table" and entry.file or entry
            if type(file) == "string" and file:match("%S") then
                file = file:gsub("^.*[\\/]", "") -- strip any path
                if not file:find("%.[wW][aA][vV]$") and not file:find("%.[oO][gG][gG]$") and not file:find("%.[mM][pP]3$") then
                    file = file .. ".wav"
                end
                local lower = file:lower()
                if not seen[lower] then
                    seen[lower] = true
                    local idx = #list + 1
                    table.insert(list, {
                        key = "custom:" .. file,
                        file = file,
                        label = "Custom " .. idx .. " (" .. file .. ")",
                        index = idx,
                        origin = "file",
                    })
                end
            end
        end
    end

    -- 2. From SavedVariables DB (ns.db.sound.customSoundsList)
    local sdb = (ns.dbObject and ns.dbObject.profile and ns.dbObject.profile.sound) or (ns.db and ns.db.sound)
    if sdb and type(sdb.customSoundsList) == "table" then
        for _, entry in ipairs(sdb.customSoundsList) do
            local file = type(entry) == "table" and entry.file or entry
            if type(file) == "string" and file:match("%S") then
                file = file:gsub("^.*[\\/]", "") -- strip any path
                if not file:find("%.[wW][aA][vV]$") and not file:find("%.[oO][gG][gG]$") and not file:find("%.[mM][pP]3$") then
                    file = file .. ".wav"
                end
                local lower = file:lower()
                if not seen[lower] then
                    seen[lower] = true
                    local idx = #list + 1
                    table.insert(list, {
                        key = "custom:" .. file,
                        file = file,
                        label = "Custom " .. idx .. " (" .. file .. ")",
                        index = idx,
                        origin = "db",
                    })
                end
            end
        end
    end

    return list
end

function ns.AddCustomSound(filename)
    if not filename or type(filename) ~= "string" then return false, "Invalid filename" end
    filename = filename:match("^%s*(.-)%s*$") -- trim
    filename = filename:gsub("^.*[\\/]", "") -- strip any path
    if filename == "" then return false, "Filename cannot be empty" end
    if not filename:find("%.[wW][aA][vV]$") and not filename:find("%.[oO][gG][gG]$") and not filename:find("%.[mM][pP]3$") then
        filename = filename .. ".wav"
    end

    local sdb = (ns.dbObject and ns.dbObject.profile and ns.dbObject.profile.sound) or (ns.db and ns.db.sound)
    if not sdb then return false, "Sound database not loaded" end
    sdb.customSoundsList = sdb.customSoundsList or {}

    local lower = filename:lower()
    for _, existing in ipairs(sdb.customSoundsList) do
        local ef = (type(existing) == "table" and existing.file or existing):lower()
        if ef == lower then
            return false, "Sound file already registered"
        end
    end

    table.insert(sdb.customSoundsList, filename)
    if ns.FlushDBToGlobals then ns.FlushDBToGlobals() end

    -- Register in LSM if available
    local lsm = LSM or (LibStub and LibStub("LibSharedMedia-3.0", true))
    if lsm and lsm.Register then
        pcall(lsm.Register, lsm, "sound", "Bleakfiber " .. filename, soundPath .. filename)
    end

    return true, filename
end

function ns.RemoveCustomSound(filename)
    if not filename then return false end
    local sdb = (ns.dbObject and ns.dbObject.profile and ns.dbObject.profile.sound) or (ns.db and ns.db.sound)
    if not sdb or not sdb.customSoundsList then return false end

    local lower = filename:lower()
    for i = #sdb.customSoundsList, 1, -1 do
        local ef = (type(sdb.customSoundsList[i]) == "table" and sdb.customSoundsList[i].file or sdb.customSoundsList[i]):lower()
        if ef == lower then
            table.remove(sdb.customSoundsList, i)
        end
    end

    -- Reset sound choices if they were pointing to this removed sound
    if sdb.soundChoice == "custom:" .. filename or sdb.soundChoice == filename then
        sdb.soundChoice = "peon"
    end
    if sdb.objectiveSoundChoice == "custom:" .. filename or sdb.objectiveSoundChoice == filename then
        sdb.objectiveSoundChoice = "whisper_ping"
    end

    if ns.FlushDBToGlobals then ns.FlushDBToGlobals() end
    return true
end

function ns.FetchSound(soundKey)
    if not soundKey or soundKey == "" then return nil end

    -- 1. Explicit custom file prefix: custom:fart.wav
    local customFile = type(soundKey) == "string" and soundKey:match("^custom:(.+)$")
    if customFile then
        if not customFile:find("%.[wW][aA][vV]$") and not customFile:find("%.[oO][gG][gG]$") and not customFile:find("%.[mM][pP]3$") then
            customFile = customFile .. ".wav"
        end
        return soundPath .. customFile
    end

    -- 2. Legacy custom numeric slot: custom1..custom99
    local num = type(soundKey) == "string" and soundKey:match("^custom(%d+)$")
    if num then
        local n = tonumber(num)
        local customList = ns.GetCustomSoundList and ns.GetCustomSoundList()
        if customList and customList[n] then
            return soundPath .. customList[n].file
        end
        return soundPath .. "custom" .. num .. ".wav"
    end

    -- 3. Preset slot aliases
    if customSoundSlots and customSoundSlots[soundKey] then
        return customSoundSlots[soundKey]
    end

    -- 4. Direct sound filename or full path
    if type(soundKey) == "string" and (soundKey:find("%.[wW][aA][vV]$") or soundKey:find("%.[oO][gG][gG]$") or soundKey:find("%.[mM][pP]3$")) then
        if soundKey:find("\\") or soundKey:find("/") then
            return soundKey
        else
            return soundPath .. soundKey
        end
    end

    -- 5. LibSharedMedia lookup
    local lsm = LSM or (LibStub and LibStub("LibSharedMedia-3.0", true))
    if lsm and lsm.Fetch then
        local snd = lsm:Fetch("sound", soundKey, true)
        if snd and snd ~= "" then
            return snd
        end
    end

    return soundKey
end

-- Media Fetch Helper with safety fallbacks
function ns.FetchFont(fontName)
    local fallback = ns.DEFAULT_FONT_PATH
    if not fontName or fontName == "" then
        fontName = ns.DEFAULT_FONT_NAME
    end

    -- Direct file path support
    if type(fontName) == "string" and (fontName:find("%.ttf$") or fontName:find("%.otf$") or fontName:find("\\") or fontName:find("/")) then
        return fontName
    end

    -- Blizzard standard game font alias
    if fontName == "Friz Quadrata TT" or fontName == "Friz" then
        return STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
    end

    if LSM then
        local font = LSM:Fetch("font", fontName, true)
        if font and font ~= "" then
            return font
        end

        local def = LSM:Fetch("font", ns.DEFAULT_FONT_NAME, true)
        if def and def ~= "" then
            return def
        end
    end

    return fallback
end

-- Listen for late-registering media from third-party addons (SharedMedia packs, ElvUI, Details)
if LSM and LSM.RegisterCallback then
    LSM.RegisterCallback(ns, "LibSharedMedia_Registered", function(_, mediatype, key)
        if mediatype == "font" and ns.Tracker and ns.Tracker.UpdateTypography then
            ns.Tracker:UpdateTypography()
        end
    end)
end
