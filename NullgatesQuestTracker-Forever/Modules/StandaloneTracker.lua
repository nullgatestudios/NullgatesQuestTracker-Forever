local addonName, ns = ...

-- Localized Lua & WoW API bindings for performance & garbage reduction
local pairs, ipairs, type, tostring, tonumber = pairs, ipairs, type, tostring, tonumber
local string_format, string_lower = string.format, string.lower
local table_insert, table_sort, table_remove = table.insert, table.sort, table.remove
local math_floor, math_ceil, math_max, math_min = math.floor, math.ceil, math.max, math.min
local InCombatLockdown = InCombatLockdown
local CreateFrame = CreateFrame

local API = ns.API
local L = ns.L
local wipe = ns.wipe

local StandaloneTracker = {}
ns.StandaloneTracker = StandaloneTracker
ns:RegisterModule("StandaloneTracker", StandaloneTracker)

-- Frame & FontString Pools
local questBlocks = {}
local objectiveStrings = {}
local partyStrings = {}
local shareButtons = {}
local zoneHeaders = {}

-- Static Data Recycling Pools (Zero-Garbage Collection)
local questEntryPool = {}
local cachedTrackedQuests = {}
local zoneMap = {}
local zoneOrder = {}
local initialOrder = {}
local zoneListPool = {}
local itemQuests = {}
local timerBlocks = {}
local rowInfo = {}
local levelInfo = {}
StandaloneTracker.cachedTrackedQuests = cachedTrackedQuests
-- Content offsets where each zone header / quest row starts and ends (read by TrackerFrame)
StandaloneTracker.rowStarts = {}
StandaloneTracker.rowEnds = {}

-- Internal zone placeholders (stored in collapsedZones; displayed localized)
local ZONE_GENERAL = "General"
local ZONE_OTHER = "Other Quests"

local function AcquireQuestEntry()
    local entry = table_remove(questEntryPool)
    if not entry then
        return { objectives = {} }
    end
    local objs = entry.objectives
    wipe(entry)
    entry.objectives = objs or {}
    return entry
end

local function ReleaseQuestEntries(list)
    for i = #list, 1, -1 do
        local entry = list[i]
        list[i] = nil
        if entry then
            if entry.objectives then
                API.ReleaseObjectives(entry.objectives)
            end
            table_insert(questEntryPool, entry)
        end
    end
end

local function CleanOutline(outline)
    if not outline or outline == "" or outline == "NONE" or outline == "nil" then
        return nil
    end
    return outline
end

local function SafeSetFont(fs, fontPath, fontSize, outline, enableShadow)
    if not fs or not fontPath then return end
    fontSize = tonumber(fontSize) or 11
    local clean = CleanOutline(outline)
    if clean then
        fs:SetFont(fontPath, fontSize, clean)
    else
        fs:SetFont(fontPath, fontSize, "")
    end
    if enableShadow == nil then
        enableShadow = not (ns.db and ns.db.fonts and ns.db.fonts.enableTextShadow == false)
    end
    if enableShadow then
        fs:SetShadowColor(0, 0, 0, 1.0)
        fs:SetShadowOffset(1, -1)
    else
        fs:SetShadowOffset(0, 0)
    end
end

local ColorToHex = ns.ColorToHex

-- Context Menu Frame for Quest Actions (legacy UIDropDownMenu fallback)
local questContextMenu = CreateFrame("Frame", "NullgateQuestContextMenu", UIParent, "UIDropDownMenuTemplate")

-- Custom Abandon Confirmation Dialog (text assigned at show time so it follows the chosen language)
StaticPopupDialogs["NQT_CONFIRM_ABANDON_QUEST"] = {
    text = "%s",
    button1 = YES,
    button2 = NO,
    OnAccept = function(self, data)
        if not data then return end
        local questID = data.questID or (data.questLogIndex and C_QuestLog and C_QuestLog.GetQuestIDForLogIndex and C_QuestLog.GetQuestIDForLogIndex(data.questLogIndex))
        if questID and C_QuestLog and C_QuestLog.SetSelectedQuest then
            C_QuestLog.SetSelectedQuest(questID)
        elseif data.questLogIndex and SelectQuestLogEntry then
            SelectQuestLogEntry(data.questLogIndex)
        end
        if C_QuestLog and C_QuestLog.SetAbandonQuest then
            C_QuestLog.SetAbandonQuest()
        elseif SetAbandonQuest then
            SetAbandonQuest()
        end
        if C_QuestLog and C_QuestLog.AbandonQuest then
            C_QuestLog.AbandonQuest()
        elseif AbandonQuest then
            AbandonQuest()
        end
        C_Timer.After(0.2, function()
            StandaloneTracker:RequestUpdate()
        end)
    end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
    preferredIndex = 3,
}

-- ---------------------------------------------------------------------------
-- Blizzard Quest Tracker suppression
-- The default tracker is moved under a permanently hidden parent (out of combat
-- only), which hides it and makes it non-interactive. No alpha tricks are used,
-- so Blizzard's quest item buttons can never become invisible-but-clickable.
-- ---------------------------------------------------------------------------
local hiddenBlizzardParent = CreateFrame("Frame")
hiddenBlizzardParent:Hide()
local blizzardHidePending = false

local function HideBlizzardTrackerFrame(f)
    if not f or f:GetParent() == hiddenBlizzardParent then return end
    if InCombatLockdown() then
        blizzardHidePending = true
        return
    end
    f._bfqReparenting = true
    f:SetParent(hiddenBlizzardParent)
    f._bfqReparenting = nil
    if not f._bfqParentHooked then
        f._bfqParentHooked = true
        hooksecurefunc(f, "SetParent", function(self, parent)
            if parent == hiddenBlizzardParent or self._bfqReparenting then return end
            if InCombatLockdown() then
                blizzardHidePending = true
                return
            end
            self._bfqReparenting = true
            self:SetParent(hiddenBlizzardParent)
            self._bfqReparenting = nil
        end)
    end
end

local function HookBlizzardTracker()
    blizzardHidePending = false
    HideBlizzardTrackerFrame(_G.QuestWatchFrame)
    HideBlizzardTrackerFrame(_G.ObjectiveTrackerFrame)
end
ns.HookBlizzardTracker = HookBlizzardTracker

-- ---------------------------------------------------------------------------
-- Quest title formatting
-- ---------------------------------------------------------------------------
local DEFAULT_TITLE_COLOR = { r = 1.0, g = 0.82, b = 0.0 }
local DEFAULT_COMPLETE_COLOR = { r = 0.0, g = 1.0, b = 0.0 }
local WHITE = { r = 1, g = 1, b = 1 }

local ACTIVE_ICONS = {
    star = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_1:13:13:0:0|t ",
    arrow = "|TInterface\\Common\\CommonIcons:13:13:0:0:2048:1024:573:728:266:516|t ",
    pointer = "|TInterface\\Common\\CommonIcons:13:13:0:0:2048:1024:573:728:266:516|t ",
    blizz = "|TInterface\\GossipFrame\\AvailableQuestIcon:13:13:0:0|t ",
    none = "",
}

-- Marker for quests that are new in WoW Forever (white texture, tinted via |T)
local FOREVER_MARKER_TEXTURE = "Interface\\AddOns\\" .. addonName .. "\\Media\\Textures\\forever_marker.tga"

-- Returns the marker string for a quest, or nil when it should not be marked
local function GetForeverMarker(questID)
    local cfg = ns.db.foreverMarker
    if not (cfg and cfg.enabled ~= false and API.IsForeverQuest(questID)) then return nil end
    local c = cfg.color or { r = 0.60, g = 0.90, b = 0.95 }
    local r, g, b = math_floor(c.r * 255 + 0.5), math_floor(c.g * 255 + 0.5), math_floor(c.b * 255 + 0.5)
    if cfg.style == "text" then
        return string_format("|cff%02x%02x%02x[%s]|r", r, g, b, L["F"])
    end
    local h = math_floor(tonumber(cfg.size) or 12)
    return string_format("|T%s:%d:%d:0:0:64:32:0:64:0:32:%d:%d:%d|t", FOREVER_MARKER_TEXTURE, h, h * 2, r, g, b)
end
StandaloneTracker.GetForeverMarker = GetForeverMarker

local function GetFormattedQuestTitle(questInfo, suppressPrefixIcons)
    local level = tonumber(questInfo.level) or 0
    local title = questInfo.title or L["Unknown Quest"]
    local db = ns.db
    local fonts = db.fonts
    local isComplete = questInfo.isComplete and not questInfo.isFailed
    local compMode = fonts.completedTitleColorMode or "difficulty"

    local hexColor
    if isComplete and compMode == "turnin" then
        hexColor = ColorToHex(fonts.completedObjectiveColor or DEFAULT_COMPLETE_COLOR)
    elseif isComplete and compMode == "custom" then
        hexColor = ColorToHex(fonts.completedTitleCustomColor or DEFAULT_COMPLETE_COLOR)
    elseif fonts.colorDifficulty ~= false then
        hexColor = ColorToHex(ns.GetDifficultyColor(level, nil, questInfo.questID) or WHITE)
    else
        hexColor = ColorToHex(fonts.titleColor or DEFAULT_TITLE_COLOR)
    end

    -- Elite / Group / Dungeon / Raid Badges
    local badge = ""
    if db.sorting.showGroupTags ~= false then
        if questInfo.isDungeon then
            badge = L["D"]
        elseif questInfo.isRaid then
            badge = L["R"]
        elseif questInfo.isElite then
            badge = "+"
        else
            local numGroup = tonumber(questInfo.suggestedGroup)
            if numGroup and numGroup > 1 then
                badge = "+" .. numGroup
            end
        end
    end

    local tag = ""
    local freq = tonumber(questInfo.frequency)
    if freq and freq > 1 then
        tag = " |cff00ccff[" .. L["Daily"] .. "]|r"
    end

    if db.tooltips.showPartyBadge and ns.SocialModule and ns.SocialModule.GetPartyQuestDetails then
        local partyDetails = ns.SocialModule:GetPartyQuestDetails(questInfo.questID, questInfo.questLogIndex)
        if partyDetails and partyDetails.onQuestCount > 0 then
            local groupIcon = "|TInterface\\QUESTFRAME\\QuestLogQuestTypeIcons2x:12:15:0:0:256:256:5:37:166:192|t"
            tag = tag .. string_format(" |cff00e5ff[%s%d]|r", groupIcon, partyDetails.onQuestCount)
        end
    end

    local activeMarker = ""
    if not suppressPrefixIcons and ns.activeQuestID and questInfo.questID == ns.activeQuestID then
        local showInline = ns.IsModuleEnabled("wayfinder") and db.wayfinder.enableInlineArrow
        if not (showInline and (db.wayfinder.inlineArrowPosition or "left") == "left") then
            activeMarker = ACTIVE_ICONS[db.activeQuestIcon or "star"] or ACTIVE_ICONS.star
        end
    end

    local completeMarker = ""
    if not suppressPrefixIcons and db.headers.showCompleteIcon ~= false and isComplete then
        local iconSize = math_max(12, StandaloneTracker.titleSize or 13)
        completeMarker = string_format("|TInterface\\GossipFrame\\ActiveQuestIcon:%d:%d:0:0|t ", iconSize, iconSize)
    end

    local levelPrefix = ""
    if level > 0 then
        levelPrefix = string_format("[%d%s] ", level, badge)
    elseif badge ~= "" then
        levelPrefix = string_format("[%s] ", badge)
    end

    -- New-in-Forever marker, before or after the quest name
    local preMarker, postMarker = "", ""
    local foreverMarker = GetForeverMarker(questInfo.questID)
    if foreverMarker then
        local cfg = db.foreverMarker
        if cfg.position == "before" then
            preMarker = foreverMarker .. " "
        else
            postMarker = " " .. foreverMarker
        end
        if cfg.tintTitle then
            hexColor = ColorToHex(cfg.color)
        end
    end

    if questInfo.isFailed then
        tag = tag .. " |cffff2020[" .. L["FAILED"] .. "]|r"
        return string_format("%s%s%s|cffff2020%s%s|r%s%s", activeMarker, completeMarker, preMarker, levelPrefix, title, postMarker, tag)
    end
    return string_format("%s%s%s%s%s%s|r%s%s", activeMarker, completeMarker, preMarker, hexColor, levelPrefix, title, postMarker, tag)
end

-- ---------------------------------------------------------------------------
-- FontString & button pools
-- ---------------------------------------------------------------------------
local function AcquireFromPool(pool, parent)
    for i = 1, #pool do
        local obj = pool[i]
        if not obj:IsShown() then
            obj:SetParent(parent)
            obj:Show()
            return obj
        end
    end
    return nil
end

local function AcquireObjectiveString(parent)
    local font = StandaloneTracker.objectiveFontPath or StandaloneTracker.fontPath
    local size = StandaloneTracker.objSize or 11
    local fs = AcquireFromPool(objectiveStrings, parent)
    if not fs then
        fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetJustifyH("LEFT")
        fs:SetWordWrap(true)
        table_insert(objectiveStrings, fs)
    end
    SafeSetFont(fs, font, size, StandaloneTracker.objOutline)
    return fs
end

-- Set or change the Active Quest (syncs with Blizzard SuperTrack if available)
function StandaloneTracker:SetActiveQuest(questID)
    if not questID or questID == 0 then
        ns.activeQuestID = nil
        ns.waypointExplicitlyCleared = true
        API.SetSuperTrackedQuestID(0)
        local wf = ns.WayfinderModule
        if wf and wf.ClearWaypoint and not (wf.IsCustomTarget and wf:IsCustomTarget()) then
            wf:ClearWaypoint(true)
        end
    else
        ns.waypointExplicitlyCleared = false
        ns.activeQuestID = questID
        API.SetSuperTrackedQuestID(questID)
        if ns.WayfinderModule and ns.WayfinderModule.SetQuestTarget then
            ns.WayfinderModule:SetQuestTarget(questID, true, true)
        end
    end
    self.lastWayfinderQuestID = ns.activeQuestID
    if ns.DataBarsModule and ns.DataBarsModule.UpdateTimerBar then
        ns.DataBarsModule:UpdateTimerBar()
    end
    self:RequestUpdate(true)
end

-- ---------------------------------------------------------------------------
-- Quest Item Buttons (secure)
--
--  NullgateQuestItemCombatLayer   visibility state driver ("Hide Tracker In Combat")
--    NullgateQuestItemBar         toggled securely by the "Toggle Tracker" key binding
--      NullgateQuestItemButton1..N  SecureActionButtonTemplate (type1 = item)
--
-- Buttons are positioned against UIParent using the quest header's screen
-- coordinates instead of being anchored to the tracker. Nothing in the
-- tracker is therefore protected, so the tracker keeps updating in combat.
-- Secure changes (attributes, position, show/hide) only happen out of combat.
-- ---------------------------------------------------------------------------
local combatLayer = CreateFrame("Frame", "NullgateQuestItemCombatLayer", UIParent, "SecureHandlerStateTemplate")
combatLayer:SetAllPoints(UIParent)
local itemBar = CreateFrame("Frame", "NullgateQuestItemBar", combatLayer, "SecureHandlerBaseTemplate")
itemBar:SetAllPoints(combatLayer)
StandaloneTracker.itemBar = itemBar

local combatDriverActive = false
local combatDriverPending = false

function StandaloneTracker:UpdateCombatVisibilityDriver()
    if InCombatLockdown() then
        combatDriverPending = true
        return
    end
    combatDriverPending = false
    local wantDriver = ns.db and ns.db.filtering and ns.db.filtering.hideInCombat
    if wantDriver and not combatDriverActive then
        RegisterStateDriver(combatLayer, "visibility", "[combat] hide; show")
        combatDriverActive = true
    elseif not wantDriver and combatDriverActive then
        UnregisterStateDriver(combatLayer, "visibility")
        combatLayer:Show()
        combatDriverActive = false
    end
end

-- Secure toggle used by the "Toggle Tracker Visibility" key binding.
-- The restricted snippet hides the item buttons even during combat, then
-- calls back into the (insecure) tracker to hide or show itself.
local toggleButton = CreateFrame("Button", "NullgateTrackerToggleButton", UIParent, "SecureHandlerClickTemplate")
toggleButton:RegisterForClicks("AnyUp")
toggleButton:SetAttribute("trackerShown", true)
SecureHandlerSetFrameRef(toggleButton, "itembar", itemBar)
toggleButton:SetAttribute("_onclick", [=[
    local shown = not self:GetAttribute("trackerShown")
    self:SetAttribute("trackerShown", shown)
    local bar = self:GetFrameRef("itembar")
    if bar then
        if shown then bar:Show() else bar:Hide() end
    end
    self:CallMethod("ApplyTrackerShown", shown)
]=])
function toggleButton:ApplyTrackerShown(shown)
    if not ns.Tracker then return end
    if shown then
        ns.Tracker:ShowTracker(true)
    else
        ns.Tracker:HideTracker(true)
    end
