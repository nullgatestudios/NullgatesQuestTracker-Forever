local addonName, ns = ...

-- Localized Lua & WoW API bindings for performance & garbage reduction
local pairs, ipairs, type, tostring, tonumber, select, pcall, next = pairs, ipairs, type, tostring, tonumber, select, pcall, next
local string_format = string.format
local table_insert = table.insert
local math_floor, math_max, math_min, math_abs = math.floor, math.max, math.min, math.abs
local UnitClass, UnitFactionGroup, UnitLevel = UnitClass, UnitFactionGroup, UnitLevel
local CreateFrame, GetTime, InCombatLockdown = CreateFrame, GetTime, InCombatLockdown

local API = ns.API
local L = ns.L

-- ---------------------------------------------------------------------------
-- Key Bindings (Blizzard Key Bindings menu)
-- ---------------------------------------------------------------------------
-- Both bindings are secure CLICK bindings: the game clicks the secure button
-- directly, so they keep working during combat lockdown.
ns.BINDING_QUEST_ITEM = "CLICK NullgateQuestItemButton1:LeftButton"
ns.BINDING_TOGGLE_TRACKER = "CLICK NullgateTrackerToggleButton:LeftButton"

_G["BINDING_HEADER_NULLGATE_TRACKER"] = "Nullgate's Quest Tracker"
_G["BINDING_NAME_" .. ns.BINDING_QUEST_ITEM] = L["Use Active Quest Item"]
_G["BINDING_NAME_" .. ns.BINDING_TOGGLE_TRACKER] = L["Toggle Tracker Visibility (Hide/Show)"]

-- Macro-friendly global helpers (/run Nullgate_ToggleTracker())
function Nullgate_ToggleTracker()
    if ns.Tracker and ns.Tracker.ToggleVisibility then
        ns.Tracker:ToggleVisibility()
    end
end

function Nullgate_HideTracker()
    if ns.Tracker and ns.Tracker.HideTracker then
        ns.Tracker:HideTracker()
    end
end

function Nullgate_ShowTracker()
    if ns.Tracker and ns.Tracker.ShowTracker then
        ns.Tracker:ShowTracker()
    end
end

-- Safe number converter (discards any secondary return values)
local function ToNumber(val)
    if val == nil then return nil end
    return tonumber(val)
end
ns.ToNumber = ToNumber

-- Addon metadata & global access
ns.addonName = addonName
ns.title = "|cff00c0ffNullgate's Quest Tracker - Forever|r"
ns.version = API.GetAddOnMetadata(addonName, "Version") or "1.2.0"

-- ---------------------------------------------------------------------------
-- Chat Output (debug & status) - silent unless the user enables it
-- ---------------------------------------------------------------------------
local PRINT_PREFIX = "|cff00c0ff[Nullgate's Quest Tracker]|r"

function ns.IsChatOutputEnabled()
    local global = ns.dbObject and ns.dbObject.global
    return global and global.chatOutput == true or false
end

local function GetChatFrame()
    if SELECTED_CHAT_FRAME and SELECTED_CHAT_FRAME.AddMessage then
        return SELECTED_CHAT_FRAME
    end
    return DEFAULT_CHAT_FRAME
end
ns.GetActiveChatFrame = GetChatFrame

local function JoinArgs(...)
    local n = select("#", ...)
    if n == 0 then return "" end
    local parts = {}
    for i = 1, n do
        parts[i] = tostring((select(i, ...)))
    end
    return table.concat(parts, " ")
end

-- Status / informational messages (only when chat output is enabled)
function ns.Print(...)
    if not ns.IsChatOutputEnabled() then return end
    local frame = GetChatFrame()
    if frame then
        frame:AddMessage(PRINT_PREFIX .. " " .. JoinArgs(...))
    end
end

-- Verbose diagnostics (only when chat output is enabled)
function ns.Debug(...)
    if not ns.IsChatOutputEnabled() then return end
    local frame = GetChatFrame()
    if frame then
        frame:AddMessage("|cff888888[NQT Debug]|r " .. JoinArgs(...))
    end
end

-- Short on-screen feedback for direct user actions (never written to chat)
function ns.Notify(message, r, g, b)
    if UIErrorsFrame and UIErrorsFrame.AddMessage and message then
        UIErrorsFrame:AddMessage(message, r or 1.0, g or 0.82, b or 0.0, 1.0)
    end
end

-- Tells the user (once per session) how to see output from a typed command
local chatHintShown = false
function ns.HintChatOutput()
    if ns.IsChatOutputEnabled() or chatHintShown then return end
    chatHintShown = true
    ns.Notify(L["Chat output is off. Enable it in Settings > General > Debug & Chat Output."])
end

