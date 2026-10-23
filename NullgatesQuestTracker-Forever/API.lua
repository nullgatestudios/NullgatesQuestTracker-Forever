local addonName, ns = ...

--[[---------------------------------------------------------------------------
    API Compatibility Layer

    WoW: Forever runs on the modern Retail engine, so every helper below prefers
    the modern C_* API. Each function is resolved exactly ONCE at load time; a
    legacy fallback is only kept inside this file (never at call sites), so the
    rest of the addon can call ns.API.* without repeating existence checks.
-----------------------------------------------------------------------------]]

local tonumber, pcall, select, ipairs, pairs = tonumber, pcall, select, ipairs, pairs
local table_insert, table_remove = table.insert, table.remove
local string_match = string.match

local wipe = table.wipe or wipe or function(t) for k in pairs(t) do t[k] = nil end return t end
ns.wipe = wipe

local API = {}
ns.API = API

-- Safe protected call that returns up to four results (nil on error)
local function SafeCall(fn, ...)
    if not fn then return nil end
    local ok, r1, r2, r3, r4 = pcall(fn, ...)
    if ok then return r1, r2, r3, r4 end
    return nil
end
ns.SafeCall = SafeCall
API.SafeCall = SafeCall

local C_QuestLog = C_QuestLog or {}
local C_Container = C_Container or {}
local C_Item = C_Item or {}
local C_AddOns = C_AddOns or {}

-- ---------------------------------------------------------------------------
-- Add-on metadata
-- ---------------------------------------------------------------------------
API.GetAddOnMetadata = C_AddOns.GetAddOnMetadata or _G.GetAddOnMetadata or function() return nil end
API.IsAddOnLoaded = C_AddOns.IsAddOnLoaded or _G.IsAddOnLoaded or function() return false end
API.DisableAddOn = C_AddOns.DisableAddOn or _G.DisableAddOn or function() end

-- ---------------------------------------------------------------------------
-- Quest log entries
-- ---------------------------------------------------------------------------
local GetNumEntries = C_QuestLog.GetNumQuestLogEntries or _G.GetNumQuestLogEntries
local GetInfo = C_QuestLog.GetInfo
local LegacyGetQuestLogTitle = _G.GetQuestLogTitle
local GetQuestIDForLogIndex = C_QuestLog.GetQuestIDForLogIndex
local GetLogIndexForQuestID = C_QuestLog.GetLogIndexForQuestID
local IsComplete = C_QuestLog.IsComplete
local ReadyForTurnIn = C_QuestLog.ReadyForTurnIn
local IsFailed = C_QuestLog.IsFailed
local GetQuestLink = _G.GetQuestLink

-- Total quest log rows (headers + quests)
function API.GetNumQuestLogEntries()
    local n = GetNumEntries and GetNumEntries()
    return tonumber(n) or 0
end

-- Normalizes completion values (true/1/-1) into 1 (complete), -1 (failed) or 0
local function NormalizeComplete(v)
    if v == true or v == 1 then return 1 end
    if v == -1 then return -1 end
    return 0
end

--[[ Fills `out` (reused table) with a normalized quest log row and returns it.
     Fields: title, level, suggestedGroup, isHeader, isCollapsed, isHidden,
             isComplete (1 / 0 / -1), frequency, questID, questLogIndex ]]
local scratchInfo = {}
local GetQuestInfo
if GetInfo then
    GetQuestInfo = function(index, out)
        local info = index and GetInfo(index)
        if not info or not info.title then return nil end
        out = out or scratchInfo
        out.title = info.title
        out.level = info.level or 0
        out.suggestedGroup = info.suggestedGroup or 0
        out.isHeader = info.isHeader and true or false
        out.isCollapsed = info.isCollapsed and true or false
        out.isHidden = info.isHidden and true or false
        out.frequency = info.frequency or 0
        out.questLogIndex = index
        local questID = info.questID
        if (not questID or questID <= 0) and GetQuestIDForLogIndex then
            questID = GetQuestIDForLogIndex(index)
        end
        out.questID = (questID and questID > 0) and questID or nil
        if out.isHeader or not out.questID then
            out.isComplete = 0
        elseif IsFailed and IsFailed(out.questID) then
            out.isComplete = -1
        elseif (IsComplete and IsComplete(out.questID)) or (ReadyForTurnIn and ReadyForTurnIn(out.questID)) then
            out.isComplete = 1
        else
            out.isComplete = NormalizeComplete(info.isComplete)
        end
        return out
    end