end

-- Keeps the secure toggle state & item bar in sync after non-keybind visibility changes
function StandaloneTracker:SyncSecureVisibility(trackerShown)
    if InCombatLockdown() then
        self.pendingItemUpdate = true
        return
    end
    toggleButton:SetAttribute("trackerShown", trackerShown and true or false)
    if trackerShown then
        itemBar:Show()
    else
        itemBar:Hide()
    end
end

local function SetButtonVisible(btn, visible)
    if InCombatLockdown() then
        StandaloneTracker.pendingItemUpdate = true
        return
    end
    if visible then
        btn:Show()
    else
        btn:Hide()
    end
end

function StandaloneTracker:GetOrCreateItemButton(index)
    index = index or 1
    self.itemButtons = self.itemButtons or {}
    if self.itemButtons[index] then return self.itemButtons[index] end

    if InCombatLockdown() then
        self.pendingItemUpdate = true
        return nil
    end

    local frameName = "NullgateQuestItemButton" .. index
    local btn = CreateFrame("Button", frameName, itemBar, "SecureActionButtonTemplate, BackdropTemplate")
    btn.buttonIndex = index
    btn:SetSize(26, 26)
    btn:SetFrameStrata((ns.db and ns.db.itemButtonStrata) or "MEDIUM")
    btn:SetFrameLevel(250)
    btn:SetClampedToScreen(true)
    btn:SetMovable(true)
    btn:EnableMouse(true)

    if btn.SetBackdrop then
        btn:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        })
        btn:SetBackdropColor(0, 0, 0, 0.85)
        btn:SetBackdropBorderColor(0.2, 0.2, 0.2, 1.0)
    end

    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetPoint("TOPLEFT", btn, "TOPLEFT", 1, -1)
    btn.icon:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -1, 1)
    btn.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    btn.cooldown = CreateFrame("Cooldown", frameName .. "Cooldown", btn, "CooldownFrameTemplate")
    btn.cooldown:SetAllPoints(btn.icon)
    btn.cooldown:EnableMouse(false)

    btn.count = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmallOutline")
    btn.count:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -2, 2)

    local hl = btn:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(btn.icon)
    hl:SetColorTexture(1, 1, 1, 0.25)
    btn:SetHighlightTexture(hl)

    -- Down + Up registration lets the template honour the "Cast on Key Down" option
    btn:RegisterForClicks("AnyDown", "AnyUp")

    btn:SetScript("OnEnter", function(s)
        GameTooltip:SetOwner(s, "ANCHOR_LEFT")
        GameTooltip:ClearLines()
        if s.isPreview then
            GameTooltip:AddLine(L["Test Quest Item Button"], 1, 0.82, 0)
            GameTooltip:AddLine(L["Click it or press your Quest Item Key to check that it works. It does not use any item."], 1, 1, 1, true)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("|cffaaaaaa" .. L["Shift + Right-Drag: Move button"] .. "|r", 0.6, 0.6, 0.6)
            GameTooltip:AddLine("|cffaaaaaa" .. L["Alt + Right-Click: Re-dock to tracker"] .. "|r", 0.6, 0.6, 0.6)
            GameTooltip:Show()
            return
        end
        if s.itemLink and type(s.itemLink) == "string" and s.itemLink:find("|Hitem:") then
            GameTooltip:SetHyperlink(s.itemLink)
        else
            GameTooltip:AddLine(L["Quest Item"], 1, 0.82, 0)
            if s.questTitle then
                GameTooltip:AddLine(s.questTitle, 1, 1, 1)
            end
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("|cff00ff00" .. L["Left-Click: Use quest item"] .. "|r", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("|cffaaaaaa" .. L["Shift + Right-Drag: Move button"] .. "|r", 0.6, 0.6, 0.6)
        GameTooltip:AddLine("|cffaaaaaa" .. L["Alt + Right-Click: Re-dock to tracker"] .. "|r", 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Free Repositioning via Shift + Right Drag (left click stays a secure item use)
    btn:RegisterForDrag("RightButton")
    btn:SetScript("OnDragStart", function(s)
        if InCombatLockdown() or not IsShiftKeyDown() then return end
        s.isMoving = true
        s:StartMoving()
    end)
    btn:SetScript("OnDragStop", function(s)
        if not s.isMoving then return end
        s.isMoving = false
        s:StopMovingOrSizing()
        local point, _, relPoint, x, y = s:GetPoint()
        ns.db.itemButtonPosition = {
            point = point or "TOPLEFT",
            relativePoint = relPoint or "TOPLEFT",
            x = math_floor((x or 0) + 0.5),
            y = math_floor((y or 0) + 0.5),
        }
        ns.Notify(L["Quest item button position saved. Alt + Right-Click to re-dock."])
    end)

    -- Alt + Right-Click resets docking
    btn:HookScript("OnMouseDown", function(_, mouseButton)
        if mouseButton == "RightButton" and IsAltKeyDown() and not InCombatLockdown() then
            ns.db.itemButtonPosition = nil
            ns.Notify(L["Quest item button re-docked to the tracker."])
            StandaloneTracker:UpdateItemButton()
        end
    end)

    -- Test button feedback (clicks and the CLICK key binding both arrive here)
    btn:HookScript("OnClick", function(s, mouseButton)
        if not s.isPreview or mouseButton ~= "LeftButton" then return end
        local now = GetTime()
        if s.lastPreviewClick and now - s.lastPreviewClick < 0.3 then return end
        s.lastPreviewClick = now
        s.cooldown:SetCooldown(now, 5)
        s.cooldown:Show()
        ns.Notify(L["Quest item button works!"], 0.2, 1.0, 0.2)
    end)

    btn:Hide()
    self.itemButtons[index] = btn
    if index == 1 then
        self.itemButton = btn
    end
    return btn
end

local function UpdateButtonCooldown(btn, itemID)
    if not btn.cooldown then return end
    if itemID then
        local start, duration = API.GetItemCooldown(itemID)
        if start and duration and duration > 0 then
            btn.cooldown:SetCooldown(start, duration)
            btn.cooldown:Show()
            return
        end
    end
    btn.cooldown:Hide()
end

-- Positions a button against UIParent using its quest header's screen rectangle.
-- Returns true when the header is inside the visible part of the tracker.
local function PlaceItemButton(btn, block, placement, topBound, bottomBound)
    local header = block and block.header
    if not header or not block:IsVisible() then return false end
    local hLeft, hRight, hTop, hBottom = header:GetLeft(), header:GetRight(), header:GetTop(), header:GetBottom()
    if not (hLeft and hRight and hTop and hBottom) then return false end

    local hScale = header:GetEffectiveScale()
    local bScale = btn:GetEffectiveScale()
    local ratio = hScale / bScale
    local centerY = (hTop + hBottom) / 2 * ratio
    local x
    if placement == "outside_left" then
        x = hLeft * ratio - 6
    else
        x = hRight * ratio - 4
    end
    btn:ClearAllPoints()
    btn:SetPoint("RIGHT", UIParent, "BOTTOMLEFT", x, centerY)

    if topBound and bottomBound then
        local half = (btn:GetHeight() or 26) / 2 * bScale
        local cyScreen = (hTop + hBottom) / 2 * hScale
        if cyScreen + half > topBound + 2 or cyScreen - half < bottomBound - 2 then
            return false
        end
    end
    return true
end

-- Visible vertical range of the tracker content in screen pixels
local function GetTrackerBounds()
    local tracker = ns.Tracker and ns.Tracker.frame
    if not tracker or not tracker:IsVisible() then return nil, nil end
    local header = tracker.header
    local scale = tracker:GetEffectiveScale()
    local top = (header and header:IsVisible() and header:GetBottom()) or tracker:GetTop()
    local bottom = tracker:GetBottom()
    if not top or not bottom then return nil, nil end
    return top * scale, bottom * scale
end

local function ShouldShowItemButtons()
    if not (ns.db and ns.db.itemButtons and ns.db.itemButtons.enabled ~= false) then return false end
    local tracker = ns.Tracker
    if not tracker or tracker.isCollapsed or tracker.isHidden then return false end
    return tracker.frame and tracker.frame:IsShown()
end

-- Test button: a fake item entry shown on the top quest so players can check
-- placement, size and the Quest Item Key without owning a quest item
local PREVIEW_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
local previewEntry = {}

function StandaloneTracker:SetItemPreview(enabled)
    if InCombatLockdown() then
        ns.Notify(ERR_NOT_IN_COMBAT or L["Not available in combat."], 1.0, 0.1, 0.1)
        return false
    end
    self.itemPreview = enabled and true or nil
    if enabled then
        local hasHost = false
        for _, q in ipairs(cachedTrackedQuests) do
            if q.questID and not q.itemID then hasHost = true break end
        end
        if not hasHost and not (ns.db and ns.db.itemButtonPosition) then
            ns.Notify(L["Track at least one quest without its own item to place the test button."], 1.0, 0.82, 0.0)
        elseif ns.db.itemButtons.enabled == false then
            ns.Notify(L["Quest item buttons are turned off in the settings."], 1.0, 0.82, 0.0)
        end
    end
    self:RequestUpdate(true)
    return true
end

-- Assigns item buttons to the visible quests that have usable items
function StandaloneTracker:UpdateItemButton(trackedQuests)
    trackedQuests = trackedQuests or cachedTrackedQuests
    local buttons = self.itemButtons or {}

    -- In combat only cosmetic state can change; secure assignments wait for PLAYER_REGEN_ENABLED
    if InCombatLockdown() then
        self.pendingItemUpdate = true
        self:UpdateItemButtonCooldowns()
        return
    end

    if not ShouldShowItemButtons() then
        for i = 1, #buttons do
            local btn = buttons[i]
            btn.parentBlock, btn.questID, btn.itemID = nil, nil, nil
            btn:Hide()
        end
        return
    end

    -- 1. Quests with items (active / super-tracked quest first)
    wipe(itemQuests)
    local activeID = ns.activeQuestID
    if not activeID then
        local stID = API.GetSuperTrackedQuestID()
        if stID and stID > 0 then activeID = stID end
    end
    local activeQ
    if activeID then
        for _, q in ipairs(trackedQuests) do
            if q.questID == activeID and q.itemID then
                activeQ = q
                itemQuests[1] = q
                break
            end
        end
    end
    for _, q in ipairs(trackedQuests) do
        if q.itemID and q ~= activeQ then
            itemQuests[#itemQuests + 1] = q
        end
    end
    if self.itemPreview then
        previewEntry.questID = self.previewHostID
        previewEntry.title = L["Test Quest Item Button"]
        table_insert(itemQuests, 1, previewEntry)
    end

    local db = ns.db
    local placement = db.itemButtonPlacement or "inside_right"
    local customPos = db.itemButtonPosition
    local strata = db.itemButtonStrata or "MEDIUM"
    local itemSize = (db.itemButtons and db.itemButtons.size) or 26
    local topBound, bottomBound = GetTrackerBounds()

    -- 2. Configure one button per item quest
    local previousShown
    for i, q in ipairs(itemQuests) do
        local btn = self:GetOrCreateItemButton(i)
        if not btn then break end

        local block = self.activeBlocks and q.questID and self.activeBlocks[q.questID]
        btn.parentBlock = block
        btn.questID = q.questID
        btn.itemID = q.itemID
        btn.itemLink = q.itemLink
        btn.questTitle = q.title
        btn.isPreview = (q == previewEntry)

        if btn.isPreview then
            -- No action attributes: the test button can never use a real item
            btn.icon:SetTexture(PREVIEW_ICON)
            btn.count:SetText("")
            btn:SetAttribute("type1", nil)
            btn:SetAttribute("item1", nil)
        else
            btn.icon:SetTexture(q.itemTexture)
            local count = tonumber(q.numItems) or 0
            btn.count:SetText(count > 1 and tostring(count) or "")
            UpdateButtonCooldown(btn, q.itemID)

            -- The item is resolved by ID at click time, so a used-up stack can never
            -- make the button use whatever item later lands in the same bag slot.
            local itemAttr = "item:" .. q.itemID
            if btn:GetAttribute("item1") ~= itemAttr then
                btn:SetAttribute("type1", "item")
                btn:SetAttribute("item1", itemAttr)
            end
        end

        btn:SetFrameStrata(strata)
        local level = 250
        if block and block.header then
            level = math_max(250, block.header:GetFrameLevel() + 50)
        end
        btn:SetFrameLevel(level)
        btn:SetSize(itemSize, itemSize)

        local visible
        if customPos then
            btn:ClearAllPoints()
            if previousShown then
                btn:SetPoint("TOP", previousShown, "BOTTOM", 0, -4)
            else
                btn:SetPoint(customPos.point or "TOPLEFT", UIParent, customPos.relativePoint or "TOPLEFT", customPos.x or 0, customPos.y or 0)
            end
            visible = true
        else
            visible = PlaceItemButton(btn, block, placement, topBound, bottomBound)
        end

        if visible then
            btn:Show()
            previousShown = btn
        else
            btn:Hide()
        end
    end

    -- 3. Release unused buttons
    for j = #itemQuests + 1, #buttons do
        local extra = buttons[j]
        extra.parentBlock, extra.questID, extra.itemID = nil, nil, nil
        extra:Hide()
    end
end

-- Dynamic Strata Updater (Live Options Sync)
function StandaloneTracker:UpdateItemButtonStrata()
    if InCombatLockdown() then
        self.pendingItemUpdate = true
        return
    end
    local strata = (ns.db and ns.db.itemButtonStrata) or "MEDIUM"
    for _, btn in ipairs(self.itemButtons or {}) do
        btn:SetFrameStrata(strata)
        local level = 250
        if btn.parentBlock and btn.parentBlock.header then
            level = math_max(250, btn.parentBlock.header:GetFrameLevel() + 50)
        end
        btn:SetFrameLevel(level)
    end
end

-- Lightweight Cooldown-Only Updater (Safe during combat lockdown)
function StandaloneTracker:UpdateItemButtonCooldowns()
    for _, btn in ipairs(self.itemButtons or {}) do
        if btn:IsShown() and btn.itemID then
            UpdateButtonCooldown(btn, btn.itemID)
        end
    end
end

-- Re-positions item buttons after scrolling, moving or resizing the tracker
function StandaloneTracker:UpdateItemButtonVisibility()
    if InCombatLockdown() then
        self.pendingItemUpdate = true
        return
    end
    local buttons = self.itemButtons
    if not buttons or #buttons == 0 or (ns.db and ns.db.itemButtonPosition) then return end
    if not ShouldShowItemButtons() then
        for i = 1, #buttons do buttons[i]:Hide() end
        return
    end
    local placement = ns.db.itemButtonPlacement or "inside_right"
    local topBound, bottomBound = GetTrackerBounds()
    for i = 1, #buttons do
        local btn = buttons[i]
        if btn.questID and btn.parentBlock then
            SetButtonVisible(btn, PlaceItemButton(btn, btn.parentBlock, placement, topBound, bottomBound))
        end
    end
end

-- Keeps docked item buttons glued to the tracker while it is being dragged
local dragFollower = CreateFrame("Frame")
dragFollower:Hide()
dragFollower:SetScript("OnUpdate", function(self)
    local tf = ns.Tracker and ns.Tracker.frame
    if not tf or not tf.isMoving or InCombatLockdown() then
        self:Hide()
    end
    StandaloneTracker:UpdateItemButtonVisibility()
end)

-- ---------------------------------------------------------------------------
-- Zone headers
-- ---------------------------------------------------------------------------
local function AcquireZoneHeader(parent)
    local fPath = StandaloneTracker.headerFontPath or StandaloneTracker.fontPath
    local zSize = StandaloneTracker.zoneHeaderSize or math_max(10, (StandaloneTracker.titleSize or 13) - 1)
    local outline = StandaloneTracker.titleOutline
    local shadow = StandaloneTracker.enableShadow

    local btn = AcquireFromPool(zoneHeaders, parent)
    if not btn then
        btn = CreateFrame("Button", nil, parent)
        btn:SetHeight(22)

        btn.bg = btn:CreateTexture(nil, "BACKGROUND")
        btn.bg:SetAllPoints(btn)

        btn.collapseText = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        btn.collapseText:SetPoint("LEFT", btn, "LEFT", 4, 0)
        btn.collapseText:SetWidth(20)
        btn.collapseText:SetJustifyH("CENTER")
        btn.collapseText:SetJustifyV("MIDDLE")
        btn.collapseText:SetWordWrap(false)

        btn.collapseArrow = btn:CreateTexture(nil, "OVERLAY")
        btn.collapseArrow:SetSize(12, 12)
        btn.collapseArrow:SetTexture("Interface\\Common\\CommonIcons")
        btn.collapseArrow:SetTexCoord(573/2048, 728/2048, 266/1024, 516/1024)
        btn.collapseArrow:SetPoint("LEFT", btn, "LEFT", 6, 0)

        btn.title = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        btn.title:SetPoint("LEFT", btn.collapseArrow, "RIGHT", 6, 0)
        btn.title:SetPoint("RIGHT", btn, "RIGHT", -6, 0)
        btn.title:SetJustifyH("LEFT")
        btn.title:SetJustifyV("MIDDLE")
        btn.title:SetWordWrap(true)

        btn.highlight = btn:CreateTexture(nil, "HIGHLIGHT")
        btn.highlight:SetAllPoints(btn)

        btn:RegisterForDrag("LeftButton")
        btn:SetScript("OnDragStart", function(self)
            self.wasDragged = true
            if ns.Tracker and ns.Tracker.StartDragging then
                ns.Tracker.StartDragging()
            end
        end)
        btn:SetScript("OnDragStop", function(self)
            if ns.Tracker and ns.Tracker.StopDragging then
                ns.Tracker.StopDragging()
            end
            C_Timer.After(0.1, function()
                self.wasDragged = false
            end)
        end)

        btn:SetScript("OnClick", function(self)
            if self.wasDragged or (ns.Tracker and ns.Tracker.frame and ns.Tracker.frame.isMoving) then return end
            if not self.zoneName or not ns.db then return end
            ns.db.collapsedZones[self.zoneName] = not ns.db.collapsedZones[self.zoneName] or nil
            StandaloneTracker:RequestUpdate(true)
        end)

        btn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(self.displayName or self.zoneName or L["Zone"], 1, 0.82, 0)
            local isCollapsed = ns.db and ns.db.collapsedZones[self.zoneName]
            GameTooltip:AddLine(isCollapsed and L["Click to expand zone quests"] or L["Click to collapse zone quests"], 0.8, 0.8, 0.8)
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

        table_insert(zoneHeaders, btn)
    end
    SafeSetFont(btn.title, fPath, zSize, outline, shadow)
    SafeSetFont(btn.collapseText, fPath, math_min(13, math_max(10, zSize - 1)), outline, shadow)
    return btn
end

-- ---------------------------------------------------------------------------
-- Quest context menu
-- ---------------------------------------------------------------------------
local function ToggleQuestCollapsed(qInfo)
    local questKey = qInfo.questID or qInfo.title
    if questKey and ns.db then
        ns.db.collapsedQuests[questKey] = not ns.db.collapsedQuests[questKey] or nil
        StandaloneTracker:RequestUpdate(true)
    end
end

-- A plain left-click waits this long so a second click can turn it into a double-click
local DOUBLE_CLICK_WINDOW = 0.25

-- ---------------------------------------------------------------------------
-- Opening quests: Blizzard world map (quest details) and/or a classic quest log
-- ---------------------------------------------------------------------------
-- Frames provided by classic-style quest log addons (e.g. Kerzo's Classic Quest Log),
-- or the client's own classic QuestLogFrame where one exists.
local CLASSIC_LOG_FRAMES = { "ClassicQuestLog", "QuestLogFrame" }

local function FindClassicQuestLog()
    for _, name in ipairs(CLASSIC_LOG_FRAMES) do
        local frame = _G[name]
        if type(frame) == "table" and frame.Show and frame ~= _G.WorldMapFrame then
            return frame
        end
    end
end

local function BlockedInCombat()
    if InCombatLockdown() then
        ns.Notify(ERR_NOT_IN_COMBAT or L["Cannot open the quest log in combat."], 1.0, 0.1, 0.1)
        return true
    end
end

local function OpenWorldMapDetails(qInfo)
    if qInfo and qInfo.questID and QuestMapFrame_OpenToQuestDetails then
        securecallfunction(QuestMapFrame_OpenToQuestDetails, qInfo.questID)
        return true
    end
    if ToggleQuestLog then
        ToggleQuestLog()
        return true
    end
end

-- Selects the quest in the log, then shows the classic log frame
local function OpenClassicQuestLog(qInfo)
    local frame = FindClassicQuestLog()
    if not frame then return false end
    if qInfo then
        if qInfo.questID and C_QuestLog.SetSelectedQuest then
            pcall(C_QuestLog.SetSelectedQuest, qInfo.questID)
        end
        if qInfo.questLogIndex and SelectQuestLogEntry then
            pcall(SelectQuestLogEntry, qInfo.questLogIndex)
        end
    end
    if frame == _G.QuestLogFrame then
        ShowUIPanel(frame)
        if QuestLog_Update then QuestLog_Update() end
    else
        frame:Show()
        if frame.Update then pcall(frame.Update, frame) end
    end
    return true
end

local classicMissingNotified = false
local function NotifyClassicMissing()
    if classicMissingNotified then return end
    classicMissingNotified = true
    ns.Notify(L["No classic quest log addon found; opening the world map instead."])
end

-- target: "world", "classic", "both", or nil for the player's "Open Quests In" setting
function ns.OpenQuestDetails(qInfo, target)
    if BlockedInCombat() then return end
    target = target or ns.db.questOpenMode or "world"
    if target == "classic" or target == "both" then
        local opened = OpenClassicQuestLog(qInfo)
        if not opened then
            NotifyClassicMissing()
            OpenWorldMapDetails(qInfo)
            return
        end
        if target == "classic" then return end
    end
    OpenWorldMapDetails(qInfo)
end

-- Header [Log] button: toggles whichever log the player chose
function ns.ToggleQuestLogWindow()
    if BlockedInCombat() then return end
    local mode = ns.db.questOpenMode or "world"
    if mode == "classic" or mode == "both" then
        local frame = FindClassicQuestLog()
        if frame then
            if frame:IsShown() then
                if frame == _G.QuestLogFrame then HideUIPanel(frame) else frame:Hide() end
            else
                OpenClassicQuestLog(nil)
            end
            if mode == "classic" then return end
        else
            NotifyClassicMissing()
        end
    end
    if ToggleQuestLog then ToggleQuestLog() end
end

-- Opens the world map on the quest's zone without the quest details panel
local function ShowQuestOnMap(qInfo)
    if BlockedInCombat() or not (qInfo and qInfo.questID) then return end
    local mapID = (GetQuestUiMapID and GetQuestUiMapID(qInfo.questID))
        or (C_QuestLog.GetMapForQuestPOIs and C_QuestLog.GetMapForQuestPOIs(qInfo.questID))
    if mapID and mapID > 0 and OpenWorldMap then
        OpenWorldMap(mapID)
    else
        OpenWorldMapDetails(qInfo)
    end
end

local function OpenQuestInLog(qInfo)
    ns.OpenQuestDetails(qInfo)
end

-- ---------------------------------------------------------------------------
-- Quest action buttons (optional icons at the right end of each quest title)
-- ---------------------------------------------------------------------------
local ACTION_BUTTONS = {
    { key = "setActive", icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_1" },
    { key = "map",       icon = "Interface\\Icons\\INV_Misc_Map_01",        crop = true, needsOutOfCombat = true },
    { key = "share",     icon = "Interface\\Icons\\INV_Misc_GroupNeedMore", crop = true },
    { key = "log",       icon = "Interface\\Icons\\INV_Misc_Book_09",       crop = true, needsOutOfCombat = true },
}
local ACTION_SPACING = 2

local function ActionButtonTooltip(btn)
    local qInfo = btn.bar.header.questInfo
    if not qInfo then return end
    GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
    local key = btn.key
    if key == "setActive" then
        local isActive = qInfo.questID and ns.activeQuestID == qInfo.questID
        GameTooltip:AddLine(isActive and L["Clear Active Quest"] or L["Set as Active Quest"], 1, 1, 1)
    elseif key == "map" then
        GameTooltip:AddLine(L["Show on Map"], 1, 1, 1)
    elseif key == "share" then
        GameTooltip:AddLine(L["Share Quest to Party"], 1, 1, 1)
    elseif key == "log" then
        GameTooltip:AddLine(L["Open Quest"], 1, 1, 1)
        GameTooltip:AddLine(L["Left-Click: World Map"], 0.2, 1, 0.2)
        GameTooltip:AddLine(L["Right-Click: Classic Quest Log"], 0.2, 1, 0.2)
    end
    if btn.def.needsOutOfCombat and InCombatLockdown() then
        GameTooltip:AddLine(L["Not available in combat."], 1, 0.3, 0.3)
    end
    GameTooltip:Show()
end

local function OnActionButtonClick(btn, mouseButton)
    local qInfo = btn.bar.header.questInfo
    if not (qInfo and qInfo.questID) then return end
    local key = btn.key
    if key == "setActive" then
        local isActive = ns.activeQuestID == qInfo.questID
        StandaloneTracker:SetActiveQuest(not isActive and qInfo.questID or nil)
    elseif key == "map" then
        ShowQuestOnMap(qInfo)
    elseif key == "share" then
        if ns.SocialModule and ns.SocialModule.ShareQuest then
            ns.SocialModule:ShareQuest(qInfo.questID, qInfo.questLogIndex)
        end
    elseif key == "log" then
        ns.OpenQuestDetails(qInfo, mouseButton == "RightButton" and "classic" or "world")
    end
end

-- Active-state star and combat greying
local function RefreshActionBar(bar)
    local qInfo = bar.header.questInfo
    local inCombat = InCombatLockdown()
    for _, btn in pairs(bar.buttons) do
        local dim = false
        if btn.key == "setActive" then
            dim = not (qInfo and qInfo.questID and ns.activeQuestID == qInfo.questID)
        elseif btn.def.needsOutOfCombat then
            dim = inCombat
        end
        btn.icon:SetDesaturated(dim)
        btn.icon:SetAlpha(dim and 0.55 or 1)
    end
end

local function GetActionBar(header)
    local bar = header.actionBar
    if bar then return bar end
    bar = CreateFrame("Frame", nil, header)
    bar.header = header
    bar:SetFrameLevel(header:GetFrameLevel() + 5)
    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetPoint("TOPLEFT", bar, "TOPLEFT", -2, 2)
    bg:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 2, -2)
    bg:SetColorTexture(0, 0, 0, 0.75)
    bar.bg = bg
    bar.buttons = {}
    for _, def in ipairs(ACTION_BUTTONS) do
        local btn = CreateFrame("Button", nil, bar)
        btn.bar = bar
        btn.key = def.key
        btn.def = def
        btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        local icon = btn:CreateTexture(nil, "ARTWORK")
        icon:SetAllPoints(btn)
        icon:SetTexture(def.icon)
        if def.crop then icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
        btn.icon = icon
        local hl = btn:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints(btn)
        hl:SetColorTexture(1, 1, 1, 0.25)
        btn:SetScript("OnClick", OnActionButtonClick)
        btn:SetScript("OnEnter", function(self)
            ActionButtonTooltip(self)
        end)
        btn:SetScript("OnLeave", function()
            GameTooltip:Hide()
            StandaloneTracker:CheckActionBarHover(bar)
        end)
        bar.buttons[def.key] = btn
    end
    header.actionBar = bar
    return bar
end

-- Hover mode: the bar shows while the pointer is anywhere over the quest
function StandaloneTracker:CheckActionBarHover(bar)
    if bar.mode ~= "hover" then return end
    C_Timer.After(0.05, function()
        local block = bar.header.block
        if bar.mode == "hover" and not (block and block:IsMouseOver()) then
            bar:Hide()
        end
    end)
end

local function ShowActionBarOnHover(header)
    local bar = header.actionBar
    if bar and bar.mode == "hover" and bar.hasButtons then
        RefreshActionBar(bar)
        bar:Show()
    end
end

function StandaloneTracker:RefreshActionBars()
    for _, block in ipairs(questBlocks) do
        local bar = block.header and block.header.actionBar
        if bar and bar:IsShown() then RefreshActionBar(bar) end
    end
end

-- Lays out the bar for this quest; returns the width the title must leave free
local function LayoutActionBar(header, qInfo, rightItemOffset, titleSize)
    local cfg = ns.db.questButtons
    local mode = cfg.mode or "off"
    if mode == "off" or not qInfo.questID then
        if header.actionBar then
            header.actionBar.mode = "off"
            header.actionBar:Hide()
        end
        return 0
    end
    local bar = GetActionBar(header)
    local size = cfg.size or 16
    local canShare = IsInGroup() and API.IsQuestPushable(qInfo.questID, qInfo.questLogIndex)
    local x = 0
    for _, def in ipairs(ACTION_BUTTONS) do
        local btn = bar.buttons[def.key]
        local wanted = cfg[def.key] ~= false and (def.key ~= "share" or canShare)
        if wanted then
            btn:SetSize(size, size)
            btn:ClearAllPoints()
            btn:SetPoint("LEFT", bar, "LEFT", x, 0)
            btn:Show()
            x = x + size + ACTION_SPACING
        else
            btn:Hide()
        end
    end
    bar.mode = mode
    bar.hasButtons = x > 0
    if x == 0 then
        bar:Hide()
        return 0
    end
    local width = x - ACTION_SPACING
    bar:SetSize(width, size)
    bar:ClearAllPoints()
    -- Right end of the first title line, always left of an inside-right quest item button
    bar:SetPoint("TOPRIGHT", header, "TOPRIGHT", rightItemOffset - 2, -math_floor((titleSize + 6 - size) / 2))
    RefreshActionBar(bar)
    if mode == "always" then
        bar.bg:Hide()
        bar:Show()
        return width + 6
    end
    bar.bg:Show()
    bar:SetShown(header.block and header.block:IsMouseOver())
    return 0
end

local function ShowWowheadURL(qInfo)
    if qInfo.questID and ns.Config and ns.Config.ShowCopyDialog then
        ns.Config:ShowCopyDialog(string_format("https://www.wowhead.com/forever/quest=%d", qInfo.questID), qInfo.title)
    end
end

function StandaloneTracker:OpenQuestContextMenu(anchor, qInfo)
    if not qInfo then return end

    local isCurActive = (qInfo.questID and ns.activeQuestID == qInfo.questID)
    local untracked = ns.db.filtering.untrackedQuests
    local isUntracked = qInfo.questID and untracked[qInfo.questID]
    local inGroup = IsInGroup and IsInGroup()

    local menu = {
        { text = "|cff00c0ff" .. (qInfo.title or L["Quest Actions"]) .. "|r", isTitle = true, notCheckable = true },
        {
            text = isCurActive and ("|cffff6666" .. L["Clear Active Quest Navigation"] .. "|r") or ("|cff00c0ff" .. L["Set as Active Quest"] .. "|r"),
            notCheckable = false,
            checked = isCurActive,
            func = function()
                StandaloneTracker:SetActiveQuest(not isCurActive and qInfo.questID or nil)
            end,
        },
        { text = L["Copy Wowhead URL"], notCheckable = true, func = function() ShowWowheadURL(qInfo) end },
        { text = L["Show in Quest Log"], notCheckable = true, func = function() OpenQuestInLog(qInfo) end },
        {
            text = L["Share Quest to Party"],
            notCheckable = true,
            disabled = not inGroup,
            func = function()
                if ns.SocialModule and ns.SocialModule.ShareQuest then
                    ns.SocialModule:ShareQuest(qInfo.questID, qInfo.questLogIndex)
                end
            end,
        },
        {
            text = L["Set Wayfinder Arrow"],
            notCheckable = true,
            func = function()
                if ns.WayfinderModule and qInfo.questID then
                    ns.WayfinderModule:SetQuestTarget(qInfo.questID, false, true)
                end
            end,
        },
        {
            text = isUntracked and L["Track Quest"] or L["Untrack Quest"],
            notCheckable = true,
            func = function()
                local qID = qInfo.questID
                if not qID then return end
                if isUntracked then
                    untracked[qID] = nil
                    API.AddQuestWatch(qID, qInfo.questLogIndex)
                else
                    untracked[qID] = true
                    API.RemoveQuestWatch(qID, qInfo.questLogIndex)
                    if QuestWatch_Update then QuestWatch_Update() end
                end
                StandaloneTracker:RequestUpdate(true)
            end,
        },
        {
            text = "|cffff4444" .. L["Abandon Quest"] .. "|r",
            notCheckable = true,
            func = function()
                local questID = qInfo.questID
                local title = qInfo.title or (questID and API.GetTitleForQuestID(questID)) or L["Quest"]
                StaticPopupDialogs["NQT_CONFIRM_ABANDON_QUEST"].text = L["Are you sure you want to abandon '%s'?"]
                StaticPopup_Show("NQT_CONFIRM_ABANDON_QUEST", title, nil, {
                    questID = questID,
                    questLogIndex = qInfo.questLogIndex,
                })
            end,
        },
        { text = L["Cancel"], notCheckable = true, isCancel = true, func = function() end },
    }

    GameTooltip:Hide()
    self.isContextMenuOpen = true

    if not GameTooltip._bfqContextMenuHooked then
        GameTooltip._bfqContextMenuHooked = true
        GameTooltip:HookScript("OnShow", function(tip)
            if StandaloneTracker.isContextMenuOpen and DropDownList1 and DropDownList1:IsShown() and DropDownList1._bfqCustomApplied then
                tip:Hide()
            end
        end)
    end

    if MenuUtil and MenuUtil.CreateContextMenu then
        self.isContextMenuOpen = false
        MenuUtil.CreateContextMenu(UIParent, function(_, rootDescription)
            for _, item in ipairs(menu) do
                if item.isTitle then
                    if rootDescription.CreateTitle then
                        rootDescription:CreateTitle(item.text)
                    end
                elseif item.isCancel then
                    if rootDescription.CreateDivider then rootDescription:CreateDivider() end
                    rootDescription:CreateButton(item.text, function() end)
                else
                    local btn = rootDescription:CreateButton(item.text, item.func)
                    if item.disabled and btn and btn.SetEnabled then
                        btn:SetEnabled(false)
                    end
                end
            end
        end)
        return
    end

    local mScale = ns.db.fonts.menuScale or 1.0
    if EasyMenu then
        EasyMenu(menu, questContextMenu, "cursor", 0, 0, "MENU")
    elseif ToggleDropDownMenu and UIDropDownMenu_Initialize then
        UIDropDownMenu_Initialize(questContextMenu, function(_, level)
            for _, item in ipairs(menu) do
                UIDropDownMenu_AddButton(item, level)
            end
        end, "MENU")
        ToggleDropDownMenu(1, nil, questContextMenu, "cursor", 0, 0)
    end

    -- Elevate DropDownList1 above GameTooltip and apply menu scaling
    if DropDownList1 then
        if not DropDownList1._bfqHooked then
            DropDownList1._bfqHooked = true
            DropDownList1:HookScript("OnHide", function(list)
                StandaloneTracker.isContextMenuOpen = false
                if list._bfqCustomApplied then
                    list:SetFrameStrata(list._bfqOrigStrata or "FULLSCREEN_DIALOG")
                    list:SetScale(list._bfqOrigScale or 1.0)
                    list._bfqCustomApplied = nil
                end
            end)
        end
        DropDownList1._bfqOrigStrata = DropDownList1._bfqOrigStrata or DropDownList1:GetFrameStrata()
        DropDownList1._bfqOrigScale = DropDownList1._bfqOrigScale or DropDownList1:GetScale()
        DropDownList1._bfqCustomApplied = true
        DropDownList1:SetFrameStrata("TOOLTIP")
        DropDownList1:SetFrameLevel(2500)
        if mScale > 0 then
            DropDownList1:SetScale(mScale)
        end
    end
end

-- ---------------------------------------------------------------------------
-- Quest rewards (tooltip)
-- ---------------------------------------------------------------------------
local SafeCall = ns.SafeCall
local ToNumber = ns.ToNumber

-- Cache for quest rewards to avoid repeated quest log selection on hover
local questRewardsCache = {}

local function FormatMoneyString(copper)
    if GetCoinTextureString then
        local coinStr = SafeCall(GetCoinTextureString, copper)
        if coinStr then return coinStr end
    end
    local g = math_floor(copper / 10000)
    local s = math_floor((copper % 10000) / 100)
    local c = copper % 100
    local parts = {}
    if g > 0 then parts[#parts + 1] = string_format("|cffffd700%dg|r", g) end
    if s > 0 then parts[#parts + 1] = string_format("|cffc7c7cf%ds|r", s) end
    if c > 0 or #parts == 0 then parts[#parts + 1] = string_format("|cffeda55f%dc|r", c) end
    return table.concat(parts, " ")
end

-- Armor/weapon proficiency matrix for "Usable" reward highlighting (classID 4 = armor, 2 = weapon)
local ARMOR_CLASSES = {
    [2] = { DRUID = true, ROGUE = true, HUNTER = true, SHAMAN = true, PALADIN = true, WARRIOR = true }, -- Leather
    [6] = { WARRIOR = true, PALADIN = true, SHAMAN = true },                                              -- Shields
    [7] = { PALADIN = true }, [8] = { DRUID = true }, [9] = { SHAMAN = true },                            -- Relics
}
local WEAPON_CLASSES = {
    [0] = { WARRIOR = true, PALADIN = true, HUNTER = true, SHAMAN = true, ROGUE = true },
    [1] = { WARRIOR = true, PALADIN = true, HUNTER = true, SHAMAN = true },
    [2] = { WARRIOR = true, HUNTER = true, ROGUE = true },
    [3] = { WARRIOR = true, HUNTER = true, ROGUE = true },
    [4] = { WARRIOR = true, PALADIN = true, ROGUE = true, PRIEST = true, SHAMAN = true, DRUID = true },
    [5] = { WARRIOR = true, PALADIN = true, SHAMAN = true, DRUID = true },
    [6] = { WARRIOR = true, PALADIN = true, HUNTER = true, DRUID = true },
    [7] = { WARRIOR = true, PALADIN = true, HUNTER = true, ROGUE = true, MAGE = true, WARLOCK = true },
    [8] = { WARRIOR = true, PALADIN = true, HUNTER = true },
    [10] = { WARRIOR = true, HUNTER = true, PRIEST = true, SHAMAN = true, MAGE = true, WARLOCK = true, DRUID = true },
    [13] = { WARRIOR = true, HUNTER = true, ROGUE = true, SHAMAN = true, DRUID = true },
    [14] = { WARRIOR = true, HUNTER = true, ROGUE = true },
    [18] = { WARRIOR = true, HUNTER = true, ROGUE = true },
    [19] = { PRIEST = true, MAGE = true, WARLOCK = true },
}
local ALWAYS_USABLE_SLOTS = {
    INVTYPE_CLOAK = true, INVTYPE_FINGER = true, INVTYPE_TRINKET = true,
    INVTYPE_NECK = true, INVTYPE_BODY = true, INVTYPE_TABARD = true,
}

local function IsItemUsableByPlayerClass(itemLink)
    if not itemLink then return nil end
    local itemID = tonumber(itemLink:match("item:(%d+)"))

    if itemID and C_PlayerInfo and C_PlayerInfo.CanUseItem then
        local ok, canUse = pcall(C_PlayerInfo.CanUseItem, itemID)
        if ok and canUse ~= nil then return canUse end
    end

    local _, _, _, _, _, itemType, _, _, itemEquipLoc, _, _, classID, subclassID = API.GetItemInfo(itemLink)
    if not itemEquipLoc or itemEquipLoc == "" or itemEquipLoc == "INVTYPE_NON_EQUIP" then
        return nil
    end

    local _, playerClass = UnitClass("player")
    local playerLevel = UnitLevel("player") or 1

    if classID == 4 or itemType == "Armor" then
        if subclassID == 0 or subclassID == 1 or ALWAYS_USABLE_SLOTS[itemEquipLoc] then
            return true
        end
        if subclassID == 3 then -- Mail
            if playerClass == "WARRIOR" or playerClass == "PALADIN" then return true end
            if playerClass == "HUNTER" or playerClass == "SHAMAN" then return playerLevel >= 40 end
            return false
        end
        if subclassID == 4 then -- Plate
            return (playerClass == "WARRIOR" or playerClass == "PALADIN") and playerLevel >= 40
        end
        if itemEquipLoc == "INVTYPE_SHIELD" then subclassID = 6 end
        local allowed = ARMOR_CLASSES[subclassID]
        if allowed then return allowed[playerClass] == true end
    end

    if classID == 2 or itemType == "Weapon" then
        if subclassID == 15 then return playerClass ~= "PALADIN" end -- Dagger
        local allowed = WEAPON_CLASSES[subclassID]
        if allowed then return allowed[playerClass] == true end
    end

    return true
end

local function GetQuestRewards(questID, questLogIndex)
    if not questID then return nil end
    if questRewardsCache[questID] then
        return questRewardsCache[questID]
    end

    questLogIndex = questLogIndex or API.GetLogIndexForQuestID(questID)
    if not questLogIndex then return nil end

    -- Reward APIs read the selected quest; restore the previous selection afterwards
    local inCombat = InCombatLockdown()
    local origSelected = not inCombat and SafeCall(GetQuestLogSelection) or nil
    local origSelectedQID = (not inCombat and C_QuestLog and C_QuestLog.GetSelectedQuest and SafeCall(C_QuestLog.GetSelectedQuest)) or nil
    if not inCombat then
        if origSelected ~= questLogIndex then
            SafeCall(SelectQuestLogEntry, questLogIndex)
        end
        if C_QuestLog and C_QuestLog.SetSelectedQuest and origSelectedQID ~= questID then
            SafeCall(C_QuestLog.SetSelectedQuest, questID)
        end
    end

    local rewards = { xp = 0, money = 0, honor = 0, items = {}, choices = {} }

    local xp = SafeCall(GetQuestLogRewardXP)
    if xp == nil then xp = SafeCall(GetQuestLogRewardXP, questID) end
    rewards.xp = tonumber(xp) or 0

    local money = SafeCall(GetQuestLogRewardMoney)
    if money == nil then money = SafeCall(GetQuestLogRewardMoney, questID) end
    rewards.money = tonumber(money) or 0

    local honor = SafeCall(GetQuestLogRewardHonor)
    if honor == nil then honor = SafeCall(GetQuestLogRewardHonor, questID) end
    rewards.honor = tonumber(honor) or 0

    local spellName, spellTexture = SafeCall(GetQuestLogRewardSpell)
    if not spellName then spellName, spellTexture = SafeCall(GetQuestLogRewardSpell, questID) end
    if spellName and spellName ~= "" then
        rewards.spell = { name = spellName, texture = spellTexture }
    end

    local function CollectItems(countFn, infoFn, linkType, target)
        local num = ToNumber((SafeCall(countFn))) or ToNumber((SafeCall(countFn, questID))) or 0
        for i = 1, num do
            local name, texture, numItems, quality = SafeCall(infoFn, i)
            if not name then
                name, texture, numItems, quality = SafeCall(infoFn, i, questID)
            end
            local itemLink = SafeCall(GetQuestLogItemLink, linkType, i) or SafeCall(GetQuestLogItemLink, linkType, i, questID)
            if name or itemLink then
                target[#target + 1] = {
                    name = name,
                    texture = texture,
                    count = ToNumber(numItems) or 1,
                    quality = ToNumber(quality) or 1,
                    itemLink = itemLink,
                }
            end
        end
        return num
    end
    local numRewards = CollectItems(GetNumQuestLogRewards, GetQuestLogRewardInfo, "reward", rewards.items)
    local numChoices = CollectItems(GetNumQuestLogChoices, GetQuestLogChoiceInfo, "choice", rewards.choices)

    if not inCombat then
        if origSelected and origSelected > 0 and origSelected ~= questLogIndex then
            SafeCall(SelectQuestLogEntry, origSelected)
        end
        if origSelectedQID and C_QuestLog and C_QuestLog.SetSelectedQuest and origSelectedQID ~= questID then
            SafeCall(C_QuestLog.SetSelectedQuest, origSelectedQID)
        end
    end

    rewards.hasRewards = (rewards.xp > 0) or (rewards.money > 0) or (rewards.honor > 0) or rewards.spell ~= nil
        or (#rewards.items > 0) or (#rewards.choices > 0)

    -- Only cache once item names/links have arrived from the server
    if numRewards <= #rewards.items and numChoices <= #rewards.choices then
        questRewardsCache[questID] = rewards
    end
    return rewards
end
ns.GetQuestRewards = GetQuestRewards

local function AddRewardItemLine(item, showUsableGear, extraTag)
    local icon = (item.texture and ("|T" .. item.texture .. ":14:14:0:0|t ")) or ""
    local count = (item.count and item.count > 1 and (" |cffffffff(x" .. item.count .. ")|r")) or ""
    local itemText = item.itemLink or ((API.GetItemQualityColorHex(item.quality)) .. (item.name or L["Item"]) .. "|r")
    local usableTag = ""
    local lineR, lineG, lineB = 0.9, 0.9, 0.9
    if showUsableGear and item.itemLink then
        local isUsable = IsItemUsableByPlayerClass(item.itemLink)
        if isUsable == true then
            usableTag = " |cff00ff00[" .. L["Usable"] .. "]|r"
        elseif isUsable == false then
            usableTag = " |cff888888[" .. L["Unusable"] .. "]|r"
            lineR, lineG, lineB = 0.6, 0.6, 0.6
        end
    end
    GameTooltip:AddLine("    " .. icon .. itemText .. count .. usableTag .. (extraTag or ""), lineR, lineG, lineB)
end

local function ShowQuestTooltip(anchorFrame, qInfo)
    if not qInfo then return end
    if StandaloneTracker.isContextMenuOpen or (DropDownList1 and DropDownList1:IsShown()) then
        GameTooltip:Hide()
        return
    end
    local db = ns.db
    local tips = db.tooltips
    local questKey = qInfo.questID or qInfo.title
    local isCollapsed = db.collapsedQuests[questKey]
    local isActive = (qInfo.questID and ns.activeQuestID == qInfo.questID)

    GameTooltip:SetOwner(anchorFrame, "ANCHOR_RIGHT")
    GameTooltip:ClearLines()

    local titleLine = qInfo.title or L["Quest"]
    if qInfo.level and qInfo.level > 0 then
        titleLine = string_format("[%d] %s", qInfo.level, titleLine)
    end
    GameTooltip:AddLine(titleLine, 1, 0.82, 0)
    local foreverMarker = GetForeverMarker(qInfo.questID)
    if foreverMarker then
        local c = db.foreverMarker.color
        GameTooltip:AddLine(foreverMarker .. " " .. L["New in WoW Forever"], c.r, c.g, c.b)
    end

    if tips.showRewards ~= false then
        local rewards = GetQuestRewards(qInfo.questID, qInfo.questLogIndex)
        if rewards then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("|cffffd100" .. L["Quest Rewards:"] .. "|r")
            if rewards.hasRewards then
                if rewards.xp > 0 then
                    local xpStr = (BreakUpLargeNumbers and BreakUpLargeNumbers(rewards.xp)) or tostring(rewards.xp)
                    local xpPctStr = ""
                    if tips.showXpPercent ~= false then
                        local maxXP = UnitXPMax("player")
                        local curLevel = UnitLevel("player")
                        local maxLevel = (GetMaxPlayerLevel and GetMaxPlayerLevel()) or 60
                        if maxXP and maxXP > 0 and curLevel and curLevel < maxLevel then
                            xpPctStr = " |cffffd100(" .. string_format(L["%.1f%% of level %d"], (rewards.xp / maxXP) * 100, curLevel) .. ")|r"
                        end
                    end
                    GameTooltip:AddLine("  • |cffffffff" .. xpStr .. "|r |cff00ff00" .. L["XP"] .. "|r" .. xpPctStr, 0.9, 0.9, 0.9)
                end
                if rewards.money > 0 then
                    GameTooltip:AddLine("  • " .. FormatMoneyString(rewards.money), 1, 1, 1)
                end
                if rewards.honor > 0 then
                    GameTooltip:AddLine("  • |cff00e5ff" .. string_format(L["%d Honor"], rewards.honor) .. "|r", 0, 0.9, 1)
                end
                if rewards.spell and rewards.spell.name then
                    local icon = (rewards.spell.texture and ("|T" .. rewards.spell.texture .. ":14:14:0:0|t ")) or ""
                    GameTooltip:AddLine("  • " .. icon .. "|cff71d5ff" .. rewards.spell.name .. "|r", 0.5, 0.8, 1)
                end

                local showUsableGear = tips.showUsableGear ~= false
                local showBestSell = tips.showBestSell ~= false

                if #rewards.choices > 0 then
                    local maxSellPrice, bestSellIndex = 0, nil
                    if showBestSell and #rewards.choices > 1 then
                        for i, choice in ipairs(rewards.choices) do
                            local price = 0
                            if choice.itemLink then
                                price = select(11, API.GetItemInfo(choice.itemLink)) or 0
                            end
                            local total = price * (choice.count or 1)
                            if total > maxSellPrice then
                                maxSellPrice = total
                                bestSellIndex = i
                            end
                        end
                    end
                    GameTooltip:AddLine("  |cffffbb00" .. L["Choose One:"] .. "|r")
                    for i, choice in ipairs(rewards.choices) do
                        local bestTag
                        if bestSellIndex == i and maxSellPrice > 0 then
                            bestTag = " |TInterface\\MoneyFrame\\UI-GoldIcon:12:12:0:0|t |cffffd100["
                                .. string_format(L["Best Sell: %s"], FormatMoneyString(maxSellPrice)) .. "]|r"
                        end
                        AddRewardItemLine(choice, showUsableGear, bestTag)
                    end
                end

                if #rewards.items > 0 then
                    GameTooltip:AddLine("  |cff00ff00" .. L["You Receive:"] .. "|r")
                    for _, item in ipairs(rewards.items) do
                        AddRewardItemLine(item, showUsableGear)
                    end
                end
            else
                GameTooltip:AddLine("  • |cff888888" .. L["None (or discovery quest)"] .. "|r", 0.6, 0.6, 0.6)
            end
        end
    end

    -- Party Quest Status
    if tips.showPartyStatus ~= false and ns.SocialModule and ns.SocialModule.GetPartyQuestDetails then
        local partyDetails = ns.SocialModule:GetPartyQuestDetails(qInfo.questID, qInfo.questLogIndex)
        if partyDetails and partyDetails.totalGroupMembers > 1 then
            local classColorParty = tips.classColorParty ~= false
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("|cffffd100" .. L["Party Quest Status:"] .. "|r")

            local offline = " |cff888888(" .. L["Offline"] .. ")|r"
            if partyDetails.onQuestCount > 0 then
                for _, member in ipairs(partyDetails.onQuest) do
                    local nameStr = classColorParty and member.coloredName or member.name
                    local statusTag = "|TInterface\\Common\\CommonIcons:13:13:0:0:2048:1024:13:253:542:752|t |cff00ff00" .. L["On Quest"] .. "|r"
                    GameTooltip:AddLine("  - " .. nameStr .. " " .. statusTag .. (member.isConnected and "" or offline))
                end
            else
                GameTooltip:AddLine("  - |cff888888" .. L["No other party members are on this quest"] .. "|r")
            end

            if tips.showMissingParty ~= false and partyDetails.missingCount > 0 then
                for _, member in ipairs(partyDetails.missing) do
                    local nameStr = classColorParty and member.coloredName or member.name
                    local statusTag = "|TInterface\\Common\\CommonIcons:13:13:0:0:2048:1024:536:761:533:758|t |cffff6666" .. L["Missing"] .. "|r"
                    if partyDetails.isPushable then
                        statusTag = statusTag .. " |cff00e5ff(" .. L["Click to Share"] .. ")|r"
                    end
                    GameTooltip:AddLine("  - " .. nameStr .. " " .. statusTag .. (member.isConnected and "" or offline))
                end
            end
        end
    end

    GameTooltip:AddLine(" ")
    local expandLabel = isCollapsed and L["Expand Quest"] or L["Collapse Quest"]
    if db.sorting.leftClickSetsActive ~= true then
        GameTooltip:AddLine("|cff00ff00" .. string_format(L["Left-Click: %s"], expandLabel) .. "|r", 0.2, 1, 0.2)
        if db.sorting.doubleClickSetsActive ~= false and not isActive then
            GameTooltip:AddLine("|cff00ff00" .. L["Double-Click: Set as Active Quest"] .. "|r", 0.2, 1, 0.2)
        end
        if isActive then
            GameTooltip:AddLine("|cff00e5ff* " .. L["Active Quest"] .. "|r", 0.0, 0.9, 1.0)
        end
    else
        if isActive then
            GameTooltip:AddLine("|cff00e5ff* " .. L["Active Quest"] .. "|r |cffaaaaaa(" .. string_format(L["Left-Click: %s"], expandLabel) .. ")|r", 0.0, 0.9, 1.0)
        else
            GameTooltip:AddLine("|cff00ff00" .. L["Left-Click: Set as Active (Move to Top)"] .. "|r", 0.2, 1, 0.2)
        end
        GameTooltip:AddLine("|cffaaaaaa" .. string_format(L["Alt + Left-Click: %s"], expandLabel) .. "|r", 0.6, 0.6, 0.6)
    end
    local wf = ns.WayfinderModule
    if isActive and wf and wf.IsCustomTarget and wf:IsCustomTarget() then
        local cur = wf:GetCurrentTarget()
        local nav = wf:GetNavigationState()
        if cur and cur.title then
            local distStr = (nav and nav.distanceYards and nav.distanceYards > 0) and wf:FormatDistance(nav.distanceYards) or ""
            GameTooltip:AddDoubleLine("|cff00c0ff" .. L["Navigating to Waypoint:"] .. "|r", "|cffffd100" .. cur.title .. "|r" .. (distStr ~= "" and (" |cffffffff(" .. distStr .. ")|r") or ""))
        end
    end
    GameTooltip:AddLine("|cffaaaaaa" .. L["Ctrl + Left-Click: Open in Quest Log"] .. "|r", 0.6, 0.6, 0.6)
    GameTooltip:AddLine("|cffaaaaaa" .. L["Shift + Left-Click: Link in Chat"] .. "|r", 0.6, 0.6, 0.6)
    GameTooltip:AddLine("|cffaaaaaa" .. L["Right-Click: Quest Actions Menu"] .. "|r", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("|cff00c0ff" .. L["Shift + Right-Click: Copy Wowhead URL"] .. "|r", 0.2, 0.8, 1)
    GameTooltip:AddLine("|cff00ff00" .. L["Alt + Right-Click: Open Settings"] .. "|r", 0.2, 1, 0.2)
    GameTooltip:Show()
end

local function HideQuestTooltip(frame)
    C_Timer.After(0.05, function()
        local header = frame and (frame.header or frame)
        local block = frame and (frame.block or frame)
        if (header and header.IsMouseOver and header:IsMouseOver()) or (block and block.IsMouseOver and block:IsMouseOver()) then
            return
        end
        GameTooltip:Hide()
    end)
end

-- ---------------------------------------------------------------------------
-- Quest blocks
-- ---------------------------------------------------------------------------
local function AcquireQuestBlock(parent)
    local block = AcquireFromPool(questBlocks, parent)
    if block then
        block.header:Show()
        return block
    end

    block = CreateFrame("Frame", nil, parent)
    block.questInfo = {}
    block:SetWidth(parent:GetWidth())
    block:EnableMouse(true)
    block:RegisterForDrag("LeftButton")
    block:SetScript("OnDragStart", function()
        if ns.Tracker and ns.Tracker.StartDragging then ns.Tracker.StartDragging() end
    end)
    block:SetScript("OnDragStop", function()
        if ns.Tracker and ns.Tracker.StopDragging then ns.Tracker.StopDragging() end
    end)
    block:SetScript("OnEnter", function(self)
        if StandaloneTracker.isContextMenuOpen or (DropDownList1 and DropDownList1:IsShown()) then return end
        ShowQuestTooltip(self.header or self, self.questInfo)
    end)
    block:SetScript("OnLeave", function(self) HideQuestTooltip(self) end)

    local completedBg = block:CreateTexture(nil, "BACKGROUND")
    completedBg:SetAllPoints(block)
    completedBg:Hide()
    block.completedBg = completedBg

    local header = CreateFrame("Button", nil, block)
    block.header = header
    header.block = block
    header.questInfo = block.questInfo
    local titleSize = StandaloneTracker.titleSize or 13
    header:SetHeight(titleSize + 6)
    header:SetPoint("TOPLEFT", block, "TOPLEFT", 0, 0)
    header:SetPoint("TOPRIGHT", block, "TOPRIGHT", 0, 0)
    header:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function(self)
        self.wasDragged = true
        if ns.Tracker and ns.Tracker.StartDragging then ns.Tracker.StartDragging() end
    end)
    header:SetScript("OnDragStop", function(self)
        if ns.Tracker and ns.Tracker.StopDragging then ns.Tracker.StopDragging() end
        C_Timer.After(0.1, function() self.wasDragged = false end)
    end)

    local title = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header.title = title
    title:SetPoint("TOPLEFT", header, "TOPLEFT", 0, 0)
    title:SetPoint("TOPRIGHT", header, "TOPRIGHT", 0, 0)
    title:SetJustifyH("LEFT")
    title:SetWordWrap(true)
    SafeSetFont(title, StandaloneTracker.headerFontPath or StandaloneTracker.fontPath, titleSize, StandaloneTracker.titleOutline or "OUTLINE")

    local statusIcon = header:CreateTexture(nil, "OVERLAY")
    header.statusIcon = statusIcon
    statusIcon:Hide()

    local wayfinderArrow = header:CreateTexture(nil, "OVERLAY")
    header.wayfinderArrow = wayfinderArrow
    wayfinderArrow:Hide()

    local hl = header:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(header)
    local qHl = ns.db.fonts.questHoverColor or WHITE
    hl:SetColorTexture(qHl.r, qHl.g, qHl.b, qHl.a or 0.08)
    header.highlight = hl

    -- Left = Collapse/Expand, Ctrl+Left = Quest Log, Shift+Left = Chat Link,
    -- Right = Context Menu, Shift+Right = Wowhead URL, Alt+Right = Settings
    header:SetScript("OnClick", function(self, mouseButton)
        if self.wasDragged or (ns.Tracker and ns.Tracker.frame and ns.Tracker.frame.isMoving) then return end
        local qInfo = self.questInfo
        if not qInfo then return end

        if mouseButton == "LeftButton" then
            if IsModifiedClick("CHATLINK") and qInfo.questID then
                local link = API.GetQuestLink(qInfo.questID, qInfo.questLogIndex)
                if link then ChatEdit_InsertLink(link) end
            elseif IsControlKeyDown() then
                OpenQuestInLog(qInfo)
            elseif IsAltKeyDown() then
                ToggleQuestCollapsed(qInfo)
            elseif ns.db.sorting.leftClickSetsActive == true and qInfo.questID and ns.activeQuestID ~= qInfo.questID then
                StandaloneTracker:SetActiveQuest(qInfo.questID)
            elseif ns.db.sorting.doubleClickSetsActive ~= false and qInfo.questID then
                if self.pendingClick then
                    -- Second click inside the window: set active instead of collapsing
                    self.pendingClick:Cancel()
                    self.pendingClick = nil
                    if ns.activeQuestID ~= qInfo.questID then
                        StandaloneTracker:SetActiveQuest(qInfo.questID)
                    end
                else
                    self.pendingClick = C_Timer.NewTimer(DOUBLE_CLICK_WINDOW, function()
                        self.pendingClick = nil
                        ToggleQuestCollapsed(qInfo)
                    end)
                end
            else
                ToggleQuestCollapsed(qInfo)
            end
        elseif mouseButton == "RightButton" then
            if IsAltKeyDown() then
                if ns.Config then ns.Config:ToggleConfigFrame() end
            elseif IsShiftKeyDown() then
                ShowWowheadURL(qInfo)
            else
                StandaloneTracker:OpenQuestContextMenu(self, qInfo)
            end
        end
    end)

    header:SetScript("OnEnter", function(self)
        if StandaloneTracker.isContextMenuOpen or (DropDownList1 and DropDownList1:IsShown()) then return end
        ShowQuestTooltip(self, self.questInfo)
    end)
    header:SetScript("OnLeave", function(self) HideQuestTooltip(self) end)

    -- Action buttons in "Show on Hover" mode follow the pointer over the whole quest
    block:HookScript("OnEnter", function(self) ShowActionBarOnHover(self.header) end)
    header:HookScript("OnEnter", function(self) ShowActionBarOnHover(self) end)
    local function CheckHover(self)
        local bar = (self.header or self).actionBar
        if bar then StandaloneTracker:CheckActionBarHover(bar) end
    end
    block:HookScript("OnLeave", CheckHover)
    header:HookScript("OnLeave", CheckHover)

    table_insert(questBlocks, block)
    return block
end

function StandaloneTracker:ApplyTypography(headerFontPath, objectiveFontPath, titleSize, objSize, headerOutline, objOutline, zoneHeaderSize, enableShadow)
    local tSize = tonumber(titleSize) or 13
    local oSize = tonumber(objSize) or 11
    local zSize = tonumber(zoneHeaderSize) or math_max(10, tSize - 1)
    local hOutline = CleanOutline(headerOutline)
    local oOutline = CleanOutline(objOutline)
    local shadow = (enableShadow ~= false)
    local oFont = objectiveFontPath or headerFontPath

    self.headerFontPath = headerFontPath
    self.fontPath = headerFontPath
    self.objectiveFontPath = oFont
    self.titleSize = tSize
    self.objSize = oSize
    self.zoneHeaderSize = zSize
    self.titleOutline = hOutline
    self.objOutline = oOutline
    self.enableShadow = shadow

    for _, block in ipairs(questBlocks) do
        SafeSetFont(block.header.title, headerFontPath, tSize, hOutline, shadow)
    end
    for _, str in ipairs(objectiveStrings) do
        SafeSetFont(str, oFont, oSize, oOutline, shadow)
    end
    for _, str in ipairs(partyStrings) do
        SafeSetFont(str, oFont, math_max(9, oSize - 1), oOutline, shadow)
    end
    for _, btn in ipairs(shareButtons) do
        SafeSetFont(btn.text, oFont, math_max(9, oSize - 1), oOutline, shadow)
    end
    for _, zh in ipairs(zoneHeaders) do
        SafeSetFont(zh.title, headerFontPath, zSize, hOutline, shadow)
        SafeSetFont(zh.collapseText, headerFontPath, math_min(13, math_max(10, zSize - 1)), hOutline, shadow)
    end

    self:RequestUpdate()
end

function StandaloneTracker:ApplyHighlightColors()
    local qHl = ns.db.fonts.questHoverColor or WHITE
    for _, block in ipairs(questBlocks) do
        block.header.highlight:SetColorTexture(qHl.r, qHl.g, qHl.b, qHl.a or 0.08)
    end
    local zHl = ns.db.fonts.zoneHoverColor or DEFAULT_TITLE_COLOR
    for _, zh in ipairs(zoneHeaders) do
        zh.highlight:SetColorTexture(zHl.r, zHl.g, zHl.b, zHl.a or 0.12)
    end
end

-- ---------------------------------------------------------------------------
-- Zone matching
-- ---------------------------------------------------------------------------
local playerValidZones = {}

local function UpdatePlayerValidZones()
    wipe(playerValidZones)
    local playerRealZone = (GetRealZoneText and GetRealZoneText()) or ""
    local playerZone = (GetZoneText and GetZoneText()) or ""
    local playerSubZone = (GetSubZoneText and GetSubZoneText()) or ""
    local mapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    local mapInfo = mapID and C_Map.GetMapInfo(mapID)
    local mapName = (mapInfo and mapInfo.name) or ""

    if playerRealZone ~= "" then table_insert(playerValidZones, playerRealZone) end
    if playerZone ~= "" and playerZone ~= playerRealZone then table_insert(playerValidZones, playerZone) end
    if playerSubZone ~= "" and playerSubZone ~= playerZone and playerSubZone ~= playerRealZone then table_insert(playerValidZones, playerSubZone) end
    if mapName ~= "" and mapName ~= playerZone and mapName ~= playerRealZone then table_insert(playerValidZones, mapName) end

    if IsInInstance and IsInInstance() then
        local instName = GetInstanceInfo and GetInstanceInfo()
        if instName and instName ~= "" then
            table_insert(playerValidZones, instName)
        end
    end
end

local normalizeCache = {}
local function NormalizeZoneStr(str)
    if not str or str == "" then return "" end
    local cached = normalizeCache[str]
    if cached then return cached end
    local s = string_lower(str):gsub("^the%s+", "")
    s = s:match("^%s*(.-)%s*$") or s
    normalizeCache[str] = s
    return s
end

-- Class Quest Lookup (English tokens + localized class names)
local CLASS_QUEST_HEADERS = {
    ["druid"] = true, ["hunter"] = true, ["mage"] = true, ["paladin"] = true,
    ["priest"] = true, ["rogue"] = true, ["shaman"] = true, ["warlock"] = true,
    ["warrior"] = true,
}
for _, locTable in ipairs({ LOCALIZED_CLASS_NAMES_MALE or {}, LOCALIZED_CLASS_NAMES_FEMALE or {} }) do
    for _, locName in pairs(locTable) do
        if type(locName) == "string" and locName ~= "" then
            CLASS_QUEST_HEADERS[string_lower(locName)] = true
        end
    end
end
do
    local locClass, engClass = UnitClass("player")
    if locClass then CLASS_QUEST_HEADERS[string_lower(locClass)] = true end
    if engClass then CLASS_QUEST_HEADERS[string_lower(engClass)] = true end
end

-- Quest log headers that never correspond to a map zone
local NON_ZONE_HEADERS = {
    ["mage"] = true, ["warrior"] = true, ["paladin"] = true, ["hunter"] = true,
    ["rogue"] = true, ["priest"] = true, ["shaman"] = true, ["warlock"] = true, ["druid"] = true,
    ["alchemy"] = true, ["blacksmithing"] = true, ["enchanting"] = true, ["engineering"] = true,
    ["leatherworking"] = true, ["tailoring"] = true, ["herbalism"] = true, ["mining"] = true,
    ["skinning"] = true, ["cooking"] = true, ["first aid"] = true, ["fishing"] = true,
    ["general"] = true, ["special"] = true, ["battlegrounds"] = true, ["seasonal"] = true,
}

local STARTER_ZONES = {
    ["dun morogh"] = true, ["coldridge valley"] = true,
    ["elwynn forest"] = true, ["northshire"] = true, ["northshire valley"] = true,
    ["teldrassil"] = true, ["shadowglen"] = true,
    ["durotar"] = true, ["valley of trials"] = true,
    ["mulgore"] = true, ["red cloud mesa"] = true,
    ["tirisfal glades"] = true, ["deathknell"] = true,
    ["zephras isle"] = true, ["zephras isles"] = true,
    ["riverlands"] = true, ["riverglades"] = true,
    ["hall of thanes"] = true, ["hall of the thanes"] = true,
    ["darkspear islands"] = true, ["darkspear island"] = true, ["darkspear strand"] = true,
}

local playerClassToken = select(2, UnitClass("player"))
local playerClassName = UnitClass("player")

local function IsClassQuest(zoneHeader, questID, questLogIndex, title)
    local norm = NormalizeZoneStr(zoneHeader)
    if norm ~= "" and CLASS_QUEST_HEADERS[norm] then
        return true
    end
    if playerClassToken == "DRUID" and norm == "moonglade" then
        return true
    elseif playerClassToken == "ROGUE" and (norm == "ravenholdt" or norm == "ravenholdt manor") then
        return true
    end
    if questID then
        local tagInfo = API.GetQuestTagInfo(questID, questLogIndex)
        if type(tagInfo) == "table" and tagInfo.tagName and string_lower(tagInfo.tagName):find("class", 1, true) then
            return true
        end
    end
    if type(title) == "string" and playerClassName and string_lower(title):find("^" .. string_lower(playerClassName) .. ":") then
        return true
    end
    return false
end
ns.IsClassQuest = IsClassQuest

local function IsClassHeaderName(zoneName)
    if not zoneName or zoneName == "" then return false end
    return CLASS_QUEST_HEADERS[NormalizeZoneStr(zoneName)] == true or zoneName == "Class Quests"
end
ns.IsClassHeaderName = IsClassHeaderName

local function GetPlayerClassDisplayName()
    return playerClassName or L["Class"]
end
ns.GetPlayerClassDisplayName = GetPlayerClassDisplayName

local function MatchesCurrentZone(zoneHeader, questID, questLogIndex)
    local db = ns.db
    -- Class quests stay visible across zones when grouped under the class header
    if db.headers.separateClassHeader ~= false and db.filtering.alwaysShowClassQuests ~= false
        and IsClassQuest(zoneHeader, questID, questLogIndex) then
        return true
    end

    local normHeader = NormalizeZoneStr(zoneHeader)
    local isClassOrProfHeader = NON_ZONE_HEADERS[normHeader] or false

    if not isClassOrProfHeader and normHeader ~= "" then
        for _, z in ipairs(playerValidZones) do
            local normZ = NormalizeZoneStr(z)
            if normZ ~= "" then
                if normHeader == normZ then
                    return true
                elseif #normZ >= 5 and #normHeader >= 5 and (normHeader:find(normZ, 1, true) or normZ:find(normHeader, 1, true)) then
                    return true
                end
            end
        end
    end

    -- Starter zone heuristic: low level class/profession quests belong to the starter area
    if isClassOrProfHeader then
        for _, z in ipairs(playerValidZones) do
            if STARTER_ZONES[NormalizeZoneStr(z)] then
                local info = questLogIndex and API.GetQuestInfo(questLogIndex, levelInfo)
                if (info and info.level or 1) <= 10 then
                    return true
                end
                break
            end
        end
    end

    if db.filtering.enableCrossZone ~= false and ns.CrossZoneModule and ns.CrossZoneModule.MatchesCurrentZone then
        if ns.CrossZoneModule:MatchesCurrentZone(questID, questLogIndex, playerValidZones) then
            return true
        end
    end
    return false
end

local function FormatTimeLeft(seconds)
    if not seconds or seconds <= 0 then return "00:00" end
    local m = math_floor(seconds / 60)
    local s = math_floor(seconds % 60)
    if m >= 60 then
        return string_format("%d:%02d:%02d", math_floor(m / 60), m % 60, s)
    end
    return string_format("%02d:%02d", m, s)
end

-- ---------------------------------------------------------------------------
-- Bag scan for usable quest items (cached; rebuilt on BAG_UPDATE_DELAYED)
-- ---------------------------------------------------------------------------
local bagQuestItemsCache = {}
local bagCacheDirty = true

local function UpdateBagQuestItemsCache()
    if not bagCacheDirty then return end
    wipe(bagQuestItemsCache)
    bagCacheDirty = false

    local questClass = (Enum and Enum.ItemClass and Enum.ItemClass.Questitem) or 12
    for bag = 0, API.NUM_BAG_SLOTS do
        for slot = 1, (API.GetContainerNumSlots(bag) or 0) do
            local itemID, hyperlink, icon, stackCount = API.GetContainerItemInfo(bag, slot)
            if itemID and hyperlink then
                local _, _, _, _, _, classID = API.GetItemInfoInstant(itemID)
                local spellName = API.GetItemSpell(itemID)
                -- Only items with an On-Use effect qualify (no passive loot such as hides or ores)
                if spellName and spellName ~= "" and (classID == questClass or classID == 0 or classID == 15) then
                    local itemName = hyperlink:match("%[(.-)%]")
                    local data = { link = hyperlink, icon = icon, count = stackCount, name = itemName, itemID = itemID }
                    if itemName and itemName ~= "" then
                        bagQuestItemsCache[string_lower(itemName)] = data
                    end
                    if C_TooltipInfo and C_TooltipInfo.GetBagItem then
                        local tip = C_TooltipInfo.GetBagItem(bag, slot)
                        if tip and tip.lines then
                            for _, line in ipairs(tip.lines) do
                                if line.leftText and line.leftText ~= "" then
                                    bagQuestItemsCache[string_lower(line.leftText)] = data
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

-- Words that describe an item's state rather than what it is ("Empty Cleansing Bowl"
-- and "Filled Cleansing Bowl" are the same quest item)
local ITEM_STATE_WORDS = {
    empty = true, filled = true, full = true, used = true, unused = true, broken = true,
    fixed = true, repaired = true, charged = true, uncharged = true, inert = true, activated = true,
    active = true, inactive = true, cleansed = true, tainted = true, corrupted = true, pure = true,
    sealed = true, unsealed = true, open = true, opened = true, closed = true, the = true, a = true,
    an = true, of = true,
}

-- Finds a usable quest item whose name shares every core word of a remembered item name
local function FindRelatedItemInBags(rememberedName)
    if not rememberedName or rememberedName == "" then return nil end
    UpdateBagQuestItemsCache()
    local core, n = {}, 0
    for word in rememberedName:gmatch("[%w']+") do
        if not ITEM_STATE_WORDS[word] and #word > 2 then
            n = n + 1
            core[n] = word
        end
    end
    if n == 0 then return nil end
    for _, data in pairs(bagQuestItemsCache) do
        local name = data.name and string_lower(data.name)
        if name then
            local matched = true
            for i = 1, n do
                if not name:find(core[i], 1, true) then
                    matched = false
                    break
                end
            end
            if matched then return data end
        end
    end
    return nil
end

local function FindQuestItemInBags(questTitle, objectives)
    UpdateBagQuestItemsCache()
    local qLower = questTitle and string_lower(questTitle) or ""
    if qLower ~= "" then
        local direct = bagQuestItemsCache[qLower]
        if direct then return direct end
        for lineLower, data in pairs(bagQuestItemsCache) do
            if lineLower:find(qLower, 1, true) then
                return data
            end
        end
    end
    if objectives then
        for _, obj in ipairs(objectives) do
            if obj.text and obj.text ~= "" then
                local oLower = string_lower(obj.text)
                for lineLower, data in pairs(bagQuestItemsCache) do
                    if (data.name and oLower:find(string_lower(data.name), 1, true)) or oLower:find(lineLower, 1, true) then
                        return data
                    end
                end
            end
        end
    end
    return nil
end

-- ---------------------------------------------------------------------------
-- Sorting (static comparators, zero closure allocations)
-- ---------------------------------------------------------------------------
local sortMode_active = "level"
local sortMoveCompleted_active = false
local sortActiveOnTop_active = true
local sortActiveQID_active = nil

local function CompareLevelThenID(a, b)
    local lvlA = tonumber(a.level) or 0
    local lvlB = tonumber(b.level) or 0
    if lvlA ~= lvlB then return lvlA < lvlB end
    return (a.questID or 0) < (b.questID or 0)
end

local function QuestListComparator(a, b)
    if sortActiveOnTop_active and sortActiveQID_active then
        local isAActive = (a.questID == sortActiveQID_active)
        local isBActive = (b.questID == sortActiveQID_active)
        if isAActive ~= isBActive then return isAActive end
    end
    if sortMoveCompleted_active and (a.isComplete ~= b.isComplete) then
        return not a.isComplete
    end
    if sortMode_active == "zone" then
        local zoneA = tostring(a.zone or "")
        local zoneB = tostring(b.zone or "")
        if zoneA ~= zoneB then return zoneA < zoneB end
    end
    return CompareLevelThenID(a, b)
end

local function ListHas(list, predicate)
    for i = 1, #list do
        if predicate(list[i]) then return true end
    end
    return false
end

local function IsActiveEntry(q) return q.questID == sortActiveQID_active end
local function IsIncompleteEntry(q) return not q.isComplete end

local function ZoneOrderComparator(zA, zB)
    local listA, listB = zoneMap[zA], zoneMap[zB]
    if sortActiveOnTop_active and sortActiveQID_active then
        local hasA, hasB = ListHas(listA, IsActiveEntry), ListHas(listB, IsActiveEntry)
        if hasA ~= hasB then return hasA end
    end
    if sortMoveCompleted_active then
        local allDoneA = #listA > 0 and not ListHas(listA, IsIncompleteEntry)
        local allDoneB = #listB > 0 and not ListHas(listB, IsIncompleteEntry)
        if allDoneA ~= allDoneB then return not allDoneA end
    end
    -- Class header sits at the bottom unless it contains the active quest
    local isClassA, isClassB = IsClassHeaderName(zA), IsClassHeaderName(zB)
    if isClassA ~= isClassB then return isClassB end
    return (initialOrder[zA] or 0) < (initialOrder[zB] or 0)
end

local function ZoneQuestComparator(a, b)
    if sortActiveOnTop_active and sortActiveQID_active then
        local isAActive = (a.questID == sortActiveQID_active)
        local isBActive = (b.questID == sortActiveQID_active)
        if isAActive ~= isBActive then return isAActive end
    end
    if sortMoveCompleted_active and (a.isComplete ~= b.isComplete) then
        return not a.isComplete
    end
    return CompareLevelThenID(a, b)
end

-- ---------------------------------------------------------------------------
-- Quest collection (read-only: never changes saved settings or the quest log selection)
-- ---------------------------------------------------------------------------
function StandaloneTracker:GetTrackedQuests()
    ReleaseQuestEntries(cachedTrackedQuests)
    UpdatePlayerValidZones()
    local db = ns.db
    local quests = cachedTrackedQuests
    local filterMode = db.filtering.filterMode or "all"
    local untracked = db.filtering.untrackedQuests
    local separateClassHeader = db.headers.separateClassHeader ~= false
    local autoDetectItems = db.itemButtons.autoDetect ~= false
    local questItemNames = ns.dbObject.global.questItemNames
    local activeZoneHeader = ZONE_GENERAL

    for i = 1, API.GetNumQuestLogEntries() do
        local info = API.GetQuestInfo(i, rowInfo)
        if info then
            if info.isHeader then
                activeZoneHeader = info.title or ZONE_GENERAL
            elseif not info.isHidden then
                local questID = info.questID
                local include = true
                if questID and untracked[questID] then
                    include = false
                elseif filterMode == "zone" then
                    include = MatchesCurrentZone(activeZoneHeader, questID, i)
                elseif filterMode == "watched" then
                    include = API.IsQuestWatched(questID, i)
                end

                if include then
                    local title, level, group, frequency = info.title, info.level, info.suggestedGroup, info.frequency
                    local completeVal = info.isComplete
                    local entry = AcquireQuestEntry()
                    local objectives = API.GetQuestObjectives(questID, i, entry.objectives)

                    local isFailed = (completeVal == -1) or API.IsQuestFailed(questID, i, objectives)
                    local isComplete = not isFailed and (completeVal == 1 or API.IsQuestComplete(questID, i, objectives))

                    -- Usable quest item (quest log special item first, then optional bag detection)
                    local itemLink, itemTexture, numItems = API.GetQuestSpecialItem(questID, i)
                    if not itemTexture and autoDetectItems then
                        local bagItem = FindQuestItemInBags(title, objectives)
                            -- The quest's item may have changed form (e.g. empty bowl -> filled bowl)
                            or FindRelatedItemInBags(questItemNames[questID])
                        if bagItem then
                            itemLink, itemTexture, numItems = bagItem.link, bagItem.icon, bagItem.count
                        end
                    end
                    local itemID = type(itemLink) == "string" and tonumber(itemLink:match("item:(%d+)")) or nil
                    if itemLink then
                        local itemName = type(itemLink) == "string" and itemLink:match("%[(.-)%]")
                        if itemName and itemName ~= "" then
                            questItemNames[questID] = string_lower(itemName)
                        end
                    end

                    -- Tag / Badge detection
                    local isElite, isDungeon, isRaid = false, false, false
                    local tagInfo = API.GetQuestTagInfo(questID, i)
                    if type(tagInfo) == "table" then
                        isElite = tagInfo.isElite or (tagInfo.tagID == 1)
                        isDungeon = (tagInfo.tagID == 81)
                        isRaid = (tagInfo.tagID == 62)
                    elseif type(tagInfo) == "number" then
                        isElite = (tagInfo == 1)
                        isDungeon = (tagInfo == 81)
                        isRaid = (tagInfo == 62)
                    end
                    local numericGroup = 0
                    if type(group) == "string" then
                        local sLower = string_lower(group)
                        if group == _G.DUNGEON or sLower:find("dungeon", 1, true) then
                            isDungeon = true
                        elseif group == _G.RAID or sLower:find("raid", 1, true) then
                            isRaid = true
                        elseif group == _G.ELITE or sLower:find("elite", 1, true) then
                            isElite = true
                        else
                            numericGroup = tonumber(group) or 0
                        end
                    elseif type(group) == "number" then
                        numericGroup = group
                    end

                    entry.questLogIndex = i
                    entry.questID = questID
                    entry.title = title
                    entry.level = tonumber(level) or 0
                    entry.suggestedGroup = numericGroup
                    entry.isElite = isElite
                    entry.isDungeon = isDungeon
                    entry.isRaid = isRaid
                    entry.isClassQuest = IsClassQuest(activeZoneHeader, questID, i, title)
                    entry.zone = (entry.isClassQuest and separateClassHeader) and GetPlayerClassDisplayName() or activeZoneHeader
                    entry.isFailed = isFailed
                    entry.isComplete = isComplete
                    entry.frequency = tonumber(frequency) or 1
                    entry.objectives = objectives
                    entry.itemLink = itemLink
                    entry.itemTexture = itemTexture
                    entry.itemID = itemID
                    entry.numItems = tonumber(numItems) or 0
                    quests[#quests + 1] = entry
                end
            end
        end
    end

    sortMode_active = db.sorting.mode or "level"
    sortMoveCompleted_active = db.sorting.moveCompletedToBottom
    sortActiveOnTop_active = db.sorting.activeOnTop ~= false
    sortActiveQID_active = ns.activeQuestID
    table_sort(quests, QuestListComparator)
    return quests
end

-- ---------------------------------------------------------------------------
-- Rendering
-- ---------------------------------------------------------------------------
local DEFAULT_ARROW_TEXTURE = "Interface\\Minimap\\ROTATING-MINIMAPGUIDEARROW"
local DEFAULT_COMPLETED_BG = { r = 0.00, g = 0.80, b = 0.20, a = 0.14 }
local DEFAULT_OBJECTIVE_COLOR = { r = 0.80, g = 0.80, b = 0.80 }

local function StyleInlineArrow(wfArrow, size)
    wfArrow:SetSize(size, size)
    local wf = ns.WayfinderModule
    local arrowTex = (wf and wf.GetInlineArrowTexture and wf:GetInlineArrowTexture()) or DEFAULT_ARROW_TEXTURE
    if wfArrow.SetSnapToPixelGrid then wfArrow:SetSnapToPixelGrid(false) end
    if wfArrow.SetTexelSnappingBias then wfArrow:SetTexelSnappingBias(0) end
    if not pcall(wfArrow.SetTexture, wfArrow, arrowTex, "CLAMP", "CLAMP", "TRILINEAR") then
        wfArrow:SetTexture(arrowTex)
    end
    wfArrow:SetTexCoord(0, 1, 0, 1)
    local nav = wf and wf.GetNavigationState and wf:GetNavigationState()
    if nav and nav.hasTarget then
        wfArrow:SetRotation(nav.relativeAngle)
        wfArrow:SetVertexColor(nav.r or 1.0, nav.g or 0.82, nav.b or 0.0, 1.0)
    else
        wfArrow:SetRotation(0)
        wfArrow:SetVertexColor(1.0, 0.82, 0.0, 0.85)
    end
    wfArrow:Show()
end

local STATUS_ICON_TEXTURES = {
    star = { "Interface\\TargetingFrame\\UI-RaidTargetingIcon_1", 0, 1, 0, 1 },
    arrow = { "Interface\\Common\\CommonIcons", 573/2048, 728/2048, 266/1024, 516/1024 },
    pointer = { "Interface\\Common\\CommonIcons", 573/2048, 728/2048, 266/1024, 516/1024 },
    blizz = { "Interface\\GossipFrame\\AvailableQuestIcon", 0, 1, 0, 1 },
}

local function TimerLineText(seconds)
    return string_format("|cffffcc00 - %s [%s]|r", L["Time Remaining:"], FormatTimeLeft(seconds))
end

local function AddObjectiveLine(block, prevAnchor, objIndent, objWidth, lineSpacing, text)
    local fs = AcquireObjectiveString(block)
    fs:ClearAllPoints()
    if prevAnchor == block.header then
        fs:SetPoint("TOPLEFT", prevAnchor, "BOTTOMLEFT", objIndent, -lineSpacing)
    else
        fs:SetPoint("TOPLEFT", prevAnchor, "BOTTOMLEFT", 0, -lineSpacing)
    end
    fs:SetWidth(objWidth)
    fs:SetWordWrap(true)
    fs:SetJustifyH("LEFT")
    fs:SetText(text)
    return fs, math_ceil(fs:GetStringHeight()) + lineSpacing
end

local function RenderQuestBlock(content, qInfo, yOffset, lineSpacing)
    local db = ns.db
    yOffset = math_floor((yOffset or 0) + 0.5)
    local contentWidth = content:GetWidth()
    local block = AcquireQuestBlock(content)
    block:SetWidth(contentWidth)
    block:ClearAllPoints()
    block:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -yOffset)
    block:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -yOffset)
    wipe(block.questInfo)
    for k, v in pairs(qInfo) do
        block.questInfo[k] = v
    end
    block.header.questInfo = block.questInfo
    block.timerFs = nil

    local header = block.header
    local questKey = qInfo.questID or qInfo.title
    local isCollapsed = db.collapsedQuests[questKey]

    header:SetWidth(contentWidth)
    header:ClearAllPoints()
    header:SetPoint("TOPLEFT", block, "TOPLEFT", 0, 0)
    header:SetPoint("TOPRIGHT", block, "TOPRIGHT", 0, 0)

    local wfDb = db.wayfinder
    local showInlineArrow = ns.IsModuleEnabled("wayfinder") and wfDb.enableInlineArrow and qInfo.questID and (qInfo.questID == ns.activeQuestID)
    local arrowPos = wfDb.inlineArrowPosition or "left"
    local inlineSize = wfDb.inlineArrowSize or 22

    local isPreviewHost = StandaloneTracker.itemPreview and qInfo.questID and qInfo.questID == StandaloneTracker.previewHostID
    local hasItem = (qInfo.itemID ~= nil or isPreviewHost) and db.itemButtons.enabled ~= false
    local itemSize = db.itemButtons.size or 26
    local rightItemOffset = (hasItem and (db.itemButtonPlacement or "inside_right") == "inside_right" and not db.itemButtonPosition) and -(itemSize + 4) or 0

    -- Action buttons sit left of an inside-right item button; the title ends before them
    local titleRightOffset = rightItemOffset - LayoutActionBar(header, qInfo, rightItemOffset, StandaloneTracker.titleSize or 13)

    local isComplete = qInfo.isComplete and not qInfo.isFailed
    if isComplete and db.fonts.completedQuestBg ~= false then
        local cBg = db.fonts.completedQuestBgColor or DEFAULT_COMPLETED_BG
        block.completedBg:SetColorTexture(cBg.r or 0, cBg.g or 0.8, cBg.b or 0.2, cBg.a or 0.14)
        block.completedBg:Show()
    else
        block.completedBg:Hide()
    end

    local alignTitles = db.sorting.alignQuestTitles ~= false
    local titleSize = StandaloneTracker.titleSize or 13
    -- Title column: wide enough for the left inline arrow at its chosen size. The
    -- width comes from settings only, so every quest keeps the same column.
    local prefixWidth = 16
    if ns.IsModuleEnabled("wayfinder") and wfDb.enableInlineArrow and arrowPos == "left" then
        prefixWidth = math_max(prefixWidth, inlineSize)
    end
    local isActive = ns.activeQuestID and (qInfo.questID == ns.activeQuestID)
    local wfArrow = header.wayfinderArrow
    local sIcon = header.statusIcon
    local titleFs = header.title

    titleFs:ClearAllPoints()
    wfArrow:Hide()
    sIcon:Hide()
    if alignTitles then
        titleFs:SetPoint("TOPLEFT", header, "TOPLEFT", prefixWidth + 4, 0)
        titleFs:SetPoint("TOPRIGHT", header, "TOPRIGHT", titleRightOffset, 0)

        if showInlineArrow and arrowPos == "left" then
            local aSize = math_min(prefixWidth, inlineSize)
            StyleInlineArrow(wfArrow, aSize)
            wfArrow:ClearAllPoints()
            wfArrow:SetPoint("LEFT", header, "LEFT", math_floor((prefixWidth - aSize) / 2), 0)
        elseif isComplete and db.headers.showCompleteIcon ~= false then
            local iconSize = math_min(prefixWidth, math_max(12, titleSize))
            sIcon:ClearAllPoints()
            sIcon:SetSize(iconSize, iconSize)
            sIcon:SetPoint("LEFT", header, "LEFT", math_floor((prefixWidth - iconSize) / 2), 0)
            sIcon:SetTexture("Interface\\GossipFrame\\ActiveQuestIcon")
            sIcon:SetTexCoord(0, 1, 0, 1)
            sIcon:SetVertexColor(1, 1, 1, 1)
            sIcon:Show()
        elseif isActive then
            local tex = STATUS_ICON_TEXTURES[db.activeQuestIcon or "star"]
            if tex then
                local iconSize = math_min(prefixWidth, 13)
                sIcon:ClearAllPoints()
                sIcon:SetSize(iconSize, iconSize)
                sIcon:SetPoint("LEFT", header, "LEFT", math_floor((prefixWidth - iconSize) / 2), 0)
                sIcon:SetTexture(tex[1])
                sIcon:SetTexCoord(tex[2], tex[3], tex[4], tex[5])
                sIcon:SetVertexColor(1, 1, 1, 1)
                sIcon:Show()
            end
        end

        if showInlineArrow and arrowPos == "right" then
            StyleInlineArrow(wfArrow, inlineSize)
            wfArrow:ClearAllPoints()
            wfArrow:SetPoint("RIGHT", header, "RIGHT", -2 + titleRightOffset, 0)
            titleFs:SetPoint("RIGHT", wfArrow, "LEFT", -4, 0)
        end
        titleFs:SetText(GetFormattedQuestTitle(qInfo, true))
    else
        if showInlineArrow then
            StyleInlineArrow(wfArrow, inlineSize)
            wfArrow:ClearAllPoints()
            if arrowPos == "left" then
                wfArrow:SetPoint("LEFT", header, "LEFT", 0, 0)
                titleFs:SetPoint("LEFT", wfArrow, "RIGHT", 4, 0)
                titleFs:SetPoint("RIGHT", header, "RIGHT", titleRightOffset, 0)
            else
                wfArrow:SetPoint("RIGHT", header, "RIGHT", -2 + titleRightOffset, 0)
                titleFs:SetPoint("TOPLEFT", header, "TOPLEFT", 0, 0)
                titleFs:SetPoint("RIGHT", wfArrow, "LEFT", -4, 0)
            end
        else
            titleFs:SetPoint("TOPLEFT", header, "TOPLEFT", 0, 0)
            titleFs:SetPoint("TOPRIGHT", header, "TOPRIGHT", titleRightOffset, 0)
        end
        titleFs:SetText(GetFormattedQuestTitle(qInfo, false))
    end
    titleFs:SetWordWrap(true)
    titleFs:SetJustifyH("LEFT")

    local titleHeight = math_max(titleSize + 6, math_ceil(titleFs:GetStringHeight() + 2), showInlineArrow and (inlineSize + 2) or 0)
    titleHeight = math_floor((titleHeight + 1) / 2) * 2
    header:SetHeight(titleHeight)
    local currentBlockHeight = titleHeight

    if qInfo.questID and StandaloneTracker.activeBlocks then
        StandaloneTracker.activeBlocks[qInfo.questID] = block
    end

    if not isCollapsed then
        local fontDb = db.fonts
        local objHex = ColorToHex(fontDb.objectiveColor or DEFAULT_OBJECTIVE_COLOR)
        local compHex = ColorToHex(fontDb.completedObjectiveColor or DEFAULT_COMPLETE_COLOR)
        local prevAnchor = header
        local objIndent = alignTitles and (prefixWidth + 4) or 6
        local objWidth = math_max(50, contentWidth - objIndent - 6 + math_min(0, rightItemOffset))
        local fs, h, _

        if qInfo.isFailed then
            _, h = AddObjectiveLine(block, prevAnchor, objIndent, objWidth, lineSpacing, "|cffff2020" .. L["Quest Failed"] .. "|r")
            currentBlockHeight = currentBlockHeight + h
        else
            -- Countdown timer line (refreshed in place by the 1-second ticker)
            if db.showTimerInObjectives ~= false and qInfo.questID then
                local tSec = ns.GetQuestTimeLeft(qInfo.questID, qInfo.questLogIndex)
                if tSec and tSec > 0 then
                    fs, h = AddObjectiveLine(block, prevAnchor, objIndent, objWidth, lineSpacing, TimerLineText(tSec))
                    currentBlockHeight = currentBlockHeight + h
                    prevAnchor = fs
                    block.timerFs = fs
                    block.timerQuestID = qInfo.questID
                    timerBlocks[#timerBlocks + 1] = block
                end
            end

            if qInfo.isComplete then
                _, h = AddObjectiveLine(block, prevAnchor, objIndent, objWidth, lineSpacing, compHex .. L["Ready for turn-in"] .. "|r")
                currentBlockHeight = currentBlockHeight + h
            elseif qInfo.objectives then
                for _, obj in ipairs(qInfo.objectives) do
                    local colorCode = obj.finished and compHex or objHex
                    fs, h = AddObjectiveLine(block, prevAnchor, objIndent, objWidth, lineSpacing, colorCode .. " - " .. (obj.text or "") .. "|r")
                    currentBlockHeight = currentBlockHeight + h
                    prevAnchor = fs
                end
            end
        end
    end

    currentBlockHeight = math_floor(currentBlockHeight + 0.5)
    block:SetHeight(currentBlockHeight)
    return currentBlockHeight
end

-- Updates countdown text in place; returns false when a timer ended and a full redraw is needed
local function RefreshTimerLines()
    for i = 1, #timerBlocks do
        local block = timerBlocks[i]
        local fs = block.timerFs
        if fs and block.timerQuestID then
            local tSec = ns.GetQuestTimeLeft(block.timerQuestID)
            if not tSec or tSec <= 0 then
                return false
            end
            fs:SetText(TimerLineText(tSec))
        end
    end
    return true
end

local DEFAULT_BORDER = { r = 0.15, g = 0.15, b = 0.15, a = 0.9 }
local DEFAULT_ZONE_COLOR = { r = 1.0, g = 0.82, b = 0.0, a = 1.0 }
local classBorderColor = { r = 0, g = 0, b = 0, a = 0.9 }

local function StyleZoneHeader(zh, hCfg, zhColor, zhTextColor, isZoneCollapsed)
    local zhTexType = hCfg.zoneHeaderTexture or "gradient"
    local bg = zh.bg
    if zhTexType == "none" then
        bg:Hide()
    elseif zhTexType == "blizzard" then
        bg:Show()
        if bg.SetAtlas and C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("Objective-Header") then
            bg:SetAtlas("Objective-Header")
            bg:SetVertexColor(1, 1, 1, zhColor.a or 0.8)
        else
            bg:SetTexture("Interface\\QuestFrame\\UI-QuestHeader")
            bg:SetVertexColor(zhColor.r, zhColor.g, zhColor.b, zhColor.a or 0.8)
        end
    elseif zhTexType == "flat" then
        bg:Show()
        bg:SetColorTexture(zhColor.r, zhColor.g, zhColor.b, (zhColor.a or 1.0) * 0.25)
    else -- "gradient"
        bg:Show()
        if bg.SetGradient and CreateColor then
            bg:SetColorTexture(1, 1, 1, 1)
            bg:SetGradient("HORIZONTAL",
                CreateColor(zhColor.r, zhColor.g, zhColor.b, (zhColor.a or 1.0) * 0.35),
                CreateColor(zhColor.r, zhColor.g, zhColor.b, 0))
        else
            bg:SetColorTexture(zhColor.r, zhColor.g, zhColor.b, 0.25)
        end
    end

    local zHl = ns.db.fonts.zoneHoverColor or DEFAULT_ZONE_COLOR
    zh.highlight:SetColorTexture(zHl.r, zHl.g, zHl.b, zHl.a or 0.12)

    local collapseShape = hCfg.zoneCollapseIcon or "arrow"
    local iconColor = hCfg.zoneCollapseIconColor or zhTextColor
    local title = zh.title
    title:ClearAllPoints()
    if collapseShape == "none" then
        zh.collapseArrow:Hide()
        zh.collapseText:Hide()
        title:SetPoint("LEFT", zh, "LEFT", 8, 0)
    elseif collapseShape == "plusminus" then
        zh.collapseArrow:Hide()
        zh.collapseText:Show()
        zh.collapseText:ClearAllPoints()
        zh.collapseText:SetPoint("LEFT", zh, "LEFT", 4, 0)
        zh.collapseText:SetWidth(20)
        zh.collapseText:SetText(isZoneCollapsed and "[+]" or "[-]")
        zh.collapseText:SetTextColor(iconColor.r, iconColor.g, iconColor.b, iconColor.a or 1)
        title:SetPoint("LEFT", zh.collapseText, "RIGHT", 4, 0)
    else -- "arrow"
        zh.collapseText:Hide()
        local arrow = zh.collapseArrow
        arrow:Show()
        arrow:SetSize(12, 12)
        arrow:SetTexture("Interface\\Common\\CommonIcons")
        arrow:SetTexCoord(573/2048, 728/2048, 266/1024, 516/1024)
        arrow:SetVertexColor(iconColor.r, iconColor.g, iconColor.b, iconColor.a or 1)
        arrow:ClearAllPoints()
        arrow:SetPoint("LEFT", zh, "LEFT", 6, 0)
        arrow:SetRotation(isZoneCollapsed and 0 or (math.pi / 2))
        title:SetPoint("LEFT", arrow, "RIGHT", 6, 0)
    end
    title:SetPoint("RIGHT", zh, "RIGHT", -6, 0)
end

function StandaloneTracker:UpdateTracker()
    local content = ns.Tracker and ns.Tracker:GetContentFrame()
    if not content or not ns.db then return end

    local db = ns.db
    if not self.activeBlocks then
        self.activeBlocks = {}
    else
        wipe(self.activeBlocks)
    end
    wipe(timerBlocks)

    for _, fs in ipairs(objectiveStrings) do fs:Hide() end
    for _, fs in ipairs(partyStrings) do fs:Hide() end
    for _, btn in ipairs(shareButtons) do btn:Hide() end
    for _, blk in ipairs(questBlocks) do blk:Hide() end
    for _, zh in ipairs(zoneHeaders) do zh:Hide() end

    -- Keep the active quest while it is in the quest log, even if a filter hides it
    if ns.activeQuestID and not API.IsQuestInLog(ns.activeQuestID) then
        ns.activeQuestID = nil
        API.SetSuperTrackedQuestID(0)
        local wf = ns.WayfinderModule
        if wf and wf.ClearWaypoint and not (wf.IsCustomTarget and wf:IsCustomTarget()) then
            wf:ClearWaypoint(true)
        end
    end
    if not ns.activeQuestID and not ns.waypointExplicitlyCleared then
        local stID = API.GetSuperTrackedQuestID()
        if stID and stID > 0 and API.IsQuestInLog(stID) then
            ns.activeQuestID = stID
        end
    end
    -- Point the Wayfinder at a newly activated quest (it tracks progress itself afterwards)
    if ns.activeQuestID ~= self.lastWayfinderQuestID then
        self.lastWayfinderQuestID = ns.activeQuestID
        local wf = ns.WayfinderModule
        if ns.activeQuestID and wf and wf.SetQuestTarget and not (wf.IsCustomTarget and wf:IsCustomTarget()) then
            wf:SetQuestTarget(ns.activeQuestID, true, false)
        end
    end

    local trackedQuests = self:GetTrackedQuests()

    -- Test button host: the first quest without its own item, so the two never share a row
    self.previewHostID = nil
    if self.itemPreview then
        for _, q in ipairs(trackedQuests) do
            if q.questID and not q.itemID then
                self.previewHostID = q.questID
                break
            end
        end
    end

    -- Row boundaries let the tracker end on a whole row and scroll row by row
    local rowStarts, rowEnds = self.rowStarts, self.rowEnds
    wipe(rowStarts)
    wipe(rowEnds)
    local contentBottom = 0

    local yOffset = 0
    local blockSpacing = 10
    local lineSpacing = 3
    local hCfg = db.headers

    if hCfg.showZoneHeaders ~= false then
        for z, list in pairs(zoneMap) do
            wipe(list)
            table_insert(zoneListPool, list)
            zoneMap[z] = nil
        end
        wipe(zoneOrder)
        wipe(initialOrder)

        for _, qInfo in ipairs(trackedQuests) do
            local z = qInfo.zone or ZONE_OTHER
            local list = zoneMap[z]
            if not list then
                list = table_remove(zoneListPool) or {}
                zoneMap[z] = list
                zoneOrder[#zoneOrder + 1] = z
            end
            list[#list + 1] = qInfo
        end
        for idx, zName in ipairs(zoneOrder) do
            initialOrder[zName] = idx
        end
        table_sort(zoneOrder, ZoneOrderComparator)

        -- Colors are resolved once per redraw (no tables created per zone)
        local borderRef = db.backdrop.borderColor or DEFAULT_BORDER
        if db.backdrop.classColorBorder then
            local cc = ns.GetClassColor()
            classBorderColor.r, classBorderColor.g, classBorderColor.b = cc.r, cc.g, cc.b
            classBorderColor.a = borderRef.a or 0.9
            borderRef = classBorderColor
        end
        local zhColor = (hCfg.zoneHeaderColorShare and borderRef) or hCfg.zoneHeaderColor or DEFAULT_ZONE_COLOR
        local zhTextColorDefault = (hCfg.zoneHeaderColorShare and borderRef) or hCfg.zoneTextColor or hCfg.zoneHeaderColor or DEFAULT_ZONE_COLOR
        local classColor = ns.GetClassColor()
        local titleSize = self.titleSize or 13
        local baseHeaderHeight = math_max(22, math_floor((titleSize + 7) / 2) * 2)
        local width = content:GetWidth()

        for _, z in ipairs(zoneOrder) do
            local qList = zoneMap[z]
            local isZoneCollapsed = db.collapsedZones[z]
            table_sort(qList, ZoneQuestComparator)

            yOffset = math_floor(yOffset + 0.5)
            local zh = AcquireZoneHeader(content)
            zh.zoneName = z
            zh.displayName = (z == ZONE_GENERAL or z == ZONE_OTHER) and L[z] or z
            zh:SetWidth(width)
            zh:ClearAllPoints()
            zh:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -yOffset)
            zh:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -yOffset)
            zh:SetHeight(baseHeaderHeight)

            local zhTextColor = IsClassHeaderName(z) and classColor or zhTextColorDefault
            StyleZoneHeader(zh, hCfg, zhColor, zhTextColor, isZoneCollapsed)

            local label = zh.displayName
            if hCfg.showZoneCount ~= false then
                label = string_format("%s |cffaaaaaa(%d)|r", label, #qList)
            end
            zh.title:SetJustifyH("LEFT")
            zh.title:SetJustifyV("MIDDLE")
            zh.title:SetWordWrap(true)
            zh.title:SetText(label)
            zh.title:SetTextColor(zhTextColor.r, zhTextColor.g, zhTextColor.b)

            local zhHeight = baseHeaderHeight
            local textH = math_ceil(zh.title:GetStringHeight() + 6)
            if textH > zhHeight then
                zhHeight = math_floor((textH + 1) / 2) * 2
            end
            zh:SetHeight(zhHeight)
            zh.collapseText:SetHeight(zhHeight)
            rowStarts[#rowStarts + 1] = yOffset
            contentBottom = yOffset + zhHeight
            rowEnds[#rowEnds + 1] = contentBottom
            yOffset = yOffset + zhHeight + 4

            if not isZoneCollapsed then
                for _, qInfo in ipairs(qList) do
                    rowStarts[#rowStarts + 1] = yOffset
                    local h = RenderQuestBlock(content, qInfo, yOffset, lineSpacing)
                    contentBottom = yOffset + h
                    rowEnds[#rowEnds + 1] = contentBottom
                    yOffset = yOffset + h + blockSpacing
                end
                yOffset = yOffset + 2
            end
        end
    else
        for _, qInfo in ipairs(trackedQuests) do
            rowStarts[#rowStarts + 1] = yOffset
            local h = RenderQuestBlock(content, qInfo, yOffset, lineSpacing)
            contentBottom = yOffset + h
            rowEnds[#rowEnds + 1] = contentBottom
            yOffset = yOffset + h + blockSpacing
        end
    end

    ns.hasActiveQuestTimer = #timerBlocks > 0

    local _, numQuests = API.CountQuests()
    -- Spacing after the last row is not content; the frame ends right under it
    ns.Tracker:UpdateHeight(math_ceil(contentBottom))
    ns.Tracker:SetQuestCount(#trackedQuests, numQuests, API.GetMaxQuests())
    ns.Tracker:UpdateFilterButtons()

    self:UpdateItemButton(trackedQuests)
end

-- Throttled Tracker Redraw Engine (coalesces bursts of quest/bag events into one redraw)
local updateScheduled = false
local function RunScheduledUpdate()
    updateScheduled = false
    StandaloneTracker:UpdateTracker()
end

function StandaloneTracker:RequestUpdate(immediate)
    if immediate then
        updateScheduled = false
        self:UpdateTracker()
        return
    end
    if updateScheduled then return end
    updateScheduled = true
    C_Timer.After(0.04, RunScheduledUpdate)
end

-- Live 1-Second Countdown Ticker (updates timer text only; full redraw only when a timer ends)
local timerTickerFrame = CreateFrame("Frame")
local timerTickerElapsed = 0
timerTickerFrame:SetScript("OnUpdate", function(_, elapsed)
    if not ns.hasActiveQuestTimer then
        timerTickerElapsed = 0
        return
    end
    timerTickerElapsed = timerTickerElapsed + elapsed
    if timerTickerElapsed < 1.0 then return end
    timerTickerElapsed = 0
    local tf = ns.Tracker and ns.Tracker.frame
    if tf and not tf:IsShown() then return end
    if not RefreshTimerLines() then
        StandaloneTracker:RequestUpdate()
    end
end)

-- ---------------------------------------------------------------------------
-- Lifecycle
-- ---------------------------------------------------------------------------
local function OnQuestWatchAdded(questID)
    local untracked = ns.db and ns.db.filtering.untrackedQuests
    if questID and untracked and untracked[questID] then
        untracked[questID] = nil
        StandaloneTracker:RequestUpdate()
    end
end

local function OnQuestWatchRemoved(questID)
    local untracked = ns.db and ns.db.filtering.untrackedQuests
    if questID and untracked and not untracked[questID] then
        untracked[questID] = true
        StandaloneTracker:RequestUpdate()
    end
end

local function QuestIDFromIndex(questIndex)
    local info = questIndex and API.GetQuestInfo(questIndex, {})
    return info and info.questID
end

function StandaloneTracker:Initialize()
    HookBlizzardTracker()
    self:UpdateCombatVisibilityDriver()

    -- Pre-create the primary quest item button so the CLICK key binding always has a target
    self:GetOrCreateItemButton(1)

    -- Quest watch changes made from Blizzard's quest log
    if C_QuestLog and C_QuestLog.AddQuestWatch then
        hooksecurefunc(C_QuestLog, "AddQuestWatch", OnQuestWatchAdded)
    end
    if C_QuestLog and C_QuestLog.RemoveQuestWatch then
        hooksecurefunc(C_QuestLog, "RemoveQuestWatch", OnQuestWatchRemoved)
    end
    if _G.AddQuestWatch then
        hooksecurefunc("AddQuestWatch", function(questIndex) OnQuestWatchAdded(QuestIDFromIndex(questIndex)) end)
    end
    if _G.RemoveQuestWatch then
        hooksecurefunc("RemoveQuestWatch", function(questIndex) OnQuestWatchRemoved(QuestIDFromIndex(questIndex)) end)
    end
    local function RefreshTimerBar()
        if ns.DataBarsModule and ns.DataBarsModule.UpdateTimerBar then
            ns.DataBarsModule:UpdateTimerBar()
        end
    end
    if C_SuperTrack and C_SuperTrack.SetSuperTrackedQuestID then
        hooksecurefunc(C_SuperTrack, "SetSuperTrackedQuestID", RefreshTimerBar)
    end
    if _G.QuestMapFrame_OpenToQuestDetails then
        hooksecurefunc("QuestMapFrame_OpenToQuestDetails", RefreshTimerBar)
    end

    local eventFrame = CreateFrame("Frame")
    self.eventFrame = eventFrame
    for _, event in ipairs({
        "ADDON_LOADED", "PLAYER_ENTERING_WORLD", "QUEST_LOG_UPDATE", "QUEST_WATCH_UPDATE",
        "QUEST_ACCEPTED", "QUEST_REMOVED", "ZONE_CHANGED", "ZONE_CHANGED_NEW_AREA",
        "UNIT_QUEST_LOG_CHANGED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
        "BAG_UPDATE_DELAYED", "BAG_UPDATE_COOLDOWN", "ACTIONBAR_UPDATE_COOLDOWN",
    }) do
        eventFrame:RegisterEvent(event)
    end
    for _, optional in ipairs({ "QUEST_TURNED_IN", "QUEST_TIMER_UPDATE", "QUEST_TIMERS_UPDATE", "SUPER_TRACKING_CHANGED" }) do
        pcall(eventFrame.RegisterEvent, eventFrame, optional)
    end

    eventFrame:SetScript("OnEvent", function(_, event, arg1)
        if event == "ADDON_LOADED" then
            if arg1 == "Blizzard_ObjectiveTracker" then
                HookBlizzardTracker()
            end
            return
        elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
            HookBlizzardTracker()
        elseif event == "UNIT_QUEST_LOG_CHANGED" and arg1 ~= "player" then
            return
        elseif event == "BAG_UPDATE_DELAYED" then
            bagCacheDirty = true
        elseif event == "BAG_UPDATE_COOLDOWN" or event == "ACTIONBAR_UPDATE_COOLDOWN" then
            StandaloneTracker:UpdateItemButtonCooldowns()
            return
        elseif event == "QUEST_WATCH_UPDATE" then
            local qID = arg1
            if qID and qID < 1000 then
                qID = QuestIDFromIndex(qID) or qID
            end
            if qID and API.IsQuestWatched(qID, arg1) then
                ns.db.filtering.untrackedQuests[qID] = nil
            end
        elseif event == "SUPER_TRACKING_CHANGED" then
            local stID = API.GetSuperTrackedQuestID()
            if stID and stID > 0 and stID ~= ns.activeQuestID then
                ns.activeQuestID = stID
                ns.waypointExplicitlyCleared = false
                RefreshTimerBar()
            elseif (not stID or stID == 0) and ns.activeQuestID then
                ns.activeQuestID = nil
                ns.waypointExplicitlyCleared = true
                local wf = ns.WayfinderModule
                if wf and wf.ClearWaypoint and not (wf.IsCustomTarget and wf:IsCustomTarget()) then
                    wf:ClearWaypoint(true)
                end
                RefreshTimerBar()
            else
                return
            end
        elseif event == "PLAYER_REGEN_DISABLED" then
            StandaloneTracker.inCombat = true
            StandaloneTracker:RefreshActionBars()
            local filtering = ns.db.filtering
            local tracker = ns.Tracker
            if filtering.hideInCombat and tracker and tracker.frame then
                tracker.frame:Hide()
            end
            if filtering.collapseInCombat and tracker and not tracker.isCollapsed then
                StandaloneTracker.collapsedByCombat = true
                tracker:ToggleCollapse()
            end
            return
        elseif event == "PLAYER_REGEN_ENABLED" then
            StandaloneTracker.inCombat = false
            if blizzardHidePending then
                HookBlizzardTracker()
            end
            if combatDriverPending then
                StandaloneTracker:UpdateCombatVisibilityDriver()
            end
            local tracker = ns.Tracker
            if StandaloneTracker.collapsedByCombat then
                StandaloneTracker.collapsedByCombat = false
                if tracker and tracker.isCollapsed then
                    tracker:ToggleCollapse()
                end
            end
            if tracker then
                if tracker.UpdateVisibility then tracker:UpdateVisibility() end
                StandaloneTracker:SyncSecureVisibility(not tracker.isHidden)
            end
            if StandaloneTracker.pendingItemUpdate then
                StandaloneTracker.pendingItemUpdate = false
                StandaloneTracker:UpdateItemButtonStrata()
            end
            StandaloneTracker:RequestUpdate(true)
            return
        elseif event == "QUEST_ACCEPTED" then
            if arg1 then ns.db.filtering.untrackedQuests[arg1] = nil end
        elseif event == "QUEST_REMOVED" or event == "QUEST_TURNED_IN" then
            if arg1 then
                ns.ClearQuestTimer(arg1)
                questRewardsCache[arg1] = nil
                ns.db.collapsedQuests[arg1] = nil
                ns.db.filtering.untrackedQuests[arg1] = nil
                ns.dbObject.global.questItemNames[arg1] = nil
            end
        end
        StandaloneTracker:RequestUpdate()
    end)

    ns:RegisterCallback("QUEST_DATA_CHANGED", function()
        StandaloneTracker:RequestUpdate()
    end)
    ns:RegisterCallback("SETTINGS_UPDATED", function()
        StandaloneTracker:UpdateCombatVisibilityDriver()
        StandaloneTracker:RequestUpdate()
    end)
    ns:RegisterCallback("TRACKER_DOCKING_CHANGED", function()
        StandaloneTracker:UpdateItemButtonVisibility()
    end)
    ns:RegisterCallback("TRACKER_DRAG_STARTED", function()
        if not (ns.db and ns.db.itemButtonPosition) then
            dragFollower:Show()
        end
    end)

    C_Timer.After(0.5, function()
        HookBlizzardTracker()
        StandaloneTracker:RequestUpdate(true)
    end)
end