-- ---------------------------------------------------------------------------
-- Public API (used by Nullgate's Addon Config & external language packs)
-- ---------------------------------------------------------------------------
local PublicAPI = _G["NullgatesQuestTrackerForever"] or {}
_G["NullgatesQuestTrackerForever"] = PublicAPI
_G["NullgateQuestTracker"] = PublicAPI
ns.PublicAPI = PublicAPI
PublicAPI.addonName = addonName
PublicAPI.version = ns.version

function PublicAPI:GetDB()
    return ns.db
end

function PublicAPI:RegisterLanguagePack(code, displayName, strings)
    return ns.RegisterLanguagePack(code, displayName, strings)
end

-- True when the quest is new in WoW Forever (not part of original Classic)
function PublicAPI:IsForeverQuest(questID)
    return API.IsForeverQuest(questID)
end

function PublicAPI:ApplySettings()
    ns.ApplyAllSettings()
end

function PublicAPI:OpenSettings()
    if ns.Config and ns.Config.ToggleConfigFrame then
        ns.Config:ToggleConfigFrame()
    end
end

-- Re-applies every visual setting across the tracker and all modules
-- SETTINGS_UPDATED listeners refresh the tracker frame, quest list, and Wayfinder HUD
function ns.ApplyAllSettings()
    ns:FireCallback("SETTINGS_UPDATED")
    local st = ns.StandaloneTracker
    if st then
        if st.ApplyHighlightColors then st:ApplyHighlightColors() end
        if st.UpdateItemButtonStrata then st:UpdateItemButtonStrata() end
    end
    if ns.WayfinderModule and ns.IsModuleEnabled("wayfinder") and ns.WayfinderModule.RefreshState then
        ns.WayfinderModule:RefreshState()
    end
    if ns.DataBarsModule and ns.IsModuleEnabled("databars") and ns.DataBarsModule.RefreshBars then
        ns.DataBarsModule:RefreshBars()
    end
end

-- Profile helpers (shared by the native Profiles tab and the master config hub)
local function ProfileExists(name)
    local list = ns.dbObject and ns.dbObject:GetProfiles()
    if type(list) ~= "table" then return false end
    for _, p in ipairs(list) do
        if p == name then return true end
    end
    return false
end
ns.ProfileExists = ProfileExists

-- Switches to `name`; a brand-new profile starts as a copy of `copyFrom` (or the current profile)
local function SwitchToProfile(name, copyFrom)
    if type(name) ~= "string" or name == "" then return end
    local dbObject = ns.dbObject
    if not dbObject then
        ns.pendingProfileSync = name
        return
    end
    local current = dbObject:GetCurrentProfile()
    if name == current then return end
    local isNew = not ProfileExists(name)
    dbObject:SetProfile(name)
    if isNew then
        local source = copyFrom or current
        if source and source ~= name and ProfileExists(source) then
            dbObject:CopyProfile(source)
        end
    end
end
ns.SwitchToProfile = SwitchToProfile

function PublicAPI:RegisterWithMasterConfig()
    local hub = _G.NullgatesAddonConfigForever
    if not (hub and hub.RegisterModule) or self.registeredWithHub then return end
    self.registeredWithHub = true
    hub:RegisterModule("NullgatesQuestTracker", {
        id = "NullgatesQuestTracker",
        name = L["Quest Tracker"],
        sidebarName = L["Quest Tracker"],
        version = ns.version,
        author = "Nullgate Studios",
        isNullgate = true,
        db = ns.db,
        getDB = function() return ns.db end,
        profiles = {
            GetCurrent = function()
                return (ns.dbObject and ns.dbObject:GetCurrentProfile()) or "Default"
            end,
            SetCurrent = function(profileKey) SwitchToProfile(profileKey) end,
            Create = function(profileKey, fromProfile) SwitchToProfile(profileKey, fromProfile) end,
            SaveCurrentAs = function(profileKey)
                local dbObject = ns.dbObject
                if not dbObject or type(profileKey) ~= "string" or profileKey == "" then return end
                local current = dbObject:GetCurrentProfile()
                if current == profileKey then return end
                dbObject:SetProfile(profileKey)
                dbObject:CopyProfile(current)
            end,
            List = function()
                return (ns.dbObject and ns.dbObject:GetProfiles()) or { "Default" }
            end,
            Delete = function(profileKey)
                if ns.dbObject and profileKey and profileKey ~= "Default" and profileKey ~= ns.dbObject:GetCurrentProfile() then
                    ns.dbObject:DeleteProfile(profileKey)
                end
            end,
            Copy = function(fromKey, toKey)
                local dbObject = ns.dbObject
                if not dbObject or not fromKey or not toKey or fromKey == toKey then return end
                dbObject:SetProfile(toKey)
                dbObject:CopyProfile(fromKey)
            end,
            Reset = function(profileKey)
                local dbObject = ns.dbObject
                if not dbObject then return end
                if profileKey and dbObject:GetCurrentProfile() ~= profileKey then
                    dbObject:SetProfile(profileKey)
                end
                dbObject:ResetProfile()
            end,
        },
        refresh = function() ns.ApplyAllSettings() end,
        toggleMovers = function(enable)
            if ns.Tracker and ns.Tracker.SetLocked then
                if enable ~= nil then
                    ns.Tracker:SetLocked(not enable)
                else
                    ns.Tracker:SetLocked(not (ns.db and ns.db.isLocked))
                end
            end
        end,
        isMoversUnlocked = function()
            return ns.db and not ns.db.isLocked
        end,
        openStandalone = function() PublicAPI:OpenSettings() end,
        buildUI = function(parentContainer)
            if PublicAPI.BuildMasterConfigUI then
                PublicAPI:BuildMasterConfigUI(parentContainer)
            end
        end,
    })
end

-- ---------------------------------------------------------------------------
-- Generic helpers
-- ---------------------------------------------------------------------------

-- Pixel-Grid Coordinate Snapper (Eliminates sub-pixel text & shadow distortion)
function ns.SnapToPixel(val, region)
    if not val then return 0 end
    local scale = (region and region.GetEffectiveScale and region:GetEffectiveScale())
        or (UIParent and UIParent:GetEffectiveScale())
        or 1
    if not scale or scale <= 0 then scale = 1 end
    return math_floor(val * scale + 0.5) / scale
end

-- Converts a { r, g, b } color table into a |cffRRGGBB escape
function ns.ColorToHex(c, dr, dg, db)
    local r = (c and c.r) or dr or 1
    local g = (c and c.g) or dg or 1
    local b = (c and c.b) or db or 1
    return string_format("|cff%02x%02x%02x", math_floor(r * 255 + 0.5), math_floor(g * 255 + 0.5), math_floor(b * 255 + 0.5))
end

-- Player Class & Faction Color Helpers (cached)
local cachedClassColor = nil
function ns.GetClassColor()
    if cachedClassColor then return cachedClassColor end
    local _, classFilename = UnitClass("player")
    local c = (CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[classFilename])
        or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFilename])
    if c then
        cachedClassColor = { r = c.r, g = c.g, b = c.b }
    else
        cachedClassColor = { r = 0.0, g = 0.75, b = 1.0 }
    end
    return cachedClassColor
end

local cachedFactionColor = nil
function ns.GetFactionColor()
    if cachedFactionColor then return cachedFactionColor end
    local englishFaction = UnitFactionGroup("player")
    if englishFaction == "Alliance" then
        cachedFactionColor = { r = 0.0, g = 0.44, b = 0.87 }
    elseif englishFaction == "Horde" then
        cachedFactionColor = { r = 0.87, g = 0.13, b = 0.13 }
    else
        cachedFactionColor = { r = 1.0, g = 0.82, b = 0.0 }
    end
    return cachedFactionColor
end

-- ---------------------------------------------------------------------------
-- Quest difficulty colors
-- ---------------------------------------------------------------------------
local DIFF_COLOR_WHITE  = { r = 1.00, g = 1.00, b = 1.00 }
local DIFF_COLOR_RED    = { r = 1.00, g = 0.12, b = 0.12 }
local DIFF_COLOR_ORANGE = { r = 1.00, g = 0.50, b = 0.25 }
local DIFF_COLOR_YELLOW = { r = 1.00, g = 1.00, b = 0.00 }
local DIFF_COLOR_GREEN  = { r = 0.25, g = 1.00, b = 0.25 }
local DIFF_COLOR_GRAY   = { r = 0.60, g = 0.60, b = 0.60 }

local function GetPlayerLevel()
    return (UnitEffectiveLevel and UnitEffectiveLevel("player")) or (UnitLevel and UnitLevel("player")) or 1
end

-- Grey / Trivial Quest Level Threshold Calculation
function ns.GetGreyThreshold(playerLevel)
    playerLevel = tonumber(playerLevel) or GetPlayerLevel()
    if UnitQuestTrivialLevelRange then
        local r = UnitQuestTrivialLevelRange("player")
        if r and r > 0 then
            return r
        end
    end
    if playerLevel <= 5 then
        return 5
    elseif playerLevel <= 39 then
        return math_floor(playerLevel / 10) + 5
    elseif playerLevel <= 59 then
        return math_floor(playerLevel / 5) + 1
    end
    return 9
end

function ns.GetDifficultyColor(level, playerLevelOverride, questID)
    level = tonumber(level) or 0
    local curPlayerLevel = GetPlayerLevel()
    local playerLevel = playerLevelOverride or curPlayerLevel
    local isCurrentLevel = (not playerLevelOverride or playerLevelOverride == curPlayerLevel)

    -- 1. Exact parity with the quest log: relative content difficulty
    if questID and isCurrentLevel and C_PlayerInfo and C_PlayerInfo.GetContentDifficultyQuestForPlayer then
        local diffEnum = C_PlayerInfo.GetContentDifficultyQuestForPlayer(questID)
        if diffEnum ~= nil then
            local blizzColor = (GetDifficultyColor and GetDifficultyColor(diffEnum))
                or (DifficultyUtil and DifficultyUtil.GetDifficultyColor and DifficultyUtil.GetDifficultyColor(diffEnum))
            if blizzColor and blizzColor.r then
                return blizzColor
            end
        end
    end

    if level <= 0 then
        return DIFF_COLOR_WHITE
    end

    -- 2. Native GetQuestDifficultyColor API
    if isCurrentLevel then
        local blizzQuestColorFn = GetQuestDifficultyColor or (DifficultyUtil and DifficultyUtil.GetQuestDifficultyColor)
        if blizzQuestColorFn then
            local c = blizzQuestColorFn(level, false, questID)
            if c and c.r then
                return c
            end
        end
    end

    -- 3. Relative difficulty fallback
    local levelDiff = level - playerLevel
    local colors = QuestDifficultyColors
    if levelDiff >= 5 then
        return (colors and colors["impossible"]) or DIFF_COLOR_RED
    elseif levelDiff >= 3 then
        return (colors and colors["verydifficult"]) or DIFF_COLOR_ORANGE
    elseif levelDiff >= -4 then
        return (colors and colors["difficult"]) or DIFF_COLOR_YELLOW
    elseif -levelDiff <= ns.GetGreyThreshold(playerLevel) then
        return (colors and colors["standard"]) or DIFF_COLOR_GREEN
    end
    return (colors and colors["trivial"]) or DIFF_COLOR_GRAY