elseif LegacyGetQuestLogTitle then
    GetQuestInfo = function(index, out)
        if not index or index <= 0 then return nil end
        local numRet = select("#", LegacyGetQuestLogTitle(index))
        local title, level, group, isHeader, isCollapsed, isComplete, frequency, questID
        if numRet >= 9 then
            local qTag
            title, level, qTag, group, isHeader, isCollapsed, isComplete, frequency, questID = LegacyGetQuestLogTitle(index)
            group = qTag or group
        else
            title, level, group, isHeader, isCollapsed, isComplete, frequency, questID = LegacyGetQuestLogTitle(index)
        end
        if not title then return nil end
        out = out or scratchInfo
        out.title = title
        out.level = tonumber(level) or 0
        out.suggestedGroup = group or 0
        out.isHeader = (isHeader == true or isHeader == 1)
        out.isCollapsed = (isCollapsed == true or isCollapsed == 1)
        out.isHidden = false
        out.isComplete = NormalizeComplete(isComplete)
        out.frequency = frequency or 0
        out.questLogIndex = index
        questID = tonumber(questID)
        if (not questID or questID <= 0) and GetQuestLink then
            local link = GetQuestLink(index)
            questID = link and tonumber(string_match(link, "quest:(%d+)"))
        end
        out.questID = (questID and questID > 0) and questID or nil
        return out
    end
else
    GetQuestInfo = function() return nil end
end
API.GetQuestInfo = GetQuestInfo

-- Number of actual quests (excluding headers & hidden entries)
function API.CountQuests()
    local numEntries = API.GetNumQuestLogEntries()
    local count = 0
    for i = 1, numEntries do
        local info = GetQuestInfo(i, scratchInfo)
        if info and not info.isHeader and not info.isHidden then
            count = count + 1
        end
    end
    return numEntries, count
end

function API.GetLogIndexForQuestID(questID)
    if not questID or questID <= 0 then return nil end
    if GetLogIndexForQuestID then
        local idx = GetLogIndexForQuestID(questID)
        if idx and idx > 0 then return idx end
        return nil
    end
    local info = {}
    for i = 1, API.GetNumQuestLogEntries() do
        if GetQuestInfo(i, info) and info.questID == questID then
            return i
        end
    end
    return nil
end

-- True when the quest is still present in the player's quest log
function API.IsQuestInLog(questID)
    return API.GetLogIndexForQuestID(questID) ~= nil
end

API.GetTitleForQuestID = C_QuestLog.GetTitleForQuestID or function(questID)
    local idx = API.GetLogIndexForQuestID(questID)
    local info = idx and GetQuestInfo(idx, {})
    return info and info.title
end

function API.GetQuestLink(questID, questLogIndex)
    if C_QuestLog.GetQuestLink and questID then
        local link = C_QuestLog.GetQuestLink(questID)
        if link then return link end
    end
    if GetQuestLink then
        return GetQuestLink(questLogIndex or questID)
    end
    return nil
end

-- ---------------------------------------------------------------------------
-- Objectives (reuses pooled tables; never changes the quest log selection)
-- ---------------------------------------------------------------------------
local objectivePool = {}
local GetQuestObjectivesC = C_QuestLog.GetQuestObjectives
local GetNumQuestLeaderBoards = _G.GetNumQuestLeaderBoards
local GetQuestLogLeaderBoard = _G.GetQuestLogLeaderBoard

local function AcquireObjective()
    local obj = table_remove(objectivePool)
    if obj then wipe(obj) else obj = {} end
    return obj
end

