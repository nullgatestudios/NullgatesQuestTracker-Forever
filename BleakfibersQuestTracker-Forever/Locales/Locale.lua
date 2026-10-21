local addonName, ns = ...

--[[---------------------------------------------------------------------------
    Localization Engine & Language Pack Loader

    • Every user-facing string is written in English and looked up through
      ns.L["English text"]. A missing translation falls back to the English key.
    • Language packs live in Locales\<code>.lua and call ns.RegisterLanguagePack.
      External add-ons can ship extra packs through the public API:
          BleakfibersQuestTrackerForever:RegisterLanguagePack(code, name, strings)
    • The active language is chosen in Settings -> General -> Language
      ("Automatic" follows the game client) and is stored account-wide.
-----------------------------------------------------------------------------]]

local type, pairs, ipairs, tostring = type, pairs, ipairs, tostring
local table_sort = table.sort

local packs = {}     -- [code] = { code = code, name = displayName, strings = {} }
local packOrder = {}
local activeStrings = {}
local activeCode = "enUS"
local requestedChoice = "auto"

local L = setmetatable({}, {
    __index = function(_, key)
        local value = activeStrings[key]
        if value == nil or value == true then
            return key
        end
        return value
    end,
    __newindex = function() end,
})
ns.L = L

-- Native language names (always shown in their own language)
ns.LANGUAGE_NAMES = {
    enUS = "English",
    deDE = "Deutsch",
    frFR = "Français",
    esES = "Español (España)",
    esMX = "Español (Latinoamérica)",
    ptBR = "Português (Brasil)",
    itIT = "Italiano",
    ruRU = "Русский",
    koKR = "한국어",
    zhCN = "简体中文",
    zhTW = "繁體中文",
}

-- Game fonts that contain the glyphs each non-Latin language needs.
-- Bundled Latin fonts (Nata Sans, Orbitron, Roboto Condensed) are swapped for
-- these automatically so translated text never renders as empty boxes.
ns.LANGUAGE_FONTS = {
    ruRU = "Fonts\\FRIZQT___CYR.TTF",
    koKR = "Fonts\\2002.TTF",
    zhCN = "Fonts\\ARKai_T.ttf",
    zhTW = "Fonts\\bLEI00D.ttf",
}

local function NormalizeCode(code)
    if code == "enGB" then return "enUS" end
    return code
end

function ns.GetClientLocale()
    return NormalizeCode((GetLocale and GetLocale()) or "enUS")
end

function ns.RegisterLanguagePack(code, displayName, strings)
    if type(code) ~= "string" or code == "" then return false end
    code = NormalizeCode(code)
    local pack = packs[code]
    if not pack then
        pack = { code = code, name = displayName or ns.LANGUAGE_NAMES[code] or code, strings = {} }
        packs[code] = pack
        packOrder[#packOrder + 1] = code
    elseif type(displayName) == "string" and displayName ~= "" then
        pack.name = displayName
    end
    if type(strings) == "table" then
        for key, value in pairs(strings) do
            if type(key) == "string" and type(value) == "string" and value ~= "" then
                pack.strings[key] = value
            end
        end
    end
    -- A pack registered after the language was chosen becomes active immediately
    if code == ns.ResolveLanguage(requestedChoice) then
        activeCode = code
        activeStrings = pack.strings
    end
    return true
end

-- Resolves "auto" / unknown choices into a concrete, installed language code
function ns.ResolveLanguage(choice)
    if not choice or choice == "" or choice == "auto" then
        choice = ns.GetClientLocale()
    end
    choice = NormalizeCode(choice)
    if choice ~= "enUS" and not packs[choice] then
        choice = "enUS"
    end
    return choice
end

function ns.SetLanguage(choice)
    requestedChoice = choice or "auto"
    activeCode = ns.ResolveLanguage(requestedChoice)
    activeStrings = (packs[activeCode] and packs[activeCode].strings) or {}
    return activeCode
end

function ns.GetActiveLanguage()
    return activeCode
end

function ns.HasLanguagePack(code)
    return packs[NormalizeCode(code or "")] ~= nil
end

-- Returns { { key = "auto", label = ... }, { key = "enUS", label = "English" }, ... }
function ns.GetLanguageOptions()
    local list = {}
    for _, code in ipairs(packOrder) do
        if code ~= "enUS" then
            list[#list + 1] = { key = code, label = packs[code].name }
        end
    end
    table_sort(list, function(a, b) return a.label < b.label end)
    table.insert(list, 1, { key = "enUS", label = ns.LANGUAGE_NAMES.enUS })
    local clientName = ns.LANGUAGE_NAMES[ns.GetClientLocale()] or ns.GetClientLocale()
    table.insert(list, 1, { key = "auto", label = L["Automatic (Game Client)"] .. " - " .. tostring(clientName) })
    return list
end

-- Font path override required by the active language (nil for Latin languages)
function ns.GetLanguageFontOverride()
    local override = ns.LANGUAGE_FONTS[activeCode]
    if not override then return nil end
    -- When the game client already runs in this language its default font has the glyphs
    if ns.GetClientLocale() == activeCode and STANDARD_TEXT_FONT then
        return STANDARD_TEXT_FONT
    end
    return override
end

-- Follow the game client until the saved preference is applied at ADDON_LOADED
ns.SetLanguage("auto")