end

function ns.IsQuestGrey(questLevel, playerLevel, questID)
    local curPlayerLevel = GetPlayerLevel()
    if questID and C_PlayerInfo and C_PlayerInfo.GetContentDifficultyQuestForPlayer
        and (not playerLevel or playerLevel == curPlayerLevel) then
        local diffEnum = C_PlayerInfo.GetContentDifficultyQuestForPlayer(questID)
        if diffEnum ~= nil and Enum and Enum.RelativeContentDifficulty then
            return diffEnum == Enum.RelativeContentDifficulty.Trivial
        end
    end
    questLevel = tonumber(questLevel) or 0
    playerLevel = tonumber(playerLevel) or curPlayerLevel
    if questLevel <= 0 then return false end
    local levelDiff = questLevel - playerLevel
    if levelDiff >= -4 then return false end
    return (-levelDiff > ns.GetGreyThreshold(playerLevel))
end

-- ---------------------------------------------------------------------------
-- Quest Timer Engine
-- Keeps timers stable through hover, tooltips and combat without re-scanning
-- the whole quest log. Entries are reused in place (zero allocation per tick).
-- ---------------------------------------------------------------------------
local timerCache = {}
ns.questTimerCache = timerCache

local function GetTimerDB()
    local profile = ns.db
    return profile and profile.databars
end

function ns.RecordQuestTimer(questID, timeLeft, maxTime)
    if not questID or not timeLeft or timeLeft <= 0 then return end
    local entry = timerCache[questID]
    if not entry then
        entry = {}
        timerCache[questID] = entry
    end
    local mTime = maxTime or entry.maxTime or timeLeft
    if mTime <= 0 then mTime = timeLeft end
    entry.maxTime = mTime
    entry.expiresAt = GetTime() + timeLeft

    local tdb = GetTimerDB()
    if tdb then
        tdb.timerMaxValues = tdb.timerMaxValues or {}
        if tdb.timerMaxValues[questID] ~= mTime then
            tdb.timerMaxValues[questID] = mTime
        end
    end
end

function ns.ClearQuestTimer(questID)
    if not questID then return end
    timerCache[questID] = nil
    local tdb = GetTimerDB()
    if tdb and tdb.timerMaxValues then
        tdb.timerMaxValues[questID] = nil
    end
end

-- Drops cached timers for quests that are gone, failed, or no longer timed
function ns.PurgeInvalidTimerCache()
    for questID in pairs(timerCache) do
        local total = API.GetQuestTimeAllowed(questID)
        if not API.IsQuestInLog(questID) or API.IsQuestFailed(questID) or not (total and total > 0) then
            timerCache[questID] = nil
        end
    end
    local tdb = GetTimerDB()
    if tdb and tdb.timerMaxValues then
        for questID in pairs(tdb.timerMaxValues) do
            if not timerCache[questID] and not API.IsQuestInLog(questID) then
                tdb.timerMaxValues[questID] = nil
            end
        end
    end
end

-- Returns timeLeft, maxTime (seconds) for a timed quest, or nil
function ns.GetQuestTimeInfo(questID, questLogIndex)
    if (not questID or questID <= 0) and questLogIndex then
        local info = API.GetQuestInfo(questLogIndex, {})
        questID = info and info.questID
    end
    if not questID or questID <= 0 then return nil end

    if API.IsQuestFailed(questID) then
        ns.ClearQuestTimer(questID)
        return nil
    end

    local total, elapsed = API.GetQuestTimeAllowed(questID)
    if total and total > 0 then
        local left = total - (elapsed or 0)
        if left > 0 then
            ns.RecordQuestTimer(questID, left, total)
            return left, total
        end
        ns.ClearQuestTimer(questID)
        return nil
    end

    -- Monotonic cache fallback for clients that briefly report no timer data
    local cached = timerCache[questID]
    if cached and cached.expiresAt and API.IsQuestInLog(questID) then
        local remaining = math_floor(cached.expiresAt - GetTime())
        if remaining > 0 then
            return remaining, cached.maxTime
        end
    end
    ns.ClearQuestTimer(questID)
    return nil
end
ns.GetQuestTimeLeft = ns.GetQuestTimeInfo

-- ---------------------------------------------------------------------------
-- Default Settings
-- ---------------------------------------------------------------------------
ns.DB_VERSION = 3

