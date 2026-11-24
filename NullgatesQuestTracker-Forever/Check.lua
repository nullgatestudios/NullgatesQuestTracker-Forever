local _, ns = ...

--[[---------------------------------------------------------------------------
    /nqt check: a short self test. Its report opens in the report window every
    Nullgate addon shares (NullgateReport.lua), ready to copy and paste into
    the report form on our website. The last report is also saved in
    NullgatesQuestTrackerDB.global.check.
-----------------------------------------------------------------------------]]

local Check = {}
ns.Check = Check

local SLUG = "quest-tracker"
local log = {}

local function Log(text)
    log[#log + 1] = tostring(text)
    if NullgateReport then NullgateReport.Update(SLUG) end
end
Check.Log = Log

local function Exists(path)
    local value = _G
    for part in path:gmatch("[^.]+") do
        if type(value) ~= "table" then return false end
        value = value[part]
    end
    return type(value) == "function"
end

-- Calls a client function that may be missing or may fail; returns its first result or nil.
local function Try(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, result = pcall(fn, ...)
    if ok then return result end
end

function Check.ShowReport()
    local L = ns.L
    return NullgateReport.Show({
        slug = SLUG, name = "Nullgate's Quest Tracker", addon = "NullgatesQuestTracker-Forever", command = "/nqt check",
        lines = log,
        title = L["Bug report"], selectAll = L["Select all"], selectLink = L["Select link"],
        help = L["Press Ctrl+C to copy this report, then paste it into a new report at the link below, with a few words on what happened."],
    })
end

function Check.Run()
    for i = #log, 1, -1 do log[i] = nil end
    local _, class = UnitClass("player")
    local client, build, _, interface = "?", "?", nil, "?"
    if GetBuildInfo then client, build, _, interface = GetBuildInfo() end
    Log(string.format("client %s, build %s, interface %s; class %s, level %s",
        tostring(client), tostring(build), tostring(interface), tostring(class), tostring(UnitLevel("player"))))

    local profile = ns.dbObject and Try(ns.dbObject.GetCurrentProfile, ns.dbObject)
    Log(string.format("language %s, profile %s, chat output %s", tostring(ns.GetActiveLanguage and ns.GetActiveLanguage()),
        tostring(profile), tostring(ns.IsChatOutputEnabled and ns.IsChatOutputEnabled())))

    local calls = {}
    for _, name in ipairs({ "C_QuestLog.GetInfo", "C_QuestLog.GetNumQuestLogEntries", "C_QuestLog.GetQuestObjectives",
        "C_QuestLog.IsQuestFlaggedCompleted", "GetQuestLogTitle", "C_Map.GetBestMapForUnit", "C_Map.GetPlayerMapPosition",
        "C_Map.SetUserWaypoint", "C_SuperTrack.SetSuperTrackedUserWaypoint", "C_ChatInfo.SendAddonMessage" }) do
        calls[#calls + 1] = name .. "=" .. (Exists(name) and "yes" or "no")
    end
    Log("calls: " .. table.concat(calls, " "))

    local entries = C_QuestLog and Try(C_QuestLog.GetNumQuestLogEntries)
    if entries == nil then entries = Try(GetNumQuestLogEntries) end
    local mapID = C_Map and Try(C_Map.GetBestMapForUnit, "player")
    Log(string.format("quest log entries %s; active quest %s; map %s (%s)", tostring(entries), tostring(ns.activeQuestID),
        tostring(mapID), tostring(GetRealZoneText and GetRealZoneText())))

    local blocks = 0
    if ns.StandaloneTracker and ns.StandaloneTracker.activeBlocks then
        for _ in pairs(ns.StandaloneTracker.activeBlocks) do blocks = blocks + 1 end
    end
    Log(string.format("quests shown in the tracker: %d", blocks))

    if ns.dbObject and ns.dbObject.global then
        local saved = {}
        for i, line in ipairs(log) do saved[i] = line end
        ns.dbObject.global.check = saved
    end
    Check.ShowReport()
end