function API.ReleaseObjectives(list)
    if not list then return end
    for i = #list, 1, -1 do
        local obj = list[i]
        list[i] = nil
        if obj then table_insert(objectivePool, obj) end
    end
end

-- Fills (and returns) `outList` with { text, finished, type, numFulfilled, numRequired }
function API.GetQuestObjectives(questID, questLogIndex, outList)
    local list = outList or {}
    API.ReleaseObjectives(list)

    if questID and GetQuestObjectivesC then
        local objs = GetQuestObjectivesC(questID)
        if objs and #objs > 0 then
            for _, o in ipairs(objs) do
                local entry = AcquireObjective()
                entry.text = o.text or ""
                entry.finished = o.finished and true or false
                entry.type = o.type or ""
                entry.numFulfilled = o.numFulfilled
                entry.numRequired = o.numRequired
                list[#list + 1] = entry
            end
            return list
        end
    end

    local index = questLogIndex or API.GetLogIndexForQuestID(questID)
    if index and GetNumQuestLeaderBoards and GetQuestLogLeaderBoard then
        local num = GetNumQuestLeaderBoards(index) or 0
        for j = 1, num do
            local desc, objType, done = GetQuestLogLeaderBoard(j, index)
            if desc then
                local entry = AcquireObjective()
                entry.text = desc
                entry.finished = done and true or false
                entry.type = objType or ""
                local c, m = string_match(desc, "(%d+)%s*/%s*(%d+)")
                if c and m then
                    entry.numFulfilled = tonumber(c)
                    entry.numRequired = tonumber(m)
                end
                list[#list + 1] = entry
            end
        end
    end
    return list
end

local function AllObjectivesFinished(objectives)
    if not objectives or #objectives == 0 then return false end
    for i = 1, #objectives do
        if not objectives[i].finished then return false end
    end
    return true
end
API.AllObjectivesFinished = AllObjectivesFinished

function API.IsQuestComplete(questID, questLogIndex, objectives)
    if questID then
        if IsComplete and IsComplete(questID) then return true end
        if ReadyForTurnIn and ReadyForTurnIn(questID) then return true end
    end
    if questLogIndex and not GetInfo then
        local info = GetQuestInfo(questLogIndex, {})
        if info and info.isComplete == 1 then return true end
    end
    return AllObjectivesFinished(objectives)
end

function API.IsQuestFailed(questID, questLogIndex, objectives)
    if questID and IsFailed and SafeCall(IsFailed, questID) then
        return true
    end
    if questLogIndex and not GetInfo then
        local info = GetQuestInfo(questLogIndex, {})
        if info and info.isComplete == -1 then return true end
    end
    if objectives then
        for i = 1, #objectives do
            local obj = objectives[i]
            if obj.failed or obj.isFailed then return true end
        end
    end
    return false
end

-- ---------------------------------------------------------------------------
-- Watching & tracking
-- ---------------------------------------------------------------------------
local GetQuestWatchType = C_QuestLog.GetQuestWatchType
local IsQuestWatchedC = C_QuestLog.IsQuestWatched
local LegacyIsQuestWatched = _G.IsQuestWatched

function API.IsQuestWatched(questID, questLogIndex)
    if questID and IsQuestWatchedC then
        return SafeCall(IsQuestWatchedC, questID) and true or false
    end
    if questID and GetQuestWatchType then
        local wt = SafeCall(GetQuestWatchType, questID)
        return wt ~= nil and wt ~= false
    end
    if questLogIndex and LegacyIsQuestWatched then
        return SafeCall(LegacyIsQuestWatched, questLogIndex) and true or false
    end
    return false
end

function API.AddQuestWatch(questID, questLogIndex)
    if questID and C_QuestLog.AddQuestWatch then
        return C_QuestLog.AddQuestWatch(questID)
    elseif questLogIndex and _G.AddQuestWatch then
        return _G.AddQuestWatch(questLogIndex)
    end
end

function API.RemoveQuestWatch(questID, questLogIndex)
    if questID and C_QuestLog.RemoveQuestWatch then
        return C_QuestLog.RemoveQuestWatch(questID)
    elseif questLogIndex and _G.RemoveQuestWatch then
        return _G.RemoveQuestWatch(questLogIndex)
    end
end

-- ---------------------------------------------------------------------------
-- Tags, items, timers & sharing
-- ---------------------------------------------------------------------------
local GetQuestTagInfoC = C_QuestLog.GetQuestTagInfo
local LegacyGetQuestTagInfo = _G.GetQuestTagInfo

function API.GetQuestTagInfo(questID, questLogIndex)
    if questID and GetQuestTagInfoC then
        return GetQuestTagInfoC(questID)
    elseif questLogIndex and LegacyGetQuestTagInfo then
        return LegacyGetQuestTagInfo(questLogIndex)
    end
    return nil
end

local GetSpecialItemC = C_QuestLog.GetQuestLogSpecialItemInfo
local GetSpecialItem = _G.GetQuestLogSpecialItemInfo

-- Returns itemLink, itemTexture, charges for a quest's usable special item
function API.GetQuestSpecialItem(questID, questLogIndex)
    if GetSpecialItem then
        local index = questLogIndex or API.GetLogIndexForQuestID(questID)
        if index then
            return GetSpecialItem(index)
        end
    elseif GetSpecialItemC and questID then
        return GetSpecialItemC(questID)
    end
    return nil
end

local GetTimeAllowed = C_QuestLog.GetTimeAllowed
function API.GetQuestTimeAllowed(questID)
    if not questID or not GetTimeAllowed then return nil end
    local ok, total, elapsed = pcall(GetTimeAllowed, questID)
    if not ok then return nil end
    return tonumber(total), tonumber(elapsed)
end

function API.IsQuestPushable(questID, questLogIndex)
    if questID and C_QuestLog.IsPushableQuest then
        return C_QuestLog.IsPushableQuest(questID) and true or false
    end
    if _G.GetQuestLogPushable then
        local index = questLogIndex or API.GetLogIndexForQuestID(questID)
        if index and _G.SelectQuestLogEntry then _G.SelectQuestLogEntry(index) end
        return _G.GetQuestLogPushable() and true or false
    end
    return false
end

function API.ShareQuest(questID, questLogIndex)
    local index = questLogIndex or API.GetLogIndexForQuestID(questID)
    if C_QuestLog.SetSelectedQuest and questID then
        C_QuestLog.SetSelectedQuest(questID)
    end
    if _G.QuestLogPushQuest then
        _G.QuestLogPushQuest(index)
        return true
    end
    return false
end

function API.IsUnitOnQuest(unit, questID, questLogIndex)
    if questID and C_QuestLog.IsUnitOnQuest then
        return SafeCall(C_QuestLog.IsUnitOnQuest, unit, questID) and true or false
    end
    if _G.IsUnitOnQuest and questLogIndex then
        return SafeCall(_G.IsUnitOnQuest, questLogIndex, unit) and true or false
    end
    return false
end

function API.GetMaxQuests()
    return (C_QuestLog.GetMaxNumQuestsCanAccept and C_QuestLog.GetMaxNumQuestsCanAccept()) or _G.MAX_QUESTLOG_QUESTS or 40
end

-- ---------------------------------------------------------------------------
-- Containers & items
-- ---------------------------------------------------------------------------
API.GetContainerNumSlots = C_Container.GetContainerNumSlots or _G.GetContainerNumSlots or function() return 0 end
API.GetContainerItemID = C_Container.GetContainerItemID or _G.GetContainerItemID or function() return nil end
API.UseContainerItem = C_Container.UseContainerItem or _G.UseContainerItem

-- Returns itemID, hyperlink, icon, stackCount, quality, hasNoValue
if C_Container.GetContainerItemInfo then
    local GetContainerItemInfoC = C_Container.GetContainerItemInfo
    function API.GetContainerItemInfo(bag, slot)
        local info = GetContainerItemInfoC(bag, slot)
        if not info then return nil end
        return info.itemID, info.hyperlink, info.iconFileID, info.stackCount, info.quality, info.hasNoValue
    end
elseif _G.GetContainerItemInfo then
    local LegacyGetContainerItemInfo = _G.GetContainerItemInfo
    function API.GetContainerItemInfo(bag, slot)
        local icon, count, _, quality, _, _, link, _, hasNoValue, itemID = LegacyGetContainerItemInfo(bag, slot)
        return itemID, link, icon, count, quality, hasNoValue
    end
else
    function API.GetContainerItemInfo() return nil end
end

API.GetItemInfo = C_Item.GetItemInfo or _G.GetItemInfo or function() return nil end
API.GetItemInfoInstant = C_Item.GetItemInfoInstant or _G.GetItemInfoInstant or function() return nil end
API.GetItemSpell = C_Item.GetItemSpell or _G.GetItemSpell or function() return nil end
API.GetItemCooldown = C_Item.GetItemCooldown or C_Container.GetItemCooldown or _G.GetItemCooldown or function() return 0, 0, 0 end

function API.GetItemQualityColorHex(quality)
    if not quality then return "|cffffffff" end
    local getter = C_Item.GetItemQualityColor or _G.GetItemQualityColor
    if getter then
        local _, _, _, hex = getter(quality)
        if hex then
            if hex:sub(1, 2) ~= "|c" then hex = "|c" .. hex end
            return hex
        end
    end
    local qc = _G.ITEM_QUALITY_COLORS and _G.ITEM_QUALITY_COLORS[quality]
    return (qc and qc.hex) or "|cffffffff"
end

API.NUM_BAG_SLOTS = _G.NUM_BAG_SLOTS or 4

-- ---------------------------------------------------------------------------
-- Map & super tracking
-- ---------------------------------------------------------------------------
local C_SuperTrack = C_SuperTrack or {}
API.GetSuperTrackedQuestID = C_SuperTrack.GetSuperTrackedQuestID or function() return 0 end
API.SetSuperTrackedQuestID = C_SuperTrack.SetSuperTrackedQuestID or function() end

-- ---------------------------------------------------------------------------
-- Quests new in WoW Forever (ranges generated from the game clients' quest
-- tables into Data/ForeverQuestIDs.lua). Binary search, cached per quest ID.
-- ---------------------------------------------------------------------------
local foreverCache = {}

function API.IsForeverQuest(questID)
    questID = tonumber(questID)
    if not questID or questID <= 0 then return false end
    local cached = foreverCache[questID]
    if cached ~= nil then return cached end
    local ranges = ns.FOREVER_QUEST_RANGES
    local found = false
    if ranges then
        local lo, hi = 1, #ranges
        while lo <= hi do
            local mid = math.floor((lo + hi) / 2)
            local r = ranges[mid]
            if questID < r[1] then
                hi = mid - 1
            elseif questID > r[2] then
                lo = mid + 1
            else
                found = true
                break
            end
        end
    end
    foreverCache[questID] = found
    return found
end

-- ---------------------------------------------------------------------------
-- Backwards-compatible namespace helpers used throughout the addon
-- ---------------------------------------------------------------------------

-- Returns the legacy 8-value tuple: title, level, group, isHeader, isCollapsed, isComplete, frequency, questID
local tupleInfo = {}
function ns.GetQuestLogTitle(index)
    local info = GetQuestInfo(index, tupleInfo)
    if not info then return nil end
    return info.title, info.level, info.suggestedGroup, info.isHeader, info.isCollapsed, info.isComplete, info.frequency, info.questID
end

ns.GetNumQuestLogEntries = API.CountQuests
ns.GetQuestLogIndexForQuestID = API.GetLogIndexForQuestID
ns.GetQuestObjectives = API.GetQuestObjectives
ns.ReleaseObjectiveObjs = API.ReleaseObjectives
ns.IsQuestComplete = API.IsQuestComplete
ns.IsQuestFailed = API.IsQuestFailed
ns.IsQuestPushable = API.IsQuestPushable
ns.ShareQuest = API.ShareQuest