ns.defaultDB = {
    global = {
        language = "auto",      -- "auto" (game client) or a language pack code such as "deDE"
        chatOutput = false,     -- Debug & status messages in chat (off by default)
        questItemNames = {},    -- questID -> last known quest item name (finds changed items)
        wavNoticeShown = false, -- the ".wav sounds must be converted" notice was shown
    },
    profile = {
        -- Positioning & Sizing
        framePosition = nil,
        growCorner = "AUTO", -- "AUTO", "BOTTOMRIGHT", "BOTTOMLEFT", "TOPRIGHT", "TOPLEFT"
        width = 280,
        maxHeight = 600,
        scale = 1.0,
        alpha = 1.0,
        isLocked = false,
        itemButtonPosition = nil,             -- Dragged quest item button position
        trackerBottomPadding = 4,             -- 0 to 20 px under the last quest
        foreverMarker = {                     -- marks quests that are new in WoW Forever
            enabled = true,
            position = "after",               -- "after" or "before" the quest name
            style = "icon",                   -- "icon" or "text"
            size = 12,
            color = { r = 0.60, g = 0.90, b = 0.95, a = 1 },
            tintTitle = false,
        },
        questOpenMode = "world",              -- "world", "classic", "both"
        questButtons = {
            mode = "off",                     -- "off", "hover", "always"
            size = 16,
            setActive = true,
            map = true,
            share = true,
            log = true,
        },
        itemButtonPlacement = "inside_right", -- "inside_right", "outside_left"
        itemButtonStrata = "MEDIUM",          -- "LOW", "MEDIUM", "HIGH", "DIALOG"
        itemButtons = {
            enabled = true,     -- Show usable quest item buttons
            size = 26,          -- Button size in pixels
            autoDetect = true,  -- Also detect usable quest items in bags
        },
        showTimerInObjectives = true,         -- Show countdown timer in quest objective descriptions
        onboardingCompleted = false,          -- First-time account onboarding wizard status
        collapsedQuests = {},     -- [questID or title] = true when user collapsed the quest
        collapsedZones = {},      -- [zoneName] = true when user collapsed a zone header
        activeQuestIcon = "star", -- "star", "arrow", "blizz", "pointer", "none"
        configWindow = {},

        -- Modular Architecture (Live Enable/Disable)
        modules = {
            wayfinder = true,
            databars = true,
            questAutomation = true,
            qol = true,
        },

        -- Quest Automation
        questAutomation = {
            autoAcceptNPC = false,
            autoAcceptShared = false,
            autoTurnIn = false,
            autoShare = false,
            shiftBypass = true,
        },

        -- Quality of Life
        qol = {
            fastAutoLoot = true,   -- Only speeds up looting when the game's auto loot is active
            autoSellJunk = false,
            autoRepair = false,
            useGuildRepair = false,
            shiftBypass = true,
        },

        -- Headers Configuration
        headers = {
            texture = "flat",              -- "none", "flat", "gradient", "blizzard"
            statusbarTexture = "Solid",
            textureColor = { r = 0.05, g = 0.08, b = 0.12, a = 0.85 },
            textureColorShare = false,
            textColor = nil,               -- Defaults dynamically to player's Class Color
            textColorShare = false,
            buttonColor = nil,             -- Defaults dynamically to player's Class Color
            buttonColorShare = false,
            countFormat = "short",         -- "none", "short", "full"
            collapsedText = "counter",     -- "none", "counter", "title"
            showQuestLogBtn = true,
            showZoneBtn = true,
            showAllBtn = true,
            showMenuBtn = true,
            showCollapseBtn = true,

            showZoneHeaders = true,
            showZoneCount = true,
            zoneHeaderTexture = "gradient",
            zoneHeaderColor = { r = 1.0, g = 0.82, b = 0.0, a = 1.0 },
            zoneTextColor = nil,
            zoneHeaderColorShare = false,
            showCompleteIcon = true,
            separateClassHeader = true,
            zoneCollapseIcon = "arrow",    -- "arrow", "plusminus", "none"
            zoneCollapseIconColor = nil,
        },

        -- Appearance & Backdrop
        backdrop = {
            show = true,
            borderStyle = "flat", -- "flat", "tooltip", "dialog", "toast", "thin", "none"
            bgTexture = "solid",  -- "solid", "tooltip", "marble", "rock", "parchment", "parchment_clean"
            edgeSize = 1,
            borderWidth = 1,
            insets = 0,
            bgColor = { r = 0.05, g = 0.05, b = 0.05, a = 0.65 },
            borderColor = { r = 0.15, g = 0.15, b = 0.15, a = 0.9 },
            classColorBorder = false,
            padding = 8,
        },

        -- Typography
        fonts = {
            font = "Nata Sans Bold",
            headerFont = "Nata Sans Bold",
            headerSize = 13,
            headerOutline = "OUTLINE",
            zoneHeaderSize = 12,
            objectiveFont = "Nata Sans Regular",
            objectiveSize = 11,
            objectiveOutline = "",
            enableTextShadow = true,
            colorDifficulty = true,
            titleColor = { r = 1.00, g = 0.82, b = 0.00 },
            objectiveColor = { r = 0.80, g = 0.80, b = 0.80 },
            completedObjectiveColor = { r = 0.00, g = 1.00, b = 0.00 },
            menuScale = 1.0,
            completedQuestBg = true,
            completedQuestBgColor = { r = 0.00, g = 0.80, b = 0.20, a = 0.14 },
            completedTitleColorMode = "difficulty", -- "difficulty", "turnin", "custom"
            completedTitleCustomColor = { r = 0.00, g = 1.00, b = 0.00 },
            questHoverColor = { r = 1.00, g = 1.00, b = 1.00, a = 0.08 },
            zoneHoverColor = { r = 1.00, g = 0.82, b = 0.00, a = 0.12 },
        },

        -- Filtering & Behavior
        filtering = {
            filterMode = "all", -- "all", "zone", "watched"
            enableCrossZone = true,
            autoHideInInstances = false,
            autoHideEmpty = false,
            collapseInCombat = false,
            hideInCombat = false,
            untrackedQuests = {},
            alwaysShowClassQuests = true,
        },

        -- Sorting
        sorting = {
            mode = "level", -- "level", "zone"
            moveCompletedToBottom = false,
            activeOnTop = true,
            showGroupTags = true,
            leftClickSetsActive = false,
            doubleClickSetsActive = true, -- double-click a quest to make it active
            alignQuestTitles = true,
        },

        -- Party announcements (automation lives in questAutomation / qol)
        social = {
            announceToParty = false,
            announceQuestComplete = true,
            announceObjectiveProgress = false,
            announceObjectiveComplete = true,
        },

        -- Tooltips & Mouseover Rewards
        tooltips = {
            showRewards = true,
            showXpPercent = true,
            showUsableGear = true,
            showBestSell = true,
            showPartyStatus = true,
            showMissingParty = true,
            classColorParty = true,
            showPartyBadge = false,
        },

        -- Audio & Sounds
        sound = {
            enableCompleteSound = true,
            soundChoice = "peon",
            customSoundsList = {},
            completeSoundChannel = "Master",
            completeSoundVolume = 100,
            enableObjectiveSound = true,
            objectiveSoundChoice = "whisper_ping",
            objectiveSoundChannel = "Master",
            objectiveSoundVolume = 100,
        },

        -- Wayfinder (Waypoint Navigation & Directional Arrows)
        wayfinder = {
            enableHUDArrow = true,
            enableInlineArrow = true,
            inlineArrowPosition = "left", -- "left" or "right"
            inlineArrowSize = 22,         -- 14 to 32
            autoTrackActiveQuest = true,
            showDistance = true,
            distanceUnit = "imperial",    -- "imperial" or "metric"
            arrowScale = 1.0,
            textDistance = 12,
            arrivalThreshold = 15,
            arrivalClearDelay = 5,
            playArrivalSound = true,
            hudPosition = nil,
            locked = false,
            showBackdrop = false,
            arrowStyle = "auto",          -- "auto", "minimal", "classic", "3d_modern", "3d_classic"
            hideInCombat = true,
            showETA = false,
            showMapPins = true,
            showCoordinates = false,
            savedWaypoints = {},
            hudFontSize = 11,
            hudFontOutline = "OUTLINE",
            showDestination = true,
            hudTitleFormat = "zone",      -- "zone", "quest", "both"
            hudTitleFontSize = 11,
            hudTitleFontOutline = "OUTLINE",
            arrowAheadColor = { r = 0.10, g = 1.00, b = 0.20, a = 1.0 },
            arrowAngleColor = { r = 1.00, g = 0.85, b = 0.10, a = 1.0 },
            arrowBehindColor = { r = 1.00, g = 0.25, b = 0.25, a = 1.0 },
            arrowArrivedColor = { r = 0.10, g = 1.00, b = 0.20, a = 1.0 },
            destTextColor = { r = 1.00, g = 0.82, b = 0.00, a = 1.0 },
            distTextColor = { r = 1.00, g = 1.00, b = 1.00, a = 1.0 },
        },

        -- DataBars: XP / Location / Quest Timer
        databars = {
            hideInCombat = false,
            hideWithTracker = true,
            useTrackerAppearance = true,
            dockSpacing = 0,
            enableXPBar = false,
            xpDockMode = "tracker_bottom",     -- "tracker_bottom", "default_bar", "free"
            xpHeight = 14,
            xpWidth = 512,
            xpFontSize = 11,
            xpFontOutline = "OUTLINE",
            xpBorderStyle = "flat",
            xpBorderWidth = 1,
            xpBorderColor = { r = 0.12, g = 0.12, b = 0.16, a = 0.95 },
            xpBgTexture = "solid",
            xpBarTexture = "Solid",
            hideBlizzardXPBar = true,
            showCompletedQuestXP = true,
            showAllQuestXP = false,
            hideQuestXPText = false,
            showDingReadyText = true,
            showRestedXP = true,
            showReputationAtMax = true,
            xpTextFormat = "smart",            -- "smart", "cur_max", "cur_pct", "remain", "none"
            xpFreePosition = nil,
            xpBgColor = { r = 0.05, g = 0.05, b = 0.05, a = 0.65 },
            xpColor = { r = 0.58, g = 0.00, b = 0.83, a = 1.00 },
            restedColor = { r = 0.00, g = 0.44, b = 0.88, a = 1.00 },
            allQuestXPColor = { r = 0.12, g = 0.45, b = 0.25, a = 0.80 },
            questXPColor = { r = 0.25, g = 0.85, b = 0.45, a = 0.65 },
            dingReadyColor = { r = 1.00, g = 0.82, b = 0.00, a = 1.00 },

            enableLocationBar = false,
            locDockMode = "tracker_top",       -- "tracker_top", "minimap_top", "free"
            locHeight = 22,
            locWidth = 280,
            locFontSize = 11,
            locFontOutline = "OUTLINE",
            locBorderStyle = "flat",
            locBorderWidth = 1,
            locBgTexture = "solid",
            locBgColor = { r = 0.06, g = 0.08, b = 0.12, a = 0.90 },
            locBorderColor = { r = 0.15, g = 0.55, b = 0.95, a = 0.85 },
            locCustomTextColor = false,
            locTextColor = { r = 1.00, g = 0.82, b = 0.00, a = 1.00 },
            coordsColor = { r = 1.00, g = 1.00, b = 1.00, a = 1.00 },
            hideMinimapHeader = true,
            colorTerritory = true,
            showSubzone = true,
            locFormat = "subzone_only",        -- "subzone_only", "smart", "zone_only", "both"
            showCoords = true,
            locFreePosition = nil,

            enableTimerBar = true,
            timerDockMode = "tracker_top",     -- "tracker_top", "tracker_bottom", "free"
            timerHeight = 22,
            timerWidth = 220,
            timerFontSize = 11,
            timerFontOutline = "OUTLINE",
            timerBorderStyle = "flat",
            timerBorderWidth = 1,
            timerBgTexture = "solid",
            timerBgColor = { r = 0.06, g = 0.08, b = 0.12, a = 0.90 },
            timerBorderColor = { r = 1.00, g = 0.82, b = 0.00, a = 0.85 },
            timerBarTexture = "Solid",
            timerShowTitle = true,
            timerFreePosition = nil,
            timerColor = { r = 1.00, g = 0.82, b = 0.00, a = 1.00 },
            timerMaxValues = {},
        },
    },
}

-- Recursive table copy for defaults merging (fills only missing keys)
local function CopyDefaults(src, dest)
    if type(src) ~= "table" then return {} end
    if type(dest) ~= "table" then dest = {} end
    for k, v in pairs(src) do
        if type(v) == "table" then
            dest[k] = CopyDefaults(v, dest[k])
        elseif dest[k] == nil then
            dest[k] = v
        end
    end
    return dest
end
ns.CopyDefaults = CopyDefaults

-- Full recursive deep copy
local function DeepCopy(src)
    if type(src) ~= "table" then return src end
    local copy = {}
    for k, v in pairs(src) do
        copy[k] = DeepCopy(v)
    end
    return copy
end
ns.DeepCopy = DeepCopy

-- ---------------------------------------------------------------------------
-- Internal callback bus
-- ---------------------------------------------------------------------------
ns.callbacks = {}

function ns:RegisterCallback(event, func)
    local list = self.callbacks[event]
    if not list then
        list = {}
        self.callbacks[event] = list
    end
    table_insert(list, func)
end

function ns:FireCallback(event, ...)
    local list = self.callbacks[event]
    if list then
        for i = 1, #list do
            list[i](...)
        end
    end
end

-- ---------------------------------------------------------------------------
-- Module Management System
-- ---------------------------------------------------------------------------
ns.modules = {}

local moduleKeyMap = {
    WayfinderModule = "wayfinder",
    DataBarsModule = "databars",
    QuestAutomationModule = "questAutomation",
    QoLModule = "qol",
}

function ns:RegisterModule(name, moduleTable)
    if not name or type(moduleTable) ~= "table" then return end
    self.modules[name] = moduleTable
    moduleTable.name = name
end

function ns:GetModule(name)
    return self.modules[name]
end

function ns.IsModuleEnabled(moduleKey)
    local mods = ns.db and ns.db.modules
    if not mods then return true end
    local key = moduleKeyMap[moduleKey] or moduleKey
    return mods[key] ~= false
end

local function GetModuleInstance(key)
    if key == "wayfinder" then return ns.WayfinderModule end
    if key == "databars" then return ns.DataBarsModule end
    if key == "questAutomation" then return ns.QuestAutomationModule end
    if key == "qol" then return ns.QoLModule end
end

local function ReportError(context, err)
    local handler = geterrorhandler and geterrorhandler()
    if handler then
        handler(string_format("%s: %s", context, tostring(err)))
    end
end

function ns.SetModuleEnabled(moduleKey, enabled)
    if not ns.db then return end
    ns.db.modules[moduleKey] = enabled and true or false

    local mod = GetModuleInstance(moduleKey)
    if not mod then return end
    local fn = enabled and (mod.Enable or mod.Initialize) or mod.Disable
    if fn then
        local ok, err = pcall(fn, mod)
        if not ok then ReportError(addonName .. " module " .. moduleKey, err) end
    end
end

function ns:InitializeModules()
    for name, mod in pairs(self.modules) do
        local key = moduleKeyMap[name]
        local isEnabled = (not key) or ns.IsModuleEnabled(key)
        if isEnabled and type(mod.Initialize) == "function" then
            local ok, err = pcall(mod.Initialize, mod)
            if not ok then
                ReportError(addonName .. " failed to initialize module '" .. name .. "'", err)
            end
        end
    end
end

-- ---------------------------------------------------------------------------
-- Settings Migrations
-- Steps run once per saved profile, directly on the raw SavedVariables tables
-- (before AceDB fills in defaults) so only values the player actually chose are
-- touched. Progress is tracked with profile.dbVersion.
-- ---------------------------------------------------------------------------
local function Sub(t, key)
    local v = t[key]
    if type(v) ~= "table" then return nil end
    return v
end

local function Ensure(t, key)
    local v = t[key]
    if type(v) ~= "table" then
        v = {}
        t[key] = v
    end
    return v
end

-- Player sound files renamed from .wav to .ogg by migration 3 (shown in a one-time notice)
local convertedWavSounds = {}
local BUNDLED_SOUND_FILES = {
    ["beep.wav"] = true, ["click.wav"] = true, ["custom1.wav"] = true, ["custom2.wav"] = true,
    ["custom3.wav"] = true, ["custom4.wav"] = true, ["custom5.wav"] = true,
}

-- "fart.wav" -> "fart.ogg" (also inside "custom:fart.wav"); notes the player's own files
local function WavToOgg(value)
    if type(value) ~= "string" or not value:lower():find("%.wav$") then return value end
    local file = value:gsub("^custom:", ""):gsub("^.*[\\/]", "")
    if not BUNDLED_SOUND_FILES[file:lower()] then
        convertedWavSounds[file:lower()] = file
    end
    return value:sub(1, -5) .. ".ogg"
end

local MIGRATIONS = {
    -- v1: one-time cleanup of settings from releases before 1.2.0
    [1] = function(p)
        local sorting = Sub(p, "sorting")
        if sorting and sorting.mode == "distance" then
            sorting.mode = "level"
        end

        -- Legacy position fields -> framePosition
        if not p.framePosition and (p.xOfs or (p.point and p.point ~= "TOPRIGHT")) then
            p.framePosition = {
                point = p.point or "TOPRIGHT",
                relativePoint = p.relativePoint or p.point or "TOPRIGHT",
                x = p.xOfs or -250,
                y = p.yOfs or -200,
            }
        end
        p.point, p.relativePoint, p.xOfs, p.yOfs = nil, nil, nil, nil

        -- Quest item placement: fold legacy left/right options into the two supported placements
        local legacy = Sub(p, "itemButtons")
        local placement = p.itemButtonPlacement
        if legacy and legacy.position == "right" and (placement == nil or placement == "outside_left") then
            placement = "inside_right"
        elseif legacy and legacy.position == "left" and placement == nil then
            placement = "outside_left"
        end
        if placement == "inside_left" then
            placement = "outside_left"
        elseif placement == "outside_right" then
            placement = "inside_right"
        end
        if placement ~= nil and placement ~= "outside_left" and placement ~= "inside_right" then
            placement = nil
        end
        p.itemButtonPlacement = placement

        -- Legacy cyan header defaults now follow the class color
        local h = Sub(p, "headers")
        if h then
            local tc = h.textColor
            if type(tc) == "table" and tc.r == 0.0 and tc.g and math_abs(tc.g - 0.75) < 0.01 and tc.b == 1.0 then
                h.textColor = nil
            end
            local bc = h.buttonColor
            if type(bc) == "table" and bc.r == 0.0 and bc.g and math_abs(bc.g - 0.75) < 0.01 and bc.b == 1.0 then
                h.buttonColor = nil
            end
        end

        local f = Sub(p, "fonts")
        if f then
            if f.objectiveOutline == "NONE" then f.objectiveOutline = "" end
            if f.headerOutline == "NONE" then f.headerOutline = "" end
            if f.font == "" then f.font = nil end
            if f.headerFont == "" then f.headerFont = nil end
            if f.objectiveFont == "" then f.objectiveFont = nil end
        end

        -- Legacy "custom" sound entries pointed at a secondary choice field
        local s = Sub(p, "sound")
        if s then
            if s.soundChoice == "custom" then
                local alt = s.customCompleteSoundChoice
                s.soundChoice = (alt and alt ~= "custom" and alt ~= "") and alt or nil
            end
            if s.objectiveSoundChoice == "custom" then
                local alt = s.customObjectiveSoundChoice
                s.objectiveSoundChoice = (alt and alt ~= "custom" and alt ~= "") and alt or nil
            end
            s.useCustomCompleteSound, s.useCustomObjectiveSound = nil, nil
            s.customCompleteSoundChoice, s.customObjectiveSoundChoice = nil, nil
            s.customCompleteSoundPath, s.customObjectiveSoundPath = nil, nil
        end
    end,

    -- v2 (1.2.0): one home for every setting
    [2] = function(p)
        -- Quest automation & fast loot used to be duplicated under "social"
        local social = Sub(p, "social")
        if social then
            local qa
            for _, key in ipairs({ "autoAcceptNPC", "autoAcceptShared", "autoTurnIn", "autoShare", "shiftBypass" }) do
                if social[key] ~= nil then
                    qa = qa or Ensure(p, "questAutomation")
                    if qa[key] == nil then
                        qa[key] = social[key]
                    end
                    social[key] = nil
                end
            end
            if social.fastAutoLoot ~= nil then
                local qol = Ensure(p, "qol")
                if qol.fastAutoLoot == nil then
                    qol.fastAutoLoot = social.fastAutoLoot
                end
                social.fastAutoLoot = nil
            end
        end

        -- Junk selling had two aliases
        local qol = Sub(p, "qol")
        if qol then
            if qol.autoVendorGreys == true then
                qol.autoSellJunk = true
            end
            qol.autoVendorGreys = nil
        end

        -- Quest item placement aliases were folded into itemButtonPlacement (v1)
        local items = Sub(p, "itemButtons")
        if items then
            items.position, items.placement = nil, nil
        end

        local bars = Sub(p, "databars")
        if bars then
            if bars.replaceBlizzardXP == false then
                bars.hideBlizzardXPBar = false
            end
            bars.replaceBlizzardXP = nil
            bars.timerActiveQuests = nil
        end

        -- Zone filter flag -> filterMode
        local filtering = Sub(p, "filtering")
        if filtering then
            if filtering.zoneOnly and filtering.filterMode == nil then
                filtering.filterMode = "zone"
            end
            filtering.zoneOnly = nil
        end

        -- Keep the player's arrow size; only clamp it to the supported range (14 - 32)
        local wf = Sub(p, "wayfinder")
        if wf then
            local size = tonumber(wf.inlineArrowSize)
            if size then
                wf.inlineArrowSize = math_max(14, math_min(32, size))
            end
            wf.initialized = nil
        end
    end,

    -- v3: sounds must be .ogg or .mp3; .wav names now point at an .ogg of the same name
    [3] = function(p)
        local s = Sub(p, "sound")
        if not s then return end
        s.soundChoice = WavToOgg(s.soundChoice)
        s.objectiveSoundChoice = WavToOgg(s.objectiveSoundChoice)
        if type(s.customSoundsList) == "table" then
            for i, entry in ipairs(s.customSoundsList) do
                if type(entry) == "table" then
                    entry.file = WavToOgg(entry.file)
                else
                    s.customSoundsList[i] = WavToOgg(entry)
                end
            end
        end
    end,
}

local function MigrateRawProfile(profile)
    if type(profile) ~= "table" then return end
    local version = tonumber(profile.dbVersion) or 0
    for v = version + 1, ns.DB_VERSION do
        local step = MIGRATIONS[v]
        if step then
            local ok, err = pcall(step, profile)
            if not ok then ReportError(addonName .. " settings migration v" .. v, err) end
        end
    end
    profile.dbVersion = ns.DB_VERSION
end

local VALID_ARROW_STYLES = { auto = true, minimal = true, classic = true, ["3d_modern"] = true, ["3d_classic"] = true }

-- Repairs invalid values on the live profile (never resets a valid user choice)
local function ValidateProfile(profile)
    if not profile then return end
    if rawget(profile, "dbVersion") == nil then
        profile.dbVersion = ns.DB_VERSION -- brand-new profile: nothing to migrate
    end
    local wf = profile.wayfinder
    if wf and not VALID_ARROW_STYLES[wf.arrowStyle] then
        wf.arrowStyle = "auto"
    end
    local placement = profile.itemButtonPlacement
    if placement ~= "outside_left" and placement ~= "inside_right" then
        profile.itemButtonPlacement = "inside_right"
    end
end

-- ---------------------------------------------------------------------------
-- Database Initialization (SavedVariables are available at our ADDON_LOADED)
-- ---------------------------------------------------------------------------
local function OnProfileChanged()
    ns.db = ns.dbObject.profile
    ValidateProfile(ns.db)
    ns:FireCallback("PROFILE_CHANGED")
    ns:FireCallback("SETTINGS_UPDATED")
    ns:FireCallback("QUEST_DATA_CHANGED")
end

-- One-time popup naming the player's .wav sound files that must be converted to .ogg
StaticPopupDialogs["NQT_WAV_SOUNDS"] = {
    text = "%s",
    button1 = OKAY,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

function ns.ShowWavSoundNotice()
    local files = {}
    for _, name in pairs(convertedWavSounds) do files[#files + 1] = name end
    if type(NullgateCustomSounds) == "table" then
        for _, entry in ipairs(NullgateCustomSounds) do
            local file = type(entry) == "table" and entry.file or entry
            if type(file) == "string" and file:lower():find("%.wav$") then
                file = file:gsub("^.*[\\/]", "")
                if not convertedWavSounds[file:lower()] then files[#files + 1] = file end
            end
        end
    end
    if #files == 0 or ns.dbObject.global.wavNoticeShown then return end
    ns.dbObject.global.wavNoticeShown = true
    table.sort(files)
    StaticPopup_Show("NQT_WAV_SOUNDS", string.format(
        L["Nullgate's Quest Tracker: custom sounds must now be .ogg or .mp3 files. Please convert these files in Media\\Sounds\\ to .ogg (same name), then restart the game:\n\n%s"],
        table.concat(files, "\n")))
end

-- The pre-rebrand add-on still installed (e.g. a copied Interface folder) would run a second tracker
local OLD_ADDON = "BleakfibersQuestTracker-Forever"

StaticPopupDialogs["NQT_OLD_ADDON"] = {
    text = "%s",
    button1 = L["Disable and Reload"],
    button2 = CANCEL,
    OnAccept = function()
        API.DisableAddOn(OLD_ADDON)
        ReloadUI()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

function ns.ShowOldAddonNotice()
    if not API.IsAddOnLoaded(OLD_ADDON) then return end
    StaticPopup_Show("NQT_OLD_ADDON", L["Bleakfiber's Quest Tracker is now Nullgate's Quest Tracker, and the old version is still installed. Running both shows two quest trackers. Disable the old one now, then delete the BleakfibersQuestTracker-Forever folder from Interface\\AddOns."])
end

local function InitializeDB()
    if ns.dbObject then return end

    local sv = _G["NullgatesQuestTrackerDB"]
    if type(sv) == "table" then
        -- Pre-AceDB single profile layout
        if type(sv.profile) == "table" then
            sv.profiles = sv.profiles or {}
            if not sv.profiles["Default"] or not next(sv.profiles["Default"]) then
                sv.profiles["Default"] = sv.profile
            end
            sv.profile = nil
        end
        -- Data that no longer belongs in SavedVariables
        sv.partyQuestData = nil
        sv.rawPosition = nil

        if type(sv.profiles) == "table" then
            for _, rawProfile in pairs(sv.profiles) do
                MigrateRawProfile(rawProfile)
            end
        end
    end

    local AceDB = LibStub("AceDB-3.0")
    -- "Default" as third argument ensures all characters share "Default" by default
    local dbObject = AceDB:New("NullgatesQuestTrackerDB", ns.defaultDB, "Default")
    ns.dbObject = dbObject
    ns.db = dbObject.profile

    ns.SetLanguage(dbObject.global.language)
    ValidateProfile(ns.db)

    dbObject.RegisterCallback(ns, "OnProfileChanged", OnProfileChanged)
    dbObject.RegisterCallback(ns, "OnProfileCopied", OnProfileChanged)
    dbObject.RegisterCallback(ns, "OnProfileReset", OnProfileChanged)

    if ns.pendingProfileSync then
        local pending = ns.pendingProfileSync
        ns.pendingProfileSync = nil
        SwitchToProfile(pending)
    end
end

-- ---------------------------------------------------------------------------
-- Color Picker Enhancements: Class Color, Faction Color, Pure Black & Hex Input
-- ---------------------------------------------------------------------------
local function HexFromRGB(r, g, b)
    return string_format("#%02X%02X%02X", math_floor(r * 255 + 0.5), math_floor(g * 255 + 0.5), math_floor(b * 255 + 0.5))
end

local function SetupColorPickerEnhancements()
    if not ColorPickerFrame or ColorPickerFrame.NullgateEnhanced then return end
    ColorPickerFrame.NullgateEnhanced = true

    local bar = CreateFrame("Frame", "NullgateColorPickerBar", ColorPickerFrame, BackdropTemplateMixin and "BackdropTemplate")
    bar:SetSize(310, 62)
    bar:SetPoint("TOP", ColorPickerFrame, "BOTTOM", 0, -3)

    if bar.SetBackdrop then
        bar:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = false, tileSize = 0, edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        bar:SetBackdropColor(0.06, 0.06, 0.08, 0.95)
        bar:SetBackdropBorderColor(0.35, 0.35, 0.40, 0.9)
    end

    local customHexEditBox

    local function ApplyColor(r, g, b)
        r = math_max(0, math_min(1, r))
        g = math_max(0, math_min(1, g))
        b = math_max(0, math_min(1, b))

        if customHexEditBox and not customHexEditBox:HasFocus() then
            customHexEditBox:SetText(HexFromRGB(r, g, b))
        end

        local a = 1
        if ColorPickerFrame.GetColorAlpha then
            local ok, val = pcall(ColorPickerFrame.GetColorAlpha, ColorPickerFrame)
            if ok and type(val) == "number" then a = val end
        end

        local colorObj = CreateColor and CreateColor(r, g, b, a)
        if colorObj and ColorPickerFrame.Content and ColorPickerFrame.Content.ColorPicker then
            local cp = ColorPickerFrame.Content.ColorPicker
            if cp.SetColorRGB then
                pcall(cp.SetColorRGB, cp, r, g, b)
            end
        end
        if ColorPickerFrame.SetColorRGB then
            pcall(ColorPickerFrame.SetColorRGB, ColorPickerFrame, r, g, b)
        end

        local hexBox = ColorPickerFrame.Content and ColorPickerFrame.Content.HexBox
        if hexBox and hexBox.SetText then
            pcall(hexBox.SetText, hexBox, HexFromRGB(r, g, b):sub(2))
            local onEnter = hexBox:GetScript("OnEnterPressed")
            if onEnter then
                pcall(onEnter, hexBox)
            end
        end

        -- Fire the color callbacks while GetColorRGB reports the chosen color
        local origGetColorRGB = ColorPickerFrame.GetColorRGB
        ColorPickerFrame.GetColorRGB = function() return r, g, b end
        local info = ColorPickerFrame.info
        if info and info.swatchFunc then
            pcall(info.swatchFunc)
        elseif ColorPickerFrame.swatchFunc then
            pcall(ColorPickerFrame.swatchFunc)
        elseif ColorPickerFrame.func then
            pcall(ColorPickerFrame.func)
        end
        ColorPickerFrame.GetColorRGB = origGetColorRGB
    end

    local function CreateSwatchButton(name, point, x, y, onClick, tooltipTitle, tooltipText)
        local btn = CreateFrame("Button", name, bar, "UIPanelButtonTemplate")
        btn:SetSize(146, 24)
        btn:SetPoint(point, bar, point, x, y)
        btn:SetText("")

        local border = btn:CreateTexture(nil, "BACKGROUND")
        border:SetSize(16, 16)
        border:SetPoint("LEFT", btn, "LEFT", 6, 0)
        border:SetColorTexture(0, 0, 0, 1)
        btn.swatchBorder = border

        local swatch = btn:CreateTexture(nil, "ARTWORK")
        swatch:SetSize(12, 12)
        swatch:SetPoint("CENTER", border, "CENTER", 0, 0)
        btn.swatch = swatch

        local label = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        label:SetPoint("LEFT", border, "RIGHT", 6, 0)
        label:SetPoint("RIGHT", btn, "RIGHT", -4, 0)
        label:SetJustifyH("LEFT")
        label:SetTextColor(1, 1, 1, 1)
        label:SetShadowColor(0, 0, 0, 1)
        label:SetShadowOffset(1, -1)
        btn.label = label

        btn:SetScript("OnClick", onClick)
        btn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine(tooltipTitle(), 1, 1, 1)
            GameTooltip:AddLine(tooltipText(), 0.85, 0.85, 0.85, true)
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
        return btn
    end

    local btnClass = CreateSwatchButton("NullgateColorPickerClassBtn", "TOPLEFT", 6, -5,
        function()
            local c = ns.GetClassColor()
            ApplyColor(c.r, c.g, c.b)
        end,
        function() return L["Set to Class Color"] end,
        function()
            local c = ns.GetClassColor()
            return string_format(L["Applies your %s color (%s) to this setting."], UnitClass("player") or "", HexFromRGB(c.r, c.g, c.b))
        end)

    local btnFaction = CreateSwatchButton("NullgateColorPickerFactionBtn", "TOPRIGHT", -6, -5,
        function()
            local c = ns.GetFactionColor()
            ApplyColor(c.r, c.g, c.b)
        end,
        function() return L["Set to Faction Color"] end,
        function()
            local c = ns.GetFactionColor()
            local _, localizedFaction = UnitFactionGroup("player")
            return string_format(L["Applies your %s color (%s) to this setting."], localizedFaction or "", HexFromRGB(c.r, c.g, c.b))
        end)

    local btnBlack = CreateSwatchButton("NullgateColorPickerBlackBtn", "BOTTOMLEFT", 6, 5,
        function()
            ApplyColor(0, 0, 0)
            if customHexEditBox then customHexEditBox:SetText("#000000") end
        end,
        function() return L["Set to Pure Black (#000000)"] end,
        function() return L["Instantly sets the color to solid black (#000000) for maximum visual contrast."] end)
    btnBlack.swatchBorder:SetColorTexture(0.65, 0.65, 0.65, 1)
    btnBlack.swatch:SetColorTexture(0, 0, 0, 1)
    btnBlack.label:SetText(L["Black (#000000)"])

    -- Direct Hex Input Box
    local hexContainer = CreateFrame("Frame", nil, bar, BackdropTemplateMixin and "BackdropTemplate")
    hexContainer:SetSize(146, 24)
    hexContainer:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", -6, 5)
    if hexContainer.SetBackdrop then
        hexContainer:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = false, tileSize = 0, edgeSize = 10,
            insets = { left = 2, right = 2, top = 2, bottom = 2 },
        })
        hexContainer:SetBackdropColor(0.03, 0.03, 0.05, 0.95)
        hexContainer:SetBackdropBorderColor(0.50, 0.42, 0.20, 0.85)
    end

    local hexTitle = hexContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hexTitle:SetPoint("LEFT", hexContainer, "LEFT", 6, 0)
    hexTitle:SetText(L["Hex:"])

    local hexEdit = CreateFrame("EditBox", "NullgateColorPickerHexEdit", hexContainer)
    hexEdit:SetPoint("LEFT", hexTitle, "RIGHT", 4, 0)
    hexEdit:SetPoint("RIGHT", hexContainer, "RIGHT", -6, 0)
    hexEdit:SetHeight(20)
    hexEdit:SetAutoFocus(false)
    hexEdit:SetMaxLetters(7)
    hexEdit:SetFontObject("GameFontHighlightSmall")
    hexEdit:SetJustifyH("CENTER")
    customHexEditBox = hexEdit

    hexEdit:SetScript("OnEnterPressed", function(self)
        local r, g, b = ns.ParseHexColor(self:GetText())
        self:ClearFocus()
        if r then
            ApplyColor(r, g, b)
            self:SetText(HexFromRGB(r, g, b))
        end
    end)
    hexEdit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    hexEdit:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(L["Hex Color Code"], 1, 0.82, 0)
        GameTooltip:AddLine(L["Type any hex color (e.g. #000000) and press Enter to apply."], 0.9, 0.9, 0.9, true)
        GameTooltip:Show()
    end)
    hexEdit:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local function PositionBar()
        bar:ClearAllPoints()
        local bottom = ColorPickerFrame:GetBottom()
        if bottom and bottom < 75 then
            bar:SetPoint("BOTTOM", ColorPickerFrame, "TOP", 0, 3)
        else
            bar:SetPoint("TOP", ColorPickerFrame, "BOTTOM", 0, -3)
        end
    end

    ColorPickerFrame:HookScript("OnShow", function()
        PositionBar()
        local c = ns.GetClassColor()
        btnClass.swatch:SetColorTexture(c.r, c.g, c.b, 1)
        btnClass.label:SetText(string_format(L["Class: %s"], UnitClass("player") or ""))

        local f = ns.GetFactionColor()
        local _, localizedFaction = UnitFactionGroup("player")
        btnFaction.swatch:SetColorTexture(f.r, f.g, f.b, 1)
        btnFaction.label:SetText(string_format(L["Faction: %s"], localizedFaction or ""))

        if ColorPickerFrame.GetColorRGB and not hexEdit:HasFocus() then
            local ok, r, g, b = pcall(ColorPickerFrame.GetColorRGB, ColorPickerFrame)
            if ok and type(r) == "number" then
                hexEdit:SetText(HexFromRGB(r, g, b))
            end
        end
    end)
    if ColorPickerFrame:HasScript("OnColorSelect") then
        ColorPickerFrame:HookScript("OnColorSelect", function(_, r, g, b)
            if not hexEdit:HasFocus() and type(r) == "number" then
                hexEdit:SetText(HexFromRGB(r, g, b))
            end
        end)
    end
    if ColorPickerFrame:HasScript("OnMouseUp") then
        ColorPickerFrame:HookScript("OnMouseUp", PositionBar)
    end
end
ns.SetupColorPickerEnhancements = SetupColorPickerEnhancements

-- Parses "#RGB", "#RRGGBB" or "RRGGBB" into 0..1 components (nil when invalid)
function ns.ParseHexColor(text)
    local raw = (text or ""):gsub("%s+", ""):gsub("^#", "")
    if #raw == 3 then
        raw = raw:sub(1, 1):rep(2) .. raw:sub(2, 2):rep(2) .. raw:sub(3, 3):rep(2)
    end
    if #raw ~= 6 then return nil end
    local r = tonumber(raw:sub(1, 2), 16)
    local g = tonumber(raw:sub(3, 4), 16)
    local b = tonumber(raw:sub(5, 6), 16)
    if not (r and g and b) then return nil end
    return r / 255, g / 255, b / 255
end

-- ---------------------------------------------------------------------------
-- Key binding migration: legacy named bindings -> secure CLICK bindings
-- ---------------------------------------------------------------------------
local LEGACY_BINDINGS = {
    BLEAKFIBER_USE_QUEST_ITEM = ns.BINDING_QUEST_ITEM,
    BLEAKFIBER_TOGGLE_TRACKER_VISIBILITY = ns.BINDING_TOGGLE_TRACKER,
}

local function MigrateKeyBindings()
    if not (GetBindingKey and SetBinding) then return true end
    if InCombatLockdown() then return false end
    local changed = false
    for oldName, newName in pairs(LEGACY_BINDINGS) do
        local k1, k2 = GetBindingKey(oldName)
        if (k1 or k2) and not GetBindingKey(newName) then
            if k1 then SetBinding(k1, newName) end
            if k2 then SetBinding(k2, newName) end
            changed = true
        end
    end
    if changed and SaveBindings and GetCurrentBindingSet then
        SaveBindings(GetCurrentBindingSet())
    end
    return true
end

-- ---------------------------------------------------------------------------
-- Main Event Engine
-- ---------------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

local bindingsMigrated = false

eventFrame:SetScript("OnEvent", function(self, event, arg1, ...)
    if event == "ADDON_LOADED" then
        if arg1 == addonName then
            InitializeDB()
        elseif arg1 == "NullgatesAddonConfig-Forever" or arg1 == "NullgatesAddonConfigForever" then
            if ns.dbObject then
                PublicAPI:RegisterWithMasterConfig()
            end
        end

    elseif event == "PLAYER_LOGIN" then
        InitializeDB()

        -- Tracker container frame first, then the modules that hook into it
        if ns.Tracker and ns.Tracker.Initialize then
            ns.Tracker:Initialize()
        end
        ns:InitializeModules()
        ns:FireCallback("ON_INITIALIZE")

        bindingsMigrated = MigrateKeyBindings()
        if not bindingsMigrated then
            self:RegisterEvent("PLAYER_REGEN_ENABLED")
        end

        PublicAPI:RegisterWithMasterConfig()
        ns.PurgeInvalidTimerCache()

        if ns.Onboarding and ns.Onboarding.CheckFirstTimeUser then
            C_Timer.After(1.5, function()
                ns.Onboarding:CheckFirstTimeUser()
            end)
        end
        C_Timer.After(3, ns.ShowWavSoundNotice)
        C_Timer.After(4, ns.ShowOldAddonNotice)

    elseif event == "PLAYER_REGEN_ENABLED" then
        if not bindingsMigrated then
            bindingsMigrated = MigrateKeyBindings()
        end
        if bindingsMigrated then
            self:UnregisterEvent("PLAYER_REGEN_ENABLED")
        end

    elseif event == "PLAYER_ENTERING_WORLD" then
        ns:FireCallback("PLAYER_ENTERING_WORLD", ...)
        if ns.db then
            ns.PurgeInvalidTimerCache()
        end
    end
end)
