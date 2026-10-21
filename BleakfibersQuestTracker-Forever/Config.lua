local addonName, ns = ...

-- Single options UI: the same tab set is hosted by the standalone window,
-- the Blizzard Settings panel, and Bleakfiber's Addon Config hub.

local L = ns.L
local LSM = LibStub("LibSharedMedia-3.0")

local Config = {}
ns.Config = Config

-- Every widget change funnels into one debounced re-apply of all settings
local applyPending = false
local function ScheduleApply()
    if applyPending then return end
    applyPending = true
    C_Timer.After(0.05, function()
        applyPending = false
        ns.ApplyAllSettings()
    end)
end

-- Dedicated Copy URL Dialog Frame
local copyDialogFrame

local function GetOrCreateCopyDialog()
    if copyDialogFrame then return copyDialogFrame end

    copyDialogFrame = CreateFrame("Frame", "BleakfiberCopyURLDialog", UIParent, BackdropTemplateMixin and "BackdropTemplate")
    copyDialogFrame:SetSize(420, 110)
    copyDialogFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 100)
    copyDialogFrame:SetFrameStrata("FULLSCREEN_DIALOG")
    copyDialogFrame:SetFrameLevel(110)
    copyDialogFrame:SetClampedToScreen(true)
    copyDialogFrame:EnableMouse(true)
    copyDialogFrame:SetMovable(true)
    copyDialogFrame:RegisterForDrag("LeftButton")
    copyDialogFrame:SetScript("OnDragStart", copyDialogFrame.StartMoving)
    copyDialogFrame:SetScript("OnDragStop", copyDialogFrame.StopMovingOrSizing)

    copyDialogFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false,
        tileSize = 16,
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    copyDialogFrame:SetBackdropColor(0.06, 0.06, 0.08, 0.98)
    copyDialogFrame:SetBackdropBorderColor(0.15, 0.55, 0.95, 0.9)

    -- Header Title
    local title = copyDialogFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    copyDialogFrame.title = title
    title:SetPoint("TOPLEFT", copyDialogFrame, "TOPLEFT", 14, -12)
    title:SetPoint("RIGHT", copyDialogFrame, "RIGHT", -30, 0)
    title:SetJustifyH("LEFT")
    title:SetText("|cff00c0ffBleakfiber's Quest Tracker|r - " .. L["Copy Wowhead URL"])

    -- Instruction text
    local note = copyDialogFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    note:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    note:SetText(L["Press Ctrl+C to copy the link, then press Enter or Escape to close:"])

    -- Close Button [X]
    local closeBtn = CreateFrame("Button", nil, copyDialogFrame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", copyDialogFrame, "TOPRIGHT", -4, -4)
    closeBtn:SetScript("OnClick", function() copyDialogFrame:Hide() end)

    -- EditBox
    local editBox = CreateFrame("EditBox", "BleakfiberCopyURLEditBox", copyDialogFrame, "InputBoxTemplate")
    copyDialogFrame.editBox = editBox
    editBox:SetSize(390, 24)
    editBox:SetPoint("TOPLEFT", note, "BOTTOMLEFT", 4, -8)
    editBox:SetAutoFocus(false)
    editBox:SetScript("OnEscapePressed", function(self) copyDialogFrame:Hide() end)
    editBox:SetScript("OnEnterPressed", function(self) copyDialogFrame:Hide() end)
    editBox:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)

    -- Done Button
    local doneBtn = CreateFrame("Button", nil, copyDialogFrame, "UIPanelButtonTemplate")
    doneBtn:SetSize(80, 22)
    doneBtn:SetPoint("BOTTOMRIGHT", copyDialogFrame, "BOTTOMRIGHT", -14, 10)
    doneBtn:SetText(L["Done"])
    doneBtn:SetScript("OnClick", function() copyDialogFrame:Hide() end)

    if UISpecialFrames then
        tinsert(UISpecialFrames, "BleakfiberCopyURLDialog")
    end

    return copyDialogFrame
end

function Config:ShowCopyDialog(url, questTitle)
    local dialog = GetOrCreateCopyDialog()
    if questTitle and questTitle ~= "" then
        dialog.title:SetText("|cff00c0ffBleakfiber's Quest Tracker|r - " .. questTitle)
    else
        dialog.title:SetText("|cff00c0ffBleakfiber's Quest Tracker|r - " .. L["Copy Wowhead URL"])
    end
    dialog:Show()
    dialog:Raise()
    dialog.editBox:SetText(url or "")
    dialog.editBox:SetFocus()
    dialog.editBox:HighlightText()
end

-- Dedicated Custom Quick Menu Frame (Independent of Blizzard UIDropDownMenu)
local quickMenuPopup = nil
local quickMenuCatcher = nil

local function GetOrCreateQuickMenu()
    if quickMenuPopup then return quickMenuPopup end

    -- Fullscreen dismiss click-catcher
    quickMenuCatcher = CreateFrame("Button", "BleakfiberQuickMenuCatcher", UIParent)
    quickMenuCatcher:SetAllPoints(UIParent)
    quickMenuCatcher:SetFrameStrata("FULLSCREEN_DIALOG")
    quickMenuCatcher:SetFrameLevel(90)
    quickMenuCatcher:EnableMouse(true)
    quickMenuCatcher:Hide()
    quickMenuCatcher:SetScript("OnClick", function()
        if quickMenuPopup then quickMenuPopup:Hide() end
    end)

    local menu = CreateFrame("Frame", "BleakfiberQuickMenuPopup", UIParent, "BackdropTemplate")
    if not menu.SetBackdrop and BackdropTemplateMixin then
        Mixin(menu, BackdropTemplateMixin)
    end
    quickMenuPopup = menu
    menu:SetFrameStrata("FULLSCREEN_DIALOG")
    menu:SetFrameLevel(100)
    menu:SetWidth(225)
    menu:SetClampedToScreen(true)
    menu:EnableMouse(true)
    menu:Hide()

    menu:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false,
        tileSize = 0,
        edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    menu:SetBackdropColor(0.06, 0.06, 0.08, 0.96)
    menu:SetBackdropBorderColor(0.20, 0.60, 0.95, 0.85)

    menu:SetScript("OnShow", function()
        quickMenuCatcher:Show()
    end)
    menu:SetScript("OnHide", function()
        quickMenuCatcher:Hide()
    end)

    return menu
end

-- Filter & Quick Options Menu for Tracker Header
function Config:OpenFilterMenu(anchor)
    local db = ns.db
    if not db then return end

    local menu = GetOrCreateQuickMenu()
    if menu:IsShown() then
        menu:Hide()
        return
    end

    local mScale = (db.fonts and db.fonts.menuScale) or 1.0
    if mScale and mScale > 0 then
        menu:SetScale(mScale)
    end

    if not menu.items then
        menu.items = {}
    end
    for _, item in ipairs(menu.items) do
        item:Hide()
    end

    local rows = {
        { type = "title", text = "|cff00c0ff" .. L["Tracker Options"] .. "|r" },
        { type = "sep" },
        { type = "header", text = L["Sort Quests"] },
        {
            type = "radio",
            text = L["Level"],
            checked = (db.sorting.mode == "level"),
            onClick = function()
                db.sorting.mode = "level"
                ns:FireCallback("QUEST_DATA_CHANGED")
            end,
        },
        {
            type = "radio",
            text = L["Zone"],
            checked = (db.sorting.mode == "zone"),
            onClick = function()
                db.sorting.mode = "zone"
                ns:FireCallback("QUEST_DATA_CHANGED")
            end,
        },
    }

    table.insert(rows, { type = "header", text = L["Show Quests"] })
    local currentFilter = (db.filtering and db.filtering.filterMode) or "all"
    for _, mode in ipairs({ { "all", L["All Quests"] }, { "zone", L["Current Zone Only"] }, { "watched", L["Watched Only"] } }) do
        table.insert(rows, {
            type = "radio",
            text = mode[2],
            checked = (currentFilter == mode[1]),
            onClick = function() Config:SetFilterMode(mode[1]) end,
        })
    end
    table.insert(rows, { type = "header", text = L["Sorting & Display"] })
    table.insert(rows, {
        type = "checkbox",
        text = L["Active Quest on Top"],
        checked = not (db.sorting and db.sorting.activeOnTop == false),
        onClick = function()
            db.sorting = db.sorting or {}
            db.sorting.activeOnTop = db.sorting.activeOnTop == false
            ns:FireCallback("QUEST_DATA_CHANGED")
        end,
    })

    table.insert(rows, {
        type = "checkbox",
        text = L["Left-Click Sets Active"],
        checked = (db.sorting and db.sorting.leftClickSetsActive == true),
        onClick = function()
            db.sorting = db.sorting or {}
            db.sorting.leftClickSetsActive = db.sorting.leftClickSetsActive ~= true
            if ns.StandaloneTracker and ns.StandaloneTracker.UpdateTracker then
                ns.StandaloneTracker:UpdateTracker()
            end
        end,
    })

    table.insert(rows, {
        type = "checkbox",
        text = L["Completed to Bottom"],
        checked = db.sorting and db.sorting.moveCompletedToBottom,
        onClick = function()
            db.sorting = db.sorting or {}
            db.sorting.moveCompletedToBottom = not db.sorting.moveCompletedToBottom
            ns:FireCallback("QUEST_DATA_CHANGED")
        end,
    })

    table.insert(rows, {
        type = "checkbox",
        text = L["Color by Difficulty"],
        checked = not (db.fonts and db.fonts.colorDifficulty == false),
        onClick = function()
            db.fonts = db.fonts or {}
            db.fonts.colorDifficulty = db.fonts.colorDifficulty == false
            ns:FireCallback("QUEST_DATA_CHANGED")
        end,
    })

    table.insert(rows, {
        type = "checkbox",
        text = L["Show Complete Icon (?)"],
        checked = not (db.headers and db.headers.showCompleteIcon == false),
        onClick = function()
            db.headers = db.headers or {}
            db.headers.showCompleteIcon = db.headers.showCompleteIcon == false
            ns:FireCallback("QUEST_DATA_CHANGED")
        end,
    })

    table.insert(rows, {
        type = "checkbox",
        text = L["Show Quest Rewards"],
        checked = not (db.tooltips and db.tooltips.showRewards == false),
        onClick = function()
            db.tooltips = db.tooltips or {}
            db.tooltips.showRewards = db.tooltips.showRewards == false
        end,
    })

    table.insert(rows, {
        type = "checkbox",
        text = L["Show Party Members"],
        checked = not (db.tooltips and db.tooltips.showPartyStatus == false),
        onClick = function()
            db.tooltips = db.tooltips or {}
            db.tooltips.showPartyStatus = db.tooltips.showPartyStatus == false
        end,
    })

    table.insert(rows, { type = "sep" })
    table.insert(rows, { type = "header", text = L["Wayfinder Navigation"] })
    table.insert(rows, {
        type = "checkbox",
        text = L["Show Floating Arrow"],
        checked = db.wayfinder and db.wayfinder.enableHUDArrow,
        onClick = function()
            db.wayfinder = db.wayfinder or {}
            db.wayfinder.enableHUDArrow = not db.wayfinder.enableHUDArrow
            if ns.WayfinderModule then ns.WayfinderModule:RefreshState() end
        end,
    })
    table.insert(rows, {
        type = "checkbox",
        text = L["Show Inline Mini-Arrow"],
        checked = db.wayfinder and db.wayfinder.enableInlineArrow,
        onClick = function()
            db.wayfinder = db.wayfinder or {}
            db.wayfinder.enableInlineArrow = not db.wayfinder.enableInlineArrow
            if ns.WayfinderModule then ns.WayfinderModule:RefreshState() end
            ns:FireCallback("QUEST_DATA_CHANGED")
        end,
    })

    table.insert(rows, { type = "sep" })
    table.insert(rows, { type = "header", text = L["Tracker Actions"] })
    table.insert(rows, {
        type = "checkbox",
        text = L["Show Zone Headers"],
        checked = db.headers and db.headers.showZoneHeaders ~= false,
        onClick = function()
            db.headers = db.headers or {}
            db.headers.showZoneHeaders = db.headers.showZoneHeaders == false
            ns:FireCallback("QUEST_DATA_CHANGED")
        end,
    })
    table.insert(rows, {
        type = "checkbox",
        text = L["Lock Position"],
        checked = db.isLocked,
        onClick = function()
            ns.Tracker:SetLocked(not db.isLocked)
        end,
    })
    table.insert(rows, {
        type = "button",
        text = L["Expand All Quests"],
        onClick = function()
            if db then
                db.collapsedQuests = {}
                ns:FireCallback("QUEST_DATA_CHANGED")
            end
            menu:Hide()
        end,
    })
    table.insert(rows, {
        type = "button",
        text = L["Collapse All Quests"],
        onClick = function()
            if db and ns.StandaloneTracker and ns.StandaloneTracker.GetTrackedQuests then
                db.collapsedQuests = db.collapsedQuests or {}
                local quests = ns.StandaloneTracker:GetTrackedQuests()
                for _, q in ipairs(quests) do
                    local key = q.questID or q.title
                    if key then
                        db.collapsedQuests[key] = true
                    end
                end
                ns:FireCallback("QUEST_DATA_CHANGED")
            end
            menu:Hide()
        end,
    })
    if db.headers and db.headers.showZoneHeaders ~= false then
        table.insert(rows, {
            type = "button",
            text = L["Expand All Zones"],
            onClick = function()
                if db then
                    db.collapsedZones = {}
                    ns:FireCallback("QUEST_DATA_CHANGED")
                end
                menu:Hide()
            end,
        })
        table.insert(rows, {
            type = "button",
            text = L["Collapse All Zones"],
            onClick = function()
                if db and ns.StandaloneTracker and ns.StandaloneTracker.GetTrackedQuests then
                    db.collapsedZones = db.collapsedZones or {}
                    local quests = ns.StandaloneTracker:GetTrackedQuests()
                    for _, q in ipairs(quests) do
                        local z = q.zone or L["Other Quests"]
                        db.collapsedZones[z] = true
                    end
                    ns:FireCallback("QUEST_DATA_CHANGED")
                end
                menu:Hide()
            end,
        })
    end

    table.insert(rows, { type = "sep" })
    local currentProfile = (ns.dbObject and ns.dbObject.GetCurrentProfile and ns.dbObject:GetCurrentProfile()) or "Default"
    table.insert(rows, { type = "header", text = string.format(L["Profile: %s"], currentProfile) })
    table.insert(rows, {
        type = "button",
        text = L["Settings & Appearance..."],
        onClick = function()
            menu:Hide()
            Config:ToggleConfigFrame()
        end,
    })
    table.insert(rows, {
        type = "button",
        text = L["Close"],
        onClick = function()
            menu:Hide()
        end,
    })

    local fontPath = (ns.StandaloneTracker and ns.StandaloneTracker.fontPath)
        or ns.FetchFont(db.fonts and db.fonts.font)
    local fontSize = 11

    local function SafeSetFont(fs, path, size, flags)
        if not fs then return end
        if path and pcall(fs.SetFont, fs, path, size, flags or "") then return end
        if STANDARD_TEXT_FONT and pcall(fs.SetFont, fs, STANDARD_TEXT_FONT, size, flags or "") then return end
    end

    local yOffset = -8
    for idx, row in ipairs(rows) do
        local item = menu.items[idx]
        if not item then
            item = CreateFrame("Button", nil, menu)
            item:SetWidth(209)
            item:SetHeight(18)
            item.highlight = item:CreateTexture(nil, "HIGHLIGHT")
            item.highlight:SetAllPoints()
            item.highlight:SetColorTexture(0, 0.75, 1, 0.15)

            item.line = item:CreateTexture(nil, "ARTWORK")
            item.line:SetHeight(1)
            item.line:SetPoint("LEFT", item, "LEFT", 2, 0)
            item.line:SetPoint("RIGHT", item, "RIGHT", -2, 0)
            item.line:SetColorTexture(1, 1, 1, 0.10)

            item.check = item:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            item.check:SetPoint("LEFT", item, "LEFT", 4, 0)

            item.text = item:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            item.text:SetPoint("LEFT", item.check, "RIGHT", 6, 0)
            item.text:SetPoint("RIGHT", item, "RIGHT", -4, 0)
            item.text:SetJustifyH("LEFT")

            menu.items[idx] = item
        end

        item:ClearAllPoints()
        item:SetPoint("TOPLEFT", menu, "TOPLEFT", 8, yOffset)
        item:Show()

        if row.type == "title" then
            item:EnableMouse(false)
            if item.line then item.line:Hide() end
            item.check:SetText("")
            item.text:ClearAllPoints()
            item.text:SetAllPoints(item)
            SafeSetFont(item.text, fontPath, fontSize + 1, "OUTLINE")
            item.text:SetText(row.text)
            item.text:SetJustifyH("CENTER")
            yOffset = yOffset - 22
        elseif row.type == "sep" then
            item:EnableMouse(false)
            item.check:SetText("")
            item.text:SetText("")
            if item.line then item.line:Show() end
            yOffset = yOffset - 8
        elseif row.type == "header" then
            item:EnableMouse(false)
            if item.line then item.line:Hide() end
            item.check:SetText("")
            item.text:ClearAllPoints()
            item.text:SetPoint("LEFT", item, "LEFT", 4, 0)
            item.text:SetPoint("RIGHT", item, "RIGHT", -4, 0)
            SafeSetFont(item.text, fontPath, fontSize - 1, "OUTLINE")
            item.text:SetText("|cff00c0ff" .. row.text:upper() .. "|r")
            item.text:SetJustifyH("LEFT")
            yOffset = yOffset - 16
        elseif row.type == "radio" then
            item:EnableMouse(true)
            if item.line then item.line:Hide() end
            SafeSetFont(item.check, fontPath, fontSize, "")
            SafeSetFont(item.text, fontPath, fontSize, "")
            local mark = row.checked and "|TInterface\\Common\\CommonIcons:13:13:0:0:2048:1024:271:510:26:235|t" or "|cff666666( )|r"
            local color = row.checked and "|cffffffff" or "|cffcccccc"
            item.check:ClearAllPoints()
            item.check:SetPoint("LEFT", item, "LEFT", 4, 0)
            item.check:SetText(mark)
            item.text:ClearAllPoints()
            item.text:SetPoint("LEFT", item.check, "RIGHT", 6, 0)
            item.text:SetPoint("RIGHT", item, "RIGHT", -4, 0)
            item.text:SetText(color .. row.text .. "|r")
            item.text:SetJustifyH("LEFT")
            item:SetScript("OnClick", function()
                if PlaySound then
                    PlaySound((SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON) or 856)
                end
                row.onClick()
                menu:Hide()
                Config:OpenFilterMenu(anchor)
            end)
            yOffset = yOffset - 18
        elseif row.type == "checkbox" then
            item:EnableMouse(true)
            if item.line then item.line:Hide() end
            SafeSetFont(item.check, fontPath, fontSize, "")
            SafeSetFont(item.text, fontPath, fontSize, "")
            local mark = row.checked and "|TInterface\\Common\\CommonIcons:13:13:0:0:2048:1024:13:253:542:752|t" or "|cff666666[ ]|r"
            local color = row.checked and "|cffffffff" or "|cffcccccc"
            item.check:ClearAllPoints()
            item.check:SetPoint("LEFT", item, "LEFT", 4, 0)
            item.check:SetText(mark)
            item.text:ClearAllPoints()
            item.text:SetPoint("LEFT", item.check, "RIGHT", 6, 0)
            item.text:SetPoint("RIGHT", item, "RIGHT", -4, 0)
            item.text:SetText(color .. row.text .. "|r")
            item.text:SetJustifyH("LEFT")
            item:SetScript("OnClick", function()
                if PlaySound then
                    PlaySound((SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON) or 856)
                end
                row.onClick()
                menu:Hide()
                Config:OpenFilterMenu(anchor)
            end)
            yOffset = yOffset - 18
        elseif row.type == "button" then
            item:EnableMouse(true)
            if item.line then item.line:Hide() end
            item.check:SetText("")
            item.text:ClearAllPoints()
            item.text:SetAllPoints(item)
            SafeSetFont(item.text, fontPath, fontSize, "")
            item.text:SetText("|cff00c0ff" .. row.text .. "|r")
            item.text:SetJustifyH("CENTER")
            item:SetScript("OnClick", function()
                if PlaySound then
                    PlaySound((SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON) or 856)
                end
                row.onClick()
            end)
            yOffset = yOffset - 20
        end
    end

    menu:SetHeight(math.abs(yOffset) + 10)

    -- Anchor menu
    menu:ClearAllPoints()
    if anchor and anchor.GetRight and anchor:GetRight() then
        menu:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -4)
    else
        local x, y = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale() or 1
        menu:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", (x or 0) / scale, (y or 0) / scale)
    end

    menu:Show()
end
Config.OpenQuickMenu = Config.OpenFilterMenu

function Config:SetFilterMode(mode)
    local db = ns.db
    if not db then return end
    db.filtering.filterMode = mode
    if ns.Tracker and ns.Tracker.UpdateFilterButtons then
        ns.Tracker:UpdateFilterButtons()
    end
    ns:FireCallback("QUEST_DATA_CHANGED")
    Config:SyncAll()
end

local function GetStatusbarTextureList()
    local list = {
        { key = "Solid", label = L["Solid / Flat"] },
        { key = "Blizzard", label = L["Blizzard Default Statusbar"] },
    }
    local seen = { Solid = true, Blizzard = true }
    local names = LSM:List("statusbar")
    if type(names) == "table" then
        for _, texName in ipairs(names) do
            if not seen[texName] then
                seen[texName] = true
                list[#list + 1] = { key = texName, label = texName }
            end
        end
    end
    return list
end

function Config:ApplyModernGlassPreset()
    local db = ns.db
    if not db then return end
    db.backdrop = db.backdrop or {}
    db.backdrop.show = true
    db.backdrop.borderStyle = "flat"
    db.backdrop.borderWidth = 1
    db.backdrop.edgeSize = 1
    db.backdrop.insets = 0
    db.backdrop.bgTexture = "solid"
    db.backdrop.bgColor = { r = 0.05, g = 0.05, b = 0.05, a = 0.65 }
    db.backdrop.borderColor = { r = 0.15, g = 0.15, b = 0.15, a = 0.90 }
    db.backdrop.classColorBorder = false

    db.headers = db.headers or {}
    db.headers.texture = "flat"
    db.headers.textureColor = { r = 0.05, g = 0.08, b = 0.12, a = 0.85 }
    db.headers.zoneHeaderTexture = "gradient"
    db.headers.zoneHeaderColor = { r = 1.0, g = 0.82, b = 0.0, a = 1.0 }

    db.fonts = db.fonts or {}
    db.fonts.headerFont = "Nata Sans Bold"
    db.fonts.objectiveFont = "Nata Sans Regular"
    db.fonts.headerSize = 13
    db.fonts.objectiveSize = 11
    db.fonts.colorDifficulty = true

    ns.ApplyAllSettings()
    Config:SyncAll()
end

function Config:ApplyClassicPreset()
    local db = ns.db
    if not db then return end
    db.backdrop = db.backdrop or {}
    db.backdrop.show = true
    db.backdrop.borderStyle = "tooltip"
    db.backdrop.edgeSize = 16
    db.backdrop.insets = 4
    db.backdrop.bgTexture = "parchment"
    db.backdrop.bgColor = { r = 0.96, g = 0.90, b = 0.78, a = 0.90 }
    db.backdrop.borderColor = { r = 0.80, g = 0.65, b = 0.20, a = 0.90 }
    db.backdrop.classColorBorder = false

    db.headers = db.headers or {}
    db.headers.texture = "gradient"
    db.headers.zoneHeaderTexture = "gradient"
    db.headers.zoneHeaderColor = { r = 1.0, g = 0.82, b = 0.0, a = 1.0 }

    db.fonts = db.fonts or {}
    db.fonts.headerFont = "Friz Quadrata TT"
    db.fonts.objectiveFont = "Friz Quadrata TT"
    db.fonts.headerSize = 13
    db.fonts.objectiveSize = 11
    db.fonts.colorDifficulty = true

    ns.ApplyAllSettings()
    Config:SyncAll()
end

function Config:ApplyMinimalPreset()
    local db = ns.db
    if not db then return end
    db.backdrop = db.backdrop or {}
    db.backdrop.show = true
    db.backdrop.borderStyle = "none"
    db.backdrop.edgeSize = 0
    db.backdrop.insets = 0
    db.backdrop.bgTexture = "solid"
    db.backdrop.bgColor = { r = 0.0, g = 0.0, b = 0.0, a = 0.35 }
    db.backdrop.borderColor = { r = 0, g = 0, b = 0, a = 0 }
    db.backdrop.classColorBorder = false

    db.headers = db.headers or {}
    db.headers.texture = "none"
    db.headers.zoneHeaderTexture = "none"

    ns.ApplyAllSettings()
    Config:SyncAll()
end

-- ---------------------------------------------------------------------------
-- Master Config Addon Integration & Dark Slate / Gold Standalone Theme
-- ---------------------------------------------------------------------------

local BACKDROP_TEMPLATE = "BackdropTemplate"

local MAIN_WINDOW_BACKDROP = {
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
}

local INSET_BACKDROP = {
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 12,
    edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 }
}

local COLORS = {
    bgSlate      = { 0.08, 0.10, 0.13, 0.96 }, -- Dark iron / slate
    sidebarBg    = { 0.06, 0.07, 0.09, 0.92 }, -- Deep inset background
    contentBg    = { 0.05, 0.06, 0.08, 0.94 }, -- Dark content background
    goldBorder   = { 0.82, 0.68, 0.28, 1.00 }, -- Bright beveled gold
    goldMuted    = { 0.50, 0.42, 0.20, 0.85 }, -- Muted gold border
    goldText     = { 1.00, 0.82, 0.25 },       -- #FFD140
    whiteText    = { 0.90, 0.92, 0.94 },
    dimText      = { 0.55, 0.58, 0.63 },
    tabNormal    = { 0.12, 0.14, 0.17, 0.65 },
    tabHighlight = { 0.20, 0.22, 0.27, 0.80 },
    tabActive    = { 0.22, 0.19, 0.12, 0.95 }, -- Gold-tinted active tab
}

--[[-----------------------------------------------------------------------------
    Native Bleakfiber UI Widgets & Responsive Layout Engine for Quest Tracker
-------------------------------------------------------------------------------]]
local function SetupAutoScroll(scrollFrame, scrollChild)
    if not (scrollFrame and scrollChild) then return end
    local scrollBar = _G[scrollFrame:GetName() and (scrollFrame:GetName() .. "ScrollBar")]

    local function UpdateScrollState()
        local frameHeight = scrollFrame:GetHeight()
        local childHeight = scrollChild:GetHeight()
        if not frameHeight or frameHeight <= 0 then return end
        if childHeight <= frameHeight + 2 then
            if scrollBar and scrollBar:IsShown() then
                scrollBar:Hide()
            end
            scrollFrame:EnableMouseWheel(false)
            scrollFrame:SetVerticalScroll(0)
        else
            if scrollBar and not scrollBar:IsShown() then
                scrollBar:Show()
            end
            scrollFrame:EnableMouseWheel(true)
        end
    end

    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local frameHeight = self:GetHeight()
        local childHeight = scrollChild:GetHeight()
        if not frameHeight or childHeight <= frameHeight + 2 then return end
        local cur = self:GetVerticalScroll()
        local maxScroll = math.max(0, childHeight - frameHeight)
        local step = 32
        local newScroll = cur - (delta * step)
        if newScroll < 0 then newScroll = 0 end
        if newScroll > maxScroll then newScroll = maxScroll end
        self:SetVerticalScroll(newScroll)
    end)

    scrollFrame:HookScript("OnSizeChanged", UpdateScrollState)
    scrollChild:HookScript("OnSizeChanged", UpdateScrollState)
    scrollFrame:HookScript("OnShow", UpdateScrollState)
    UpdateScrollState()
    return UpdateScrollState
end

local function CreateSectionHeader(parent, text, xOfs, yOfs)
    text = L[text]
    local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header:SetPoint("TOPLEFT", parent, "TOPLEFT", xOfs or 16, yOfs or -10)
    header:SetText(text)
    header:SetTextColor(COLORS.goldText[1], COLORS.goldText[2], COLORS.goldText[3])

    local divider = parent:CreateTexture(nil, "ARTWORK")
    divider:SetHeight(1)
    divider:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -4)
    divider:SetPoint("RIGHT", parent, "RIGHT", -16, 0)
    divider:SetColorTexture(COLORS.goldMuted[1], COLORS.goldMuted[2], COLORS.goldMuted[3], 0.5)

    return header, divider
end

local function CreateStyledCheckbox(parent, labelText, tooltipText, getFunc, setFunc)
    labelText = L[labelText]
    tooltipText = tooltipText and L[tooltipText]
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(22, 22)

    local text = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("LEFT", cb, "RIGHT", 6, 1)
    text:SetText(labelText)
    text:SetWordWrap(true)
    text:SetJustifyH("LEFT")
    cb.Text = text

    if tooltipText then
        cb:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(labelText, COLORS.goldText[1], COLORS.goldText[2], COLORS.goldText[3])
            GameTooltip:AddLine(tooltipText, COLORS.whiteText[1], COLORS.whiteText[2], COLORS.whiteText[3], true)
            GameTooltip:Show()
        end)
        cb:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end

    cb:SetScript("OnClick", function(self)
        local checked = self:GetChecked()
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 856)
        if setFunc then setFunc(checked) end
        ScheduleApply()
    end)

    cb.Sync = function()
        if getFunc then cb:SetChecked(getFunc() == true) end
    end

    return cb
end

local function CreateStyledSlider(parent, name, labelText, tooltipText, minVal, maxVal, step, getFunc, setFunc, formatStr)
    labelText = L[labelText]
    tooltipText = tooltipText and L[tooltipText]
    local slider = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
    slider:SetWidth(190)
    slider:SetHeight(16)
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)

    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("BOTTOMLEFT", slider, "TOPLEFT", 0, 4)
    label:SetText(labelText)
    label:SetTextColor(COLORS.goldText[1], COLORS.goldText[2], COLORS.goldText[3])
    slider.Label = label

    local lowText = _G[slider:GetName() .. "Low"]
    local highText = _G[slider:GetName() .. "High"]
    local valText = _G[slider:GetName() .. "Text"]

    if lowText then
        lowText:SetText(tostring(minVal))
        lowText:SetTextColor(COLORS.dimText[1], COLORS.dimText[2], COLORS.dimText[3])
    end
    if highText then
        highText:SetText(tostring(maxVal))
        highText:SetTextColor(COLORS.dimText[1], COLORS.dimText[2], COLORS.dimText[3])
    end

    if valText then
        valText:ClearAllPoints()
        valText:SetPoint("BOTTOMRIGHT", slider, "TOPRIGHT", 0, 4)
        valText:SetJustifyH("RIGHT")
        valText:SetTextColor(COLORS.whiteText[1], COLORS.whiteText[2], COLORS.whiteText[3])
    end

    formatStr = formatStr or "%d"

    local function UpdateValText(val)
        if valText then
            valText:SetText(string.format(formatStr, val))
        end
    end

    slider:SetScript("OnValueChanged", function(self, val)
        val = math.floor((val / step) + 0.5) * step
        UpdateValText(val)
        if self._isSyncing then return end
        if setFunc then setFunc(val) end
        ScheduleApply()
    end)

    if tooltipText then
        slider:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(labelText, COLORS.goldText[1], COLORS.goldText[2], COLORS.goldText[3])
            GameTooltip:AddLine(tooltipText, COLORS.whiteText[1], COLORS.whiteText[2], COLORS.whiteText[3], true)
            GameTooltip:Show()
        end)
        slider:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end

    slider.Sync = function()
        if getFunc then
            slider._isSyncing = true
            local cur = getFunc() or minVal
            slider:SetValue(cur)
            UpdateValText(cur)
            slider._isSyncing = false
        end
    end

    return slider
end

local function CreateStyledButton(parent, text, width, height, onClick, tooltipText)
    text = L[text]
    tooltipText = tooltipText and L[tooltipText]
    local btn = CreateFrame("Button", nil, parent, BACKDROP_TEMPLATE)
    btn:SetSize(width or 120, height or 22)
    btn:SetBackdrop(INSET_BACKDROP)
    btn:SetBackdropColor(unpack(COLORS.tabNormal))
    btn:SetBackdropBorderColor(unpack(COLORS.goldMuted))

    local label = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("CENTER", btn, "CENTER", 0, 0)
    label:SetText(text)
    btn.Label = label

    btn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.20, 0.22, 0.28, 0.95)
        self:SetBackdropBorderColor(unpack(COLORS.goldBorder))
        label:SetTextColor(COLORS.goldText[1], COLORS.goldText[2], COLORS.goldText[3])
        if tooltipText then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(text, COLORS.goldText[1], COLORS.goldText[2], COLORS.goldText[3])
            GameTooltip:AddLine(tooltipText, COLORS.whiteText[1], COLORS.whiteText[2], COLORS.whiteText[3], true)
            GameTooltip:Show()
        end
    end)

    btn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(unpack(COLORS.tabNormal))
        self:SetBackdropBorderColor(unpack(COLORS.goldMuted))
        label:SetTextColor(COLORS.whiteText[1], COLORS.whiteText[2], COLORS.whiteText[3])
        if tooltipText then GameTooltip:Hide() end
    end)

    if onClick then
        btn:SetScript("OnClick", function(self)
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 856)
            onClick(self)
        end)
    end

    return btn
end

local function CreateStyledColorPickerWithHex(parent, labelText, width, height, getColorFunc, setColorFunc, tooltipText, syncListRef)
    labelText = labelText and L[labelText]
    tooltipText = tooltipText and L[tooltipText]
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(width or 190, height or 22)

    -- Left part: Color Swatch Button (opens ColorPickerFrame)
    local swatchBtn = CreateFrame("Button", nil, container, BACKDROP_TEMPLATE)
    swatchBtn:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
    swatchBtn:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT", 0, 0)
    swatchBtn:SetWidth(112)
    swatchBtn:SetBackdrop(INSET_BACKDROP)
    swatchBtn:SetBackdropColor(unpack(COLORS.tabNormal))
    swatchBtn:SetBackdropBorderColor(unpack(COLORS.goldMuted))

    local swatchBorder = swatchBtn:CreateTexture(nil, "BACKGROUND")
    swatchBorder:SetSize(14, 14)
    swatchBorder:SetPoint("LEFT", swatchBtn, "LEFT", 6, 0)
    swatchBorder:SetColorTexture(0.7, 0.7, 0.7, 1)

    local swatchTex = swatchBtn:CreateTexture(nil, "ARTWORK")
    swatchTex:SetSize(12, 12)
    swatchTex:SetPoint("CENTER", swatchBorder, "CENTER", 0, 0)
    swatchTex:SetColorTexture(0.05, 0.05, 0.05, 1)

    local btnLabel = swatchBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    btnLabel:SetPoint("LEFT", swatchBorder, "RIGHT", 6, 0)
    btnLabel:SetPoint("RIGHT", swatchBtn, "RIGHT", -4, 0)
    btnLabel:SetJustifyH("LEFT")
    btnLabel:SetWordWrap(false)
    btnLabel:SetText(labelText or L["Background Color"])

    -- Right part: Direct Hex EditBox (#000000)
    local hexBoxFrame = CreateFrame("Frame", nil, container, BACKDROP_TEMPLATE)
    hexBoxFrame:SetPoint("TOPLEFT", swatchBtn, "TOPRIGHT", 4, 0)
    hexBoxFrame:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", 0, 0)
    hexBoxFrame:SetBackdrop(INSET_BACKDROP)
    hexBoxFrame:SetBackdropColor(0.04, 0.05, 0.07, 0.95)
    hexBoxFrame:SetBackdropBorderColor(unpack(COLORS.goldMuted))

    local hexEdit = CreateFrame("EditBox", nil, hexBoxFrame)
    hexEdit:SetAllPoints(hexBoxFrame)
    hexEdit:SetAutoFocus(false)
    hexEdit:SetMaxLetters(7)
    hexEdit:SetFontObject("GameFontHighlightSmall")
    hexEdit:SetJustifyH("CENTER")

    local function SyncVisuals()
        local r, g, b = 0.05, 0.05, 0.05
        if getColorFunc then
            local cr, cg, cb = getColorFunc()
            if cr ~= nil then r, g, b = cr, cg, cb end
        end
        swatchTex:SetColorTexture(r, g, b, 1)
        if not hexEdit:HasFocus() then
            hexEdit:SetText(string.format("#%02X%02X%02X", math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5)))
        end
    end

    local function ApplyNewColor(r, g, b, a)
        if setColorFunc then
            setColorFunc(r, g, b, a)
        end
        SyncVisuals()
        if syncListRef then
            for _, w in ipairs(syncListRef) do
                if w ~= container and w.Sync then w.Sync() end
            end
        end
        ScheduleApply()
    end

    hexEdit:SetScript("OnEnterPressed", function(self)
        local raw = (self:GetText() or ""):gsub("%s+", ""):gsub("^#", "")
        if #raw == 3 then
            raw = raw:sub(1, 1):rep(2) .. raw:sub(2, 2):rep(2) .. raw:sub(3, 3):rep(2)
        end
        if #raw == 6 then
            local rHex = tonumber(raw:sub(1, 2), 16)
            local gHex = tonumber(raw:sub(3, 4), 16)
            local bHex = tonumber(raw:sub(5, 6), 16)
            if rHex and gHex and bHex then
                local _, _, _, curA = getColorFunc()
                self:ClearFocus()
                ApplyNewColor(rHex / 255, gHex / 255, bHex / 255, curA or 1.0)
                return
            end
        end
        self:ClearFocus()
        SyncVisuals()
    end)

    hexEdit:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        SyncVisuals()
    end)

    hexEdit:SetScript("OnEnter", function(self)
        hexBoxFrame:SetBackdropBorderColor(unpack(COLORS.goldBorder))
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(L["Direct Hex Color Input"], COLORS.goldText[1], COLORS.goldText[2], COLORS.goldText[3])
        GameTooltip:AddLine(L["Type any 6-digit hex color code (such as #000000 for pure pitch black) and press Enter."], COLORS.whiteText[1], COLORS.whiteText[2], COLORS.whiteText[3], true)
        GameTooltip:Show()
    end)
    hexEdit:SetScript("OnLeave", function()
        hexBoxFrame:SetBackdropBorderColor(unpack(COLORS.goldMuted))
        GameTooltip:Hide()
    end)

    swatchBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.20, 0.22, 0.28, 0.95)
        self:SetBackdropBorderColor(unpack(COLORS.goldBorder))
        btnLabel:SetTextColor(COLORS.goldText[1], COLORS.goldText[2], COLORS.goldText[3])
        if tooltipText then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(labelText or L["Background Color"], COLORS.goldText[1], COLORS.goldText[2], COLORS.goldText[3])
            GameTooltip:AddLine(tooltipText, COLORS.whiteText[1], COLORS.whiteText[2], COLORS.whiteText[3], true)
            GameTooltip:Show()
        end
    end)
    swatchBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(unpack(COLORS.tabNormal))
        self:SetBackdropBorderColor(unpack(COLORS.goldMuted))
        btnLabel:SetTextColor(COLORS.whiteText[1], COLORS.whiteText[2], COLORS.whiteText[3])
        GameTooltip:Hide()
    end)

    swatchBtn:SetScript("OnClick", function(self)
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 856)
        if not ColorPickerFrame then return end
        if ns.SetupColorPickerEnhancements then
            ns.SetupColorPickerEnhancements()
        end
        ColorPickerFrame:Hide()
        ColorPickerFrame:SetFrameStrata("FULLSCREEN_DIALOG")
        ColorPickerFrame:SetFrameLevel(self:GetFrameLevel() + 20)
        ColorPickerFrame:SetClampedToScreen(true)

        local r2, g2, b2, a2 = 0.05, 0.05, 0.05, 0.65
        if getColorFunc then
            local cr, cg, cb, ca = getColorFunc()
            if cr ~= nil then r2, g2, b2, a2 = cr, cg, cb, ca or 0.65 end
        end

        if ColorPickerFrame.SetupColorPickerAndShow then
            local info = {
                swatchFunc = function()
                    local r, g, b = ColorPickerFrame:GetColorRGB()
                    local a = ColorPickerFrame.GetColorAlpha and ColorPickerFrame:GetColorAlpha() or a2
                    ApplyNewColor(r, g, b, a)
                end,
                hasOpacity = true,
                opacityFunc = function()
                    local r, g, b = ColorPickerFrame:GetColorRGB()
                    local a = ColorPickerFrame.GetColorAlpha and ColorPickerFrame:GetColorAlpha() or a2
                    ApplyNewColor(r, g, b, a)
                end,
                opacity = a2,
                cancelFunc = function()
                    ApplyNewColor(r2, g2, b2, a2)
                end,
                r = r2,
                g = g2,
                b = b2,
            }
            ColorPickerFrame:SetupColorPickerAndShow(info)
        else
            ColorPickerFrame.func = function()
                local r, g, b = ColorPickerFrame:GetColorRGB()
                local a = OpacitySliderFrame and OpacitySliderFrame.GetValue and (1 - OpacitySliderFrame:GetValue()) or a2
                ApplyNewColor(r, g, b, a)
            end
            ColorPickerFrame.hasOpacity = true
            ColorPickerFrame.opacityFunc = ColorPickerFrame.func
            ColorPickerFrame.opacity = 1 - a2
            ColorPickerFrame:SetColorRGB(r2, g2, b2)
            ColorPickerFrame.cancelFunc = function()
                ApplyNewColor(r2, g2, b2, a2)
            end
            ColorPickerFrame:Show()
        end
    end)

    container:SetScript("OnSizeChanged", function(self, w)
        if w and w > 120 then
            local sw = math.max(95, math.floor(w * 0.58))
            swatchBtn:SetWidth(sw)
        end
    end)

    container.Sync = SyncVisuals
    container.SetEnabled = function(_, enabled)
        swatchBtn:SetEnabled(enabled)
        hexEdit:SetEnabled(enabled)
        container:SetAlpha(enabled and 1 or 0.4)
    end
    SyncVisuals()
    return container
end

local function CreateStyledKeybindButton(parent, bindingName, labelPrefix, width, height, tooltipText)
    labelPrefix = L[labelPrefix or "Keybind"]
    tooltipText = tooltipText and L[tooltipText]
    local btn = CreateFrame("Button", nil, parent, BACKDROP_TEMPLATE)
    btn:SetSize(width or 190, height or 22)
    btn:SetBackdrop(INSET_BACKDROP)
    btn:SetBackdropColor(unpack(COLORS.tabNormal))
    btn:SetBackdropBorderColor(unpack(COLORS.goldMuted))
    btn:RegisterForClicks("AnyUp")

    local label = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("LEFT", btn, "LEFT", 6, 0)
    label:SetPoint("RIGHT", btn, "RIGHT", -6, 0)
    label:SetJustifyH("CENTER")
    label:SetWordWrap(false)
    btn.Label = label

    local isBinding = false

    local function UpdateKeyText()
        if isBinding then
            label:SetText("|cffffd100" .. L["Press Key (ESC to Clear)..."] .. "|r")
            return
        end
        local key = GetBindingKey and GetBindingKey(bindingName)
        if key and key ~= "" then
            label:SetText(string.format("%s: |cff00ff00[%s]|r", labelPrefix, key))
        else
            label:SetText(string.format("%s: |cff888888[%s]|r", labelPrefix, L["None"]))
        end
    end

    local function StopBindingMode()
        isBinding = false
        btn:EnableKeyboard(false)
        btn:SetBackdropBorderColor(unpack(COLORS.goldMuted))
        UpdateKeyText()
    end

    btn:SetScript("OnClick", function(self, button)
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 856)
        if InCombatLockdown() then
            ns.Notify(L["Key bindings cannot be changed in combat."])
            return
        end
        if isBinding then
            if button == "RightButton" then
                StopBindingMode()
                return
            end
        else
            if button == "RightButton" then
                if GetBindingKey and SetBinding then
                    local k1, k2 = GetBindingKey(bindingName)
                    if k1 then SetBinding(k1) end
                    if k2 then SetBinding(k2) end
                    if SaveBindings and GetCurrentBindingSet then SaveBindings(GetCurrentBindingSet()) end
                end
                UpdateKeyText()
                return
            end
            isBinding = true
            self:EnableKeyboard(true)
            self:SetBackdropBorderColor(unpack(COLORS.goldBorder))
            UpdateKeyText()
        end
    end)

    btn:SetScript("OnKeyDown", function(self, key)
        if not isBinding then return end
        if key == "ESCAPE" then
            if GetBindingKey and SetBinding then
                local k1, k2 = GetBindingKey(bindingName)
                if k1 then SetBinding(k1) end
                if k2 then SetBinding(k2) end
                if SaveBindings and GetCurrentBindingSet then SaveBindings(GetCurrentBindingSet()) end
            end
            StopBindingMode()
            return
        end
        if key == "LSHIFT" or key == "RSHIFT" or key == "LCTRL" or key == "RCTRL" or key == "LALT" or key == "RALT" or key == "UNKNOWN" then
            return
        end
        local mod = ""
        if IsAltKeyDown and IsAltKeyDown() then mod = mod .. "ALT-" end
        if IsControlKeyDown and IsControlKeyDown() then mod = mod .. "CTRL-" end
        if IsShiftKeyDown and IsShiftKeyDown() then mod = mod .. "SHIFT-" end
        local fullKey = mod .. key
        if GetBindingKey and SetBinding then
            local k1, k2 = GetBindingKey(bindingName)
            if k1 then SetBinding(k1) end
            if k2 then SetBinding(k2) end
            SetBinding(fullKey, bindingName)
            if SaveBindings and GetCurrentBindingSet then SaveBindings(GetCurrentBindingSet()) end
        end
        StopBindingMode()
    end)

    btn:SetScript("OnHide", function()
        if isBinding then StopBindingMode() end
    end)

    btn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.20, 0.22, 0.28, 0.95)
        self:SetBackdropBorderColor(unpack(COLORS.goldBorder))
        if tooltipText then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(labelPrefix, COLORS.goldText[1], COLORS.goldText[2], COLORS.goldText[3])
            GameTooltip:AddLine(tooltipText, COLORS.whiteText[1], COLORS.whiteText[2], COLORS.whiteText[3], true)
            GameTooltip:AddLine(L["Left-Click to bind a key. Right-Click or press ESC while binding to clear."], 0.65, 0.85, 1.0, true)
            GameTooltip:Show()
        end
    end)

    btn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(unpack(COLORS.tabNormal))
        if not isBinding then
            self:SetBackdropBorderColor(unpack(COLORS.goldMuted))
        end
        GameTooltip:Hide()
    end)

    btn.Sync = UpdateKeyText
    UpdateKeyText()
    return btn
end

--[[-----------------------------------------------------------------------------
    Custom Dark Slate & Gold Dropdown Menu System
-------------------------------------------------------------------------------]]
local sharedDropdownMenu = nil
local sharedDropdownCatcher = nil

local function GetOrCreateLocalDropdownMenu()
    if sharedDropdownMenu then return sharedDropdownMenu end

    sharedDropdownCatcher = CreateFrame("Button", "BFQ_DropdownCatcher", UIParent)
    sharedDropdownCatcher:SetFrameStrata("FULLSCREEN_DIALOG")
    sharedDropdownCatcher:SetFrameLevel(98)
    sharedDropdownCatcher:SetAllPoints(UIParent)
    sharedDropdownCatcher:EnableMouse(true)
    sharedDropdownCatcher:Hide()
    sharedDropdownCatcher:SetScript("OnClick", function()
        if sharedDropdownMenu then sharedDropdownMenu:Hide() end
    end)

    local menu = CreateFrame("Frame", "BFQ_DropdownMenu", UIParent, BACKDROP_TEMPLATE)
    menu:SetFrameStrata("FULLSCREEN_DIALOG")
    menu:SetFrameLevel(99)
    menu:SetClampedToScreen(true)
    menu:SetBackdrop(INSET_BACKDROP)
    menu:SetBackdropColor(0.08, 0.10, 0.13, 0.98)
    menu:SetBackdropBorderColor(unpack(COLORS.goldBorder))
    menu:EnableMouse(true)
    menu:Hide()

    menu:SetScript("OnShow", function()
        sharedDropdownCatcher:Show()
    end)
    menu:SetScript("OnHide", function()
        sharedDropdownCatcher:Hide()
    end)

    local scrollFrame = CreateFrame("ScrollFrame", "BFQ_DropdownScrollFrame", menu, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", menu, "TOPLEFT", 4, -4)
    scrollFrame:SetPoint("BOTTOMRIGHT", menu, "BOTTOMRIGHT", -22, 4)
    menu.scrollFrame = scrollFrame

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(150, 100)
    scrollFrame:SetScrollChild(scrollChild)
    menu.scrollChild = scrollChild

    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local cur = self:GetVerticalScroll()
        local maxS = math.max(0, scrollChild:GetHeight() - self:GetHeight())
        local newS = math.min(maxS, math.max(0, cur - (delta * 22)))
        self:SetVerticalScroll(newS)
    end)

    menu.buttons = {}
    sharedDropdownMenu = menu
    return menu
end

-- Static option tables are translated; dynamic lists (profiles, fonts, media) are shown as-is
local function NormalizeDropdownOptions(options, translate)
    local list = {}
    if type(options) == "table" then
        if #options > 0 then
            for _, item in ipairs(options) do
                if type(item) == "table" then
                    local k = (item.key ~= nil) and item.key or ((item.value ~= nil) and item.value or item[1])
                    local l = item.label or item.text or item[2] or tostring(k)
                    table.insert(list, { key = k, label = translate and L[l] or l, raw = item })
                else
                    table.insert(list, { key = item, label = tostring(item), raw = item })
                end
            end
        else
            for k, v in pairs(options) do
                local l = tostring(v)
                table.insert(list, { key = k, label = translate and L[l] or l })
            end
            table.sort(list, function(a, b) return a.label:lower() < b.label:lower() end)
        end
    end
    return list
end

local function GetAvailableFonts()
    local fonts = {}
    local seen = {}
    do
        local lsmList = LSM:List("font")
        if lsmList then
            for _, f in ipairs(lsmList) do
                if not seen[f] then
                    table.insert(fonts, { key = f, label = f })
                    seen[f] = true
                end
            end
        end
    end
    local standardFonts = {
        "Nata Sans Bold", "Nata Sans Regular", "Nata Sans Medium",
        "BleakUI Bold", "BleakUI Regular",
        "Friz Quadrata TT", "Arial Narrow", "Skurri", "Morpheus"
    }
    for _, f in ipairs(standardFonts) do
        if not seen[f] then
            table.insert(fonts, { key = f, label = f })
            seen[f] = true
        end
    end
    table.sort(fonts, function(a, b) return a.label:lower() < b.label:lower() end)
    return fonts
end

local function CreateStyledDropdown(parent, labelPrefix, width, height, options, getFunc, setFunc, tooltipText, isFont)
    labelPrefix = labelPrefix and L[labelPrefix]
    tooltipText = tooltipText and L[tooltipText]
    local btn = CreateFrame("Button", nil, parent, BACKDROP_TEMPLATE)
    btn:SetSize(width or 180, height or 22)
    btn:SetBackdrop(INSET_BACKDROP)
    btn:SetBackdropColor(unpack(COLORS.tabNormal))
    btn:SetBackdropBorderColor(unpack(COLORS.goldMuted))

    local label = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("LEFT", btn, "LEFT", 8, 0)
    label:SetPoint("RIGHT", btn, "RIGHT", -20, 0)
    label:SetJustifyH("LEFT")
    label:SetWordWrap(false)
    btn.Label = label

    local arrow = btn:CreateTexture(nil, "OVERLAY")
    arrow:SetSize(12, 12)
    arrow:SetPoint("RIGHT", btn, "RIGHT", -6, 0)
    arrow:SetTexture("Interface\\Common\\CommonIcons")
    arrow:SetTexCoord(573/2048, 728/2048, 266/1024, 516/1024)
    arrow:SetRotation(math.pi / 2)

    local function GetOptionsList()
        if type(options) == "function" then
            return NormalizeDropdownOptions(options())
        end
        return NormalizeDropdownOptions(options, true)
    end

    local function GetSelectedLabel(curVal)
        local curOpts = GetOptionsList()
        for _, opt in ipairs(curOpts) do
            if opt.key == curVal then return opt.label end
        end
        return tostring(curVal or L["None"])
    end

    local function UpdateLabel()
        local cur = getFunc and getFunc()
        local disp = GetSelectedLabel(cur)
        label:SetText((labelPrefix and (labelPrefix .. ": ") or "") .. disp)
        if isFont then
            local fPath = cur and ns.FetchFont(cur)
            if fPath then
                pcall(function() label:SetFont(fPath, 11, "") end)
            end
        end
    end

    btn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.20, 0.22, 0.28, 0.95)
        self:SetBackdropBorderColor(unpack(COLORS.goldBorder))
        label:SetTextColor(COLORS.goldText[1], COLORS.goldText[2], COLORS.goldText[3])
        if tooltipText then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(labelPrefix or L["Option"], COLORS.goldText[1], COLORS.goldText[2], COLORS.goldText[3])
            GameTooltip:AddLine(tooltipText, COLORS.whiteText[1], COLORS.whiteText[2], COLORS.whiteText[3], true)
            GameTooltip:Show()
        end
    end)

    btn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(unpack(COLORS.tabNormal))
        self:SetBackdropBorderColor(unpack(COLORS.goldMuted))
        label:SetTextColor(COLORS.whiteText[1], COLORS.whiteText[2], COLORS.whiteText[3])
        if tooltipText then GameTooltip:Hide() end
    end)

    btn:SetScript("OnClick", function(self)
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 856)
        local menu = GetOrCreateLocalDropdownMenu()
        if menu:IsShown() and menu.currentButton == self then
            menu:Hide()
            return
        end

        local curOpts = GetOptionsList()
        local curVal = getFunc and getFunc()
        menu.currentButton = self

        for _, b in ipairs(menu.buttons) do b:Hide() end

        local btnHeight = 22
        local maxVisible = 8
        local visibleCount = math.min(#curOpts, maxVisible)
        local menuWidth = math.max(width or 180, 160)
        local totalContentHeight = #curOpts * btnHeight

        local hasScroll = (#curOpts > maxVisible)
        menu.scrollChild:SetSize(menuWidth - (hasScroll and 28 or 10), totalContentHeight)

        local scrollBar = _G["BFQ_DropdownScrollFrameScrollBar"]
        if scrollBar then
            if hasScroll then
                scrollBar:Show()
                menu.scrollFrame:SetPoint("BOTTOMRIGHT", menu, "BOTTOMRIGHT", -22, 4)
            else
                scrollBar:Hide()
                menu.scrollFrame:SetPoint("BOTTOMRIGHT", menu, "BOTTOMRIGHT", -4, 4)
            end
        end

        local selectedIndex = 1

        for i, itm in ipairs(curOpts) do
            local b = menu.buttons[i]
            if not b then
                b = CreateFrame("Button", nil, menu.scrollChild, BACKDROP_TEMPLATE)
                b:SetHeight(btnHeight)
                b:SetBackdrop(INSET_BACKDROP)

                b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                b.text:SetPoint("LEFT", b, "LEFT", 8, 0)
                b.text:SetPoint("RIGHT", b, "RIGHT", -8, 0)
                b.text:SetJustifyH("LEFT")

                b:SetScript("OnEnter", function(s)
                    s:SetBackdropColor(0.20, 0.22, 0.28, 0.95)
                    s:SetBackdropBorderColor(unpack(COLORS.goldBorder))
                end)
                b:SetScript("OnLeave", function(s)
                    if s.isActive then
                        s:SetBackdropColor(0.22, 0.19, 0.12, 0.95)
                        s:SetBackdropBorderColor(unpack(COLORS.goldBorder))
                    else
                        s:SetBackdropColor(0.10, 0.12, 0.15, 0.50)
                        s:SetBackdropBorderColor(unpack(COLORS.goldMuted))
                    end
                end)
                menu.buttons[i] = b
            end

            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", menu.scrollChild, "TOPLEFT", 2, -((i - 1) * btnHeight))
            b:SetPoint("RIGHT", menu.scrollChild, "RIGHT", -2, 0)

            local isActive = (itm.key == curVal)
            b.isActive = isActive
            if isActive then
                selectedIndex = i
                b.text:SetText("|TInterface\\Common\\CommonIcons:13:13:0:0:2048:1024:271:510:26:235|t " .. itm.label)
                b:SetBackdropColor(0.22, 0.19, 0.12, 0.95)
                b:SetBackdropBorderColor(unpack(COLORS.goldBorder))
            else
                b.text:SetText("   " .. itm.label)
                b:SetBackdropColor(0.10, 0.12, 0.15, 0.50)
                b:SetBackdropBorderColor(unpack(COLORS.goldMuted))
            end

            if isFont then
                local fPath = ns.FetchFont(itm.key)
                if fPath then
                    pcall(function() b.text:SetFont(fPath, 11, "") end)
                end
            else
                b.text:SetFontObject("GameFontHighlightSmall")
            end

            local chosenKey = itm.key
            local chosenRaw = itm.raw
            b:SetScript("OnClick", function()
                PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 856)
                if setFunc then
                    setFunc(chosenKey, chosenRaw)
                end
                UpdateLabel()
                menu:Hide()
                ScheduleApply()
            end)
            b:Show()
        end

        local menuHeight = (visibleCount * btnHeight) + 8
        menu:SetSize(menuWidth, menuHeight)

        local screenHeight = UIParent:GetHeight() or 768
        local btnBottom = self:GetBottom() or (screenHeight / 2)
        menu:ClearAllPoints()
        if btnBottom < (menuHeight + 20) then
            menu:SetPoint("BOTTOMLEFT", self, "TOPLEFT", 0, 2)
        else
            menu:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -2)
        end

        menu:Show()
        menu:Raise()

        if hasScroll then
            local scrollPos = math.max(0, math.min(totalContentHeight - (visibleCount * btnHeight), (selectedIndex - 1) * btnHeight))
            menu.scrollFrame:SetVerticalScroll(scrollPos)
        else
            menu.scrollFrame:SetVerticalScroll(0)
        end
    end)

    btn.Sync = UpdateLabel
    btn.SetEnabledState = function(_, enabled)
        btn:SetEnabled(enabled)
        btn:SetAlpha(enabled and 1 or 0.4)
    end
    UpdateLabel()
    return btn
end

local function CreateStyledFontDropdown(parent, labelPrefix, width, height, getFunc, setFunc, tooltipText)
    return CreateStyledDropdown(parent, labelPrefix, width, height, GetAvailableFonts, getFunc, setFunc, tooltipText, true)
end

local function CreateStyledTextInput(parent, width, height, placeholder, onEnterFunc)
    local boxFrame = CreateFrame("Frame", nil, parent, BACKDROP_TEMPLATE)
    boxFrame:SetSize(width or 180, height or 22)
    boxFrame:SetBackdrop(INSET_BACKDROP)
    boxFrame:SetBackdropColor(0.04, 0.05, 0.07, 0.95)
    boxFrame:SetBackdropBorderColor(unpack(COLORS.goldMuted))

    local edit = CreateFrame("EditBox", nil, boxFrame)
    edit:SetPoint("LEFT", boxFrame, "LEFT", 8, 0)
    edit:SetPoint("RIGHT", boxFrame, "RIGHT", -8, 0)
    edit:SetHeight(height or 22)
    edit:SetAutoFocus(false)
    edit:SetFontObject("GameFontHighlightSmall")
    edit:SetJustifyH("LEFT")
    boxFrame.EditBox = edit

    local hint = boxFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("LEFT", boxFrame, "LEFT", 8, 0)
    hint:SetText(placeholder and L[placeholder] or "")

    edit:SetScript("OnTextChanged", function(self)
        local txt = self:GetText()
        if txt and txt ~= "" then
            hint:Hide()
        else
            hint:Show()
        end
    end)

    edit:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        if onEnterFunc then onEnterFunc(self:GetText()) end
    end)

    edit:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)

    boxFrame.EditBox = edit
    return boxFrame
end

--[[-----------------------------------------------------------------------------
    Native Tab Builders for Quest Tracker
-------------------------------------------------------------------------------]]

-- Tab builders capture these proxies, which always resolve against the active
-- profile, so widgets keep working after a profile switch or reset.
local function LiveTable(resolve)
    return setmetatable({}, {
        __index = function(_, key)
            local t = resolve()
            return t and t[key]
        end,
        __newindex = function(_, key, value)
            local t = resolve()
            if t then t[key] = value end
        end,
    })
end

local LiveDB = LiveTable(function() return ns.db end)

local function LiveSection(section)
    return LiveTable(function()
        local db = ns.db
        if not db then return nil end
        if db[section] == nil then db[section] = {} end
        return db[section]
    end)
end
local OUTLINE_OPTIONS = {
    { key = "OUTLINE",      label = "Outline" },
    { key = "THICKOUTLINE", label = "Thick Outline" },
    { key = "",             label = "None" },
}

local BACKGROUND_SURFACE_TEXTURES = {
    { key = "solid",           label = "Solid / Flat" },
    { key = "tooltip",         label = "Blizzard Tooltip Dark" },
    { key = "marble",          label = "Blizzard Marble" },
    { key = "rock",            label = "Blizzard Rock" },
    { key = "parchment",       label = "Blizzard Quest Parchment" },
    { key = "parchment_clean", label = "Blizzard Parchment (Clean)" },
}

local BORDER_STYLES = {
    { key = "flat",    label = "Flat (Sleek 1px)" },
    { key = "tooltip", label = "Blizzard Tooltip" },
    { key = "dialog",  label = "Blizzard Dialog" },
    { key = "none",    label = "None (Borderless)" },
}

local HEADER_STYLES = {
    { key = "gradient", label = "Gradient Bar" },
    { key = "flat",     label = "Flat Solid Bar" },
    { key = "blizzard", label = "Blizzard Header" },
    { key = "none",     label = "None (Transparent)" },
}

local ZONE_COLLAPSE_ICONS = {
    { key = "arrow",     label = "Triangle / Arrow" },
    { key = "plusminus", label = "Plus / Minus ([-] / [+])" },
    { key = "none",      label = "None (Hide)" },
}

local COMPLETED_TITLE_MODES = {
    { key = "difficulty", label = "Keep Level Difficulty Color" },
    { key = "turnin",     label = "Turn-In Green" },
    { key = "custom",     label = "Custom Color" },
}

local ARROW_STYLES = {
    { key = "auto",       label = "Auto (2D Modern)" },
    { key = "minimal",    label = "2D Modern Minimalist" },
    { key = "3d_modern",  label = "3D Perspective (Modern)" },
    { key = "3d_classic", label = "3D Perspective (Classic)" },
    { key = "classic",    label = "2D Classic Guide Arrow" },
}

local SORT_MODES = {
    { key = "level", label = "By Quest Level" },
    { key = "zone",  label = "By Current Zone" },
}

local DISTANCE_UNITS = {
    { key = "imperial", label = "Imperial (Yards)" },
    { key = "metric",   label = "Metric (Meters)" },
}

local ITEM_POSITIONS = {
    { key = "outside_left", label = "Left Side (Outside Tracker)" },
    { key = "inside_right", label = "Right Side (Inside Tracker)" },
}

local ITEM_STRATAS = {
    { key = "LOW",    label = "Low" },
    { key = "MEDIUM", label = "Medium (Matches Tracker & Bags)" },
    { key = "HIGH",   label = "High" },
    { key = "DIALOG", label = "Dialog" },
}

local GROW_CORNERS = {
    { key = "AUTO",        label = "Auto (Snap to Nearest Screen Corner)" },
    { key = "BOTTOMRIGHT", label = "Bottom-Right (Grows Up & Left)" },
    { key = "BOTTOMLEFT",  label = "Bottom-Left (Grows Up & Right)" },
    { key = "TOPRIGHT",    label = "Top-Right (Grows Down & Left)" },
    { key = "TOPLEFT",     label = "Top-Left (Grows Down & Right)" },
}

local XP_DOCK_MODES = {
    { key = "tracker_bottom", label = "Dock Tracker Bottom" },
    { key = "free",           label = "Free Floating" },
}

local LOC_DOCK_MODES = {
    { key = "tracker_top",  label = "Dock Tracker Top" },
    { key = "minimap_top",  label = "Dock Minimap Top" },
    { key = "free",         label = "Free Floating" },
}

local SOUND_CHANNELS = {
    { key = "Master",   label = "Master Channel" },
    { key = "SFX",      label = "Sound Effects (SFX)" },
    { key = "Ambience", label = "Ambience Channel" },
}

local COMPLETE_SOUNDS = {
    { key = "peon",           label = "Peon: \"Work complete!\"" },
    { key = "quest_complete", label = "Classic Quest Complete" },
    { key = "whisper_ping",   label = "Whisper Ping" },
    { key = "coins",          label = "Gold Coin Ding" },
    { key = "loot_clink",     label = "Loot Coin Clink" },
    { key = "level_up",       label = "Level Up Fanfare" },
    { key = "raid_warning",   label = "Raid Warning Chime" },
    { key = "ready_check",    label = "Ready Check Chime" },
    { key = "pvp_horn",       label = "PvP Queue Horn" },
    { key = "beep",           label = "Bleakfiber Beep (beep.wav)" },
    { key = "click",          label = "Bleakfiber Click (click.wav)" },
}

local OBJECTIVE_SOUNDS = {
    { key = "whisper_ping", label = "Whisper Ping" },
    { key = "coins",        label = "Gold Coin Ding" },
    { key = "loot_clink",   label = "Loot Coin Clink" },
    { key = "map_ping",     label = "Mini-Map Ping" },
    { key = "item_click",   label = "Subtle Click" },
    { key = "beep",         label = "Bleakfiber Beep (beep.wav)" },
    { key = "click",        label = "Bleakfiber Click (click.wav)" },
}

local function GetCompleteSoundOptions()
    local options = {}
    local seen = {}
    for _, opt in ipairs(COMPLETE_SOUNDS) do
        table.insert(options, { key = opt.key, label = L[opt.label] })
        seen[opt.key] = true
    end
    local customList = ns.GetCustomSoundList and ns.GetCustomSoundList()
    if customList and #customList > 0 then
        for _, item in ipairs(customList) do
            if not seen[item.key] then
                table.insert(options, { key = item.key, label = item.label })
                seen[item.key] = true
            end
        end
    end
    do
        local lsmSounds = LSM:List("sound")
        if type(lsmSounds) == "table" then
            for _, soundName in ipairs(lsmSounds) do
                if not seen[soundName] then
                    table.insert(options, { key = soundName, label = soundName })
                    seen[soundName] = true
                end
            end
        end
    end
    return options
end

local function GetObjectiveSoundOptions()
    local options = {}
    local seen = {}
    for _, opt in ipairs(OBJECTIVE_SOUNDS) do
        table.insert(options, { key = opt.key, label = L[opt.label] })
        seen[opt.key] = true
    end
    local customList = ns.GetCustomSoundList and ns.GetCustomSoundList()
    if customList and #customList > 0 then
        for _, item in ipairs(customList) do
            if not seen[item.key] then
                table.insert(options, { key = item.key, label = item.label })
                seen[item.key] = true
            end
        end
    end
    do
        local lsmSounds = LSM:List("sound")
        if type(lsmSounds) == "table" then
            for _, soundName in ipairs(lsmSounds) do
                if not seen[soundName] then
                    table.insert(options, { key = soundName, label = soundName })
                    seen[soundName] = true
                end
            end
        end
    end
    return options
end

--[[-----------------------------------------------------------------------------
    Declarative settings, flowed in two columns beneath each tab's own layout
-------------------------------------------------------------------------------]]
local FONT_FLAG_OPTIONS = {
    { key = "",                    label = "None" },
    { key = "OUTLINE",             label = "Outline" },
    { key = "THICKOUTLINE",        label = "Thick Outline" },
    { key = "MONOCHROME",          label = "Monochrome" },
    { key = "OUTLINE, MONOCHROME", label = "Outline Monochrome" },
}

local BAR_BORDER_STYLES = {
    { key = "flat",    label = "Sleek 1px (Modern Flat)" },
    { key = "tooltip", label = "Blizzard Tooltip (Classic Rounded)" },
    { key = "dialog",  label = "Blizzard Dialog (Classic Window)" },
    { key = "toast",   label = "Blizzard Toast (Soft Alert)" },
    { key = "none",    label = "None (Borderless)" },
}

local function Bars() return ns.db.databars end
local function WF() return ns.db.wayfinder end

local function DataBars(method, ...)
    local mod = ns.DataBarsModule
    if mod and mod[method] then mod[method](mod, ...) end
end

local function Wayfinder(method, ...)
    local mod = ns.WayfinderModule
    if mod and mod[method] then mod[method](mod, ...) end
end

local function UnpackColor(c, fallback)
    c = c or fallback
    return c.r, c.g, c.b, c.a or fallback.a
end

local function InheritsTrackerLook()
    return Bars().useTrackerAppearance ~= false
end

-- Border style, background texture, and colors for one DataBar (prefix "xp", "loc", "timer")
local function BarAppearanceSpecs(prefix, title, defaultBg, defaultBorder)
    local styleKey, texKey = prefix .. "BorderStyle", prefix .. "BgTexture"
    local bgKey, borderKey = prefix .. "BgColor", prefix .. "BorderColor"
    local specs = {
        { type = "select", label = title .. " Border Style", values = BAR_BORDER_STYLES,
          desc = "Border frame style for this bar (inherited from the tracker while Inherit Tracker Frame Appearance is enabled).",
          disabled = InheritsTrackerLook,
          get = function()
              if InheritsTrackerLook() then return ns.db.backdrop.borderStyle or "flat" end
              return Bars()[styleKey] or "flat"
          end,
          set = function(v) Bars()[styleKey] = v; DataBars("RefreshBars") end },
        { type = "select", label = title .. " Background Texture", values = BACKGROUND_SURFACE_TEXTURES,
          desc = "Background surface texture behind this bar (inherited from the tracker while Inherit Tracker Frame Appearance is enabled).",
          disabled = InheritsTrackerLook,
          get = function()
              if InheritsTrackerLook() then return ns.db.backdrop.bgTexture or "solid" end
              return Bars()[texKey] or "solid"
          end,
          set = function(v)
              local bars = Bars()
              local prev = bars[texKey] or "solid"
              bars[texKey] = v
              local isParchment = (v == "parchment" or v == "parchment_clean")
              local wasParchment = (prev == "parchment" or prev == "parchment_clean")
              if isParchment and not wasParchment then
                  bars[bgKey] = { r = 0.96, g = 0.90, b = 0.78, a = 0.90 }
              elseif wasParchment and not isParchment then
                  bars[bgKey] = { r = 0.05, g = 0.05, b = 0.05, a = 0.65 }
              end
              DataBars("RefreshBars")
          end },
        { type = "color", label = title .. " Background",
          desc = "Background color and opacity behind this bar.",
          disabled = InheritsTrackerLook,
          get = function()
              if InheritsTrackerLook() then
                  return UnpackColor(ns.db.backdrop.bgColor, { r = 0.05, g = 0.05, b = 0.05, a = 0.65 })
              end
              return UnpackColor(Bars()[bgKey], defaultBg)
          end,
          set = function(r, g, b, a) Bars()[bgKey] = { r = r, g = g, b = b, a = a }; DataBars("RefreshBars") end },
        { type = "color", label = title .. " Border",
          desc = "Border color and opacity around this bar.",
          disabled = function() return InheritsTrackerLook() or Bars()[styleKey] == "none" end,
          get = function()
              if InheritsTrackerLook() then
                  local bd = ns.db.backdrop
                  if bd.classColorBorder and ns.GetClassColor then
                      local cc = ns.GetClassColor()
                      if cc then return cc.r, cc.g, cc.b, (bd.borderColor and bd.borderColor.a) or 0.90 end
                  end
                  return UnpackColor(bd.borderColor, { r = 0.15, g = 0.15, b = 0.15, a = 0.90 })
              end
              return UnpackColor(Bars()[borderKey], defaultBorder)
          end,
          set = function(r, g, b, a) Bars()[borderKey] = { r = r, g = g, b = b, a = a }; DataBars("RefreshBars") end },
    }
    return specs
end

local function Concat(...)
    local out = {}
    for i = 1, select("#", ...) do
        for _, v in ipairs((select(i, ...))) do out[#out + 1] = v end
    end
    return out
end

StaticPopupDialogs["BFQ_RELOAD_FOR_LANGUAGE"] = {
    text = "Bleakfiber's Quest Tracker: reload the interface now to finish changing the language?",
    button1 = ACCEPT,
    button2 = CANCEL,
    OnShow = function(self)
        local textRegion = self.text or self.Text
        if textRegion and textRegion.SetText then
            textRegion:SetText(L["Bleakfiber's Quest Tracker: reload the interface now to finish changing the language?"])
        end
    end,
    OnAccept = function() ReloadUI() end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

local TAB_EXTRAS = {
    general = {
        { type = "header", text = "LANGUAGE & CHAT OUTPUT" },
        { type = "select", label = "Language", values = function() return ns.GetLanguageOptions() end,
          desc = "Choose the language used by the tracker and its settings. Language packs ship in the Locales folder; Automatic follows your game client.",
          get = function() return ns.dbObject.global.language or "auto" end,
          set = function(v)
              if v == (ns.dbObject.global.language or "auto") then return end
              ns.dbObject.global.language = v
              ns.SetLanguage(v)
              StaticPopup_Show("BFQ_RELOAD_FOR_LANGUAGE")
          end },
        { type = "toggle", label = "Debug & Chat Output",
          desc = "Allow the addon to write status, diagnostic, and debug messages to your chat window. When off, nothing is printed to chat.",
          get = function() return ns.dbObject.global.chatOutput == true end,
          set = function(v) ns.dbObject.global.chatOutput = v end },
        { type = "header", text = "TRACKER SIZE" },
        { type = "range", label = "Bottom Padding (px)", min = 0, max = 20, step = 1,
          desc = "Empty space between the last quest and the bottom edge of the tracker.",
          get = function() return ns.db.trackerBottomPadding or 4 end,
          set = function(v) ns.db.trackerBottomPadding = v end },
        { type = "header", text = "QUEST FILTERING" },
        { type = "select", label = "Quest Filter Mode",
          values = { { key = "all", label = "All Quests" }, { key = "zone", label = "Current Zone Only" }, { key = "watched", label = "Watched Only" } },
          desc = "Choose which quests the tracker shows: every quest, only quests for your current zone, or only quests you have watched (Shift-click in the quest log).",
          get = function() return ns.db.filtering.filterMode or "all" end,
          set = function(v) Config:SetFilterMode(v) end },
        { type = "toggle", label = "Enable Cross-Zone Objective Tracking",
          desc = "Show quests in the zones where their objectives or turn-ins are, even if you accepted them elsewhere.",
          get = function() return ns.db.filtering.enableCrossZone ~= false end,
          set = function(v) ns.db.filtering.enableCrossZone = v; ns:FireCallback("QUEST_DATA_CHANGED") end },
    },
    quests = {
        { type = "header", text = "ADDITIONAL QUEST OPTIONS" },
        { type = "toggle", label = "Show Timers in Objective Text",
          desc = "Show a live countdown next to timed quest objectives (e.g. [04:12]). Only appears on quests with an active timer.",
          get = function() return ns.db.showTimerInObjectives ~= false end,
          set = function(v) ns.db.showTimerInObjectives = v end },
        { type = "toggle", label = "Highlight Most Valuable Choice Reward",
          desc = "For quests with several reward choices, mark the item with the highest vendor price.",
          disabled = function() return ns.db.tooltips.showRewards == false end,
          get = function() return ns.db.tooltips.showBestSell ~= false end,
          set = function(v) ns.db.tooltips.showBestSell = v end },
        { type = "select", label = "Active Quest Marker",
          values = {
              { key = "star", label = "Gold Star (Blizzard)" }, { key = "arrow", label = "Gold Arrow" },
              { key = "blizz", label = "Blizzard Quest Icon" }, { key = "pointer", label = "Cyan Pointer (>)" },
              { key = "none", label = "None" },
          },
          desc = "Icon shown next to the active quest. Hidden while the inline Wayfinder arrow is shown.",
          disabled = function() return ns.IsModuleEnabled("wayfinder") and WF().enableInlineArrow end,
          get = function() return ns.db.activeQuestIcon or "star" end,
          set = function(v) ns.db.activeQuestIcon = v; ns:FireCallback("QUEST_DATA_CHANGED") end },
        { type = "keybind", label = "Quest Item Key", binding = ns.BINDING_QUEST_ITEM,
          desc = "Uses the quest item of the top quest in the tracker. Works in combat." },
        { type = "toggle", label = "Show Test Quest Item Button",
          desc = "Shows a test quest item button on a quest so you can check its placement, size and your Quest Item Key without owning a quest item. Clicking it uses no item. Turns off when you reload. Also /bfq testitem.",
          get = function() return ns.StandaloneTracker and ns.StandaloneTracker.itemPreview == true end,
          set = function(v)
              if not ns.StandaloneTracker:SetItemPreview(v) then
                  C_Timer.After(0, function() Config:SyncAll() end)
              end
          end },
        { type = "select", label = "Open Quests In",
          values = { { key = "world", label = "World Map (Blizzard)" }, { key = "classic", label = "Classic Quest Log" }, { key = "both", label = "Both" } },
          desc = "Where Ctrl+Click, Show in Quest Log, and the [Log] header button open quests. Classic Quest Log needs a classic quest log addon (such as Kerzo's Classic Quest Log); without one, the world map opens instead.",
          get = function() return ns.db.questOpenMode or "world" end,
          set = function(v) ns.db.questOpenMode = v end },
        { type = "header", text = "FOREVER QUESTS" },
        { type = "toggle", label = "Mark Quests New in WoW Forever",
          desc = "Adds a marker to quests that were not in original Classic. The list comes straight from the game clients' own quest data. Type /bfq questid to check a quest.",
          get = function() return ns.db.foreverMarker.enabled ~= false end,
          set = function(v) ns.db.foreverMarker.enabled = v end },
        { type = "select", label = "Marker Position",
          values = { { key = "after", label = "After the Quest Name" }, { key = "before", label = "Before the Quest Name" } },
          desc = "Where the marker appears on the quest title.",
          disabled = function() return ns.db.foreverMarker.enabled == false end,
          get = function() return ns.db.foreverMarker.position or "after" end,
          set = function(v) ns.db.foreverMarker.position = v end },
        { type = "select", label = "Marker Style",
          values = { { key = "icon", label = "Infinity Icon" }, { key = "text", label = "Text Badge [F]" } },
          desc = "Show the marker as a small infinity icon or as a text badge.",
          disabled = function() return ns.db.foreverMarker.enabled == false end,
          get = function() return ns.db.foreverMarker.style or "icon" end,
          set = function(v) ns.db.foreverMarker.style = v end },
        { type = "range", label = "Marker Size (px)", min = 8, max = 20, step = 1,
          desc = "Height of the infinity icon.",
          disabled = function() return ns.db.foreverMarker.enabled == false or ns.db.foreverMarker.style == "text" end,
          get = function() return ns.db.foreverMarker.size or 12 end,
          set = function(v) ns.db.foreverMarker.size = v end },
        { type = "color", label = "Marker Color",
          desc = "Color of the marker and of the tooltip note.",
          disabled = function() return ns.db.foreverMarker.enabled == false end,
          get = function()
              local c = ns.db.foreverMarker.color or { r = 0.60, g = 0.90, b = 0.95 }
              return c.r, c.g, c.b, 1
          end,
          set = function(r, g, b) ns.db.foreverMarker.color = { r = r, g = g, b = b, a = 1 } end },
        { type = "toggle", label = "Tint the Quest Name",
          desc = "Also colors the name of quests new in WoW Forever with the marker color.",
          disabled = function() return ns.db.foreverMarker.enabled == false end,
          get = function() return ns.db.foreverMarker.tintTitle == true end,
          set = function(v) ns.db.foreverMarker.tintTitle = v end },
        { type = "header", text = "QUEST ACTION BUTTONS" },
        { type = "select", label = "Quest Action Buttons",
          values = { { key = "off", label = "Off" }, { key = "hover", label = "Show on Hover" }, { key = "always", label = "Always" } },
          desc = "Small buttons at the right end of each quest title for quick actions. They always stay left of the quest item button and never cover it.",
          get = function() return ns.db.questButtons.mode or "off" end,
          set = function(v) ns.db.questButtons.mode = v end },
        { type = "range", label = "Action Button Size (px)", min = 12, max = 24, step = 1,
          desc = "Size of the quest action buttons.",
          disabled = function() return (ns.db.questButtons.mode or "off") == "off" end,
          get = function() return ns.db.questButtons.size or 16 end,
          set = function(v) ns.db.questButtons.size = v end },
        { type = "toggle", label = "Set Active Button",
          desc = "Star button that sets or clears the active quest.",
          disabled = function() return (ns.db.questButtons.mode or "off") == "off" end,
          get = function() return ns.db.questButtons.setActive ~= false end,
          set = function(v) ns.db.questButtons.setActive = v end },
        { type = "toggle", label = "Show on Map Button",
          desc = "Opens the world map on the quest's zone.",
          disabled = function() return (ns.db.questButtons.mode or "off") == "off" end,
          get = function() return ns.db.questButtons.map ~= false end,
          set = function(v) ns.db.questButtons.map = v end },
        { type = "toggle", label = "Share Button",
          desc = "Shares the quest with your group. Only shown while you are in a group and the quest can be shared.",
          disabled = function() return (ns.db.questButtons.mode or "off") == "off" end,
          get = function() return ns.db.questButtons.share ~= false end,
          set = function(v) ns.db.questButtons.share = v end },
        { type = "toggle", label = "Open Quest Button",
          desc = "Left-click opens the quest on the world map. Right-click opens it in a classic quest log addon.",
          disabled = function() return (ns.db.questButtons.mode or "off") == "off" end,
          get = function() return ns.db.questButtons.log ~= false end,
          set = function(v) ns.db.questButtons.log = v end },
    },
    appearance = {
        { type = "header", text = "FRAME BORDER" },
        { type = "toggle", label = "Show Background & Backdrop",
          desc = "Show the tracker background and border.",
          get = function() return ns.db.backdrop.show ~= false end,
          set = function(v) ns.db.backdrop.show = v end },
        { type = "range", label = "Border Thickness (px)", min = 0, max = 5, step = 1,
          desc = "Pixel thickness of the flat border (0 for no border).",
          disabled = function() local st = ns.db.backdrop.borderStyle; return st ~= nil and st ~= "flat" end,
          get = function()
              local bd = ns.db.backdrop
              if bd.borderWidth ~= nil then return bd.borderWidth end
              return bd.edgeSize or 1
          end,
          set = function(v) ns.db.backdrop.borderWidth = v; ns.db.backdrop.edgeSize = v end },
        { type = "range", label = "Corner & Border Size (px)", min = 8, max = 24, step = 1,
          desc = "Edge and corner size for the classic rounded borders (default 16).",
          disabled = function() local st = ns.db.backdrop.borderStyle; return st == nil or st == "flat" or st == "none" end,
          get = function() return ns.db.backdrop.edgeSize or 16 end,
          set = function(v) ns.db.backdrop.edgeSize = v end },
        { type = "range", label = "DataBar Docking Spacing (px)", min = 0, max = 5, step = 1,
          desc = "Gap between the tracker and docked DataBars, and between stacked bars.",
          get = function() return Bars().dockSpacing or 0 end,
          set = function(v) Bars().dockSpacing = v; DataBars("UpdateAllDocking") end },
    },
    headers = {
        { type = "header", text = "QUEST CLICKS" },
        { type = "toggle", label = "Double-Click Sets Active Quest",
          desc = "Double-click a quest to make it your active quest. A single click still collapses or expands it, after a short 0.25 second wait. If you use the Set Active action button, you can turn this off so single clicks act instantly. Has no effect while Left-Click Sets Active Quest is on.",
          disabled = function() return ns.db.sorting.leftClickSetsActive == true end,
          get = function() return ns.db.sorting.doubleClickSetsActive ~= false end,
          set = function(v) ns.db.sorting.doubleClickSetsActive = v end },
        { type = "header", text = "HEADER COLOR SHARING & COUNTER" },
        { type = "toggle", label = "Header Texture Uses Border Color",
          desc = "Tint the header texture with the tracker border color.",
          disabled = function() return ns.db.headers.texture == "none" end,
          get = function() return ns.db.headers.textureColorShare == true end,
          set = function(v) ns.db.headers.textureColorShare = v end },
        { type = "toggle", label = "Header Text Uses Border Color",
          desc = "Color the header text with the tracker border color.",
          get = function() return ns.db.headers.textColorShare == true end,
          set = function(v) ns.db.headers.textColorShare = v end },
        { type = "toggle", label = "Header Buttons Use Border Color",
          desc = "Color the header buttons with the tracker border color.",
          get = function() return ns.db.headers.buttonColorShare == true end,
          set = function(v) ns.db.headers.buttonColorShare = v end },
        { type = "select", label = "Quest Counter Format",
          values = { { key = "none", label = "None" }, { key = "short", label = "(5/40) - Short" }, { key = "full", label = "(5/40 Quests) - Full" } },
          desc = "Format of the quest log counter shown in the header.",
          get = function() return ns.db.headers.countFormat or "short" end,
          set = function(v) ns.db.headers.countFormat = v end },
        { type = "select", label = "Collapsed Tracker Text",
          values = { { key = "none", label = "None (Minimal [+])" }, { key = "counter", label = "Counter Only" }, { key = "title", label = "Title & Counter" } },
          desc = "Text shown on the header while the tracker is collapsed.",
          get = function() return ns.db.headers.collapsedText or "counter" end,
          set = function(v) ns.db.headers.collapsedText = v end },
    },
    wayfinder = {
        { type = "header", text = "ARROW HUD DETAILS" },
        { type = "toggle", label = "Lock Arrow Position",
          desc = "Prevent dragging the floating HUD arrow.",
          get = function() return WF().locked == true end,
          set = function(v) WF().locked = v end },
        { type = "toggle", label = "Show Backdrop Circle",
          desc = "Show a semi-transparent circle behind the floating arrow.",
          get = function() return WF().showBackdrop == true end,
          set = function(v) WF().showBackdrop = v end },
        { type = "toggle", label = "Show Destination Name",
          desc = "Show the destination name above the distance readout.",
          get = function() return WF().showDestination ~= false end,
          set = function(v) WF().showDestination = v; Wayfinder("ForceImmediateUpdate") end },
        { type = "select", label = "Destination Name Format",
          values = { { key = "zone", label = "Zone" }, { key = "quest", label = "Quest Title" }, { key = "both", label = "Zone & Quest Title" } },
          desc = "What the arrow shows above the distance readout.",
          disabled = function() return WF().showDestination == false end,
          get = function() return WF().hudTitleFormat or "zone" end,
          set = function(v) WF().hudTitleFormat = v; Wayfinder("ForceImmediateUpdate") end },
        { type = "select", label = "Destination Text Outline", values = FONT_FLAG_OPTIONS,
          desc = "Outline style for the destination name.",
          get = function() return WF().hudTitleFontOutline or "OUTLINE" end,
          set = function(v) WF().hudTitleFontOutline = v end },
        { type = "select", label = "Distance Text Outline", values = FONT_FLAG_OPTIONS,
          desc = "Outline style for the distance readout.",
          get = function() return WF().hudFontOutline or "OUTLINE" end,
          set = function(v) WF().hudFontOutline = v end },
        { type = "toggle", label = "Show Distance Readout",
          desc = "Show the distance (yards or meters) below the arrow.",
          get = function() return WF().showDistance ~= false end,
          set = function(v) WF().showDistance = v; Wayfinder("ForceImmediateUpdate") end },
        { type = "toggle", label = "Show Estimated Time of Arrival",
          desc = "Show an ETA based on your current movement speed.",
          get = function() return WF().showETA == true end,
          set = function(v) WF().showETA = v end },
        { type = "header", text = "NAVIGATION BEHAVIOR" },
        { type = "toggle", label = "Auto-Track Active Quest",
          desc = "Point the arrow at the active (or super-tracked) quest automatically.",
          get = function() return WF().autoTrackActiveQuest ~= false end,
          set = function(v) WF().autoTrackActiveQuest = v; Wayfinder("RefreshState") end },
        { type = "select", label = "Inline Arrow Position",
          values = { { key = "left", label = "Left (In Front of Title)" }, { key = "right", label = "Right (Tracker Margin)" } },
          desc = "Where the small arrow appears next to the active quest title.",
          get = function() return WF().inlineArrowPosition or "left" end,
          set = function(v) WF().inlineArrowPosition = v end },
        { type = "range", label = "Arrival Distance (Yards)", min = 5, max = 50, step = 1,
          desc = "How close you must get before the arrow reports that you have arrived.",
          get = function() return WF().arrivalThreshold or 15 end,
          set = function(v) WF().arrivalThreshold = v end },
        { type = "range", label = "Clear Waypoint After Arrival (s)", min = 0, max = 30, step = 1,
          desc = "Seconds to wait after arriving before a custom waypoint is cleared (0 clears immediately).",
          get = function() local v = WF().arrivalClearDelay; if v == nil then return 5 end return v end,
          set = function(v) WF().arrivalClearDelay = v end },
        { type = "toggle", label = "Show World Map Waypoint Pins",
          desc = "Mark custom waypoints on the World Map.",
          get = function() return WF().showMapPins ~= false end,
          set = function(v) WF().showMapPins = v; Wayfinder("RefreshMapPins") end },
        { type = "toggle", label = "Show Player & Cursor Coordinates",
          desc = "Show player and cursor coordinates at the bottom of the World Map.",
          get = function() return WF().showCoordinates == true end,
          set = function(v) WF().showCoordinates = v; Wayfinder("UpdateCoordinatesDisplay") end },
    },
    databars = Concat({
        { type = "header", text = "SHARED BAR APPEARANCE" },
        { type = "toggle", label = "Inherit Tracker Frame Appearance",
          desc = "DataBars use the tracker's background, border style, and colors. Turn off to style each bar separately below.",
          get = function() return InheritsTrackerLook() end,
          set = function(v) Bars().useTrackerAppearance = v; DataBars("RefreshBars") end },
        { type = "header", text = "XP BAR DETAILS" },
        { type = "toggle", label = "Hide Blizzard XP Bar",
          desc = "Hide Blizzard's default experience / status tracking bar.",
          get = function() return Bars().hideBlizzardXPBar ~= false end,
          set = function(v) Bars().hideBlizzardXPBar = v; DataBars("SuppressBlizzardXP", v) end },
        { type = "toggle", label = "Show All Quests XP (Ghost Bar)",
          desc = "Overlay the total XP of every quest in your log on the bar.",
          get = function() return Bars().showAllQuestXP == true end,
          set = function(v) Bars().showAllQuestXP = v; DataBars("UpdateXPBar") end },
        { type = "toggle", label = "Hide Quest XP Text",
          desc = "Hide the +Done / +All quest XP text on the bar. The ghost bars and tooltip details stay.",
          get = function() return Bars().hideQuestXPText == true end,
          set = function(v) Bars().hideQuestXPText = v; DataBars("UpdateXPBar") end },
        { type = "toggle", label = "Show Watched Reputation at Max Level",
          desc = "At maximum level, show your watched faction's reputation instead of XP.",
          get = function() return Bars().showReputationAtMax ~= false end,
          set = function(v) Bars().showReputationAtMax = v; DataBars("UpdateXPBar") end },
        { type = "select", label = "XP Text Format",
          values = {
              { key = "smart", label = "Smart (Current / Max (Pct%) + Quest XP)" }, { key = "cur_max", label = "Current / Max" },
              { key = "cur_pct", label = "Percentage Only" }, { key = "remain", label = "XP Remaining to Level" },
              { key = "none", label = "Hide Text (Clean Bar)" },
          },
          desc = "How the XP text is written on the bar.",
          get = function() return Bars().xpTextFormat or "smart" end,
          set = function(v) Bars().xpTextFormat = v; DataBars("UpdateXPBar") end },
        { type = "range", label = "XP Text Size (px)", min = 8, max = 18, step = 1,
          desc = "Font size of the XP bar text.",
          get = function() return Bars().xpFontSize or 11 end,
          set = function(v) Bars().xpFontSize = v; DataBars("ApplyTypography") end },
        { type = "select", label = "XP Text Outline", values = FONT_FLAG_OPTIONS,
          desc = "Outline style of the XP bar text.",
          get = function() return Bars().xpFontOutline or "OUTLINE" end,
          set = function(v) Bars().xpFontOutline = v; DataBars("ApplyTypography") end },
        { type = "select", label = "XP Statusbar Texture", values = GetStatusbarTextureList,
          desc = "Fill texture of the XP bar.",
          get = function() return Bars().xpBarTexture or "Solid" end,
          set = function(v) Bars().xpBarTexture = v; DataBars("RefreshBars") end },
    }, BarAppearanceSpecs("xp", "XP Bar", { r = 0.05, g = 0.05, b = 0.05, a = 0.65 }, { r = 0.12, g = 0.12, b = 0.16, a = 0.95 }), {
        { type = "header", text = "LOCATION BAR DETAILS" },
        { type = "toggle", label = "Hide Default Minimap Zone Header",
          desc = "Hide Blizzard's zone text above the minimap while the Location Bar is enabled.",
          get = function() return Bars().hideMinimapHeader ~= false end,
          set = function(v) Bars().hideMinimapHeader = v; DataBars("ApplyMinimapHeaderSuppression", v) end },
        { type = "toggle", label = "Show Subzone Text",
          desc = "Show the subzone name next to the zone name.",
          get = function() return Bars().showSubzone ~= false end,
          set = function(v) Bars().showSubzone = v; DataBars("UpdateLocationBar", true) end },
        { type = "select", label = "Location Text Format",
          values = {
              { key = "subzone_only", label = "Subzone When Available" }, { key = "smart", label = "Smart Auto-Fit" },
              { key = "zone_only", label = "Zone Only" }, { key = "both", label = "Both (Zone - Subzone)" },
          },
          desc = "How zone and subzone names are combined on the Location Bar.",
          get = function() return Bars().locFormat or "subzone_only" end,
          set = function(v) Bars().locFormat = v; DataBars("UpdateLocationBar", true) end },
        { type = "range", label = "Location Bar Height", min = 16, max = 36, step = 1,
          desc = "Height of the Location Bar in pixels (default 22).",
          get = function() return Bars().locHeight or 22 end,
          set = function(v) Bars().locHeight = v; DataBars("UpdateLocationDocking") end },
        { type = "range", label = "Location Text Size (px)", min = 8, max = 18, step = 1,
          desc = "Font size of the Location Bar text.",
          get = function() return Bars().locFontSize or 11 end,
          set = function(v) Bars().locFontSize = v; DataBars("ApplyTypography") end },
        { type = "select", label = "Location Text Outline", values = FONT_FLAG_OPTIONS,
          desc = "Outline style of the Location Bar text.",
          get = function() return Bars().locFontOutline or "OUTLINE" end,
          set = function(v) Bars().locFontOutline = v; DataBars("ApplyTypography") end },
    }, BarAppearanceSpecs("loc", "Location Bar", { r = 0.06, g = 0.08, b = 0.12, a = 0.90 }, { r = 0.15, g = 0.55, b = 0.95, a = 0.85 }), {
        { type = "header", text = "QUEST TIMER BAR" },
        { type = "toggle", label = "Enable Quest Timer Bar",
          desc = "Show a bar with the time left on your active timed quest. Hidden when no timed quest is active.",
          get = function() return Bars().enableTimerBar ~= false end,
          set = function(v) Bars().enableTimerBar = v; DataBars("RefreshBars") end },
        { type = "select", label = "Timer Bar Docking",
          values = { { key = "tracker_top", label = "Dock to Tracker Top" }, { key = "tracker_bottom", label = "Dock to Tracker Bottom" }, { key = "free", label = "Free Floating (Movable)" } },
          desc = "Where the Quest Timer Bar is placed.",
          get = function() return Bars().timerDockMode or "tracker_top" end,
          set = function(v) Bars().timerDockMode = v; DataBars("UpdateTimerDocking"); DataBars("UpdateTimerBar") end },
        { type = "toggle", label = "Show Quest Title on Timer Bar",
          desc = "Show the quest name next to the countdown.",
          get = function() return Bars().timerShowTitle ~= false end,
          set = function(v) Bars().timerShowTitle = v; DataBars("UpdateTimerBar") end },
        { type = "range", label = "Timer Bar Height (px)", min = 16, max = 36, step = 1,
          desc = "Height of the timer bar (default 22).",
          get = function() return Bars().timerHeight or 22 end,
          set = function(v) Bars().timerHeight = v; DataBars("UpdateTimerDocking") end },
        { type = "range", label = "Timer Bar Width (px)", min = 140, max = 400, step = 5,
          desc = "Width of the timer bar while free floating (default 220).",
          get = function() return Bars().timerWidth or 220 end,
          set = function(v) Bars().timerWidth = v; DataBars("UpdateTimerDocking") end },
        { type = "range", label = "Timer Text Size (px)", min = 8, max = 18, step = 1,
          desc = "Font size of the countdown text.",
          get = function() return Bars().timerFontSize or 11 end,
          set = function(v) Bars().timerFontSize = v; DataBars("ApplyTypography") end },
        { type = "select", label = "Timer Text Outline", values = FONT_FLAG_OPTIONS,
          desc = "Outline style of the countdown text.",
          get = function() return Bars().timerFontOutline or "OUTLINE" end,
          set = function(v) Bars().timerFontOutline = v; DataBars("ApplyTypography") end },
        { type = "select", label = "Timer Statusbar Texture", values = GetStatusbarTextureList,
          desc = "Fill texture of the timer bar.",
          get = function() return Bars().timerBarTexture or "Solid" end,
          set = function(v) Bars().timerBarTexture = v; DataBars("RefreshBars") end },
    }, BarAppearanceSpecs("timer", "Timer Bar", { r = 0.06, g = 0.08, b = 0.12, a = 0.90 }, { r = 1.00, g = 0.82, b = 0.00, a = 0.85 })),
}

local extraSliderCount = 0

-- Builds the widgets for one tab's extra settings; returns a layout function
-- that places them below startY and returns the new bottom offset.
local function BuildExtraSettings(content, syncList, specs)
    local entries = {}

    local function RefreshDisabled()
        for _, e in ipairs(entries) do
            if e.spec.disabled then
                local enabled = not e.spec.disabled()
                local w = e.widget
                if w.SetEnabledState then
                    w:SetEnabledState(enabled)
                elseif e.spec.type == "color" then
                    w:SetEnabled(enabled)
                else
                    if w.SetEnabled then w:SetEnabled(enabled) end
                    w:SetAlpha(enabled and 1 or 0.4)
                    if w.Label then w.Label:SetAlpha(enabled and 1 or 0.4) end
                end
            end
        end
    end

    local function Wrap(set)
        return function(...)
            set(...)
            RefreshDisabled()
        end
    end

    for _, spec in ipairs(specs) do
        local w, height, full
        if spec.type == "header" then
            local header = CreateSectionHeader(content, spec.text, 12, 0)
            w, height, full = header, 30, true
        elseif spec.type == "toggle" then
            w = CreateStyledCheckbox(content, spec.label, spec.desc, spec.get, Wrap(spec.set))
            height = 30
        elseif spec.type == "range" then
            extraSliderCount = extraSliderCount + 1
            w = CreateStyledSlider(content, "BFQ_ExtraSlider" .. extraSliderCount, spec.label, spec.desc,
                spec.min, spec.max, spec.step, spec.get, Wrap(spec.set), spec.format)
            height = 46
        elseif spec.type == "select" then
            w = CreateStyledDropdown(content, spec.label, 220, 22, spec.values, spec.get, Wrap(spec.set), spec.desc)
            height = 32
        elseif spec.type == "color" then
            w = CreateStyledColorPickerWithHex(content, spec.label, 220, 22, spec.get, Wrap(spec.set), spec.desc)
            height = 32
        elseif spec.type == "keybind" then
            w = CreateStyledKeybindButton(content, spec.binding, spec.label, 220, 22, spec.desc)
            height = 32
        end
        if w then
            entries[#entries + 1] = { spec = spec, widget = w, height = height, full = full }
            if w.Sync then
                local baseSync = w.Sync
                w.Sync = function()
                    baseSync(w)
                    RefreshDisabled()
                end
                syncList[#syncList + 1] = w
            end
        end
    end
    RefreshDisabled()

    return function(startY, width)
        if not width or width < 100 then width = content:GetWidth() or 500 end
        local twoCols = width >= 470
        local colWidth = twoCols and math.floor((width - 48) / 2) or (width - 36)
        local colX = { 16, 16 + colWidth + 16 }
        local y = startY - 10
        local col, rowHeight = 1, 0
        for _, e in ipairs(entries) do
            local w = e.widget
            if e.full then
                if col == 2 then y = y - rowHeight end
                col, rowHeight = 1, 0
                w:ClearAllPoints()
                w:SetPoint("TOPLEFT", content, "TOPLEFT", 12, y)
                y = y - e.height
            else
                local offsetY = (e.spec.type == "range") and -16 or 0
                w:ClearAllPoints()
                w:SetPoint("TOPLEFT", content, "TOPLEFT", colX[col] + (e.spec.type == "toggle" and 0 or 4), y + offsetY)
                if e.spec.type == "toggle" then
                    if w.Text then w.Text:SetWidth(colWidth - 34) end
                else
                    w:SetWidth(math.min(220, colWidth - 20))
                end
                rowHeight = math.max(rowHeight, e.height)
                if twoCols and col == 1 then
                    col = 2
                else
                    col = 1
                    y = y - rowHeight
                    rowHeight = 0
                end
            end
        end
        if col == 2 then y = y - rowHeight end
        return y
    end
end

-- TAB 1: General Settings
local function BuildGeneralTab(content, syncList)
    local db = LiveDB
    local filterDb = LiveSection("filtering")

    local h1 = CreateSectionHeader(content, "FRAME LOCK & SIZING", 12, 0)
    local cbLock = CreateStyledCheckbox(content, "Lock Tracker Frame (Shift-drag unlock)",
        "Locks the tracker frame in place. When unlocked, hold Shift + Left Click to drag anywhere on screen.",
        function() return db.isLocked == true end,
        function(v)
            db.isLocked = v
            if ns.Tracker and ns.Tracker.SetLocked then ns.Tracker:SetLocked(v) end
        end
    )
    table.insert(syncList, cbLock)

    local slScale = CreateStyledSlider(content, "BFQ_SlScale", "Tracker Scale:",
        "Adjusts overall tracker UI scale (50% - 150%).",
        0.5, 1.5, 0.05,
        function() return db.scale or 1.0 end,
        function(v) db.scale = v end,
        "%.2f"
    )
    table.insert(syncList, slScale)

    local slAlpha = CreateStyledSlider(content, "BFQ_SlAlpha", "Tracker Alpha:",
        "Adjusts overall tracker frame transparency.",
        0.2, 1.0, 0.05,
        function() return db.alpha or 1.0 end,
        function(v) db.alpha = v end,
        "%.2f"
    )
    table.insert(syncList, slAlpha)

    local slWidth = CreateStyledSlider(content, "BFQ_SlWidth", "Tracker Width (Pixels):",
        "Sets the horizontal pixel width of the quest tracker container.",
        180, 450, 5,
        function() return db.width or 280 end,
        function(v) db.width = v end,
        "%d px"
    )
    table.insert(syncList, slWidth)

    local slHeight = CreateStyledSlider(content, "BFQ_SlMaxHeight", "Max Height (Pixels):",
        "Sets maximum vertical height before the quest list begins clipping or scrolling.",
        200, 1200, 20,
        function() return db.maxHeight or 600 end,
        function(v) db.maxHeight = v end,
        "%d px"
    )
    table.insert(syncList, slHeight)

    local ddGrowCorner = CreateStyledDropdown(content, "Grow Anchor Corner", 190, 22, GROW_CORNERS,
        function() return db.growCorner or "AUTO" end,
        function(v)
            db.growCorner = v
            if ns.Tracker and ns.Tracker.UpdateAnchorCorner then
                ns.Tracker:UpdateAnchorCorner(v)
            end
        end,
        "Determines which screen corner the tracker anchors to and expands from. 'Auto' dynamically detects the nearest corner when dragged. Bottom-Right anchors to the bottom-right and grows upward and to the left as quests are added."
    )
    table.insert(syncList, ddGrowCorner)

    local h2 = CreateSectionHeader(content, "VISIBILITY & COMBAT BEHAVIOR", 12, 0)
    local cbEmpty = CreateStyledCheckbox(content, "Auto-Hide When Empty",
        "Automatically hides the quest tracker backdrop when you have no active tracked quests.",
        function() return filterDb.autoHideEmpty == true end,
        function(v) filterDb.autoHideEmpty = v end
    )
    table.insert(syncList, cbEmpty)

    local cbInstance = CreateStyledCheckbox(content, "Auto-Hide Inside Instances",
        "Automatically conceals the quest tracker while inside dungeons, raids, or battlegrounds.",
        function() return filterDb.autoHideInInstances == true end,
        function(v) filterDb.autoHideInInstances = v end
    )
    table.insert(syncList, cbInstance)

    local cbCombatHide = CreateStyledCheckbox(content, "Hide Tracker In Combat",
        "Automatically hides the entire quest tracker frame during combat encounters.",
        function() return filterDb.hideInCombat == true end,
        function(v) filterDb.hideInCombat = v end
    )
    table.insert(syncList, cbCombatHide)

    local cbCombatCollapse = CreateStyledCheckbox(content, "Collapse Tracker In Combat",
        "Collapses quest objectives down to a compact single header bar while in combat.",
        function() return filterDb.collapseInCombat == true end,
        function(v) filterDb.collapseInCombat = v end
    )
    table.insert(syncList, cbCombatCollapse)

    local btnToggleVis = CreateStyledButton(content, "Toggle Tracker (Hide/Show)", 190, 22, function()
        if ns.Tracker and ns.Tracker.ToggleVisibility then
            ns.Tracker:ToggleVisibility()
        end
    end, "Completely hide or show the entire quest tracker window. Macro / Slash commands: /bfqhide, /bfq hide, /bfq show, /bfq togglehide.")

    local btnBindHide = CreateStyledKeybindButton(content, ns.BINDING_TOGGLE_TRACKER, "Hide Tracker Key", 190, 22,
        "Bind a keyboard shortcut to completely hide or show the quest tracker window."
    )
    table.insert(syncList, btnBindHide)

    local cbHideDataBarsWithTracker = CreateStyledCheckbox(content, "Hide DataBars When Tracker Hidden",
        "When enabled, hiding the quest tracker via keybind, button, or slash command also hides all active DataBars (XP Bar, Location Bar, and Quest Timer Bar).",
        function() return not (db.databars and db.databars.hideWithTracker == false) end,
        function(v)
            db.databars = db.databars or {}
            db.databars.hideWithTracker = v
            if ns.DataBarsModule and ns.DataBarsModule.RefreshBars then
                ns.DataBarsModule:RefreshBars()
            end
        end
    )
    table.insert(syncList, cbHideDataBarsWithTracker)

    local h3 = CreateSectionHeader(content, "MODULE MANAGEMENT", 12, 0)
    local cbModWayfinder = CreateStyledCheckbox(content, "Wayfinder Navigation Module",
        "3D floating HUD waypoint arrow, inline tracker mini arrows, and distance readouts.",
        function() return ns.IsModuleEnabled("wayfinder") end,
        function(v) ns.SetModuleEnabled("wayfinder", v) end
    )
    table.insert(syncList, cbModWayfinder)

    local cbModDataBars = CreateStyledCheckbox(content, "DataBars Suite Module",
        "Standalone Experience / Reputation progress bar, Location & precision coordinates header bar, and timed quest bar.",
        function() return ns.IsModuleEnabled("databars") end,
        function(v) ns.SetModuleEnabled("databars", v) end
    )
    table.insert(syncList, cbModDataBars)

    local cbModQuestAuto = CreateStyledCheckbox(content, "Quest Automation Module",
        "Automated quest accepting, auto-sharing with party members, and smart turn-in completion.",
        function() return ns.IsModuleEnabled("questAutomation") end,
        function(v) ns.SetModuleEnabled("questAutomation", v) end
    )
    table.insert(syncList, cbModQuestAuto)

    local cbModQoL = CreateStyledCheckbox(content, "Quality of Life (QoL) Module",
        "Instant Fast Auto Loot, automatic grey/junk selling at vendors, and merchant equipment repair.",
        function() return ns.IsModuleEnabled("qol") end,
        function(v) ns.SetModuleEnabled("qol", v) end
    )
    table.insert(syncList, cbModQoL)

    local h4 = CreateSectionHeader(content, "UTILITY & POSITION ACTIONS", 12, 0)
    local cbOverlay = CreateStyledCheckbox(content, "Show Bounds Overlay & Resize Handle",
        "Display the on-screen blue bounding box and [Drag to Resize] handle on the tracker.",
        function()
            return ns.Tracker and ns.Tracker.IsConfigOverlayShown and ns.Tracker:IsConfigOverlayShown()
        end,
        function(v)
            if ns.Tracker then
                if v then
                    if ns.Tracker.ShowConfigOverlay then ns.Tracker:ShowConfigOverlay() end
                else
                    if ns.Tracker.HideConfigOverlay then ns.Tracker:HideConfigOverlay() end
                end
            end
        end
    )
    table.insert(syncList, cbOverlay)

    local btnOnboard = CreateStyledButton(content, "Run Setup Walkthrough", 190, 22, function()
        if ns.Onboarding and ns.Onboarding.ShowWizard then
            ns.Onboarding:ShowWizard()
        end
    end, "Open the interactive first-time setup walkthrough modal (/bfq onboard).")

    local btnResetPos = CreateStyledButton(content, "Reset Tracker Position", 190, 22, function()
        if ns.Tracker and ns.Tracker.ResetPosition then
            ns.Tracker:ResetPosition()
        end
        ns.Notify(L["Tracker position reset to default."])
    end, "Reset the tracker to the default screen position (top-right).")

    local btnResetUntracked = CreateStyledButton(content, "Reset Untracked Quests", 190, 22, function()
        if db.filtering then
            db.filtering.untrackedQuests = {}
        end
        ns:FireCallback("QUEST_DATA_CHANGED")
        ns.Notify(L["Untracked quests restored."])
    end, "Restores all quests that were hidden from the tracker using the right-click 'Untrack Quest' menu.")

    local function Layout(w)
        if not w or w < 100 then w = content:GetWidth() or 500 end
        local y = -10
        h1:SetPoint("TOPLEFT", content, "TOPLEFT", 12, y)
        y = y - 30

        if w >= 470 then
            local colWidth = math.floor((w - 48) / 2)
            local col1X = 16
            local col2X = col1X + colWidth + 16

            cbLock:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            cbLock.Text:SetWidth(colWidth - 32)
            slScale:SetPoint("TOPLEFT", content, "TOPLEFT", col2X, y)
            slScale:SetWidth(math.min(190, colWidth - 20))
            y = y - 48

            slAlpha:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            slAlpha:SetWidth(math.min(190, colWidth - 20))
            slWidth:SetPoint("TOPLEFT", content, "TOPLEFT", col2X, y)
            slWidth:SetWidth(math.min(190, colWidth - 20))
            y = y - 48

            slHeight:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            slHeight:SetWidth(math.min(190, colWidth - 20))
            ddGrowCorner:SetPoint("TOPLEFT", content, "TOPLEFT", col2X, y)
            ddGrowCorner:SetWidth(math.min(190, colWidth - 20))
            y = y - 48

            h2:SetPoint("TOPLEFT", content, "TOPLEFT", 12, y)
            y = y - 30

            cbEmpty:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            cbEmpty.Text:SetWidth(colWidth - 32)
            cbInstance:SetPoint("TOPLEFT", content, "TOPLEFT", col2X, y)
            cbInstance.Text:SetWidth(colWidth - 32)
            y = y - 34

            cbCombatHide:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            cbCombatHide.Text:SetWidth(colWidth - 32)
            cbCombatCollapse:SetPoint("TOPLEFT", content, "TOPLEFT", col2X, y)
            cbCombatCollapse.Text:SetWidth(colWidth - 32)
            y = y - 34

            btnToggleVis:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            btnToggleVis:SetWidth(math.min(190, colWidth - 20))
            btnBindHide:SetPoint("TOPLEFT", content, "TOPLEFT", col2X, y)
            btnBindHide:SetWidth(math.min(190, colWidth - 20))
            y = y - 34

            cbHideDataBarsWithTracker:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            cbHideDataBarsWithTracker.Text:SetWidth(w - 56)
            y = y - 40

            h3:SetPoint("TOPLEFT", content, "TOPLEFT", 12, y)
            y = y - 30

            cbModWayfinder:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            cbModWayfinder.Text:SetWidth(colWidth - 32)
            cbModDataBars:SetPoint("TOPLEFT", content, "TOPLEFT", col2X, y)
            cbModDataBars.Text:SetWidth(colWidth - 32)
            y = y - 34

            cbModQuestAuto:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            cbModQuestAuto.Text:SetWidth(colWidth - 32)
            cbModQoL:SetPoint("TOPLEFT", content, "TOPLEFT", col2X, y)
            cbModQoL.Text:SetWidth(colWidth - 32)
            y = y - 40

            h4:SetPoint("TOPLEFT", content, "TOPLEFT", 12, y)
            y = y - 30

            cbOverlay:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            cbOverlay.Text:SetWidth(colWidth - 32)
            btnOnboard:SetPoint("TOPLEFT", content, "TOPLEFT", col2X, y)
            btnOnboard:SetWidth(math.min(190, colWidth - 20))
            y = y - 36

            btnResetPos:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            btnResetPos:SetWidth(math.min(190, colWidth - 20))
            btnResetUntracked:SetPoint("TOPLEFT", content, "TOPLEFT", col2X, y)
            btnResetUntracked:SetWidth(math.min(190, colWidth - 20))
            y = y - 36
        else
            local colWidth = w - 36
            local col1X = 16

            cbLock:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            cbLock.Text:SetWidth(colWidth - 32)
            y = y - 32
            slScale:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            slScale:SetWidth(math.min(220, colWidth - 20))
            y = y - 46
            slAlpha:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            slAlpha:SetWidth(math.min(220, colWidth - 20))
            y = y - 46
            slWidth:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            slWidth:SetWidth(math.min(220, colWidth - 20))
            y = y - 46
            slHeight:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            slHeight:SetWidth(math.min(220, colWidth - 20))
            y = y - 46
            ddGrowCorner:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            ddGrowCorner:SetWidth(math.min(220, colWidth - 20))
            y = y - 46

            h2:SetPoint("TOPLEFT", content, "TOPLEFT", 12, y)
            y = y - 30

            cbEmpty:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            cbEmpty.Text:SetWidth(colWidth - 32)
            y = y - 32
            cbInstance:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            cbInstance.Text:SetWidth(colWidth - 32)
            y = y - 32
            cbCombatHide:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            cbCombatHide.Text:SetWidth(colWidth - 32)
            y = y - 32
            cbCombatCollapse:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            cbCombatCollapse.Text:SetWidth(colWidth - 32)
            y = y - 32
            btnToggleVis:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            btnToggleVis:SetWidth(math.min(220, colWidth - 20))
            y = y - 34
            btnBindHide:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            btnBindHide:SetWidth(math.min(220, colWidth - 20))
            y = y - 34
            cbHideDataBarsWithTracker:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            cbHideDataBarsWithTracker.Text:SetWidth(colWidth - 32)
            y = y - 38

            h3:SetPoint("TOPLEFT", content, "TOPLEFT", 12, y)
            y = y - 30

            cbModWayfinder:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            cbModWayfinder.Text:SetWidth(colWidth - 32)
            y = y - 32
            cbModDataBars:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            cbModDataBars.Text:SetWidth(colWidth - 32)
            y = y - 32
            cbModQuestAuto:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            cbModQuestAuto.Text:SetWidth(colWidth - 32)
            y = y - 32
            cbModQoL:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            cbModQoL.Text:SetWidth(colWidth - 32)
            y = y - 38

            h4:SetPoint("TOPLEFT", content, "TOPLEFT", 12, y)
            y = y - 30

            cbOverlay:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            cbOverlay.Text:SetWidth(colWidth - 32)
            y = y - 32
            btnOnboard:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            btnOnboard:SetWidth(math.min(220, colWidth - 20))
            y = y - 36
            btnResetPos:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            btnResetPos:SetWidth(math.min(220, colWidth - 20))
            y = y - 36
            btnResetUntracked:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            btnResetUntracked:SetWidth(math.min(220, colWidth - 20))
            y = y - 36
        end

        content:SetHeight(math.abs(y) + 20)
    end

    content.LayoutTab = Layout
    Layout(content:GetWidth())
end

-- TAB 2: Quests & Items
local function BuildQuestsTab(content, syncList)
    local db = LiveDB
    local itemDb = LiveSection("itemButtons")
    local headerDb = LiveSection("headers")
    local fontDb = LiveSection("fonts")
    local sortDb = LiveSection("sorting")
    local tipDb = LiveSection("tooltips")

    local h1 = CreateSectionHeader(content, "QUEST ITEM ACTION BUTTONS", 12, 0)
    local cbItemBtn = CreateStyledCheckbox(content, "Enable Quest Item Buttons",
        "Renders clickable quest item shortcut buttons next to objectives (e.g. Hearthstone, quest items).",
        function() return itemDb.enabled ~= false end,
        function(v) itemDb.enabled = v end
    )
    table.insert(syncList, cbItemBtn)

    local slItemSize = CreateStyledSlider(content, "BFQ_SlItemSize", "Item Button Size:",
        "Pixel dimensions of quest item shortcut buttons (20 - 48px).",
        20, 48, 1,
        function() return itemDb.size or 26 end,
        function(v)
            itemDb.size = v
            if ns.db then
                ns.db.itemButtons = ns.db.itemButtons or {}
                ns.db.itemButtons.size = v
            end
            if ns.Tracker and ns.Tracker.UpdateSettings then
                ns.Tracker:UpdateSettings()
            end
            if ns.StandaloneTracker and ns.StandaloneTracker.UpdateItemButton then
                ns.StandaloneTracker:UpdateItemButton()
            end
        end,
        "%d px"
    )
    table.insert(syncList, slItemSize)

    local cbItemAuto = CreateStyledCheckbox(content, "Auto-Detect Usable Quest Items",
        "Automatically identifies quest item bags and slots matching active quest requirements.",
        function() return itemDb.autoDetect ~= false end,
        function(v) itemDb.autoDetect = v end
    )
    table.insert(syncList, cbItemAuto)

    local btnItemPos = CreateStyledDropdown(content, "Item Placement", 220, 22, ITEM_POSITIONS,
        function()
            local p = db.itemButtonPlacement
            if p ~= "outside_left" and p ~= "inside_right" then
                p = "inside_right"
            end
            return p
        end,
        function(v)
            db.itemButtonPlacement = v
            db.itemButtonPosition = nil
            if ns.StandaloneTracker then ns.StandaloneTracker:UpdateItemButtonVisibility() end
        end,
        "Dock quest item buttons on the left side outside of the tracker or on the right side of the quest inside of the tracker."
    )
    table.insert(syncList, btnItemPos)

    local btnItemStrata = CreateStyledDropdown(content, "Item Frame Strata", 190, 22, ITEM_STRATAS,
        function() return ns.db and ns.db.itemButtonStrata or "MEDIUM" end,
        function(v)
            ns.db = ns.db or {}
            ns.db.itemButtonStrata = v
            if ns.StandaloneTracker and ns.StandaloneTracker.UpdateItemButtonStrata then
                ns.StandaloneTracker:UpdateItemButtonStrata()
            end
        end,
        "Sets the frame strata for quest item buttons. 'Medium' matches the tracker and bag addons so overlapping windows properly cover the item buttons."
    )
    table.insert(syncList, btnItemStrata)

    local h2 = CreateSectionHeader(content, "OBJECTIVES, BADGES & TOOLTIPS", 12, 0)
    local cbCompleteIcon = CreateStyledCheckbox(content, "Show Completed ? Checkmark Icon",
        "Shows a prominent gold question mark or checkmark when a quest is ready to turn in.",
        function() return headerDb.showCompleteIcon ~= false end,
        function(v) headerDb.showCompleteIcon = v end
    )
    table.insert(syncList, cbCompleteIcon)

    local cbDiffColor = CreateStyledCheckbox(content, "Color Quests by Difficulty Level",
        "Tints quest titles based on character level (Red = Impossible, Orange = Hard, Yellow = Normal, Green = Easy, Grey = Trivial).",
        function() return fontDb.colorDifficulty ~= false end,
        function(v) fontDb.colorDifficulty = v end
    )
    table.insert(syncList, cbDiffColor)

    local cbGroupTags = CreateStyledCheckbox(content, "Show Group & Elite Badges",
        "Displays elite, dungeon, and recommended player count tags ([11+], [Elite], [Dungeon]).",
        function() return sortDb.showGroupTags ~= false end,
        function(v) sortDb.showGroupTags = v end
    )
    table.insert(syncList, cbGroupTags)

    local cbRewards = CreateStyledCheckbox(content, "Show Quest Rewards in Tooltips",
        "Displays experience, copper/silver/gold rewards, and items upon hovering over a quest in the tracker.",
        function() return tipDb.showRewards ~= false end,
        function(v) tipDb.showRewards = v end
    )
    table.insert(syncList, cbRewards)

    local cbXpPct = CreateStyledCheckbox(content, "Show XP Reward Percentage",
        "Displays what percent of your current level will be granted by completing the quest.",
        function() return tipDb.showXpPercent ~= false end,
        function(v) tipDb.showXpPercent = v end
    )
    table.insert(syncList, cbXpPct)

    local cbUsableGear = CreateStyledCheckbox(content, "Highlight Usable Equipment Upgrades",
        "Highlights equipment rewards that match your character class and armor proficiencies.",
        function() return tipDb.showUsableGear ~= false end,
        function(v) tipDb.showUsableGear = v end
    )
    table.insert(syncList, cbUsableGear)

    local cbPartyStatus = CreateStyledCheckbox(content, "Show Party Members on Quest",
        "Shows which party members are currently on the quest when hovering over a quest in the tracker.",
        function() return tipDb.showPartyStatus ~= false end,
        function(v) tipDb.showPartyStatus = v end
    )
    table.insert(syncList, cbPartyStatus)

    local cbMissingParty = CreateStyledCheckbox(content, "Show Missing Party Members",
        "Displays group members who do not currently have the quest, noting if it can be shared with them.",
        function() return tipDb.showMissingParty ~= false end,
        function(v) tipDb.showMissingParty = v end
    )
    table.insert(syncList, cbMissingParty)

    local cbClassColorParty = CreateStyledCheckbox(content, "Class Color Party Names",
        "Formats party member names in tooltips using their character class colors.",
        function() return tipDb.classColorParty ~= false end,
        function(v) tipDb.classColorParty = v end
    )
    table.insert(syncList, cbClassColorParty)

    local cbPartyBadge = CreateStyledCheckbox(content, "Show Party Count Badge [|TInterface\\QUESTFRAME\\QuestLogQuestTypeIcons2x:12:15:0:0:256:256:5:37:166:192|t #]",
        "Appends a party member count badge with group icon next to quest titles in the tracker when party members share the quest.",
        function() return tipDb.showPartyBadge == true end,
        function(v)
            tipDb.showPartyBadge = v
            if ns.FireCallback then ns:FireCallback("QUEST_DATA_CHANGED") end
        end
    )
    table.insert(syncList, cbPartyBadge)

    local h3 = CreateSectionHeader(content, "ZONE EXPANSION ACTIONS", 12, 0)
    local btnExpandAll = CreateStyledButton(content, "Expand All Zones", 190, 22, function()
        if db then
            db.collapsedZones = {}
            if ns.FireCallback then ns:FireCallback("QUEST_DATA_CHANGED") end
        end
    end, "Expand all collapsible zone headers inside the tracker.")

    local btnCollapseAll = CreateStyledButton(content, "Collapse All Zones", 190, 22, function()
        if ns.StandaloneTracker and ns.StandaloneTracker.GetTrackedQuests then
            db.collapsedZones = db.collapsedZones or {}
            local quests = ns.StandaloneTracker:GetTrackedQuests()
            for _, q in ipairs(quests) do
                local z = q.zone or "Other Quests"
                db.collapsedZones[z] = true
            end
            if ns.FireCallback then ns:FireCallback("QUEST_DATA_CHANGED") end
        end
    end, "Collapse all zone headers down to compact single bars.")

    local function Layout(w)
        if not w or w < 100 then w = content:GetWidth() or 500 end
        local y = -10
        h1:SetPoint("TOPLEFT", content, "TOPLEFT", 12, y)
        y = y - 30

        if w >= 470 then
            local colWidth = math.floor((w - 48) / 2)
            local col1X = 16
            local col2X = col1X + colWidth + 16

            cbItemBtn:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            cbItemBtn.Text:SetWidth(colWidth - 32)
            slItemSize:SetPoint("TOPLEFT", content, "TOPLEFT", col2X, y)
            slItemSize:SetWidth(math.min(190, colWidth - 20))
            y = y - 48

            cbItemAuto:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            cbItemAuto.Text:SetWidth(colWidth - 32)
            btnItemPos:SetPoint("TOPLEFT", content, "TOPLEFT", col2X, y)
            btnItemPos:SetWidth(math.min(190, colWidth - 20))
            y = y - 40

            h2:SetPoint("TOPLEFT", content, "TOPLEFT", 12, y)
            y = y - 30

            cbCompleteIcon:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            cbCompleteIcon.Text:SetWidth(colWidth - 32)
            cbDiffColor:SetPoint("TOPLEFT", content, "TOPLEFT", col2X, y)
            cbDiffColor.Text:SetWidth(colWidth - 32)
            y = y - 34

            cbGroupTags:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            cbGroupTags.Text:SetWidth(colWidth - 32)
            cbPartyBadge:SetPoint("TOPLEFT", content, "TOPLEFT", col2X, y)
            cbPartyBadge.Text:SetWidth(colWidth - 32)
            y = y - 34

            cbRewards:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            cbRewards.Text:SetWidth(colWidth - 32)
            cbXpPct:SetPoint("TOPLEFT", content, "TOPLEFT", col2X, y)
            cbXpPct.Text:SetWidth(colWidth - 32)
            y = y - 34

            cbUsableGear:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            cbUsableGear.Text:SetWidth(colWidth - 32)
            cbPartyStatus:SetPoint("TOPLEFT", content, "TOPLEFT", col2X, y)
            cbPartyStatus.Text:SetWidth(colWidth - 32)
            y = y - 34

            cbMissingParty:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            cbMissingParty.Text:SetWidth(colWidth - 32)
            cbClassColorParty:SetPoint("TOPLEFT", content, "TOPLEFT", col2X, y)
            cbClassColorParty.Text:SetWidth(colWidth - 32)
            y = y - 40

            h3:SetPoint("TOPLEFT", content, "TOPLEFT", 12, y)
            y = y - 30

            btnExpandAll:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            btnExpandAll:SetWidth(math.min(190, colWidth - 20))
            btnCollapseAll:SetPoint("TOPLEFT", content, "TOPLEFT", col2X, y)
            btnCollapseAll:SetWidth(math.min(190, colWidth - 20))
            y = y - 36
        else
            local colWidth = w - 36
            local col1X = 16

            cbItemBtn:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            cbItemBtn.Text:SetWidth(colWidth - 32)
            y = y - 32
            slItemSize:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            slItemSize:SetWidth(math.min(220, colWidth - 20))
            y = y - 46
            cbItemAuto:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            cbItemAuto.Text:SetWidth(colWidth - 32)
            y = y - 32
            btnItemPos:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            btnItemPos:SetWidth(math.min(220, colWidth - 20))
            y = y - 38

            h2:SetPoint("TOPLEFT", content, "TOPLEFT", 12, y)
            y = y - 30

            cbCompleteIcon:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            cbCompleteIcon.Text:SetWidth(colWidth - 32)
            y = y - 32
            cbDiffColor:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            cbDiffColor.Text:SetWidth(colWidth - 32)
            y = y - 32
            cbGroupTags:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            cbGroupTags.Text:SetWidth(colWidth - 32)
            y = y - 32
            cbPartyBadge:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            cbPartyBadge.Text:SetWidth(colWidth - 32)
            y = y - 32
            cbRewards:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            cbRewards.Text:SetWidth(colWidth - 32)
            y = y - 32
            cbXpPct:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            cbXpPct.Text:SetWidth(colWidth - 32)
            y = y - 32
            cbUsableGear:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            cbUsableGear.Text:SetWidth(colWidth - 32)
            y = y - 32
            cbPartyStatus:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            cbPartyStatus.Text:SetWidth(colWidth - 32)
            y = y - 32
            cbMissingParty:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            cbMissingParty.Text:SetWidth(colWidth - 32)
            y = y - 32
            cbClassColorParty:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            cbClassColorParty.Text:SetWidth(colWidth - 32)
            y = y - 38

            h3:SetPoint("TOPLEFT", content, "TOPLEFT", 12, y)
            y = y - 30

            btnExpandAll:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            btnExpandAll:SetWidth(math.min(220, colWidth - 20))
            y = y - 36
            btnCollapseAll:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            btnCollapseAll:SetWidth(math.min(220, colWidth - 20))
            y = y - 36
        end

        content:SetHeight(math.abs(y) + 20)
    end

    content.LayoutTab = Layout
    Layout(content:GetWidth())
end

-- TAB 3: Colors & Fonts
local function BuildColorsTab(content, syncList)
    local db = LiveDB
    local bgDb = LiveSection("backdrop")
    local fontDb = LiveSection("fonts")
    local headerDb = LiveSection("headers")
    local wfDb = LiveSection("wayfinder")
    local dataDb = LiveSection("databars")
    local ui = {}

    -- SECTION 1: TRACKER BACKDROP & BORDER
    ui.h1, ui.d1 = CreateSectionHeader(content, "TRACKER BACKDROP & BORDER", 12, 0)

    ui.cpBgColor = CreateStyledColorPickerWithHex(content, "Bg Color", 190, 22,
        function()
            local c = bgDb.bgColor or { r = 0.05, g = 0.05, b = 0.05, a = 0.65 }
            return c.r, c.g, c.b, c.a or 0.65
        end,
        function(r, g, b, a)
            local curA = (bgDb.bgColor and bgDb.bgColor.a) or 0.65
            bgDb.bgColor = { r = r, g = g, b = b, a = a or curA }
        end,
        "Click the swatch to open the color picker with live palette, or click the editbox and type any Hex code (e.g. #000000) and press Enter.",
        syncList
    )
    table.insert(syncList, ui.cpBgColor)

    ui.btnPureBlack = CreateStyledButton(content, "Pure Black (#000000)", 190, 22, function()
        bgDb.bgTexture = "solid"
        bgDb.bgColor = { r = 0, g = 0, b = 0, a = 1.0 }
        if ns.Tracker and ns.Tracker.UpdateBackdrop then ns.Tracker:UpdateBackdrop() end
        for _, w in ipairs(syncList) do if w.Sync then w.Sync() end end
        ns.Notify(L["Tracker background set to Pure Black (#000000) at 100% opacity."])
    end, "Instantly sets the background to solid pitch black (#000000) with 100% opacity for maximum contrast and readability.")

    ui.slBgAlpha = CreateStyledSlider(content, "BFQ_SlBgAlpha", "Background Opacity:",
        "Controls the dark backdrop fill opacity (0% - 100%).",
        0.0, 1.0, 0.05,
        function() return (bgDb.bgColor and bgDb.bgColor.a) or 0.65 end,
        function(v)
            bgDb.bgColor = bgDb.bgColor or { r = 0.05, g = 0.05, b = 0.05, a = 0.65 }
            bgDb.bgColor.a = v
        end,
        "%.2f"
    )
    table.insert(syncList, ui.slBgAlpha)

    ui.slBorderAlpha = CreateStyledSlider(content, "BFQ_SlBorderAlpha", "Border Opacity:",
        "Controls the border opacity (0% - 100%).",
        0.0, 1.0, 0.05,
        function() return (bgDb.borderColor and bgDb.borderColor.a) or 0.90 end,
        function(v)
            bgDb.borderColor = bgDb.borderColor or { r = 0.15, g = 0.15, b = 0.15, a = 0.90 }
            bgDb.borderColor.a = v
        end,
        "%.2f"
    )
    table.insert(syncList, ui.slBorderAlpha)

    ui.btnBgTexture = CreateStyledDropdown(content, "Surface Texture", 190, 22, BACKGROUND_SURFACE_TEXTURES,
        function() return bgDb.bgTexture or "solid" end,
        function(v)
            local prev = bgDb.bgTexture or "solid"
            bgDb.bgTexture = v
            local isParchment = (v == "parchment" or v == "parchment_clean")
            local wasParchment = (prev == "parchment" or prev == "parchment_clean")
            if isParchment and not wasParchment then
                bgDb.bgColor = { r = 0.96, g = 0.90, b = 0.78, a = 0.90 }
            elseif not isParchment and wasParchment then
                bgDb.bgColor = { r = 0.05, g = 0.05, b = 0.05, a = 0.65 }
            end
            if ns.Tracker and ns.Tracker.UpdateBackdrop then ns.Tracker:UpdateBackdrop() end
            if ns.DataBarsModule and ns.DataBarsModule.RefreshBars then ns.DataBarsModule:RefreshBars() end
            for _, w in ipairs(syncList) do if w.Sync then w.Sync() end end
        end,
        "Select the background surface texture for the tracker window (Solid, Tooltip, Marble, Rock, or Parchment)."
    )
    table.insert(syncList, ui.btnBgTexture)

    ui.btnBorder = CreateStyledDropdown(content, "Border Style", 190, 22, BORDER_STYLES,
        function() return bgDb.borderStyle or "flat" end,
        function(v) bgDb.borderStyle = v end,
        "Choose between Flat 1px border, Blizzard Tooltip rounded corners, Dialog, or borderless."
    )
    table.insert(syncList, ui.btnBorder)

    ui.cpBorderColor = CreateStyledColorPickerWithHex(content, "Border Color", 190, 22,
        function()
            local c = bgDb.borderColor or { r = 0.15, g = 0.15, b = 0.15, a = 0.90 }
            return c.r, c.g, c.b, c.a or 0.90
        end,
        function(r, g, b, a)
            local curA = (bgDb.borderColor and bgDb.borderColor.a) or 0.90
            bgDb.borderColor = { r = r, g = g, b = b, a = a or curA }
        end,
        "Choose a custom border color or enter a Hex code (e.g. #262626) when Class-Colored Border is disabled.",
        syncList
    )
    table.insert(syncList, ui.cpBorderColor)

    ui.cbClassBorder = CreateStyledCheckbox(content, "Class-Colored Tracker Border",
        "Tints the tracker frame border using your player character's class color.",
        function() return bgDb.classColorBorder == true end,
        function(v) bgDb.classColorBorder = v end
    )
    table.insert(syncList, ui.cbClassBorder)

    ui.btnResetBackdrop = CreateStyledButton(content, "Reset Backdrop Defaults", 190, 22, function()
        if bgDb then
            bgDb.bgTexture = "solid"
            bgDb.bgColor = { r = 0.05, g = 0.05, b = 0.05, a = 0.65 }
            bgDb.borderColor = { r = 0.15, g = 0.15, b = 0.15, a = 0.90 }
            bgDb.borderStyle = "flat"
            bgDb.classColorBorder = false
        end
        if ns.Tracker and ns.Tracker.UpdateBackdrop then ns.Tracker:UpdateBackdrop() end
        for _, w in ipairs(syncList) do if w.Sync then w.Sync() end end
        ns.Notify(L["Tracker backdrop and border colors reset to defaults."])
    end, "Reset tracker background color, border color, and opacity back to defaults.")

    -- SECTION 2: QUEST & OBJECTIVE TYPOGRAPHY & COLORS
    ui.h1b, ui.d1b = CreateSectionHeader(content, "QUEST & OBJECTIVE TYPOGRAPHY & COLORS", 12, 0)

    ui.cbColorDiff = CreateStyledCheckbox(content, "Color Quest Titles by Level Difficulty",
        "Colors quest titles by level difficulty (Green/Yellow/Orange/Red). Uncheck to use your custom Quest Title Color below.",
        function() return fontDb.colorDifficulty ~= false end,
        function(v) fontDb.colorDifficulty = v end
    )
    table.insert(syncList, ui.cbColorDiff)

    ui.cpTitleColor = CreateStyledColorPickerWithHex(content, "Quest Title", 190, 22,
        function()
            local c = fontDb.titleColor or { r = 1.00, g = 0.82, b = 0.00 }
            return c.r, c.g, c.b, 1.0
        end,
        function(r, g, b)
            fontDb.titleColor = { r = r, g = g, b = b }
        end,
        "Custom color for quest titles when 'Color Quest Titles by Level Difficulty' is unchecked. Supports #RRGGBB Hex input.",
        syncList
    )
    table.insert(syncList, ui.cpTitleColor)

    ui.cpObjColor = CreateStyledColorPickerWithHex(content, "Objectives", 190, 22,
        function()
            local c = fontDb.objectiveColor or { r = 0.80, g = 0.80, b = 0.80 }
            return c.r, c.g, c.b, 1.0
        end,
        function(r, g, b)
            fontDb.objectiveColor = { r = r, g = g, b = b }
        end,
        "Custom text color for incomplete quest objective lines. Supports #RRGGBB Hex input (e.g. #FFFFFF for pure white).",
        syncList
    )
    table.insert(syncList, ui.cpObjColor)

    ui.cpCompColor = CreateStyledColorPickerWithHex(content, "Completed", 190, 22,
        function()
            local c = fontDb.completedObjectiveColor or { r = 0.00, g = 1.00, b = 0.00 }
            return c.r, c.g, c.b, 1.0
        end,
        function(r, g, b)
            fontDb.completedObjectiveColor = { r = r, g = g, b = b }
        end,
        "Custom text color for finished objectives and 'Ready for turn-in' lines. Supports #RRGGBB Hex input (default: #00FF00).",
        syncList
    )
    table.insert(syncList, ui.cpCompColor)

    ui.cbCompletedBg = CreateStyledCheckbox(content, "Completed Quest Background Tint",
        "Display a soft background tint behind quests that are ready for turn-in.",
        function() return fontDb.completedQuestBg ~= false end,
        function(v)
            fontDb.completedQuestBg = v
            if ns.StandaloneTracker and ns.StandaloneTracker.UpdateTracker then ns.StandaloneTracker:UpdateTracker() end
        end
    )
    table.insert(syncList, ui.cbCompletedBg)

    ui.cpCompletedBgColor = CreateStyledColorPickerWithHex(content, "Completed Bg Tint", 190, 22,
        function()
            local c = fontDb.completedQuestBgColor or { r = 0.00, g = 0.80, b = 0.20, a = 0.14 }
            return c.r, c.g, c.b, c.a or 0.14
        end,
        function(r, g, b, a)
            local curA = (fontDb.completedQuestBgColor and fontDb.completedQuestBgColor.a) or 0.14
            fontDb.completedQuestBgColor = { r = r, g = g, b = b, a = a or curA }
            if ns.StandaloneTracker and ns.StandaloneTracker.UpdateTracker then ns.StandaloneTracker:UpdateTracker() end
        end,
        "Custom background tint color and opacity for completed quests ready for turn-in.",
        syncList
    )
    table.insert(syncList, ui.cpCompletedBgColor)

    ui.ddCompletedTitleMode = CreateStyledDropdown(content, "Completed Title Color", 190, 22, COMPLETED_TITLE_MODES,
        function() return fontDb.completedTitleColorMode or "difficulty" end,
        function(v)
            fontDb.completedTitleColorMode = v
            if ns.StandaloneTracker and ns.StandaloneTracker.UpdateTracker then ns.StandaloneTracker:UpdateTracker() end
        end,
        "Choose how completed quest titles are colored (keep level difficulty color, match turn-in green, or custom color)."
    )
    table.insert(syncList, ui.ddCompletedTitleMode)

    ui.cpCompletedTitleCustomColor = CreateStyledColorPickerWithHex(content, "Custom Title Color", 190, 22,
        function()
            local c = fontDb.completedTitleCustomColor or { r = 0.00, g = 1.00, b = 0.00 }
            return c.r, c.g, c.b, 1.0
        end,
        function(r, g, b)
            fontDb.completedTitleCustomColor = { r = r, g = g, b = b }
            if ns.StandaloneTracker and ns.StandaloneTracker.UpdateTracker then ns.StandaloneTracker:UpdateTracker() end
        end,
        "Custom title color for completed quests when 'Completed Title Color' is set to Custom.",
        syncList
    )
    table.insert(syncList, ui.cpCompletedTitleCustomColor)

    ui.cpQuestHoverColor = CreateStyledColorPickerWithHex(content, "Quest Hover Color", 190, 22,
        function()
            local c = fontDb.questHoverColor or { r = 1.00, g = 1.00, b = 1.00, a = 0.08 }
            return c.r, c.g, c.b, c.a or 0.08
        end,
        function(r, g, b, a)
            local curA = (fontDb.questHoverColor and fontDb.questHoverColor.a) or 0.08
            fontDb.questHoverColor = { r = r, g = g, b = b, a = a or curA }
            if ns.StandaloneTracker and ns.StandaloneTracker.ApplyHighlightColors then ns.StandaloneTracker:ApplyHighlightColors() end
        end,
        "Mouseover highlight color and opacity when hovering over a quest row.",
        syncList
    )
    table.insert(syncList, ui.cpQuestHoverColor)

    ui.cpZoneHoverColor = CreateStyledColorPickerWithHex(content, "Zone Hover Color", 190, 22,
        function()
            local c = fontDb.zoneHoverColor or { r = 1.00, g = 0.82, b = 0.00, a = 0.12 }
            return c.r, c.g, c.b, c.a or 0.12
        end,
        function(r, g, b, a)
            local curA = (fontDb.zoneHoverColor and fontDb.zoneHoverColor.a) or 0.12
            fontDb.zoneHoverColor = { r = r, g = g, b = b, a = a or curA }
            if ns.StandaloneTracker and ns.StandaloneTracker.ApplyHighlightColors then ns.StandaloneTracker:ApplyHighlightColors() end
        end,
        "Mouseover highlight color and opacity when hovering over a zone header.",
        syncList
    )
    table.insert(syncList, ui.cpZoneHoverColor)

    ui.ddHeaderFont = CreateStyledFontDropdown(content, "Header Font", 190, 22,
        function() return fontDb.headerFont or fontDb.font or "Nata Sans Bold" end,
        function(v)
            fontDb.headerFont = v
            fontDb.font = v
            if ns.Tracker and ns.Tracker.UpdateTypography then ns.Tracker:UpdateTypography() end
        end,
        "Select the typography face for tracker headers, zone titles, and quest titles."
    )
    table.insert(syncList, ui.ddHeaderFont)

    ui.ddHeaderOutline = CreateStyledDropdown(content, "Header Outline", 190, 22, OUTLINE_OPTIONS,
        function() return fontDb.headerOutline or "OUTLINE" end,
        function(v)
            fontDb.headerOutline = v
            if ns.Tracker and ns.Tracker.UpdateTypography then ns.Tracker:UpdateTypography() end
        end,
        "Select the font outline rendering style for headers and quest titles."
    )
    table.insert(syncList, ui.ddHeaderOutline)

    ui.ddObjFont = CreateStyledFontDropdown(content, "Objective Font", 190, 22,
        function() return fontDb.objectiveFont or "Nata Sans Regular" end,
        function(v)
            fontDb.objectiveFont = v
            if ns.Tracker and ns.Tracker.UpdateTypography then ns.Tracker:UpdateTypography() end
        end,
        "Select the typography face for quest objectives, progress text, and descriptions."
    )
    table.insert(syncList, ui.ddObjFont)

    ui.ddObjOutline = CreateStyledDropdown(content, "Objective Outline", 190, 22, OUTLINE_OPTIONS,
        function() return fontDb.objectiveOutline or "" end,
        function(v)
            fontDb.objectiveOutline = v
            if ns.Tracker and ns.Tracker.UpdateTypography then ns.Tracker:UpdateTypography() end
        end,
        "Select the font outline rendering style for objective lines."
    )
    table.insert(syncList, ui.ddObjOutline)

    ui.slHeaderSize = CreateStyledSlider(content, "BFQ_SlHdrSize", "Header Font Size:",
        "Font size for quest title headers in the tracker (9 - 20 pt).",
        9, 20, 1,
        function() return fontDb.headerSize or 13 end,
        function(v) fontDb.headerSize = v end,
        "%d pt"
    )
    table.insert(syncList, ui.slHeaderSize)

    ui.slObjSize = CreateStyledSlider(content, "BFQ_SlObjSize", "Objective Font Size:",
        "Font size for objective lines and progress counters (8 - 18 pt).",
        8, 18, 1,
        function() return fontDb.objectiveSize or 11 end,
        function(v) fontDb.objectiveSize = v end,
        "%d pt"
    )
    table.insert(syncList, ui.slObjSize)

    ui.slZoneSize = CreateStyledSlider(content, "BFQ_SlZoneSize", "Zone Header Font Size:",
        "Font size for collapsible zone title headers (9 - 18 pt).",
        9, 18, 1,
        function() return fontDb.zoneHeaderSize or 12 end,
        function(v) fontDb.zoneHeaderSize = v end,
        "%d pt"
    )
    table.insert(syncList, ui.slZoneSize)

    ui.cbShadow = CreateStyledCheckbox(content, "Enable Text Dropshadows",
        "Adds crisp dropshadows behind all tracker text for maximum readability.",
        function() return fontDb.enableTextShadow ~= false end,
        function(v) fontDb.enableTextShadow = v end
    )
    table.insert(syncList, ui.cbShadow)

    ui.slMenuScale = CreateStyledSlider(content, "BFQ_SlMenuScale", "Menu & Dropdown Scale:",
        "Adjust display scale of the right-click quest menu and header Tracker Options quick menu (80% - 160%).",
        0.8, 1.6, 0.05,
        function() return fontDb.menuScale or 1.0 end,
        function(v)
            fontDb.menuScale = v
            if quickMenuPopup then
                quickMenuPopup:SetScale(v)
            end
            if DropDownList1 and DropDownList1:IsShown() then
                DropDownList1:SetScale(v)
            end
        end,
        "%.2f"
    )
    table.insert(syncList, ui.slMenuScale)

    ui.btnResetQuestColors = CreateStyledButton(content, "Reset Quest & Obj Defaults", 190, 22, function()
        if fontDb then
            fontDb.colorDifficulty = true
            fontDb.titleColor = { r = 1.00, g = 0.82, b = 0.00 }
            fontDb.objectiveColor = { r = 0.80, g = 0.80, b = 0.80 }
            fontDb.completedObjectiveColor = { r = 0.00, g = 1.00, b = 0.00 }
            fontDb.headerSize = 13
            fontDb.objectiveSize = 11
            fontDb.zoneHeaderSize = 12
            fontDb.headerOutline = "OUTLINE"
            fontDb.objectiveOutline = ""
            fontDb.enableTextShadow = true
            fontDb.menuScale = 1.0
            fontDb.completedQuestBg = true
            fontDb.completedQuestBgColor = { r = 0.00, g = 0.80, b = 0.20, a = 0.14 }
            fontDb.completedTitleColorMode = "difficulty"
            fontDb.completedTitleCustomColor = { r = 0.00, g = 1.00, b = 0.00 }
            fontDb.questHoverColor = { r = 1.00, g = 1.00, b = 1.00, a = 0.08 }
            fontDb.zoneHoverColor = { r = 1.00, g = 0.82, b = 0.00, a = 0.12 }
        end
        if quickMenuPopup then quickMenuPopup:SetScale(1.0) end
        if ns.StandaloneTracker and ns.StandaloneTracker.ApplyHighlightColors then ns.StandaloneTracker:ApplyHighlightColors() end
        if ns.StandaloneTracker and ns.StandaloneTracker.UpdateTracker then ns.StandaloneTracker:UpdateTracker() end
        if ns.Tracker and ns.Tracker.UpdateTypography then ns.Tracker:UpdateTypography() end
        for _, w in ipairs(syncList) do if w.Sync then w.Sync() end end
        ns.Notify(L["Quest and objective text colors & typography reset to defaults."])
    end, "Reset quest title, objective, completed colors, and font sizes back to defaults.")

    -- SECTION 3: HEADER & ZONE BAR COLORS
    ui.h2, ui.d2 = CreateSectionHeader(content, "HEADER & ZONE BAR COLORS", 12, 0)

    ui.cpHeaderText = CreateStyledColorPickerWithHex(content, "Header Text", 190, 22,
        function()
            local c = headerDb.textColor or (ns.GetClassColor and ns.GetClassColor()) or { r = 0.0, g = 0.75, b = 1.0 }
            return c.r, c.g, c.b, 1.0
        end,
        function(r, g, b)
            headerDb.textColor = { r = r, g = g, b = b }
        end,
        "Choose a custom color or #RRGGBB Hex code for the main 'Quests (X/Y)' header title text.",
        syncList
    )
    table.insert(syncList, ui.cpHeaderText)

    ui.cpHeaderBar = CreateStyledColorPickerWithHex(content, "Header Bar", 190, 22,
        function()
            local c = headerDb.textureColor or { r = 0.05, g = 0.08, b = 0.12, a = 0.85 }
            return c.r, c.g, c.b, c.a or 0.85
        end,
        function(r, g, b, a)
            local curA = (headerDb.textureColor and headerDb.textureColor.a) or 0.85
            headerDb.textureColor = { r = r, g = g, b = b, a = a or curA }
        end,
        "Choose a custom color or #RRGGBB Hex code for the main header bar background.",
        syncList
    )
    table.insert(syncList, ui.cpHeaderBar)

    ui.cpHeaderBtns = CreateStyledColorPickerWithHex(content, "Header Buttons", 190, 22,
        function()
            local c = headerDb.buttonColor or (ns.GetClassColor and ns.GetClassColor()) or { r = 1.0, g = 0.82, b = 0.0 }
            return c.r, c.g, c.b, 1.0
        end,
        function(r, g, b)
            headerDb.buttonColor = { r = r, g = g, b = b }
        end,
        "Choose a custom color or #RRGGBB Hex code for header bar buttons ([Log], [Zone], [All], gear icon, collapse).",
        syncList
    )
    table.insert(syncList, ui.cpHeaderBtns)

    ui.cpZoneText = CreateStyledColorPickerWithHex(content, "Zone Text", 190, 22,
        function()
            local c = headerDb.zoneTextColor or headerDb.zoneHeaderColor or { r = 1.0, g = 0.82, b = 0.0, a = 1.0 }
            return c.r, c.g, c.b, 1.0
        end,
        function(r, g, b)
            headerDb.zoneTextColor = { r = r, g = g, b = b, a = 1.0 }
        end,
        "Choose a custom color or #RRGGBB Hex code for collapsible zone header titles (e.g. 'Westfall (3)').",
        syncList
    )
    table.insert(syncList, ui.cpZoneText)

    ui.cpZoneBar = CreateStyledColorPickerWithHex(content, "Zone Bar", 190, 22,
        function()
            local c = headerDb.zoneHeaderColor or { r = 1.0, g = 0.82, b = 0.0, a = 1.0 }
            return c.r, c.g, c.b, c.a or 1.0
        end,
        function(r, g, b, a)
            local curA = (headerDb.zoneHeaderColor and headerDb.zoneHeaderColor.a) or 1.0
            headerDb.zoneHeaderColor = { r = r, g = g, b = b, a = a or curA }
        end,
        "Choose a custom color or #RRGGBB Hex code for collapsible zone header bar backgrounds.",
        syncList
    )
    table.insert(syncList, ui.cpZoneBar)

    ui.cbZoneShareBorder = CreateStyledCheckbox(content, "Match Zone Header Color to Border",
        "Automatically synchronizes zone header bar and text colors with your tracker border color.",
        function() return headerDb.zoneHeaderColorShare == true end,
        function(v) headerDb.zoneHeaderColorShare = v end
    )
    table.insert(syncList, ui.cbZoneShareBorder)

    ui.btnResetHeaderColors = CreateStyledButton(content, "Reset Header & Zone Defaults", 190, 22, function()
        if db.headers then
            db.headers.textColor = nil
            db.headers.textureColor = { r = 0.05, g = 0.08, b = 0.12, a = 0.85 }
            db.headers.buttonColor = nil
            db.headers.zoneTextColor = { r = 1.0, g = 0.82, b = 0.0, a = 1.0 }
            db.headers.zoneHeaderColor = { r = 1.0, g = 0.82, b = 0.0, a = 1.0 }
            db.headers.zoneHeaderColorShare = false
        end
        if ns.Tracker and ns.Tracker.UpdateSettings then ns.Tracker:UpdateSettings() end
        if ns.StandaloneTracker and ns.StandaloneTracker.UpdateTracker then ns.StandaloneTracker:UpdateTracker() end
        for _, w in ipairs(syncList) do if w.Sync then w.Sync() end end
        ns.Notify(L["Main header and zone header colors reset to defaults."])
    end, "Reset main header and zone header colors back to defaults.")

    -- SECTION 4: WAYFINDER NAVIGATION COLORS & FONTS
    ui.h3, ui.d3 = CreateSectionHeader(content, "WAYFINDER NAVIGATION COLORS & FONTS", 12, 0)

    ui.cpWfAhead = CreateStyledColorPickerWithHex(content, "Arrow Ahead", 190, 22,
        function()
            local c = wfDb.arrowAheadColor or { r = 0.10, g = 1.00, b = 0.20, a = 1.0 }
            return c.r, c.g, c.b, 1.0
        end,
        function(r, g, b)
            wfDb.arrowAheadColor = { r = r, g = g, b = b, a = 1.0 }
        end,
        "Color of the Wayfinder arrow when facing directly toward your destination (default: green #1AFF33).",
        syncList
    )
    table.insert(syncList, ui.cpWfAhead)

    ui.cpWfAngle = CreateStyledColorPickerWithHex(content, "Arrow Angled", 190, 22,
        function()
            local c = wfDb.arrowAngleColor or { r = 1.00, g = 0.85, b = 0.10, a = 1.0 }
            return c.r, c.g, c.b, 1.0
        end,
        function(r, g, b)
            wfDb.arrowAngleColor = { r = r, g = g, b = b, a = 1.0 }
        end,
        "Color of the Wayfinder arrow when facing sideways / off-course (default: amber #FFD91A).",
        syncList
    )
    table.insert(syncList, ui.cpWfAngle)

    ui.cpWfBehind = CreateStyledColorPickerWithHex(content, "Arrow Behind", 190, 22,
        function()
            local c = wfDb.arrowBehindColor or { r = 1.00, g = 0.25, b = 0.25, a = 1.0 }
            return c.r, c.g, c.b, 1.0
        end,
        function(r, g, b)
            wfDb.arrowBehindColor = { r = r, g = g, b = b, a = 1.0 }
        end,
        "Color of the Wayfinder arrow when facing away from your destination (default: red #FF4040).",
        syncList
    )
    table.insert(syncList, ui.cpWfBehind)

    ui.cpWfArrived = CreateStyledColorPickerWithHex(content, "Arrow Arrived", 190, 22,
        function()
            local c = wfDb.arrowArrivedColor or { r = 0.10, g = 1.00, b = 0.20, a = 1.0 }
            return c.r, c.g, c.b, 1.0
        end,
        function(r, g, b)
            wfDb.arrowArrivedColor = { r = r, g = g, b = b, a = 1.0 }
        end,
        "Color of the Wayfinder arrow and 'Arrived!' text when destination range is reached (default: #1AFF33).",
        syncList
    )
    table.insert(syncList, ui.cpWfArrived)

    ui.cpWfDest = CreateStyledColorPickerWithHex(content, "Destination Text", 190, 22,
        function()
            local c = wfDb.destTextColor or { r = 1.00, g = 0.82, b = 0.00, a = 1.0 }
            return c.r, c.g, c.b, 1.0
        end,
        function(r, g, b)
            wfDb.destTextColor = { r = r, g = g, b = b, a = 1.0 }
        end,
        "Color of the HUD destination title text above the distance readout (default: gold #FFD100).",
        syncList
    )
    table.insert(syncList, ui.cpWfDest)

    ui.cpWfDist = CreateStyledColorPickerWithHex(content, "Distance Text", 190, 22,
        function()
            local c = wfDb.distTextColor or { r = 1.00, g = 1.00, b = 1.00, a = 1.0 }
            return c.r, c.g, c.b, 1.0
        end,
        function(r, g, b)
            wfDb.distTextColor = { r = r, g = g, b = b, a = 1.0 }
        end,
        "Color of the HUD distance readout numbers and units below the arrow (default: white #FFFFFF).",
        syncList
    )
    table.insert(syncList, ui.cpWfDist)

    ui.slWfDistSize = CreateStyledSlider(content, "BFQ_SlWfDistSize", "HUD Distance Font Size:",
        "Font size for the distance text below the floating HUD arrow (8 - 18 pt).",
        8, 18, 1,
        function() return wfDb.hudFontSize or 11 end,
        function(v)
            wfDb.hudFontSize = v
            if ns.WayfinderModule and ns.WayfinderModule.ApplyHUDSettings then ns.WayfinderModule:ApplyHUDSettings() end
        end,
        "%d pt"
    )
    table.insert(syncList, ui.slWfDistSize)

    ui.slWfTitleSize = CreateStyledSlider(content, "BFQ_SlWfTitleSize", "HUD Destination Font Size:",
        "Font size for the destination title text above the floating HUD arrow (8 - 18 pt).",
        8, 18, 1,
        function() return wfDb.hudTitleFontSize or 11 end,
        function(v)
            wfDb.hudTitleFontSize = v
            if ns.WayfinderModule and ns.WayfinderModule.ApplyHUDSettings then ns.WayfinderModule:ApplyHUDSettings() end
        end,
        "%d pt"
    )
    table.insert(syncList, ui.slWfTitleSize)

    ui.btnResetWfColors = CreateStyledButton(content, "Reset Wayfinder Defaults", 190, 22, function()
        if wfDb then
            wfDb.arrowAheadColor = { r = 0.10, g = 1.00, b = 0.20, a = 1.0 }
            wfDb.arrowAngleColor = { r = 1.00, g = 0.85, b = 0.10, a = 1.0 }
            wfDb.arrowBehindColor = { r = 1.00, g = 0.25, b = 0.25, a = 1.0 }
            wfDb.arrowArrivedColor = { r = 0.10, g = 1.00, b = 0.20, a = 1.0 }
            wfDb.destTextColor = { r = 1.00, g = 0.82, b = 0.00, a = 1.0 }
            wfDb.distTextColor = { r = 1.00, g = 1.00, b = 1.00, a = 1.0 }
            wfDb.hudFontSize = 11
            wfDb.hudTitleFontSize = 11
        end
        if ns.WayfinderModule and ns.WayfinderModule.ApplyHUDSettings then ns.WayfinderModule:ApplyHUDSettings() end
        if ns.WayfinderModule and ns.WayfinderModule.ForceImmediateUpdate then ns.WayfinderModule:ForceImmediateUpdate() end
        for _, w in ipairs(syncList) do if w.Sync then w.Sync() end end
        ns.Notify(L["Wayfinder arrow colors, text colors, and font sizes reset to defaults."])
    end, "Reset Wayfinder navigation arrow colors, destination text color, and distance text color back to defaults.")

    -- SECTION 5: DATABARS COLORS & FONTS
    ui.h4, ui.d4 = CreateSectionHeader(content, "DATABARS COLORS & FONTS", 12, 0)

    ui.cpXPColor = CreateStyledColorPickerWithHex(content, "XP Bar Normal", 190, 22,
        function()
            local c = dataDb.xpColor or { r = 0.58, g = 0.00, b = 0.83, a = 1.00 }
            return c.r, c.g, c.b, 1.0
        end,
        function(r, g, b)
            dataDb.xpColor = { r = r, g = g, b = b, a = 1.00 }
        end,
        "Color of standard player experience progress on the XP DataBar (default: purple #9400D3).",
        syncList
    )
    table.insert(syncList, ui.cpXPColor)

    ui.cpRestedColor = CreateStyledColorPickerWithHex(content, "Rested XP Bonus", 190, 22,
        function()
            local c = dataDb.restedColor or { r = 0.00, g = 0.44, b = 0.88, a = 1.00 }
            return c.r, c.g, c.b, 1.0
        end,
        function(r, g, b)
            dataDb.restedColor = { r = r, g = g, b = b, a = 1.00 }
        end,
        "Color of the rested experience bonus pool segment (default: blue #0070DE).",
        syncList
    )
    table.insert(syncList, ui.cpRestedColor)

    ui.cpQuestXPColor = CreateStyledColorPickerWithHex(content, "Turn-in Quest XP", 190, 22,
        function()
            local c = dataDb.questXPColor or { r = 0.25, g = 0.85, b = 0.45, a = 0.65 }
            return c.r, c.g, c.b, 1.0
        end,
        function(r, g, b)
            dataDb.questXPColor = { r = r, g = g, b = b, a = 0.65 }
        end,
        "Color of the completed quest turn-in XP overlay ghost bar (default: ghost green #40D973).",
        syncList
    )
    table.insert(syncList, ui.cpQuestXPColor)

    ui.cpDingReadyColor = CreateStyledColorPickerWithHex(content, "Ding Ready Alert", 190, 22,
        function()
            local c = dataDb.dingReadyColor or { r = 1.00, g = 0.82, b = 0.00, a = 1.00 }
            return c.r, c.g, c.b, 1.0
        end,
        function(r, g, b)
            dataDb.dingReadyColor = { r = r, g = g, b = b, a = 1.00 }
        end,
        "Color of the glowing [Ding Ready!] level-up notification on the XP Bar (default: gold #FFD100).",
        syncList
    )
    table.insert(syncList, ui.cpDingReadyColor)

    ui.cpLocTextColor = CreateStyledColorPickerWithHex(content, "Location Text", 190, 22,
        function()
            local c = dataDb.locTextColor or { r = 1.00, g = 0.82, b = 0.00, a = 1.00 }
            return c.r, c.g, c.b, 1.0
        end,
        function(r, g, b)
            dataDb.locTextColor = { r = r, g = g, b = b, a = 1.00 }
        end,
        "Custom text color for zone and subzone names on the Location Bar (when PvP territory coloring is bypassed).",
        syncList
    )
    table.insert(syncList, ui.cpLocTextColor)

    ui.cpCoordsColor = CreateStyledColorPickerWithHex(content, "Coordinates Text", 190, 22,
        function()
            local c = dataDb.coordsColor or { r = 1.00, g = 1.00, b = 1.00, a = 1.00 }
            return c.r, c.g, c.b, 1.0
        end,
        function(r, g, b)
            dataDb.coordsColor = { r = r, g = g, b = b, a = 1.00 }
        end,
        "Color of player map coordinates readout (XX.X, YY.Y) on the Location Bar (default: white #FFFFFF).",
        syncList
    )
    table.insert(syncList, ui.cpCoordsColor)

    ui.cpTimerColor = CreateStyledColorPickerWithHex(content, "Quest Timer Bar", 190, 22,
        function()
            local c = dataDb.timerColor or { r = 1.00, g = 0.82, b = 0.00, a = 1.00 }
            return c.r, c.g, c.b, 1.0
        end,
        function(r, g, b)
            dataDb.timerColor = { r = r, g = g, b = b, a = 1.00 }
        end,
        "Statusbar fill and border color for the timed quest countdown bar (default: gold #FFD100).",
        syncList
    )
    table.insert(syncList, ui.cpTimerColor)

    ui.cbLocCustomColor = CreateStyledCheckbox(content, "Override Territory With Custom Location Color",
        "When checked, uses your custom Location Text color instead of automatic PvP territory coloring.",
        function() return dataDb.locCustomTextColor == true end,
        function(v)
            dataDb.locCustomTextColor = v
            if ns.DataBarsModule and ns.DataBarsModule.RefreshBars then ns.DataBarsModule:RefreshBars() end
        end
    )
    table.insert(syncList, ui.cbLocCustomColor)

    ui.btnResetDataBarsColors = CreateStyledButton(content, "Reset DataBars Defaults", 190, 22, function()
        if dataDb then
            dataDb.xpBgColor = { r = 0.05, g = 0.05, b = 0.05, a = 0.65 }
            dataDb.xpColor = { r = 0.58, g = 0.00, b = 0.83, a = 1.00 }
            dataDb.restedColor = { r = 0.00, g = 0.44, b = 0.88, a = 1.00 }
            dataDb.questXPColor = { r = 0.25, g = 0.85, b = 0.45, a = 0.65 }
            dataDb.allQuestXPColor = { r = 0.12, g = 0.45, b = 0.25, a = 0.80 }
            dataDb.dingReadyColor = { r = 1.00, g = 0.82, b = 0.00, a = 1.00 }
            dataDb.locTextColor = { r = 1.00, g = 0.82, b = 0.00, a = 1.00 }
            dataDb.locCustomTextColor = false
            dataDb.coordsColor = { r = 1.00, g = 1.00, b = 1.00, a = 1.00 }
            dataDb.timerColor = { r = 1.00, g = 0.82, b = 0.00, a = 1.00 }
        end
        if ns.DataBarsModule and ns.DataBarsModule.RefreshBars then ns.DataBarsModule:RefreshBars() end
        for _, w in ipairs(syncList) do if w.Sync then w.Sync() end end
        ns.Notify(L["DataBars colors reset to defaults."])
    end, "Reset XP Bar, Location Bar, coordinates, and Timer Bar colors back to defaults.")

    -- SECTION 6: THEME PRESETS & MASTER RESET
    ui.h5, ui.d5 = CreateSectionHeader(content, "THEME PRESETS & MASTER RESET", 12, 0)

    ui.btnPresetGlass = CreateStyledButton(content, "Modern Dark Glass", 190, 22, function()
        if Config.ApplyModernGlassPreset then Config:ApplyModernGlassPreset() end
        ns.Notify(L["Applied Modern Dark Glass preset."])
        for _, w in ipairs(syncList) do if w.Sync then w.Sync() end end
    end, "Modern dark glassmorphism preset with sleek flat 1px border and crisp white text.")

    ui.btnPresetClassic = CreateStyledButton(content, "Classic WoW Plus", 190, 22, function()
        if Config.ApplyClassicPreset then Config:ApplyClassicPreset() end
        ns.Notify(L["Applied Classic WoW Plus preset."])
        for _, w in ipairs(syncList) do if w.Sync then w.Sync() end end
    end, "Classic World of Warcraft parchment tooltip border with gold headers and high contrast.")

    ui.btnPresetMinimal = CreateStyledButton(content, "Ultra Minimalist", 190, 22, function()
        if Config.ApplyMinimalPreset then Config:ApplyMinimalPreset() end
        ns.Notify(L["Applied Ultra Minimalist preset."])
        for _, w in ipairs(syncList) do if w.Sync then w.Sync() end end
    end, "Borderless flat backdrop with compact typography for maximum screen space.")

    ui.btnResetAllColors = CreateStyledButton(content, "Reset All Colors to Defaults", 190, 22, function()
        -- Reset Backdrop
        if bgDb then
            bgDb.bgColor = { r = 0.05, g = 0.05, b = 0.05, a = 0.65 }
            bgDb.borderColor = { r = 0.15, g = 0.15, b = 0.15, a = 0.90 }
            bgDb.borderStyle = "flat"
            bgDb.classColorBorder = false
        end
        -- Reset Quests & Typography
        if fontDb then
            fontDb.colorDifficulty = true
            fontDb.titleColor = { r = 1.00, g = 0.82, b = 0.00 }
            fontDb.objectiveColor = { r = 0.80, g = 0.80, b = 0.80 }
            fontDb.completedObjectiveColor = { r = 0.00, g = 1.00, b = 0.00 }
        end
        -- Reset Headers
        if headerDb then
            headerDb.textColor = nil
            headerDb.textureColor = { r = 0.05, g = 0.08, b = 0.12, a = 0.85 }
            headerDb.buttonColor = nil
            headerDb.zoneTextColor = { r = 1.0, g = 0.82, b = 0.0, a = 1.0 }
            headerDb.zoneHeaderColor = { r = 1.0, g = 0.82, b = 0.0, a = 1.0 }
            headerDb.zoneHeaderColorShare = false
        end
        -- Reset Wayfinder
        if wfDb then
            wfDb.arrowAheadColor = { r = 0.10, g = 1.00, b = 0.20, a = 1.0 }
            wfDb.arrowAngleColor = { r = 1.00, g = 0.85, b = 0.10, a = 1.0 }
            wfDb.arrowBehindColor = { r = 1.00, g = 0.25, b = 0.25, a = 1.0 }
            wfDb.arrowArrivedColor = { r = 0.10, g = 1.00, b = 0.20, a = 1.0 }
            wfDb.destTextColor = { r = 1.00, g = 0.82, b = 0.00, a = 1.0 }
            wfDb.distTextColor = { r = 1.00, g = 1.00, b = 1.00, a = 1.0 }
        end
        -- Reset DataBars
        if dataDb then
            dataDb.xpBgColor = { r = 0.05, g = 0.05, b = 0.05, a = 0.65 }
            dataDb.xpColor = { r = 0.58, g = 0.00, b = 0.83, a = 1.00 }
            dataDb.restedColor = { r = 0.00, g = 0.44, b = 0.88, a = 1.00 }
            dataDb.questXPColor = { r = 0.25, g = 0.85, b = 0.45, a = 0.65 }
            dataDb.allQuestXPColor = { r = 0.12, g = 0.45, b = 0.25, a = 0.80 }
            dataDb.dingReadyColor = { r = 1.00, g = 0.82, b = 0.00, a = 1.00 }
            dataDb.locTextColor = { r = 1.00, g = 0.82, b = 0.00, a = 1.00 }
            dataDb.locCustomTextColor = false
            dataDb.coordsColor = { r = 1.00, g = 1.00, b = 1.00, a = 1.00 }
            dataDb.timerColor = { r = 1.00, g = 0.82, b = 0.00, a = 1.00 }
        end

        if ns.Tracker and ns.Tracker.UpdateBackdrop then ns.Tracker:UpdateBackdrop() end
        if ns.Tracker and ns.Tracker.UpdateSettings then ns.Tracker:UpdateSettings() end
        if ns.StandaloneTracker and ns.StandaloneTracker.UpdateTracker then ns.StandaloneTracker:UpdateTracker() end
        if ns.WayfinderModule and ns.WayfinderModule.ApplyHUDSettings then ns.WayfinderModule:ApplyHUDSettings() end
        if ns.WayfinderModule and ns.WayfinderModule.ForceImmediateUpdate then ns.WayfinderModule:ForceImmediateUpdate() end
        if ns.DataBarsModule and ns.DataBarsModule.RefreshBars then ns.DataBarsModule:RefreshBars() end
        for _, w in ipairs(syncList) do if w.Sync then w.Sync() end end
        ns.Notify(L["All tracker, header, Wayfinder, and DataBars colors have been reset to defaults."])
    end, "Resets ALL colors across the entire addon (Tracker Backdrop, Quests, Headers, Wayfinder arrow, DataBars) back to default settings.")

    local function Layout(w)
        if not w or w < 100 then w = content:GetWidth() or 500 end
        local y = -10

        -- SECTION 1: TRACKER BACKDROP & BORDER
        ui.h1:SetPoint("TOPLEFT", content, "TOPLEFT", 12, y)
        y = y - 30

        if w >= 470 then
            local colWidth = math.floor((w - 48) / 2)
            local col1X = 16
            local col2X = col1X + colWidth + 16

            ui.btnBgTexture:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            ui.btnBgTexture:SetWidth(math.min(190, colWidth - 20))
            ui.btnBorder:SetPoint("TOPLEFT", content, "TOPLEFT", col2X, y)
            ui.btnBorder:SetWidth(math.min(190, colWidth - 20))
            y = y - 36

            ui.cpBgColor:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            ui.cpBgColor:SetWidth(math.min(190, colWidth - 20))
            ui.cpBorderColor:SetPoint("TOPLEFT", content, "TOPLEFT", col2X, y)
            ui.cpBorderColor:SetWidth(math.min(190, colWidth - 20))
            y = y - 36

            ui.slBgAlpha:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            ui.slBgAlpha:SetWidth(math.min(190, colWidth - 20))
            ui.slBorderAlpha:SetPoint("TOPLEFT", content, "TOPLEFT", col2X, y)
            ui.slBorderAlpha:SetWidth(math.min(190, colWidth - 20))
            y = y - 48

            ui.btnPureBlack:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            ui.btnPureBlack:SetWidth(math.min(190, colWidth - 20))
            ui.cbClassBorder:SetPoint("TOPLEFT", content, "TOPLEFT", col2X, y)
            ui.cbClassBorder.Text:SetWidth(colWidth - 32)
            y = y - 36

            ui.btnResetBackdrop:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            ui.btnResetBackdrop:SetWidth(math.min(190, colWidth - 20))
            y = y - 44

            -- SECTION 2: QUEST & OBJECTIVE TYPOGRAPHY & COLORS
            ui.h1b:SetPoint("TOPLEFT", content, "TOPLEFT", 12, y)
            y = y - 30

            ui.cbColorDiff:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            ui.cbColorDiff.Text:SetWidth(colWidth - 32)
            ui.cpTitleColor:SetPoint("TOPLEFT", content, "TOPLEFT", col2X, y)
            ui.cpTitleColor:SetWidth(math.min(190, colWidth - 20))
            y = y - 36

            ui.cpObjColor:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            ui.cpObjColor:SetWidth(math.min(190, colWidth - 20))
            ui.cpCompColor:SetPoint("TOPLEFT", content, "TOPLEFT", col2X, y)
            ui.cpCompColor:SetWidth(math.min(190, colWidth - 20))
            y = y - 40

            ui.cbCompletedBg:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            ui.cbCompletedBg.Text:SetWidth(colWidth - 32)
            ui.cpCompletedBgColor:SetPoint("TOPLEFT", content, "TOPLEFT", col2X, y)
            ui.cpCompletedBgColor:SetWidth(math.min(190, colWidth - 20))
            y = y - 36

            ui.ddCompletedTitleMode:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            ui.ddCompletedTitleMode:SetWidth(math.min(190, colWidth - 20))
            ui.cpCompletedTitleCustomColor:SetPoint("TOPLEFT", content, "TOPLEFT", col2X, y)
            ui.cpCompletedTitleCustomColor:SetWidth(math.min(190, colWidth - 20))
            y = y - 38

            ui.cpQuestHoverColor:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            ui.cpQuestHoverColor:SetWidth(math.min(190, colWidth - 20))
            ui.cpZoneHoverColor:SetPoint("TOPLEFT", content, "TOPLEFT", col2X, y)
            ui.cpZoneHoverColor:SetWidth(math.min(190, colWidth - 20))
            y = y - 40

            ui.ddHeaderFont:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            ui.ddHeaderFont:SetWidth(math.min(190, colWidth - 20))
            ui.ddHeaderOutline:SetPoint("TOPLEFT", content, "TOPLEFT", col2X, y)
            ui.ddHeaderOutline:SetWidth(math.min(190, colWidth - 20))
            y = y - 38

            ui.slHeaderSize:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            ui.slHeaderSize:SetWidth(math.min(190, colWidth - 20))
            ui.slZoneSize:SetPoint("TOPLEFT", content, "TOPLEFT", col2X, y)
            ui.slZoneSize:SetWidth(math.min(190, colWidth - 20))
            y = y - 48

            ui.ddObjFont:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            ui.ddObjFont:SetWidth(math.min(190, colWidth - 20))
            ui.ddObjOutline:SetPoint("TOPLEFT", content, "TOPLEFT", col2X, y)
            ui.ddObjOutline:SetWidth(math.min(190, colWidth - 20))
            y = y - 38

            ui.slObjSize:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            ui.slObjSize:SetWidth(math.min(190, colWidth - 20))
            ui.cbShadow:SetPoint("TOPLEFT", content, "TOPLEFT", col2X, y)
            ui.cbShadow.Text:SetWidth(colWidth - 32)
            y = y - 48

            ui.slMenuScale:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            ui.slMenuScale:SetWidth(math.min(190, colWidth - 20))
            ui.btnResetQuestColors:SetPoint("TOPLEFT", content, "TOPLEFT", col2X, y)
            ui.btnResetQuestColors:SetWidth(math.min(190, colWidth - 20))
            y = y - 44

            -- SECTION 3: HEADER & ZONE BAR COLORS
            ui.h2:SetPoint("TOPLEFT", content, "TOPLEFT", 12, y)
            y = y - 30

            ui.cpHeaderText:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            ui.cpHeaderText:SetWidth(math.min(190, colWidth - 20))
            ui.cpHeaderBar:SetPoint("TOPLEFT", content, "TOPLEFT", col2X, y)
            ui.cpHeaderBar:SetWidth(math.min(190, colWidth - 20))
            y = y - 36

            ui.cpHeaderBtns:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            ui.cpHeaderBtns:SetWidth(math.min(190, colWidth - 20))
            ui.cpZoneText:SetPoint("TOPLEFT", content, "TOPLEFT", col2X, y)
            ui.cpZoneText:SetWidth(math.min(190, colWidth - 20))
            y = y - 36

            ui.cpZoneBar:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            ui.cpZoneBar:SetWidth(math.min(190, colWidth - 20))
            ui.cbZoneShareBorder:SetPoint("TOPLEFT", content, "TOPLEFT", col2X, y)
            ui.cbZoneShareBorder.Text:SetWidth(colWidth - 32)
            y = y - 40

            ui.btnResetHeaderColors:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            ui.btnResetHeaderColors:SetWidth(math.min(190, colWidth - 20))
            y = y - 44

            -- SECTION 4: WAYFINDER NAVIGATION COLORS & FONTS
            ui.h3:SetPoint("TOPLEFT", content, "TOPLEFT", 12, y)
            y = y - 30

            ui.cpWfAhead:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            ui.cpWfAhead:SetWidth(math.min(190, colWidth - 20))
            ui.cpWfAngle:SetPoint("TOPLEFT", content, "TOPLEFT", col2X, y)
            ui.cpWfAngle:SetWidth(math.min(190, colWidth - 20))
            y = y - 36

            ui.cpWfBehind:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            ui.cpWfBehind:SetWidth(math.min(190, colWidth - 20))
            ui.cpWfArrived:SetPoint("TOPLEFT", content, "TOPLEFT", col2X, y)
            ui.cpWfArrived:SetWidth(math.min(190, colWidth - 20))
            y = y - 36

            ui.cpWfDest:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            ui.cpWfDest:SetWidth(math.min(190, colWidth - 20))
            ui.cpWfDist:SetPoint("TOPLEFT", content, "TOPLEFT", col2X, y)
            ui.cpWfDist:SetWidth(math.min(190, colWidth - 20))
            y = y - 40

            ui.slWfDistSize:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            ui.slWfDistSize:SetWidth(math.min(190, colWidth - 20))
            ui.slWfTitleSize:SetPoint("TOPLEFT", content, "TOPLEFT", col2X, y)
            ui.slWfTitleSize:SetWidth(math.min(190, colWidth - 20))
            y = y - 48

            ui.btnResetWfColors:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            ui.btnResetWfColors:SetWidth(math.min(190, colWidth - 20))
            y = y - 44

            -- SECTION 5: DATABARS COLORS & FONTS
            ui.h4:SetPoint("TOPLEFT", content, "TOPLEFT", 12, y)
            y = y - 30

            ui.cpXPColor:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            ui.cpXPColor:SetWidth(math.min(190, colWidth - 20))
            ui.cpRestedColor:SetPoint("TOPLEFT", content, "TOPLEFT", col2X, y)
            ui.cpRestedColor:SetWidth(math.min(190, colWidth - 20))
            y = y - 36

            ui.cpQuestXPColor:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            ui.cpQuestXPColor:SetWidth(math.min(190, colWidth - 20))
            ui.cpDingReadyColor:SetPoint("TOPLEFT", content, "TOPLEFT", col2X, y)
            ui.cpDingReadyColor:SetWidth(math.min(190, colWidth - 20))
            y = y - 36

            ui.cpLocTextColor:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            ui.cpLocTextColor:SetWidth(math.min(190, colWidth - 20))
            ui.cpCoordsColor:SetPoint("TOPLEFT", content, "TOPLEFT", col2X, y)
            ui.cpCoordsColor:SetWidth(math.min(190, colWidth - 20))
            y = y - 36

            ui.cpTimerColor:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            ui.cpTimerColor:SetWidth(math.min(190, colWidth - 20))
            ui.cbLocCustomColor:SetPoint("TOPLEFT", content, "TOPLEFT", col2X, y)
            ui.cbLocCustomColor.Text:SetWidth(colWidth - 32)
            y = y - 40

            ui.btnResetDataBarsColors:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            ui.btnResetDataBarsColors:SetWidth(math.min(190, colWidth - 20))
            y = y - 44

            -- SECTION 6: THEME PRESETS & MASTER RESET
            ui.h5:SetPoint("TOPLEFT", content, "TOPLEFT", 12, y)
            y = y - 30

            ui.btnPresetGlass:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            ui.btnPresetGlass:SetWidth(math.min(190, colWidth - 20))
            ui.btnPresetClassic:SetPoint("TOPLEFT", content, "TOPLEFT", col2X, y)
            ui.btnPresetClassic:SetWidth(math.min(190, colWidth - 20))
            y = y - 36

            ui.btnPresetMinimal:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            ui.btnPresetMinimal:SetWidth(math.min(190, colWidth - 20))
            ui.btnResetAllColors:SetPoint("TOPLEFT", content, "TOPLEFT", col2X, y)
            ui.btnResetAllColors:SetWidth(math.min(190, colWidth - 20))
            y = y - 44
        else
            local colWidth = w - 36
            local col1X = 16

            -- SECTION 1
            ui.btnBgTexture:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            ui.btnBgTexture:SetWidth(math.min(220, colWidth - 20))
            y = y - 36
            ui.btnBorder:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            ui.btnBorder:SetWidth(math.min(220, colWidth - 20))
            y = y - 36
            ui.cpBgColor:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            ui.cpBgColor:SetWidth(math.min(220, colWidth - 20))
            y = y - 36
            ui.cpBorderColor:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            ui.cpBorderColor:SetWidth(math.min(220, colWidth - 20))
            y = y - 36
            ui.btnPureBlack:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            ui.btnPureBlack:SetWidth(math.min(220, colWidth - 20))
            y = y - 36
            ui.slBgAlpha:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            ui.slBgAlpha:SetWidth(math.min(220, colWidth - 20))
            y = y - 46
            ui.slBorderAlpha:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            ui.slBorderAlpha:SetWidth(math.min(220, colWidth - 20))
            y = y - 46
            ui.cbClassBorder:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            ui.cbClassBorder.Text:SetWidth(colWidth - 32)
            y = y - 36
            ui.btnResetBackdrop:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            ui.btnResetBackdrop:SetWidth(math.min(220, colWidth - 20))
            y = y - 44

            -- SECTION 2
            ui.h1b:SetPoint("TOPLEFT", content, "TOPLEFT", 12, y)
            y = y - 30

            ui.cbColorDiff:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            ui.cbColorDiff.Text:SetWidth(colWidth - 32)
            y = y - 34
            ui.cpTitleColor:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            ui.cpTitleColor:SetWidth(math.min(220, colWidth - 20))
            y = y - 34
            ui.cpObjColor:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            ui.cpObjColor:SetWidth(math.min(220, colWidth - 20))
            y = y - 34
            ui.cpCompColor:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            ui.cpCompColor:SetWidth(math.min(220, colWidth - 20))
            y = y - 36

            ui.cbCompletedBg:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            ui.cbCompletedBg.Text:SetWidth(colWidth - 32)
            y = y - 34
            ui.cpCompletedBgColor:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            ui.cpCompletedBgColor:SetWidth(math.min(220, colWidth - 20))
            y = y - 34
            ui.ddCompletedTitleMode:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            ui.ddCompletedTitleMode:SetWidth(math.min(220, colWidth - 20))
            y = y - 38
            ui.cpCompletedTitleCustomColor:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            ui.cpCompletedTitleCustomColor:SetWidth(math.min(220, colWidth - 20))
            y = y - 34
            ui.cpQuestHoverColor:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            ui.cpQuestHoverColor:SetWidth(math.min(220, colWidth - 20))
            y = y - 34
            ui.cpZoneHoverColor:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            ui.cpZoneHoverColor:SetWidth(math.min(220, colWidth - 20))
            y = y - 38

            ui.ddHeaderFont:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            ui.ddHeaderFont:SetWidth(math.min(220, colWidth - 20))
            y = y - 38
            ui.ddHeaderOutline:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            ui.ddHeaderOutline:SetWidth(math.min(220, colWidth - 20))
            y = y - 38
            ui.slHeaderSize:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            ui.slHeaderSize:SetWidth(math.min(220, colWidth - 20))
            y = y - 46
            ui.slZoneSize:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            ui.slZoneSize:SetWidth(math.min(220, colWidth - 20))
            y = y - 46

            ui.ddObjFont:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            ui.ddObjFont:SetWidth(math.min(220, colWidth - 20))
            y = y - 38
            ui.ddObjOutline:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            ui.ddObjOutline:SetWidth(math.min(220, colWidth - 20))
            y = y - 38
            ui.slObjSize:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            ui.slObjSize:SetWidth(math.min(220, colWidth - 20))
            y = y - 46
            ui.slMenuScale:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            ui.slMenuScale:SetWidth(math.min(220, colWidth - 20))
            y = y - 46
            ui.cbShadow:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            ui.cbShadow.Text:SetWidth(colWidth - 32)
            y = y - 38
            ui.btnResetQuestColors:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            ui.btnResetQuestColors:SetWidth(math.min(220, colWidth - 20))
            y = y - 44

            -- SECTION 3
            ui.h2:SetPoint("TOPLEFT", content, "TOPLEFT", 12, y)
            y = y - 30

            ui.cpHeaderText:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            ui.cpHeaderText:SetWidth(math.min(220, colWidth - 20))
            y = y - 34
            ui.cpHeaderBar:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            ui.cpHeaderBar:SetWidth(math.min(220, colWidth - 20))
            y = y - 34
            ui.cpHeaderBtns:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            ui.cpHeaderBtns:SetWidth(math.min(220, colWidth - 20))
            y = y - 34
            ui.cpZoneText:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            ui.cpZoneText:SetWidth(math.min(220, colWidth - 20))
            y = y - 34
            ui.cpZoneBar:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            ui.cpZoneBar:SetWidth(math.min(220, colWidth - 20))
            y = y - 34
            ui.cbZoneShareBorder:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            ui.cbZoneShareBorder.Text:SetWidth(colWidth - 32)
            y = y - 36
            ui.btnResetHeaderColors:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            ui.btnResetHeaderColors:SetWidth(math.min(220, colWidth - 20))
            y = y - 44

            -- SECTION 4
            ui.h3:SetPoint("TOPLEFT", content, "TOPLEFT", 12, y)
            y = y - 30

            ui.cpWfAhead:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            ui.cpWfAhead:SetWidth(math.min(220, colWidth - 20))
            y = y - 34
            ui.cpWfAngle:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            ui.cpWfAngle:SetWidth(math.min(220, colWidth - 20))
            y = y - 34
            ui.cpWfBehind:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            ui.cpWfBehind:SetWidth(math.min(220, colWidth - 20))
            y = y - 34
            ui.cpWfArrived:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            ui.cpWfArrived:SetWidth(math.min(220, colWidth - 20))
            y = y - 34
            ui.cpWfDest:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            ui.cpWfDest:SetWidth(math.min(220, colWidth - 20))
            y = y - 34
            ui.cpWfDist:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            ui.cpWfDist:SetWidth(math.min(220, colWidth - 20))
            y = y - 34
            ui.slWfDistSize:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            ui.slWfDistSize:SetWidth(math.min(220, colWidth - 20))
            y = y - 46
            ui.slWfTitleSize:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            ui.slWfTitleSize:SetWidth(math.min(220, colWidth - 20))
            y = y - 46
            ui.btnResetWfColors:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            ui.btnResetWfColors:SetWidth(math.min(220, colWidth - 20))
            y = y - 44

            -- SECTION 5
            ui.h4:SetPoint("TOPLEFT", content, "TOPLEFT", 12, y)
            y = y - 30

            ui.cpXPColor:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            ui.cpXPColor:SetWidth(math.min(220, colWidth - 20))
            y = y - 34
            ui.cpRestedColor:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            ui.cpRestedColor:SetWidth(math.min(220, colWidth - 20))
            y = y - 34
            ui.cpQuestXPColor:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            ui.cpQuestXPColor:SetWidth(math.min(220, colWidth - 20))
            y = y - 34
            ui.cpDingReadyColor:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            ui.cpDingReadyColor:SetWidth(math.min(220, colWidth - 20))
            y = y - 34
            ui.cpLocTextColor:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            ui.cpLocTextColor:SetWidth(math.min(220, colWidth - 20))
            y = y - 34
            ui.cpCoordsColor:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            ui.cpCoordsColor:SetWidth(math.min(220, colWidth - 20))
            y = y - 34
            ui.cpTimerColor:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            ui.cpTimerColor:SetWidth(math.min(220, colWidth - 20))
            y = y - 34
            ui.cbLocCustomColor:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            ui.cbLocCustomColor.Text:SetWidth(colWidth - 32)
            y = y - 36
            ui.btnResetDataBarsColors:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            ui.btnResetDataBarsColors:SetWidth(math.min(220, colWidth - 20))
            y = y - 44

            -- SECTION 6
            ui.h5:SetPoint("TOPLEFT", content, "TOPLEFT", 12, y)
            y = y - 30

            ui.btnPresetGlass:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            ui.btnPresetGlass:SetWidth(math.min(220, colWidth - 20))
            y = y - 36
            ui.btnPresetClassic:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            ui.btnPresetClassic:SetWidth(math.min(220, colWidth - 20))
            y = y - 36
            ui.btnPresetMinimal:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            ui.btnPresetMinimal:SetWidth(math.min(220, colWidth - 20))
            y = y - 36
            ui.btnResetAllColors:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            ui.btnResetAllColors:SetWidth(math.min(220, colWidth - 20))
            y = y - 44
        end

        content:SetHeight(math.abs(y) + 30)
    end

    content.LayoutTab = Layout
    Layout(content:GetWidth())
end

-- TAB 4: Headers & Sort
local function BuildHeadersTab(content, syncList)
    local db = LiveDB
    local headerDb = LiveSection("headers")
    local sortDb = LiveSection("sorting")

    local h1 = CreateSectionHeader(content, "MAIN HEADER BAR BUTTONS", 12, 0)
    local cbLog = CreateStyledCheckbox(content, "Show [Log] Button",
        "Shows the [Log] button to instantly toggle Blizzard QuestLogFrame.",
        function() return headerDb.showQuestLogBtn ~= false end,
        function(v) headerDb.showQuestLogBtn = v end
    )
    table.insert(syncList, cbLog)

    local cbZone = CreateStyledCheckbox(content, "Show [Zone] Filter Button",
        "Shows the [Zone] button to filter tracker quests strictly to your current zone.",
        function() return headerDb.showZoneBtn ~= false end,
        function(v) headerDb.showZoneBtn = v end
    )
    table.insert(syncList, cbZone)

    local cbAll = CreateStyledCheckbox(content, "Show [All] Show-All Button",
        "Shows the [All] button to display all active quest log entries.",
        function() return headerDb.showAllBtn ~= false end,
        function(v) headerDb.showAllBtn = v end
    )
    table.insert(syncList, cbAll)

    local cbMenu = CreateStyledCheckbox(content, "Show [...] Options Menu Button",
        "Shows the [...] button to open options and quick settings.",
        function() return headerDb.showMenuBtn ~= false end,
        function(v) headerDb.showMenuBtn = v end
    )
    table.insert(syncList, cbMenu)

    local cbCollapse = CreateStyledCheckbox(content, "Show [-] Collapse Button",
        "Shows the [-] button to minimize or expand the tracker body.",
        function() return headerDb.showCollapseBtn ~= false end,
        function(v) headerDb.showCollapseBtn = v end
    )
    table.insert(syncList, cbCollapse)

    local h1b = CreateSectionHeader(content, "HEADER & ZONE STYLING & COLORS", 12, 0)

    local ddHeaderTex = CreateStyledDropdown(content, "Header Bar Style", 190, 22, HEADER_STYLES,
        function() return headerDb.texture or "gradient" end,
        function(v) headerDb.texture = v end,
        "Choose the visual background style for the main top 'Quests' header bar."
    )
    table.insert(syncList, ddHeaderTex)

    local ddZoneTex = CreateStyledDropdown(content, "Zone Bar Style", 190, 22, HEADER_STYLES,
        function() return headerDb.zoneHeaderTexture or "gradient" end,
        function(v) headerDb.zoneHeaderTexture = v end,
        "Choose the visual background style for collapsible zone category header bars."
    )
    table.insert(syncList, ddZoneTex)

    local cpHeaderText = CreateStyledColorPickerWithHex(content, "Header Text", 190, 22,
        function()
            local c = headerDb.textColor or (ns.GetClassColor and ns.GetClassColor()) or { r = 1.0, g = 0.82, b = 0.0 }
            return c.r, c.g, c.b, 1.0
        end,
        function(r, g, b)
            headerDb.textColor = { r = r, g = g, b = b }
        end,
        "Choose a custom color or #RRGGBB Hex code for the main header title text (default: Gold).",
        syncList
    )
    table.insert(syncList, cpHeaderText)

    local cpHeaderBar = CreateStyledColorPickerWithHex(content, "Header Bar", 190, 22,
        function()
            local c = headerDb.textureColor or { r = 0.05, g = 0.08, b = 0.12, a = 0.85 }
            return c.r, c.g, c.b, c.a or 0.85
        end,
        function(r, g, b, a)
            local curA = (headerDb.textureColor and headerDb.textureColor.a) or 0.85
            headerDb.textureColor = { r = r, g = g, b = b, a = a or curA }
        end,
        "Choose a custom color or #RRGGBB Hex code for the main header bar background.",
        syncList
    )
    table.insert(syncList, cpHeaderBar)

    local cpHeaderBtns = CreateStyledColorPickerWithHex(content, "Header Buttons", 190, 22,
        function()
            local c = headerDb.buttonColor or (ns.GetClassColor and ns.GetClassColor()) or { r = 1.0, g = 0.82, b = 0.0 }
            return c.r, c.g, c.b, 1.0
        end,
        function(r, g, b)
            headerDb.buttonColor = { r = r, g = g, b = b }
        end,
        "Choose a custom color or #RRGGBB Hex code for header bar buttons ([Log], [Zone], [All], gear icon, collapse).",
        syncList
    )
    table.insert(syncList, cpHeaderBtns)

    local cpZoneText = CreateStyledColorPickerWithHex(content, "Zone Text", 190, 22,
        function()
            local c = headerDb.zoneTextColor or headerDb.zoneHeaderColor or { r = 1.0, g = 0.82, b = 0.0, a = 1.0 }
            return c.r, c.g, c.b, 1.0
        end,
        function(r, g, b)
            headerDb.zoneTextColor = { r = r, g = g, b = b, a = 1.0 }
        end,
        "Choose a custom color or #RRGGBB Hex code for collapsible zone header titles (e.g. 'Westfall (3)').",
        syncList
    )
    table.insert(syncList, cpZoneText)

    local cpZoneBar = CreateStyledColorPickerWithHex(content, "Zone Bar", 190, 22,
        function()
            local c = headerDb.zoneHeaderColor or { r = 1.0, g = 0.82, b = 0.0, a = 1.0 }
            return c.r, c.g, c.b, c.a or 1.0
        end,
        function(r, g, b, a)
            local curA = (headerDb.zoneHeaderColor and headerDb.zoneHeaderColor.a) or 1.0
            headerDb.zoneHeaderColor = { r = r, g = g, b = b, a = a or curA }
        end,
        "Choose a custom color or #RRGGBB Hex code for collapsible zone header bar backgrounds.",
        syncList
    )
    table.insert(syncList, cpZoneBar)

    local cbZoneShareBorder = CreateStyledCheckbox(content, "Match Zone Header Color to Border",
        "Automatically synchronizes zone header bar and text colors with your tracker border color.",
        function() return headerDb.zoneHeaderColorShare == true end,
        function(v) headerDb.zoneHeaderColorShare = v end
    )
    table.insert(syncList, cbZoneShareBorder)

    local btnResetHeaderColors = CreateStyledButton(content, "Reset Header & Zone Defaults", 190, 22, function()
        if db.headers then
            db.headers.textColor = nil
            db.headers.textureColor = { r = 0.05, g = 0.08, b = 0.12, a = 0.85 }
            db.headers.buttonColor = nil
            db.headers.zoneTextColor = { r = 1.0, g = 0.82, b = 0.0, a = 1.0 }
            db.headers.zoneHeaderColor = { r = 1.0, g = 0.82, b = 0.0, a = 1.0 }
            db.headers.zoneHeaderColorShare = false
            db.headers.zoneCollapseIcon = "arrow"
            db.headers.zoneCollapseIconColor = nil
            if db.sorting then db.sorting.alignQuestTitles = true end
        end
        if ns.Tracker and ns.Tracker.UpdateSettings then ns.Tracker:UpdateSettings() end
        if ns.StandaloneTracker and ns.StandaloneTracker.UpdateTracker then ns.StandaloneTracker:UpdateTracker() end
        for _, w in ipairs(syncList) do if w.Sync then w.Sync() end end
        ns.Notify(L["Main header and zone header colors reset to defaults."])
    end, "Reset main header and zone header colors back to defaults.")

    local h2 = CreateSectionHeader(content, "ZONE GROUPING & SORTING", 12, 0)
    local cbZoneHeaders = CreateStyledCheckbox(content, "Group Quests Under Zone Headers",
        "Groups quests into collapsible zone header categories.",
        function() return headerDb.showZoneHeaders ~= false end,
        function(v) headerDb.showZoneHeaders = v end
    )
    table.insert(syncList, cbZoneHeaders)

    local cbZoneCount = CreateStyledCheckbox(content, "Show Zone Quest Counts",
        "Displays the active quest count next to each zone name (e.g. Westfall (3)).",
        function() return headerDb.showZoneCount ~= false end,
        function(v) headerDb.showZoneCount = v end
    )
    table.insert(syncList, cbZoneCount)

    local ddCollapseShape = CreateStyledDropdown(content, "Collapse Indicator", 190, 22, ZONE_COLLAPSE_ICONS,
        function() return headerDb.zoneCollapseIcon or "arrow" end,
        function(v)
            headerDb.zoneCollapseIcon = v
            if ns.StandaloneTracker and ns.StandaloneTracker.UpdateTracker then ns.StandaloneTracker:UpdateTracker() end
        end,
        "Choose the symbol next to zone names (Triangle/Arrow, Plus/Minus, or None)."
    )
    table.insert(syncList, ddCollapseShape)

    local cpCollapseColor = CreateStyledColorPickerWithHex(content, "Indicator Color", 190, 22,
        function()
            local c = headerDb.zoneCollapseIconColor or headerDb.zoneTextColor or headerDb.zoneHeaderColor or { r = 1.0, g = 0.82, b = 0.0, a = 1.0 }
            return c.r, c.g, c.b, c.a or 1.0
        end,
        function(r, g, b, a)
            local curA = (headerDb.zoneCollapseIconColor and headerDb.zoneCollapseIconColor.a) or 1.0
            headerDb.zoneCollapseIconColor = { r = r, g = g, b = b, a = a or curA }
            if ns.StandaloneTracker and ns.StandaloneTracker.UpdateTracker then ns.StandaloneTracker:UpdateTracker() end
        end,
        "Choose a custom color for the zone collapse shape/icon (defaults to zone header text color).",
        syncList
    )
    table.insert(syncList, cpCollapseColor)

    local cbClassHeader = CreateStyledCheckbox(content, "Separate Class Quests Header",
        "Groups class quests into a dedicated class header (e.g. Paladin, Druid) and keeps them visible across all zones.",
        function() return headerDb.separateClassHeader ~= false end,
        function(v)
            headerDb.separateClassHeader = v
            if db.filtering then
                db.filtering.alwaysShowClassQuests = v
            end
            if ns.Tracker and ns.Tracker.UpdateSettings then ns.Tracker:UpdateSettings() end
            if ns.StandaloneTracker and ns.StandaloneTracker.UpdateTracker then ns.StandaloneTracker:UpdateTracker() end
        end
    )
    table.insert(syncList, cbClassHeader)

    local btnSort = CreateStyledDropdown(content, "Sorting Mode", 190, 22, SORT_MODES,
        function() return sortDb.mode or "level" end,
        function(v) sortDb.mode = v end,
        "Sort quests by quest level or group them by current zone."
    )
    table.insert(syncList, btnSort)

    local cbCompletedBottom = CreateStyledCheckbox(content, "Move Completed Quests to Bottom",
        "Pushes completed turn-in quests down to the bottom of the list.",
        function() return sortDb.moveCompletedToBottom == true end,
        function(v) sortDb.moveCompletedToBottom = v end
    )
    table.insert(syncList, cbCompletedBottom)

    local cbActiveTop = CreateStyledCheckbox(content, "Pin Active Quest (Star) to the Top",
        "Always pins your currently tracked/starred active quest at the very top.",
        function() return sortDb.activeOnTop ~= false end,
        function(v) sortDb.activeOnTop = v end
    )
    table.insert(syncList, cbActiveTop)

    local cbLeftClickActive = CreateStyledCheckbox(content, "Left-Click Sets Active Quest (Move to Top)",
        "When unchecked (default), clicking any quest minimizes or expands it in place without moving it. When checked, clicking an inactive quest sets it active and moves it to top.",
        function() return sortDb.leftClickSetsActive == true end,
        function(v)
            sortDb.leftClickSetsActive = v
            if ns.StandaloneTracker and ns.StandaloneTracker.UpdateTracker then ns.StandaloneTracker:UpdateTracker() end
        end
    )
    table.insert(syncList, cbLeftClickActive)

    local cbAlignTitles = CreateStyledCheckbox(content, "Align Quest Titles (Uniform Column)",
        "Aligns all quest titles into a uniform column regardless of whether an active tracking arrow or completion icon is present. Prevents jagged offsets.",
        function() return sortDb.alignQuestTitles ~= false end,
        function(v)
            sortDb.alignQuestTitles = v
            if ns.StandaloneTracker and ns.StandaloneTracker.UpdateTracker then ns.StandaloneTracker:UpdateTracker() end
        end
    )
    table.insert(syncList, cbAlignTitles)

    local function Layout(w)
        if not w or w < 100 then w = content:GetWidth() or 500 end
        local y = -10
        h1:SetPoint("TOPLEFT", content, "TOPLEFT", 12, y)
        y = y - 30

        if w >= 470 then
            local colWidth = math.floor((w - 48) / 2)
            local col1X = 16
            local col2X = col1X + colWidth + 16

            cbLog:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            cbLog.Text:SetWidth(colWidth - 32)
            cbZone:SetPoint("TOPLEFT", content, "TOPLEFT", col2X, y)
            cbZone.Text:SetWidth(colWidth - 32)
            y = y - 34

            cbAll:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            cbAll.Text:SetWidth(colWidth - 32)
            cbMenu:SetPoint("TOPLEFT", content, "TOPLEFT", col2X, y)
            cbMenu.Text:SetWidth(colWidth - 32)
            y = y - 34

            cbCollapse:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            cbCollapse.Text:SetWidth(colWidth - 32)
            y = y - 40

            h1b:SetPoint("TOPLEFT", content, "TOPLEFT", 12, y)
            y = y - 30

            ddHeaderTex:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            ddHeaderTex:SetWidth(math.min(190, colWidth - 20))
            ddZoneTex:SetPoint("TOPLEFT", content, "TOPLEFT", col2X, y)
            ddZoneTex:SetWidth(math.min(190, colWidth - 20))
            y = y - 36

            cpHeaderText:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            cpHeaderText:SetWidth(math.min(190, colWidth - 20))
            cpHeaderBar:SetPoint("TOPLEFT", content, "TOPLEFT", col2X, y)
            cpHeaderBar:SetWidth(math.min(190, colWidth - 20))
            y = y - 36

            cpHeaderBtns:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            cpHeaderBtns:SetWidth(math.min(190, colWidth - 20))
            cpZoneText:SetPoint("TOPLEFT", content, "TOPLEFT", col2X, y)
            cpZoneText:SetWidth(math.min(190, colWidth - 20))
            y = y - 36

            cpZoneBar:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            cpZoneBar:SetWidth(math.min(190, colWidth - 20))
            cbZoneShareBorder:SetPoint("TOPLEFT", content, "TOPLEFT", col2X, y)
            cbZoneShareBorder.Text:SetWidth(colWidth - 32)
            y = y - 36

            btnResetHeaderColors:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            btnResetHeaderColors:SetWidth(math.min(190, colWidth - 20))
            y = y - 44

            h2:SetPoint("TOPLEFT", content, "TOPLEFT", 12, y)
            y = y - 30

            cbZoneHeaders:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            cbZoneHeaders.Text:SetWidth(colWidth - 32)
            cbZoneCount:SetPoint("TOPLEFT", content, "TOPLEFT", col2X, y)
            cbZoneCount.Text:SetWidth(colWidth - 32)
            y = y - 34

            ddCollapseShape:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            ddCollapseShape:SetWidth(math.min(190, colWidth - 20))
            cpCollapseColor:SetPoint("TOPLEFT", content, "TOPLEFT", col2X, y)
            cpCollapseColor:SetWidth(math.min(190, colWidth - 20))
            y = y - 38

            cbClassHeader:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            cbClassHeader.Text:SetWidth(colWidth - 32)
            btnSort:SetPoint("TOPLEFT", content, "TOPLEFT", col2X, y)
            btnSort:SetWidth(math.min(190, colWidth - 20))
            y = y - 38

            cbCompletedBottom:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            cbCompletedBottom.Text:SetWidth(colWidth - 32)
            cbActiveTop:SetPoint("TOPLEFT", content, "TOPLEFT", col2X, y)
            cbActiveTop.Text:SetWidth(colWidth - 32)
            y = y - 34

            cbLeftClickActive:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            cbLeftClickActive.Text:SetWidth(math.max(260, w - 48))
            y = y - 34

            cbAlignTitles:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            cbAlignTitles.Text:SetWidth(math.max(260, w - 48))
            y = y - 34
        else
            local colWidth = w - 36
            local col1X = 16

            cbLog:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            cbLog.Text:SetWidth(colWidth - 32)
            y = y - 32
            cbZone:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            cbZone.Text:SetWidth(colWidth - 32)
            y = y - 32
            cbAll:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            cbAll.Text:SetWidth(colWidth - 32)
            y = y - 32
            cbMenu:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            cbMenu.Text:SetWidth(colWidth - 32)
            y = y - 32
            cbCollapse:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            cbCollapse.Text:SetWidth(colWidth - 32)
            y = y - 38

            h1b:SetPoint("TOPLEFT", content, "TOPLEFT", 12, y)
            y = y - 30

            ddHeaderTex:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            ddHeaderTex:SetWidth(math.min(220, colWidth - 20))
            y = y - 36
            ddZoneTex:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            ddZoneTex:SetWidth(math.min(220, colWidth - 20))
            y = y - 36
            cpHeaderText:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            cpHeaderText:SetWidth(math.min(220, colWidth - 20))
            y = y - 36
            cpHeaderBar:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            cpHeaderBar:SetWidth(math.min(220, colWidth - 20))
            y = y - 36
            cpHeaderBtns:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            cpHeaderBtns:SetWidth(math.min(220, colWidth - 20))
            y = y - 36
            cpZoneText:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            cpZoneText:SetWidth(math.min(220, colWidth - 20))
            y = y - 36
            cpZoneBar:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            cpZoneBar:SetWidth(math.min(220, colWidth - 20))
            y = y - 36
            cbZoneShareBorder:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            cbZoneShareBorder.Text:SetWidth(colWidth - 32)
            y = y - 34
            btnResetHeaderColors:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            btnResetHeaderColors:SetWidth(math.min(220, colWidth - 20))
            y = y - 44

            h2:SetPoint("TOPLEFT", content, "TOPLEFT", 12, y)
            y = y - 30

            cbZoneHeaders:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            cbZoneHeaders.Text:SetWidth(colWidth - 32)
            y = y - 32
            cbZoneCount:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            cbZoneCount.Text:SetWidth(colWidth - 32)
            y = y - 32
            ddCollapseShape:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            ddCollapseShape:SetWidth(math.min(220, colWidth - 20))
            y = y - 38
            cpCollapseColor:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            cpCollapseColor:SetWidth(math.min(220, colWidth - 20))
            y = y - 34
            cbClassHeader:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            cbClassHeader.Text:SetWidth(colWidth - 32)
            y = y - 32
            btnSort:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            btnSort:SetWidth(math.min(220, colWidth - 20))
            y = y - 38
            cbCompletedBottom:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            cbCompletedBottom.Text:SetWidth(colWidth - 32)
            y = y - 32
            cbActiveTop:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            cbActiveTop.Text:SetWidth(colWidth - 32)
            y = y - 32
            cbLeftClickActive:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            cbLeftClickActive.Text:SetWidth(colWidth - 32)
            y = y - 32
            cbAlignTitles:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            cbAlignTitles.Text:SetWidth(colWidth - 32)
            y = y - 32
        end

        content:SetHeight(math.abs(y) + 20)
    end

    content.LayoutTab = Layout
    Layout(content:GetWidth())
end

-- TAB 5: Automation & QoL
local function BuildAutomationTab(content, syncList)
    local db = LiveDB
    local qolDb = LiveSection("qol")
    local socialDb = LiveSection("social")

    local h1 = CreateSectionHeader(content, "QUEST & LOOT AUTOMATION", 12, 0)
    local cbFastLoot = CreateStyledCheckbox(content, "Fast Auto Loot (Instant Looting)",
        "Collects every item in the loot window instantly whenever the game's Auto Loot is active (Interface option or the auto-loot modifier key).",
        function() return qolDb.fastAutoLoot ~= false end,
        function(v) qolDb.fastAutoLoot = v end
    )
    table.insert(syncList, cbFastLoot)

    local cbAutoAcceptNPC = CreateStyledCheckbox(content, "Auto-Accept Quests from NPCs",
        "Automatically accepts quests offered by friendly questgiver NPCs.",
        function()
            if db.questAutomation and db.questAutomation.autoAcceptNPC ~= nil then
                return db.questAutomation.autoAcceptNPC == true
            end
            return socialDb.autoAcceptNPC == true
        end,
        function(v)
            db.questAutomation = db.questAutomation or {}
            db.questAutomation.autoAcceptNPC = v
            if db.social then db.social.autoAcceptNPC = v end
        end
    )
    table.insert(syncList, cbAutoAcceptNPC)

    local cbAutoAcceptShared = CreateStyledCheckbox(content, "Auto-Accept Quests Shared by Party",
        "Automatically accepts quests shared by group or raid members.",
        function()
            if db.questAutomation and db.questAutomation.autoAcceptShared ~= nil then
                return db.questAutomation.autoAcceptShared == true
            end
            return socialDb.autoAcceptShared == true
        end,
        function(v)
            db.questAutomation = db.questAutomation or {}
            db.questAutomation.autoAcceptShared = v
            if db.social then db.social.autoAcceptShared = v end
        end
    )
    table.insert(syncList, cbAutoAcceptShared)

    local cbAutoTurnIn = CreateStyledCheckbox(content, "Auto-Turn In Quests (Single Reward)",
        "Automatically turns in completed quests when there is 0 or only 1 item reward choice.",
        function()
            if db.questAutomation and db.questAutomation.autoTurnIn ~= nil then
                return db.questAutomation.autoTurnIn == true
            end
            return socialDb.autoTurnIn == true
        end,
        function(v)
            db.questAutomation = db.questAutomation or {}
            db.questAutomation.autoTurnIn = v
            if db.social then db.social.autoTurnIn = v end
        end
    )
    table.insert(syncList, cbAutoTurnIn)

    local cbShiftBypass = CreateStyledCheckbox(content, "Hold Shift to Temporarily Bypass",
        "Holding Shift disables automated loot and quest accept/turn-in while interacting.",
        function()
            if db.questAutomation and db.questAutomation.shiftBypass ~= nil then
                return db.questAutomation.shiftBypass ~= false
            end
            return socialDb.shiftBypass ~= false
        end,
        function(v)
            db.questAutomation = db.questAutomation or {}
            db.questAutomation.shiftBypass = v
            if db.social then db.social.shiftBypass = v end
            if db.qol then db.qol.shiftBypass = v end
        end
    )
    table.insert(syncList, cbShiftBypass)

    local cbAutoShare = CreateStyledCheckbox(content, "Auto-Share Quests with Party",
        "Automatically shares newly accepted quests with your party or raid members.",
        function() return db.questAutomation and db.questAutomation.autoShare == true end,
        function(v)
            db.questAutomation = db.questAutomation or {}
            db.questAutomation.autoShare = v
            if db.social then db.social.autoShare = v end
        end
    )
    table.insert(syncList, cbAutoShare)

    local h2 = CreateSectionHeader(content, "MERCHANT & SOCIAL QOL", 12, 0)
    local cbSellJunk = CreateStyledCheckbox(content, "Auto-Sell Grey Junk Items at Vendors",
        "Automatically sells all low-quality grey items when opening vendor merchant frames.",
        function() return qolDb.autoSellJunk == true end,
        function(v) qolDb.autoSellJunk = v end
    )
    table.insert(syncList, cbSellJunk)

    local cbAutoRepair = CreateStyledCheckbox(content, "Auto-Repair Equipment at Vendors",
        "Automatically repairs all damaged gear and weapons when speaking with repair vendors.",
        function() return qolDb.autoRepair == true end,
        function(v) qolDb.autoRepair = v end
    )
    table.insert(syncList, cbAutoRepair)

    local cbGuildRepair = CreateStyledCheckbox(content, "Use Guild Bank for Repairs",
        "Attempt to use Guild Bank repair allowances if available, falling back to personal funds if unavailable.",
        function() return qolDb.useGuildRepair == true end,
        function(v) qolDb.useGuildRepair = v end
    )
    table.insert(syncList, cbGuildRepair)

    local cbMerchantShift = CreateStyledCheckbox(content, "Hold Shift to Bypass Vendor Auto-Sell/Repair",
        "Hold Shift while opening a merchant window to temporarily pause auto-selling and auto-repairing.",
        function() return qolDb.shiftBypass ~= false end,
        function(v) qolDb.shiftBypass = v end
    )
    table.insert(syncList, cbMerchantShift)

    local cbAnnouncePartyMaster = CreateStyledCheckbox(content, "Announce to Party Chat (Master Toggle)",
        "Master toggle to send quest milestone messages to party chat when grouped.",
        function() return socialDb.announceToParty == true end,
        function(v) socialDb.announceToParty = v end
    )
    table.insert(syncList, cbAnnouncePartyMaster)

    local cbAnnounceQuest = CreateStyledCheckbox(content, "Announce Full Quest Complete to Party",
        "Sends a friendly announcement to party chat when you complete all objectives for a quest.",
        function() return socialDb.announceQuestComplete ~= false end,
        function(v) socialDb.announceQuestComplete = v end
    )
    table.insert(syncList, cbAnnounceQuest)

    local cbAnnounceObj = CreateStyledCheckbox(content, "Announce Objective Complete to Party",
        "Announces individual objective completions (e.g. 8/8 Kobold Ears) to party chat.",
        function() return socialDb.announceObjectiveComplete ~= false end,
        function(v) socialDb.announceObjectiveComplete = v end
    )
    table.insert(syncList, cbAnnounceObj)

    local cbAnnounceObjProg = CreateStyledCheckbox(content, "Announce Objective Progress (N/X)",
        "Send incremental objective progress updates to party chat (e.g. Defias Traitors 5/15).",
        function() return socialDb.announceObjectiveProgress == true end,
        function(v) socialDb.announceObjectiveProgress = v end
    )
    table.insert(syncList, cbAnnounceObjProg)

    local function Layout(w)
        if not w or w < 100 then w = content:GetWidth() or 500 end
        local y = -10
        h1:SetPoint("TOPLEFT", content, "TOPLEFT", 12, y)
        y = y - 30

        if w >= 470 then
            local colWidth = math.floor((w - 48) / 2)
            local col1X = 16
            local col2X = col1X + colWidth + 16

            cbFastLoot:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            cbFastLoot.Text:SetWidth(colWidth - 32)
            cbAutoAcceptNPC:SetPoint("TOPLEFT", content, "TOPLEFT", col2X, y)
            cbAutoAcceptNPC.Text:SetWidth(colWidth - 32)
            y = y - 34

            cbAutoAcceptShared:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            cbAutoAcceptShared.Text:SetWidth(colWidth - 32)
            cbAutoTurnIn:SetPoint("TOPLEFT", content, "TOPLEFT", col2X, y)
            cbAutoTurnIn.Text:SetWidth(colWidth - 32)
            y = y - 34

            cbAutoShare:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            cbAutoShare.Text:SetWidth(colWidth - 32)
            cbShiftBypass:SetPoint("TOPLEFT", content, "TOPLEFT", col2X, y)
            cbShiftBypass.Text:SetWidth(colWidth - 32)
            y = y - 40

            h2:SetPoint("TOPLEFT", content, "TOPLEFT", 12, y)
            y = y - 30

            cbSellJunk:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            cbSellJunk.Text:SetWidth(colWidth - 32)
            cbAutoRepair:SetPoint("TOPLEFT", content, "TOPLEFT", col2X, y)
            cbAutoRepair.Text:SetWidth(colWidth - 32)
            y = y - 34

            cbGuildRepair:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            cbGuildRepair.Text:SetWidth(colWidth - 32)
            cbMerchantShift:SetPoint("TOPLEFT", content, "TOPLEFT", col2X, y)
            cbMerchantShift.Text:SetWidth(colWidth - 32)
            y = y - 34

            cbAnnouncePartyMaster:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            cbAnnouncePartyMaster.Text:SetWidth(colWidth - 32)
            cbAnnounceQuest:SetPoint("TOPLEFT", content, "TOPLEFT", col2X, y)
            cbAnnounceQuest.Text:SetWidth(colWidth - 32)
            y = y - 34

            cbAnnounceObj:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            cbAnnounceObj.Text:SetWidth(colWidth - 32)
            cbAnnounceObjProg:SetPoint("TOPLEFT", content, "TOPLEFT", col2X, y)
            cbAnnounceObjProg.Text:SetWidth(colWidth - 32)
            y = y - 34
        else
            local colWidth = w - 36
            local col1X = 16

            cbFastLoot:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            cbFastLoot.Text:SetWidth(colWidth - 32)
            y = y - 32
            cbAutoAcceptNPC:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            cbAutoAcceptNPC.Text:SetWidth(colWidth - 32)
            y = y - 32
            cbAutoAcceptShared:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            cbAutoAcceptShared.Text:SetWidth(colWidth - 32)
            y = y - 32
            cbAutoTurnIn:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            cbAutoTurnIn.Text:SetWidth(colWidth - 32)
            y = y - 32
            cbAutoShare:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            cbAutoShare.Text:SetWidth(colWidth - 32)
            y = y - 32
            cbShiftBypass:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            cbShiftBypass.Text:SetWidth(colWidth - 32)
            y = y - 38

            h2:SetPoint("TOPLEFT", content, "TOPLEFT", 12, y)
            y = y - 30

            cbSellJunk:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            cbSellJunk.Text:SetWidth(colWidth - 32)
            y = y - 32
            cbAutoRepair:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            cbAutoRepair.Text:SetWidth(colWidth - 32)
            y = y - 32
            cbGuildRepair:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            cbGuildRepair.Text:SetWidth(colWidth - 32)
            y = y - 32
            cbMerchantShift:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            cbMerchantShift.Text:SetWidth(colWidth - 32)
            y = y - 32
            cbAnnouncePartyMaster:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            cbAnnouncePartyMaster.Text:SetWidth(colWidth - 32)
            y = y - 32
            cbAnnounceQuest:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            cbAnnounceQuest.Text:SetWidth(colWidth - 32)
            y = y - 32
            cbAnnounceObj:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            cbAnnounceObj.Text:SetWidth(colWidth - 32)
            y = y - 32
            cbAnnounceObjProg:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            cbAnnounceObjProg.Text:SetWidth(colWidth - 32)
            y = y - 32
        end

        content:SetHeight(math.abs(y) + 20)
    end

    content.LayoutTab = Layout
    Layout(content:GetWidth())
end

-- TAB 6: Wayfinder & Audio
local function BuildWayfinderTab(content, syncList)
    local db = LiveDB
    local wfDb = LiveSection("wayfinder")
    local soundDb = LiveSection("sound")

    local h1 = CreateSectionHeader(content, "WAYFINDER HUD NAVIGATION", 12, 0)
    local cbHUDArrow = CreateStyledCheckbox(content, "Enable Floating HUD Arrow",
        "Shows a floating navigation arrow pointing toward your active quest objective.",
        function() return wfDb.enableHUDArrow ~= false end,
        function(v)
            wfDb.enableHUDArrow = v
            if ns.WayfinderModule and ns.WayfinderModule.UpdateFrameVisibility then
                ns.WayfinderModule:UpdateFrameVisibility()
            end
        end
    )
    table.insert(syncList, cbHUDArrow)

    local cbInlineArrow = CreateStyledCheckbox(content, "Enable Inline Tracker Arrow",
        "Shows a mini directional arrow directly inside the tracker next to each quest.",
        function() return wfDb.enableInlineArrow ~= false end,
        function(v)
            wfDb.enableInlineArrow = v
            if ns.StandaloneTracker and ns.StandaloneTracker.UpdateTracker then
                ns.StandaloneTracker:UpdateTracker()
            end
        end
    )
    table.insert(syncList, cbInlineArrow)

    local btnArrowStyle = CreateStyledDropdown(content, "Arrow Style", 190, 22, ARROW_STYLES,
        function() return wfDb.arrowStyle or "auto" end,
        function(v)
            wfDb.arrowStyle = v
            if ns.WayfinderModule and ns.WayfinderModule.ApplyHUDSettings then
                ns.WayfinderModule:ApplyHUDSettings()
            end
            if ns.StandaloneTracker and ns.StandaloneTracker.UpdateTracker then
                ns.StandaloneTracker:UpdateTracker()
            end
        end,
        "Choose between 2D Modern Minimalist, 3D Perspective (Modern), 3D Perspective (Classic), or 2D Classic Guide Arrow."
    )
    table.insert(syncList, btnArrowStyle)

    local btnUnits = CreateStyledDropdown(content, "Distance Units", 190, 22, DISTANCE_UNITS,
        function() return wfDb.distanceUnit or "imperial" end,
        function(v) wfDb.distanceUnit = v end,
        "Choose Imperial yards/miles or Metric meters/kilometers for distance readouts."
    )
    table.insert(syncList, btnUnits)

    local slArrowScale = CreateStyledSlider(content, "BFQ_SlWfScale", "HUD Arrow Scale:",
        "Scales the size of the floating HUD navigation arrow (60% - 160%).",
        0.6, 1.6, 0.05,
        function() return wfDb.arrowScale or 1.0 end,
        function(v)
            wfDb.arrowScale = v
            if ns.WayfinderModule and ns.WayfinderModule.ApplyHUDScale then
                ns.WayfinderModule:ApplyHUDScale()
            elseif ns.WayfinderModule and ns.WayfinderModule.ApplyHUDSettings then
                ns.WayfinderModule:ApplyHUDSettings()
            end
        end,
        "%.2f"
    )
    table.insert(syncList, slArrowScale)

    local slInlineSize = CreateStyledSlider(content, "BFQ_SlWfInlineSize", "Inline Arrow Size:",
        "Pixel dimensions of mini arrows in the tracker (14 - 32px).",
        14, 32, 1,
        function() return wfDb.inlineArrowSize or 22 end,
        function(v)
            wfDb.inlineArrowSize = v
            if ns.StandaloneTracker and ns.StandaloneTracker.UpdateTracker then
                ns.StandaloneTracker:UpdateTracker()
            end
        end,
        "%d px"
    )
    table.insert(syncList, slInlineSize)

    local slTextDistance = CreateStyledSlider(content, "BFQ_SlWfTextDist", "HUD Text Spacing:",
        "Vertical distance between floating arrow and destination text (5 - 50px).",
        5, 50, 1,
        function() return wfDb.textDistance or 12 end,
        function(v)
            wfDb.textDistance = v
            if ns.WayfinderModule and ns.WayfinderModule.UpdateHUDTextAnchors then
                ns.WayfinderModule:UpdateHUDTextAnchors()
            end
        end,
        "%d px"
    )
    table.insert(syncList, slTextDistance)

    local cbArrivalSound = CreateStyledCheckbox(content, "Play Arrival Chime",
        "Plays an arrival sound effect when entering destination range.",
        function() return wfDb.playArrivalSound ~= false end,
        function(v) wfDb.playArrivalSound = v end
    )
    table.insert(syncList, cbArrivalSound)

    local cbHideCombat = CreateStyledCheckbox(content, "Hide Waypoint in Combat",
        "Hides waypoint arrows and distance readouts during combat.",
        function() return wfDb.hideInCombat ~= false end,
        function(v)
            wfDb.hideInCombat = v
            if ns.WayfinderModule and ns.WayfinderModule.UpdateFrameVisibility then
                ns.WayfinderModule:UpdateFrameVisibility()
            end
        end
    )
    table.insert(syncList, cbHideCombat)

    local h1b = CreateSectionHeader(content, "WAYFINDER UTILITY ACTIONS", 12, 0)
    local btnPreviewArrow = CreateStyledButton(content, "Preview / Move Arrow", 190, 22, function()
        if ns.WayfinderModule and ns.WayfinderModule.TogglePreviewMode then
            ns.WayfinderModule:TogglePreviewMode()
        end
    end, "Temporarily toggle the HUD arrow on screen so you can test appearance and drag it to a new location.")

    local btnResetHUDPos = CreateStyledButton(content, "Reset Arrow Position", 190, 22, function()
        if ns.WayfinderModule and ns.WayfinderModule.hudFrame then
            ns.WayfinderModule.hudFrame:ClearAllPoints()
            ns.WayfinderModule.hudFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 160)
            if db.wayfinder then
                db.wayfinder.hudPosition = { point = "CENTER", x = 0, y = 160 }
            end
            ns.Notify(L["HUD arrow position reset."])
        end
    end, "Reset the floating HUD arrow back to its default position above center screen.")

    local btnPointClosest = CreateStyledButton(content, "Point Closest (/cway)", 190, 22, function()
        if ns.WayfinderModule and ns.WayfinderModule.SetClosestWaypoint then
            ns.WayfinderModule:SetClosestWaypoint()
        end
    end, "Direct the HUD arrow to the closest active custom waypoint.")

    local btnClearWaypoints = CreateStyledButton(content, "Clear All Custom Waypoints", 190, 22, function()
        if ns.WayfinderModule and ns.WayfinderModule.ClearAllCustomWaypoints then
            ns.WayfinderModule:ClearAllCustomWaypoints()
        end
    end, "Remove all manually created custom waypoints.")

    local h2 = CreateSectionHeader(content, "AUDIO & SOUND EFFECTS", 12, 0)
    local cbCompleteSound = CreateStyledCheckbox(content, "Play Sound on Quest Complete",
        "Plays an audio alert when you achieve 100% completion on a quest.",
        function() return soundDb.enableCompleteSound ~= false end,
        function(v) soundDb.enableCompleteSound = v end
    )
    table.insert(syncList, cbCompleteSound)

    local slCompleteVol = CreateStyledSlider(content, "BFQ_SlVolComplete", "Complete Sound Volume:",
        "Volume percentage for quest completion sounds.",
        10, 100, 5,
        function() return soundDb.completeSoundVolume or 100 end,
        function(v) soundDb.completeSoundVolume = v end,
        "%d%%"
    )
    table.insert(syncList, slCompleteVol)

    local btnCompleteSound = CreateStyledDropdown(content, "Complete Sound", 190, 22, GetCompleteSoundOptions,
        function() return soundDb.soundChoice or "peon" end,
        function(v)
            soundDb.soundChoice = v
            if ns.SocialModule and ns.SocialModule.PlayPreviewSound then
                ns.SocialModule:PlayPreviewSound(v)
            end
        end,
        "Select which sound effect to play when a quest is ready for turn-in."
    )
    table.insert(syncList, btnCompleteSound)

    local btnCompleteChannel = CreateStyledDropdown(content, "Complete Channel", 190, 22, SOUND_CHANNELS,
        function() return soundDb.completeSoundChannel or "Master" end,
        function(v)
            soundDb.completeSoundChannel = v
        end,
        "Select audio channel for completion sound playback."
    )
    table.insert(syncList, btnCompleteChannel)

    local btnPreviewComplete = CreateStyledButton(content, "Preview Complete Sound", 190, 22, function()
        if ns.SocialModule and ns.SocialModule.PlayPreviewSound then
            local c = soundDb.soundChoice or "peon"
            local ch = soundDb.completeSoundChannel or "Master"
            local vol = soundDb.completeSoundVolume or 100
            ns.SocialModule:PlayPreviewSound(c, ch, vol)
        end
    end, "Play the currently selected quest completion sound effect at configured volume.")

    local cbObjSound = CreateStyledCheckbox(content, "Play Sound on Objective Update",
        "Plays a subtle chime whenever objective progress advances (e.g. 3/4).",
        function() return soundDb.enableObjectiveSound ~= false end,
        function(v) soundDb.enableObjectiveSound = v end
    )
    table.insert(syncList, cbObjSound)

    local slObjVol = CreateStyledSlider(content, "BFQ_SlVolObj", "Objective Sound Volume:",
        "Volume percentage for objective update sounds.",
        10, 100, 5,
        function() return soundDb.objectiveSoundVolume or 100 end,
        function(v) soundDb.objectiveSoundVolume = v end,
        "%d%%"
    )
    table.insert(syncList, slObjVol)

    local btnObjSound = CreateStyledDropdown(content, "Objective Sound", 190, 22, GetObjectiveSoundOptions,
        function() return soundDb.objectiveSoundChoice or "whisper_ping" end,
        function(v)
            soundDb.objectiveSoundChoice = v
            if ns.SocialModule and ns.SocialModule.PlayPreviewObjectiveSound then
                ns.SocialModule:PlayPreviewObjectiveSound(v)
            end
        end,
        "Select which subtle sound effect to play when an objective progresses."
    )
    table.insert(syncList, btnObjSound)

    local btnObjChannel = CreateStyledDropdown(content, "Objective Channel", 190, 22, SOUND_CHANNELS,
        function() return soundDb.objectiveSoundChannel or "Master" end,
        function(v)
            soundDb.objectiveSoundChannel = v
        end,
        "Select audio channel for objective progress sound playback."
    )
    table.insert(syncList, btnObjChannel)

    local btnPreviewObj = CreateStyledButton(content, "Preview Objective Sound", 190, 22, function()
        if ns.SocialModule and ns.SocialModule.PlayPreviewObjectiveSound then
            local c = soundDb.objectiveSoundChoice or "whisper_ping"
            local ch = soundDb.objectiveSoundChannel or "Master"
            local vol = soundDb.objectiveSoundVolume or 100
            ns.SocialModule:PlayPreviewObjectiveSound(c, ch, vol)
        end
    end, "Play the currently selected objective progress sound effect at configured volume.")

    local h3 = CreateSectionHeader(content, "CUSTOM AUDIO FILES", 12, 0)

    local descCustom = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    descCustom:SetJustifyH("LEFT")
    descCustom:SetText(L["Place .wav files in Media\\Sounds\\ & restart WoW. Enter filename below or list in Media\\CustomSounds.lua:"])

    local inputCustom = CreateStyledTextInput(content, 190, 22, "filename.wav (e.g. fart.wav)")
    local btnAddCustom = CreateStyledButton(content, "Add Sound", 100, 22, function()
        local eb = inputCustom.EditBox
        local txt = eb and eb:GetText()
        if txt and txt:match("%S") then
            local ok, res = ns.AddCustomSound(txt)
            if ok then
                if eb then eb:SetText("") end
                if btnCompleteSound then btnCompleteSound:Sync() end
                if btnObjSound then btnObjSound:Sync() end
                ns.Notify(string.format(L["Registered custom sound: %s"], txt), 0.2, 1.0, 0.2)
            elseif res then
                ns.Notify(string.format(L["Could not add sound: %s"], res), 1.0, 0.3, 0.3)
            end
        end
    end, "Register this sound file so it appears in the Complete Sound and Objective Sound dropdowns.")

    local function Layout(w)
        if not w or w < 100 then w = content:GetWidth() or 500 end
        local y = -10
        h1:SetPoint("TOPLEFT", content, "TOPLEFT", 12, y)
        y = y - 30

        if w >= 470 then
            local colWidth = math.floor((w - 48) / 2)
            local col1X = 16
            local col2X = col1X + colWidth + 16

            cbHUDArrow:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            cbHUDArrow.Text:SetWidth(colWidth - 32)
            cbInlineArrow:SetPoint("TOPLEFT", content, "TOPLEFT", col2X, y)
            cbInlineArrow.Text:SetWidth(colWidth - 32)
            y = y - 34

            btnArrowStyle:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            btnArrowStyle:SetWidth(math.min(190, colWidth - 20))
            btnUnits:SetPoint("TOPLEFT", content, "TOPLEFT", col2X, y)
            btnUnits:SetWidth(math.min(190, colWidth - 20))
            y = y - 38

            slArrowScale:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            slArrowScale:SetWidth(math.min(190, colWidth - 20))
            slInlineSize:SetPoint("TOPLEFT", content, "TOPLEFT", col2X, y)
            slInlineSize:SetWidth(math.min(190, colWidth - 20))
            y = y - 48

            slTextDistance:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            slTextDistance:SetWidth(math.min(190, colWidth - 20))
            y = y - 48

            cbArrivalSound:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            cbArrivalSound.Text:SetWidth(colWidth - 32)
            cbHideCombat:SetPoint("TOPLEFT", content, "TOPLEFT", col2X, y)
            cbHideCombat.Text:SetWidth(colWidth - 32)
            y = y - 40

            h1b:SetPoint("TOPLEFT", content, "TOPLEFT", 12, y)
            y = y - 30

            btnPreviewArrow:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            btnPreviewArrow:SetWidth(math.min(190, colWidth - 20))
            btnResetHUDPos:SetPoint("TOPLEFT", content, "TOPLEFT", col2X, y)
            btnResetHUDPos:SetWidth(math.min(190, colWidth - 20))
            y = y - 36

            btnPointClosest:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            btnPointClosest:SetWidth(math.min(190, colWidth - 20))
            btnClearWaypoints:SetPoint("TOPLEFT", content, "TOPLEFT", col2X, y)
            btnClearWaypoints:SetWidth(math.min(190, colWidth - 20))
            y = y - 40

            h2:SetPoint("TOPLEFT", content, "TOPLEFT", 12, y)
            y = y - 30

            cbCompleteSound:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            cbCompleteSound.Text:SetWidth(colWidth - 32)
            slCompleteVol:SetPoint("TOPLEFT", content, "TOPLEFT", col2X, y)
            slCompleteVol:SetWidth(math.min(190, colWidth - 20))
            y = y - 48

            btnCompleteSound:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            btnCompleteSound:SetWidth(math.min(190, colWidth - 20))
            btnCompleteChannel:SetPoint("TOPLEFT", content, "TOPLEFT", col2X, y)
            btnCompleteChannel:SetWidth(math.min(190, colWidth - 20))
            y = y - 36

            btnPreviewComplete:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            btnPreviewComplete:SetWidth(math.min(190, colWidth - 20))
            y = y - 40

            cbObjSound:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            cbObjSound.Text:SetWidth(colWidth - 32)
            slObjVol:SetPoint("TOPLEFT", content, "TOPLEFT", col2X, y)
            slObjVol:SetWidth(math.min(190, colWidth - 20))
            y = y - 48

            btnObjSound:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            btnObjSound:SetWidth(math.min(190, colWidth - 20))
            btnObjChannel:SetPoint("TOPLEFT", content, "TOPLEFT", col2X, y)
            btnObjChannel:SetWidth(math.min(190, colWidth - 20))
            y = y - 36

            btnPreviewObj:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            btnPreviewObj:SetWidth(math.min(190, colWidth - 20))
            y = y - 36

            y = y - 14
            h3:SetPoint("TOPLEFT", content, "TOPLEFT", 12, y)
            y = y - 28

            descCustom:SetPoint("TOPLEFT", content, "TOPLEFT", 16, y)
            descCustom:SetWidth(math.max(200, w - 32))
            y = y - 24

            inputCustom:SetPoint("TOPLEFT", content, "TOPLEFT", 16, y)
            inputCustom:SetWidth(math.min(220, math.max(160, w - 160)))
            btnAddCustom:SetPoint("LEFT", inputCustom, "RIGHT", 10, 0)
            btnAddCustom:SetWidth(100)
            y = y - 36
        else
            local colWidth = w - 36
            local col1X = 16

            cbHUDArrow:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            cbHUDArrow.Text:SetWidth(colWidth - 32)
            y = y - 32
            cbInlineArrow:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            cbInlineArrow.Text:SetWidth(colWidth - 32)
            y = y - 32
            btnArrowStyle:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            btnArrowStyle:SetWidth(math.min(220, colWidth - 20))
            y = y - 36
            btnUnits:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            btnUnits:SetWidth(math.min(220, colWidth - 20))
            y = y - 38
            slArrowScale:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            slArrowScale:SetWidth(math.min(220, colWidth - 20))
            y = y - 46
            slInlineSize:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            slInlineSize:SetWidth(math.min(220, colWidth - 20))
            y = y - 46
            slTextDistance:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            slTextDistance:SetWidth(math.min(220, colWidth - 20))
            y = y - 46
            cbArrivalSound:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            cbArrivalSound.Text:SetWidth(colWidth - 32)
            y = y - 32
            cbHideCombat:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            cbHideCombat.Text:SetWidth(colWidth - 32)
            y = y - 38

            h1b:SetPoint("TOPLEFT", content, "TOPLEFT", 12, y)
            y = y - 30

            btnPreviewArrow:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            btnPreviewArrow:SetWidth(math.min(220, colWidth - 20))
            y = y - 36
            btnResetHUDPos:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            btnResetHUDPos:SetWidth(math.min(220, colWidth - 20))
            y = y - 36
            btnPointClosest:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            btnPointClosest:SetWidth(math.min(220, colWidth - 20))
            y = y - 36
            btnClearWaypoints:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            btnClearWaypoints:SetWidth(math.min(220, colWidth - 20))
            y = y - 38

            h2:SetPoint("TOPLEFT", content, "TOPLEFT", 12, y)
            y = y - 30

            cbCompleteSound:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            cbCompleteSound.Text:SetWidth(colWidth - 32)
            y = y - 32
            slCompleteVol:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            slCompleteVol:SetWidth(math.min(220, colWidth - 20))
            y = y - 46
            btnCompleteSound:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            btnCompleteSound:SetWidth(math.min(220, colWidth - 20))
            y = y - 36
            btnCompleteChannel:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            btnCompleteChannel:SetWidth(math.min(220, colWidth - 20))
            y = y - 36
            btnPreviewComplete:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            btnPreviewComplete:SetWidth(math.min(220, colWidth - 20))
            y = y - 38

            cbObjSound:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            cbObjSound.Text:SetWidth(colWidth - 32)
            y = y - 32
            slObjVol:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            slObjVol:SetWidth(math.min(220, colWidth - 20))
            y = y - 46
            btnObjSound:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            btnObjSound:SetWidth(math.min(220, colWidth - 20))
            y = y - 36
            btnObjChannel:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            btnObjChannel:SetWidth(math.min(220, colWidth - 20))
            y = y - 36
            btnPreviewObj:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            btnPreviewObj:SetWidth(math.min(220, colWidth - 20))
            y = y - 36

            y = y - 14
            h3:SetPoint("TOPLEFT", content, "TOPLEFT", 12, y)
            y = y - 28

            descCustom:SetPoint("TOPLEFT", content, "TOPLEFT", 16, y)
            descCustom:SetWidth(colWidth - 20)
            y = y - 30

            inputCustom:SetPoint("TOPLEFT", content, "TOPLEFT", 16, y)
            inputCustom:SetWidth(math.min(220, colWidth - 20))
            y = y - 28
            btnAddCustom:SetPoint("TOPLEFT", content, "TOPLEFT", 16, y)
            btnAddCustom:SetWidth(100)
            y = y - 36
        end

        content:SetHeight(math.abs(y) + 20)
    end

    content.LayoutTab = Layout
    Layout(content:GetWidth())
end

-- TAB 7: DataBars
local function BuildDataBarsTab(content, syncList)
    local dataDb = LiveSection("databars")

    local cbHideWithTracker = CreateStyledCheckbox(content, "Hide DataBars When Tracker Hidden",
        "When enabled, hiding the quest tracker via keybind, button, or slash command also hides all active DataBars (XP Bar, Location Bar, and Quest Timer Bar).",
        function() return dataDb.hideWithTracker ~= false end,
        function(v)
            dataDb.hideWithTracker = v
            if ns.DataBarsModule and ns.DataBarsModule.RefreshBars then
                ns.DataBarsModule:RefreshBars()
            end
        end
    )
    table.insert(syncList, cbHideWithTracker)

    local cbHideDataBarsCombat = CreateStyledCheckbox(content, "Hide DataBars In Combat",
        "Automatically hides all DataBars during combat encounters and restores them when combat ends.",
        function() return dataDb.hideInCombat == true end,
        function(v)
            dataDb.hideInCombat = v
            if ns.DataBarsModule and ns.DataBarsModule.RefreshBars then
                ns.DataBarsModule:RefreshBars()
            end
        end
    )
    table.insert(syncList, cbHideDataBarsCombat)

    local h1 = CreateSectionHeader(content, "EXPERIENCE & QUEST LOG PROGRESS BAR", 12, 0)
    local cbXPBar = CreateStyledCheckbox(content, "Enable Standalone XP DataBar",
        "Renders a customizable experience and completed quest turn-in progress bar.",
        function() return dataDb.enableXPBar == true end,
        function(v) dataDb.enableXPBar = v end
    )
    table.insert(syncList, cbXPBar)

    local btnXPDock = CreateStyledDropdown(content, "XP Dock Mode", 190, 22, XP_DOCK_MODES,
        function() return dataDb.xpDockMode or "tracker_bottom" end,
        function(v)
            dataDb.xpDockMode = v
            if ns.DataBarsModule and ns.DataBarsModule.UpdateXPDocking then
                ns.DataBarsModule:UpdateXPDocking()
            end
            if content and content.LayoutTab then
                content.LayoutTab(content:GetWidth())
            end
        end,
        "Dock experience bar directly underneath the tracker or unlock for free movement."
    )
    table.insert(syncList, btnXPDock)

    local slXPHeight = CreateStyledSlider(content, "BFQ_SlXpHeight", "XP Bar Height:",
        "Pixel height of the experience bar (8 - 36px).",
        8, 36, 1,
        function() return dataDb.xpHeight or 14 end,
        function(v)
            dataDb.xpHeight = v
            if ns.DataBarsModule and ns.DataBarsModule.UpdateXPDocking then
                ns.DataBarsModule:UpdateXPDocking()
            end
        end,
        "%d px"
    )
    table.insert(syncList, slXPHeight)

    local slXPWidth = CreateStyledSlider(content, "BFQ_SlXpWidth", "XP Bar Width (Floating):",
        "Pixel width of the floating experience bar (140 - 800px).",
        140, 800, 10,
        function() return dataDb.xpWidth or 280 end,
        function(v)
            dataDb.xpWidth = v
            if ns.DataBarsModule and ns.DataBarsModule.UpdateXPDocking then
                ns.DataBarsModule:UpdateXPDocking()
            end
        end,
        "%d px"
    )
    table.insert(syncList, slXPWidth)

    local cbQuestXP = CreateStyledCheckbox(content, "Show Completed Turn-in Ghost Bar",
        "Overlays anticipated experience from completed turn-in quests onto the XP bar.",
        function() return dataDb.showCompletedQuestXP ~= false end,
        function(v) dataDb.showCompletedQuestXP = v end
    )
    table.insert(syncList, cbQuestXP)

    local cbDingReady = CreateStyledCheckbox(content, "Show [Ding Ready!] Alert",
        "Displays [Ding Ready!] in glowing gold when completed quests provide enough XP to level.",
        function() return dataDb.showDingReadyText ~= false end,
        function(v) dataDb.showDingReadyText = v end
    )
    table.insert(syncList, cbDingReady)

    local cbRestedXP = CreateStyledCheckbox(content, "Show Rested XP Bonus Segment",
        "Renders rested experience bonus segment in blue.",
        function() return dataDb.showRestedXP ~= false end,
        function(v) dataDb.showRestedXP = v end
    )
    table.insert(syncList, cbRestedXP)

    local h2 = CreateSectionHeader(content, "LOCATION & COORDINATES HEADER BAR", 12, 0)
    local cbLocBar = CreateStyledCheckbox(content, "Enable Location & Coordinates Bar",
        "Renders a precision zone, subzone, and coordinates bar.",
        function() return dataDb.enableLocationBar == true end,
        function(v) dataDb.enableLocationBar = v end
    )
    table.insert(syncList, cbLocBar)

    local btnLocDock = CreateStyledDropdown(content, "Loc Dock Mode", 190, 22, LOC_DOCK_MODES,
        function() return dataDb.locDockMode or "tracker_top" end,
        function(v) dataDb.locDockMode = v end,
        "Dock location bar above tracker, above minimap, or unlock for free movement."
    )
    table.insert(syncList, btnLocDock)

    local cbCoords = CreateStyledCheckbox(content, "Show Precision Coordinates",
        "Displays player map coordinates (e.g. 45.2, 58.6) on the location bar.",
        function() return dataDb.showCoords ~= false end,
        function(v) dataDb.showCoords = v end
    )
    table.insert(syncList, cbCoords)

    local cbTerritory = CreateStyledCheckbox(content, "Color by PvP Territory Status",
        "Colors zone and subzone names by PvP status (Sanctuary, Friendly, Contested, Hostile).",
        function() return dataDb.colorTerritory ~= false end,
        function(v) dataDb.colorTerritory = v end
    )
    table.insert(syncList, cbTerritory)

    local btnResetXPPos = CreateStyledButton(content, "Reset Free XP Position", 190, 22, function()
        if dataDb then dataDb.xpFreePosition = nil end
        if ns.DataBarsModule and ns.DataBarsModule.UpdateXPDocking then ns.DataBarsModule:UpdateXPDocking() end
        ns.Notify(L["XP Bar position reset."])
    end, "Reset the free floating XP bar back to its default position.")

    local btnResetXPColors = CreateStyledButton(content, "Reset XP Colors", 190, 22, function()
        if dataDb then
            dataDb.xpBgColor = { r = 0.00, g = 0.00, b = 0.00, a = 0.00 }
            dataDb.xpColor = { r = 0.58, g = 0.00, b = 0.83, a = 1.00 }
            dataDb.restedColor = { r = 0.00, g = 0.44, b = 0.88, a = 1.00 }
            dataDb.questXPColor = { r = 0.25, g = 0.85, b = 0.45, a = 0.65 }
            dataDb.allQuestXPColor = { r = 0.12, g = 0.45, b = 0.25, a = 0.80 }
            dataDb.dingReadyColor = { r = 1.00, g = 0.82, b = 0.00, a = 1.00 }
        end
        if ns.DataBarsModule and ns.DataBarsModule.UpdateXPBar then ns.DataBarsModule:UpdateXPBar() end
        ns.Notify(L["XP Bar colors reset to defaults."])
    end, "Reset all XP bar colors back to defaults.")

    local btnResetLocPos = CreateStyledButton(content, "Reset Free Loc Position", 190, 22, function()
        if dataDb then dataDb.locFreePosition = nil end
        if ns.DataBarsModule then ns.DataBarsModule:UpdateLocationDocking() end
        ns.Notify(L["Location Bar position reset."])
    end, "Reset the free floating Location Bar back to its default position.")

    local h3 = CreateSectionHeader(content, "QUEST TIMER BAR & DOCKING", 12, 0)
    local btnPreviewTimer = CreateStyledButton(content, "Preview / Move Timer Bar", 190, 22, function()
        if ns.DataBarsModule then
            ns.DataBarsModule.timerPreviewMode = not ns.DataBarsModule.timerPreviewMode
            if ns.DataBarsModule.RefreshBars then ns.DataBarsModule:RefreshBars() end
        end
    end, "Temporarily toggle preview mode for the Quest Timer Bar so you can adjust its position.")

    local btnResetTimerPos = CreateStyledButton(content, "Reset Timer Bar Position", 190, 22, function()
        if dataDb then dataDb.timerFreePosition = nil end
        if ns.DataBarsModule and ns.DataBarsModule.UpdateTimerDocking then ns.DataBarsModule:UpdateTimerDocking() end
        ns.Notify(L["Timer Bar position reset."])
    end, "Reset the free floating Timer Bar back to its default position.")

    local function Layout(w)
        if not w or w < 100 then w = content:GetWidth() or 500 end
        local y = -10
        h1:SetPoint("TOPLEFT", content, "TOPLEFT", 12, y)
        y = y - 30

        local isFreeXP = (dataDb.xpDockMode == "free")

        if w >= 470 then
            local colWidth = math.floor((w - 48) / 2)
            local col1X = 16
            local col2X = col1X + colWidth + 16

            cbHideWithTracker:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            cbHideWithTracker.Text:SetWidth(colWidth - 32)
            cbHideDataBarsCombat:SetPoint("TOPLEFT", content, "TOPLEFT", col2X, y)
            cbHideDataBarsCombat.Text:SetWidth(colWidth - 32)
            y = y - 34

            cbXPBar:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            cbXPBar.Text:SetWidth(colWidth - 32)
            btnXPDock:SetPoint("TOPLEFT", content, "TOPLEFT", col2X, y)
            btnXPDock:SetWidth(math.min(190, colWidth - 20))
            y = y - 40

            slXPHeight:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            slXPHeight:SetWidth(math.min(190, colWidth - 20))
            if isFreeXP then
                slXPWidth:Show()
                slXPWidth:SetPoint("TOPLEFT", content, "TOPLEFT", col2X, y)
                slXPWidth:SetWidth(math.min(190, colWidth - 20))
            else
                slXPWidth:Hide()
            end
            y = y - 48

            cbQuestXP:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            cbQuestXP.Text:SetWidth(colWidth - 32)
            cbDingReady:SetPoint("TOPLEFT", content, "TOPLEFT", col2X, y)
            cbDingReady.Text:SetWidth(colWidth - 32)
            y = y - 34

            cbRestedXP:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            cbRestedXP.Text:SetWidth(colWidth - 32)
            y = y - 34

            btnResetXPPos:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            btnResetXPPos:SetWidth(math.min(190, colWidth - 20))
            btnResetXPColors:SetPoint("TOPLEFT", content, "TOPLEFT", col2X, y)
            btnResetXPColors:SetWidth(math.min(190, colWidth - 20))
            y = y - 40

            h2:SetPoint("TOPLEFT", content, "TOPLEFT", 12, y)
            y = y - 30

            cbLocBar:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            cbLocBar.Text:SetWidth(colWidth - 32)
            btnLocDock:SetPoint("TOPLEFT", content, "TOPLEFT", col2X, y)
            btnLocDock:SetWidth(math.min(190, colWidth - 20))
            y = y - 40

            cbCoords:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            cbCoords.Text:SetWidth(colWidth - 32)
            cbTerritory:SetPoint("TOPLEFT", content, "TOPLEFT", col2X, y)
            cbTerritory.Text:SetWidth(colWidth - 32)
            y = y - 34

            btnResetLocPos:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            btnResetLocPos:SetWidth(math.min(190, colWidth - 20))
            y = y - 40

            h3:SetPoint("TOPLEFT", content, "TOPLEFT", 12, y)
            y = y - 30

            btnPreviewTimer:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            btnPreviewTimer:SetWidth(math.min(190, colWidth - 20))
            btnResetTimerPos:SetPoint("TOPLEFT", content, "TOPLEFT", col2X, y)
            btnResetTimerPos:SetWidth(math.min(190, colWidth - 20))
            y = y - 36
        else
            local colWidth = w - 36
            local col1X = 16

            cbHideWithTracker:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            cbHideWithTracker.Text:SetWidth(colWidth - 32)
            y = y - 32
            cbHideDataBarsCombat:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            cbHideDataBarsCombat.Text:SetWidth(colWidth - 32)
            y = y - 32
            cbXPBar:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            cbXPBar.Text:SetWidth(colWidth - 32)
            y = y - 32
            btnXPDock:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            btnXPDock:SetWidth(math.min(220, colWidth - 20))
            y = y - 38
            slXPHeight:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            slXPHeight:SetWidth(math.min(220, colWidth - 20))
            y = y - 46
            if isFreeXP then
                slXPWidth:Show()
                slXPWidth:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
                slXPWidth:SetWidth(math.min(220, colWidth - 20))
                y = y - 46
            else
                slXPWidth:Hide()
            end
            cbQuestXP:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            cbQuestXP.Text:SetWidth(colWidth - 32)
            y = y - 32
            cbDingReady:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            cbDingReady.Text:SetWidth(colWidth - 32)
            y = y - 32
            cbRestedXP:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            cbRestedXP.Text:SetWidth(colWidth - 32)
            y = y - 34
            btnResetXPPos:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            btnResetXPPos:SetWidth(math.min(220, colWidth - 20))
            y = y - 36
            btnResetXPColors:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            btnResetXPColors:SetWidth(math.min(220, colWidth - 20))
            y = y - 38

            h2:SetPoint("TOPLEFT", content, "TOPLEFT", 12, y)
            y = y - 30

            cbLocBar:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            cbLocBar.Text:SetWidth(colWidth - 32)
            y = y - 32
            btnLocDock:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            btnLocDock:SetWidth(math.min(220, colWidth - 20))
            y = y - 38
            cbCoords:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            cbCoords.Text:SetWidth(colWidth - 32)
            y = y - 32
            cbTerritory:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            cbTerritory.Text:SetWidth(colWidth - 32)
            y = y - 34
            btnResetLocPos:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            btnResetLocPos:SetWidth(math.min(220, colWidth - 20))
            y = y - 38

            h3:SetPoint("TOPLEFT", content, "TOPLEFT", 12, y)
            y = y - 30

            btnPreviewTimer:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            btnPreviewTimer:SetWidth(math.min(220, colWidth - 20))
            y = y - 36
            btnResetTimerPos:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            btnResetTimerPos:SetWidth(math.min(220, colWidth - 20))
            y = y - 36
        end

        content:SetHeight(math.abs(y) + 20)
    end

    content.LayoutTab = Layout
    Layout(content:GetWidth())
end

-- TAB 8: Profiles
local function BuildProfilesTab(content, syncList)
    local h1 = CreateSectionHeader(content, "ACTIVE PROFILE", 12, 0)

    local lblCurrent = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    local function UpdateCurrent()
        local cur = (ns.dbObject and ns.dbObject.GetCurrentProfile and ns.dbObject:GetCurrentProfile()) or "Default"
        lblCurrent:SetText(string.format(L["Active Profile: %s"], "|cFFFFD100" .. cur .. "|r"))
    end

    local function TriggerFullSync()
        UpdateCurrent()
        Config:SyncAll()
    end
    lblCurrent.Sync = UpdateCurrent
    table.insert(syncList, lblCurrent)

    local function GetProfileOptions()
        local list = {}
        if ns.dbObject and ns.dbObject.GetProfiles then
            local profiles = ns.dbObject:GetProfiles()
            for _, p in ipairs(profiles or {}) do
                table.insert(list, { key = p, label = p })
            end
        end
        if #list == 0 then
            table.insert(list, { key = "Default", label = "Default" })
        end
        return list
    end

    local function GetOtherProfileOptions()
        local list = {}
        local cur = (ns.dbObject and ns.dbObject.GetCurrentProfile and ns.dbObject:GetCurrentProfile()) or "Default"
        if ns.dbObject and ns.dbObject.GetProfiles then
            local profiles = ns.dbObject:GetProfiles()
            for _, p in ipairs(profiles or {}) do
                if p ~= cur then
                    table.insert(list, { key = p, label = p })
                end
            end
        end
        return list
    end

    local ddSelectProfile = CreateStyledDropdown(content, "Switch Profile", 220, 22,
        GetProfileOptions,
        function() return (ns.dbObject and ns.dbObject.GetCurrentProfile and ns.dbObject:GetCurrentProfile()) or "Default" end,
        function(v)
            if ns.dbObject and ns.dbObject.SetProfile and v then
                ns.dbObject:SetProfile(v)
                TriggerFullSync()
            end
        end,
        "Select a profile to switch your active quest tracker configuration to."
    )
    table.insert(syncList, ddSelectProfile)

    local btnReset = CreateStyledButton(content, "Reset to Defaults", 180, 22, function()
        if ns.dbObject and ns.dbObject.ResetProfile then
            ns.dbObject:ResetProfile()
            TriggerFullSync()
        end
    end, "Resets all quest tracker settings in the active profile back to defaults.")

    -- SECTION 2: CREATE NEW PROFILE
    local h2 = CreateSectionHeader(content, "CREATE NEW PROFILE", 12, 0)
    local newProfileInput = CreateStyledTextInput(content, 220, 22, "Enter profile name...")
    local btnCreate = CreateStyledButton(content, "Create Profile", 180, 22, function()
        local name = newProfileInput.EditBox:GetText()
        if name then
            name = name:match("^%s*(.-)%s*$")
            if name and name ~= "" then
                if ns.dbObject and ns.dbObject.SetProfile then
                    ns.dbObject:SetProfile(name)
                    newProfileInput.EditBox:SetText("")
                    newProfileInput.EditBox:ClearFocus()
                    TriggerFullSync()
                end
            end
        end
    end, "Create and switch to a new profile with default settings.")
    newProfileInput.EditBox:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        btnCreate:GetScript("OnClick")(btnCreate)
    end)

    -- SECTION 3: COPY FROM EXISTING PROFILE
    local h3 = CreateSectionHeader(content, "COPY FROM EXISTING PROFILE", 12, 0)
    local selectedCopySource = nil
    local ddCopyProfile = CreateStyledDropdown(content, "Copy From", 220, 22,
        GetOtherProfileOptions,
        function() return selectedCopySource or "" end,
        function(v) selectedCopySource = v end,
        "Select an existing profile to copy its settings into the current profile."
    )
    table.insert(syncList, ddCopyProfile)

    local btnCopy = CreateStyledButton(content, "Copy Selected Profile", 180, 22, function()
        if selectedCopySource and selectedCopySource ~= "" and ns.dbObject and ns.dbObject.CopyProfile then
            ns.dbObject:CopyProfile(selectedCopySource)
            TriggerFullSync()
        end
    end, "Copies all settings from the selected profile into your active profile (overwriting existing settings).")

    -- SECTION 4: DELETE PROFILE
    local h4 = CreateSectionHeader(content, "DELETE PROFILE", 12, 0)
    local selectedDeleteTarget = nil
    local ddDeleteProfile = CreateStyledDropdown(content, "Delete Profile", 220, 22,
        GetOtherProfileOptions,
        function() return selectedDeleteTarget or "" end,
        function(v) selectedDeleteTarget = v end,
        "Select an inactive profile to delete permanently."
    )
    table.insert(syncList, ddDeleteProfile)

    local btnDelete = CreateStyledButton(content, "Delete Selected Profile", 180, 22, function()
        if selectedDeleteTarget and selectedDeleteTarget ~= "" and ns.dbObject and ns.dbObject.DeleteProfile then
            ns.dbObject:DeleteProfile(selectedDeleteTarget)
            selectedDeleteTarget = nil
            TriggerFullSync()
        end
    end, "Permanently deletes the selected profile (cannot delete your currently active profile).")

    UpdateCurrent()

    local function Layout(w)
        if not w or w < 100 then w = content:GetWidth() or 500 end
        local y = -10

        -- SECTION 1: ACTIVE PROFILE
        h1:SetPoint("TOPLEFT", content, "TOPLEFT", 12, y)
        y = y - 30

        lblCurrent:SetPoint("TOPLEFT", content, "TOPLEFT", 16, y)
        y = y - 26

        if w >= 470 then
            local colWidth = math.floor((w - 48) / 2)
            local col1X = 16
            local col2X = col1X + colWidth + 16

            ddSelectProfile:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            ddSelectProfile:SetWidth(math.min(220, colWidth - 20))
            btnReset:SetPoint("TOPLEFT", content, "TOPLEFT", col2X, y)
            btnReset:SetWidth(math.min(180, colWidth - 20))
            y = y - 44

            -- SECTION 2: CREATE NEW PROFILE
            h2:SetPoint("TOPLEFT", content, "TOPLEFT", 12, y)
            y = y - 30
            newProfileInput:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            newProfileInput:SetWidth(math.min(220, colWidth - 20))
            btnCreate:SetPoint("TOPLEFT", content, "TOPLEFT", col2X, y)
            btnCreate:SetWidth(math.min(180, colWidth - 20))
            y = y - 44

            -- SECTION 3: COPY FROM EXISTING PROFILE
            h3:SetPoint("TOPLEFT", content, "TOPLEFT", 12, y)
            y = y - 30
            ddCopyProfile:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            ddCopyProfile:SetWidth(math.min(220, colWidth - 20))
            btnCopy:SetPoint("TOPLEFT", content, "TOPLEFT", col2X, y)
            btnCopy:SetWidth(math.min(180, colWidth - 20))
            y = y - 44

            -- SECTION 4: DELETE PROFILE
            h4:SetPoint("TOPLEFT", content, "TOPLEFT", 12, y)
            y = y - 30
            ddDeleteProfile:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            ddDeleteProfile:SetWidth(math.min(220, colWidth - 20))
            btnDelete:SetPoint("TOPLEFT", content, "TOPLEFT", col2X, y)
            btnDelete:SetWidth(math.min(180, colWidth - 20))
            y = y - 44
        else
            local colWidth = w - 36
            local col1X = 16

            ddSelectProfile:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            ddSelectProfile:SetWidth(math.min(220, colWidth - 20))
            y = y - 36
            btnReset:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            btnReset:SetWidth(math.min(180, colWidth - 20))
            y = y - 44

            h2:SetPoint("TOPLEFT", content, "TOPLEFT", 12, y)
            y = y - 30
            newProfileInput:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            newProfileInput:SetWidth(math.min(220, colWidth - 20))
            y = y - 36
            btnCreate:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            btnCreate:SetWidth(math.min(180, colWidth - 20))
            y = y - 44

            h3:SetPoint("TOPLEFT", content, "TOPLEFT", 12, y)
            y = y - 30
            ddCopyProfile:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            ddCopyProfile:SetWidth(math.min(220, colWidth - 20))
            y = y - 36
            btnCopy:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            btnCopy:SetWidth(math.min(180, colWidth - 20))
            y = y - 44

            h4:SetPoint("TOPLEFT", content, "TOPLEFT", 12, y)
            y = y - 30
            ddDeleteProfile:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            ddDeleteProfile:SetWidth(math.min(220, colWidth - 20))
            y = y - 36
            btnDelete:SetPoint("TOPLEFT", content, "TOPLEFT", col1X, y)
            btnDelete:SetWidth(math.min(180, colWidth - 20))
            y = y - 44
        end

        content:SetHeight(math.abs(y) + 30)
    end

    content.LayoutTab = Layout
    Layout(content:GetWidth())
end

--[[-----------------------------------------------------------------------------
    Options container (shared by the standalone window, the Blizzard Settings
    panel, and Bleakfiber's Addon Config hub)
-------------------------------------------------------------------------------]]
local TABS = {
    { id = "general",    label = "General",         builder = BuildGeneralTab },
    { id = "quests",     label = "Quests & Items",  builder = BuildQuestsTab },
    { id = "appearance", label = "Colors & Fonts",  builder = BuildColorsTab },
    { id = "headers",    label = "Headers & Sort",  builder = BuildHeadersTab },
    { id = "wayfinder",  label = "Wayfinder/Audio", builder = BuildWayfinderTab },
    { id = "databars",   label = "Databars",        builder = BuildDataBarsTab },
    { id = "automation", label = "Automation",      builder = BuildAutomationTab },
    { id = "profiles",   label = "Profiles",        builder = BuildProfilesTab },
}

local builtContainers = {}
local scrollFrameCount = 0

-- Re-reads every widget in every built options container from the active profile
function Config:SyncAll()
    for _, container in ipairs(builtContainers) do
        if container.SyncAll then container.SyncAll() end
    end
end

function Config:BuildNativeOptions(containerFrame)
    if not containerFrame then return end

    if containerFrame.nativeOptionsBuilt then
        containerFrame.SyncAll()
        return containerFrame
    end

    local tabBar = CreateFrame("Frame", nil, containerFrame)
    tabBar:SetHeight(28)
    tabBar:SetPoint("TOPLEFT", containerFrame, "TOPLEFT", 0, 0)
    tabBar:SetPoint("TOPRIGHT", containerFrame, "TOPRIGHT", 0, 0)

    local insetBox = CreateFrame("Frame", nil, containerFrame, BACKDROP_TEMPLATE)
    insetBox:SetPoint("TOPLEFT", tabBar, "BOTTOMLEFT", 0, -4)
    insetBox:SetPoint("BOTTOMRIGHT", containerFrame, "BOTTOMRIGHT", -4, 4)
    insetBox:SetBackdrop(INSET_BACKDROP)
    insetBox:SetBackdropColor(unpack(COLORS.contentBg))
    insetBox:SetBackdropBorderColor(unpack(COLORS.goldMuted))

    local tabButtons = {}
    local tabScrolls = {}
    local syncLists = {}
    local tabChildren = {}

    local function SyncList(list)
        for _, widget in ipairs(list) do
            if widget.Sync then widget:Sync() end
        end
    end

    local function SelectTab(tabID)
        for _, t in ipairs(TABS) do
            local btn = tabButtons[t.id]
            local scroll = tabScrolls[t.id]
            if t.id == tabID then
                btn:SetBackdropColor(unpack(COLORS.tabActive))
                btn:SetBackdropBorderColor(unpack(COLORS.goldBorder))
                btn.label:SetTextColor(COLORS.goldText[1], COLORS.goldText[2], COLORS.goldText[3])
                scroll:Show()
                local child = tabChildren[t.id]
                if child.LayoutTab then
                    child.LayoutTab(scroll:GetWidth() - 24)
                end
                SyncList(syncLists[t.id])
            else
                btn:SetBackdropColor(unpack(COLORS.tabNormal))
                btn:SetBackdropBorderColor(unpack(COLORS.goldMuted))
                btn.label:SetTextColor(COLORS.whiteText[1], COLORS.whiteText[2], COLORS.whiteText[3])
                scroll:Hide()
            end
        end
    end

    local function LayoutTabBar(w)
        if not w or w < 100 then w = containerFrame:GetWidth() or 540 end
        local gap = 4
        if w >= 620 then
            tabBar:SetHeight(28)
            local btnW = math.min(92, math.floor((w - ((#TABS - 1) * gap)) / #TABS))
            local curX = 0
            for _, t in ipairs(TABS) do
                local b = tabButtons[t.id]
                b:SetSize(btnW, 24)
                b:ClearAllPoints()
                b:SetPoint("TOPLEFT", tabBar, "TOPLEFT", curX, 0)
                curX = curX + btnW + gap
            end
        else
            -- Two rows on narrow hosts
            tabBar:SetHeight(52)
            local perRow = math.ceil(#TABS / 2)
            for i, t in ipairs(TABS) do
                local row = (i <= perRow) and 0 or 1
                local count = (row == 0) and perRow or (#TABS - perRow)
                local index = (row == 0) and (i - 1) or (i - perRow - 1)
                local btnW = math.floor((w - ((count - 1) * gap)) / count)
                local b = tabButtons[t.id]
                b:SetSize(btnW, 22)
                b:ClearAllPoints()
                b:SetPoint("TOPLEFT", tabBar, "TOPLEFT", index * (btnW + gap), -26 * row)
            end
        end
    end

    for _, t in ipairs(TABS) do
        local tID = t.id
        local btn = CreateFrame("Button", nil, tabBar, BACKDROP_TEMPLATE)
        btn:SetSize(72, 24)
        btn:SetBackdrop(INSET_BACKDROP)
        btn:SetBackdropColor(unpack(COLORS.tabNormal))
        btn:SetBackdropBorderColor(unpack(COLORS.goldMuted))

        local lbl = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        lbl:SetPoint("LEFT", btn, "LEFT", 2, 0)
        lbl:SetPoint("RIGHT", btn, "RIGHT", -2, 0)
        lbl:SetWordWrap(false)
        lbl:SetText(L[t.label])
        btn.label = lbl

        btn:SetScript("OnClick", function() SelectTab(tID) end)
        tabButtons[tID] = btn

        scrollFrameCount = scrollFrameCount + 1
        local scroll = CreateFrame("ScrollFrame", "BFQ_OptionsScroll" .. scrollFrameCount, insetBox, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", insetBox, "TOPLEFT", 6, -6)
        scroll:SetPoint("BOTTOMRIGHT", insetBox, "BOTTOMRIGHT", -26, 6)

        local child = CreateFrame("Frame", nil, scroll)
        child:SetSize(500, 500)
        scroll:SetScrollChild(child)

        local updateScroll = SetupAutoScroll(scroll, child)

        local sList = {}
        syncLists[tID] = sList
        t.builder(child, sList)
        tabChildren[tID] = child

        local extras = TAB_EXTRAS[tID]
        if extras then
            local layoutExtras = BuildExtraSettings(child, sList, extras)
            local baseLayout = child.LayoutTab
            child.LayoutTab = function(w)
                if baseLayout then baseLayout(w) end
                local bottom = layoutExtras(-(child:GetHeight() - 30), w)
                child:SetHeight(math.abs(bottom) + 30)
            end
        end

        scroll:HookScript("OnSizeChanged", function(_, sw)
            if sw and sw > 60 and child.LayoutTab then
                child.LayoutTab(sw - 24)
                if updateScroll then updateScroll() end
            end
        end)

        scroll:Hide()
        tabScrolls[tID] = scroll
    end

    containerFrame.SyncAll = function()
        for _, list in pairs(syncLists) do
            SyncList(list)
        end
    end

    containerFrame:HookScript("OnSizeChanged", function(_, w)
        if w and w > 60 then
            LayoutTabBar(w)
        end
    end)

    LayoutTabBar(containerFrame:GetWidth())
    SelectTab("general")
    containerFrame.SyncAll()

    containerFrame.nativeOptionsBuilt = true
    builtContainers[#builtContainers + 1] = containerFrame
    return containerFrame
end

function Config:EmbedOptionsIntoContainer(containerFrame)
    if not containerFrame then return end
    if ns.SetupColorPickerEnhancements then
        ns.SetupColorPickerEnhancements()
    end
    return Config:BuildNativeOptions(containerFrame)
end

local function SaveWindowGeometry(f)
    if not ns.db then return end
    local cw = ns.db.configWindow
    local pt, _, relPt, x, y = f:GetPoint()
    cw.point = pt
    cw.relativePoint = relPt or pt
    cw.xOfs = math.floor((x or 0) + 0.5)
    cw.yOfs = math.floor((y or 0) + 0.5)
    cw.width = math.floor(f:GetWidth() + 0.5)
    cw.height = math.floor(f:GetHeight() + 0.5)
end

function Config:GetOrCreateStandaloneFrame()
    if self.standaloneFrame then return self.standaloneFrame end

    local cw = (ns.db and ns.db.configWindow) or {}

    local f = CreateFrame("Frame", "BleakfibersStandaloneConfigFrame", UIParent, BACKDROP_TEMPLATE)
    f:Hide()
    f:SetSize(cw.width or 820, cw.height or 580)
    f:SetPoint(cw.point or "CENTER", UIParent, cw.relativePoint or "CENTER", cw.xOfs or 0, cw.yOfs or 0)
    f:SetFrameStrata("HIGH")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:SetResizable(true)
    f:SetResizeBounds(640, 420, 1200, 850)
    tinsert(UISpecialFrames, "BleakfibersStandaloneConfigFrame")

    f:SetBackdrop(MAIN_WINDOW_BACKDROP)
    f:SetBackdropColor(unpack(COLORS.bgSlate))
    f:SetBackdropBorderColor(unpack(COLORS.goldBorder))

    -- Title bar (drag handle)
    local titleBar = CreateFrame("Frame", nil, f)
    titleBar:SetHeight(32)
    titleBar:SetPoint("TOPLEFT", f, "TOPLEFT", 6, -6)
    titleBar:SetPoint("TOPRIGHT", f, "TOPRIGHT", -32, -6)
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function() f:StartMoving() end)
    titleBar:SetScript("OnDragStop", function()
        f:StopMovingOrSizing()
        SaveWindowGeometry(f)
    end)

    local titleIcon = titleBar:CreateTexture(nil, "ARTWORK")
    titleIcon:SetSize(18, 18)
    titleIcon:SetPoint("LEFT", titleBar, "LEFT", 6, 0)
    titleIcon:SetTexture("Interface\\Icons\\INV_Misc_Book_07")
    titleIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local titleText = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleText:SetPoint("LEFT", titleIcon, "RIGHT", 8, 0)
    titleText:SetText("|cFFFFD100Bleakfiber's Quest Tracker|r  |cFF8899A6Forever|r")

    local versionText = titleBar:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    versionText:SetPoint("LEFT", titleText, "RIGHT", 8, -1)
    versionText:SetText("v" .. tostring(ns.version))

    local refreshBtn = CreateStyledButton(titleBar, "Refresh", 65, 20, function()
        ns.ApplyAllSettings()
        Config:SyncAll()
        ns.Notify(L["Quest Tracker settings refreshed."])
    end, "Reapplies all visual settings and refreshes the quest tracker.")
    refreshBtn:SetPoint("RIGHT", titleBar, "RIGHT", -6, 0)

    local btnMovers = CreateStyledButton(titleBar, "Toggle Movers", 95, 20, function()
        if ns.Tracker and ns.Tracker.SetLocked then
            ns.Tracker:SetLocked(not (ns.db and ns.db.isLocked))
            Config:SyncAll()
        end
    end, "Unlocks or locks the quest tracker for click-and-drag repositioning.")
    btnMovers:SetPoint("RIGHT", refreshBtn, "LEFT", -6, 0)

    local titleDivider = f:CreateTexture(nil, "ARTWORK")
    titleDivider:SetHeight(1)
    titleDivider:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -36)
    titleDivider:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -36)
    titleDivider:SetColorTexture(COLORS.goldBorder[1], COLORS.goldBorder[2], COLORS.goldBorder[3], 0.6)

    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetSize(28, 28)
    closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    -- Resize grip
    local resizeGrip = CreateFrame("Button", nil, f)
    resizeGrip:SetSize(16, 16)
    resizeGrip:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -4, 4)
    resizeGrip:EnableMouse(true)
    local gripTex = resizeGrip:CreateTexture(nil, "ARTWORK")
    gripTex:SetAllPoints(resizeGrip)
    gripTex:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resizeGrip:SetScript("OnEnter", function() gripTex:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight") end)
    resizeGrip:SetScript("OnLeave", function() gripTex:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up") end)
    resizeGrip:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" then f:StartSizing("BOTTOMRIGHT") end
    end)
    resizeGrip:SetScript("OnMouseUp", function()
        f:StopMovingOrSizing()
        SaveWindowGeometry(f)
    end)

    local footerText = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    footerText:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 12, 8)
    footerText:SetText("|cFF667788" .. L["Use /bfq to toggle this window"] .. "|r")

    local contentPane = CreateFrame("Frame", nil, f, BACKDROP_TEMPLATE)
    contentPane:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -42)
    contentPane:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 24)
    contentPane:SetBackdrop(INSET_BACKDROP)
    contentPane:SetBackdropColor(unpack(COLORS.contentBg))
    contentPane:SetBackdropBorderColor(unpack(COLORS.goldMuted))
    f.contentPane = contentPane

    f:SetScript("OnShow", function()
        Config:EmbedOptionsIntoContainer(contentPane)
    end)
    f:SetScript("OnHide", function()
        if ns.Tracker and ns.Tracker.HideConfigOverlay then
            ns.Tracker:HideConfigOverlay()
        end
    end)

    self.standaloneFrame = f
    return f
end

function Config:ToggleConfigFrame()
    local f = self:GetOrCreateStandaloneFrame()
    if f:IsShown() then
        PlaySound(SOUNDKIT.IG_MAINMENU_CLOSE)
        f:Hide()
    else
        PlaySound(SOUNDKIT.IG_MAINMENU_OPEN)
        f:Show()
    end
end

-- Blizzard Settings (Esc > Options > AddOns) hosts the same options container
function Config:RegisterSettingsPanel()
    if self.settingsCategory or not (Settings and Settings.RegisterCanvasLayoutCategory) then return end

    local panel = CreateFrame("Frame")
    panel:Hide()
    local content = CreateFrame("Frame", nil, panel)
    content:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -8)
    content:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -8, 8)
    panel:SetScript("OnShow", function()
        Config:EmbedOptionsIntoContainer(content)
    end)
    panel:SetScript("OnHide", function()
        if ns.Tracker and ns.Tracker.HideConfigOverlay then
            ns.Tracker:HideConfigOverlay()
        end
    end)

    local category = Settings.RegisterCanvasLayoutCategory(panel, "Bleakfiber's Quest Tracker")
    Settings.RegisterAddOnCategory(category)
    self.settingsCategory = category
end

local PublicAPI = ns.PublicAPI

function PublicAPI:BuildMasterConfigUI(parentContainer)
    if not parentContainer then return end
    Config:EmbedOptionsIntoContainer(parentContainer.content or parentContainer)
end

--[[-----------------------------------------------------------------------------
    Slash commands
-------------------------------------------------------------------------------]]
local function ColorOnOff(enabled)
    return enabled and ("|cff00ff00" .. L["ON"] .. "|r") or ("|cffff3333" .. L["OFF"] .. "|r")
end

local function PrintPositionDebug()
    local frame = ns.Tracker and ns.Tracker:GetFrame()
    local pos = ns.db and ns.db.framePosition
    ns.Print(L["--- Tracker Position Debug ---"])
    if pos then
        ns.Print(string.format(L["Saved in DB: %s relative to %s at (%d, %d)"], tostring(pos.point), tostring(pos.relativePoint), pos.x or 0, pos.y or 0))
    else
        ns.Print(L["Saved in DB: default position"])
    end
    if frame then
        ns.Print(string.format(L["Live Frame: left=%.1f, top=%.1f, scale=%.2f"], frame:GetLeft() or -1, frame:GetTop() or -1, frame:GetScale() or 1))
    end
end

-- Lists every quest and whether Blizzard reports it as shareable (read-only; nothing is pushed)
local function PrintShareDiagnostics()
    local API = ns.API
    ns.Print(L["--- Quest Share Diagnostic ---"])
    local info, found = {}, 0
    for i = 1, API.GetNumQuestLogEntries() do
        API.GetQuestInfo(i, info)
        if not info.isHeader and info.questID then
            found = found + 1
            local status = API.IsQuestPushable(info.questID, i) and ("|cff00ff00" .. L["Shareable"] .. "|r") or ("|cffff4444" .. L["Not shareable"] .. "|r")
            ns.Print(string.format("  [%d] %s (ID %d) - %s", found, info.title or "?", info.questID, status))
        end
    end
    if found == 0 then
        ns.Print(L["No active quests found in quest log."])
    end
end

local function PrintZoneDiagnostics()
    local API = ns.API
    local mapID = C_Map.GetBestMapForUnit("player")
    local mapInfo = mapID and C_Map.GetMapInfo(mapID)
    ns.Print(L["--- Cross-Zone Diagnostics ---"])
    ns.Print(string.format(L["Zone: %s | Real: %s | Sub: %s"], GetZoneText() or "?", GetRealZoneText() or "?", GetSubZoneText() or ""))
    ns.Print(string.format(L["MapID: %s (%s)"], tostring(mapID), (mapInfo and mapInfo.name) or "?"))

    local info, header, count = {}, L["General"], 0
    for i = 1, API.GetNumQuestLogEntries() do
        API.GetQuestInfo(i, info)
        if info.isHeader then
            header = info.title or header
        elseif info.questID then
            count = count + 1
            local poiMap = C_QuestLog.GetMapForQuestPOIs and C_QuestLog.GetMapForQuestPOIs(info.questID)
            local poiInfo = poiMap and poiMap > 0 and C_Map.GetMapInfo(poiMap)
            local state = (info.isComplete == 1) and ("|cff00ff00" .. L["Turn-in"] .. "|r") or ("|cffffcc00" .. L["Incomplete"] .. "|r")
            ns.Print(string.format("  |cff00e5ff[%d]|r %s %s", info.questID, info.title or "?", state))
            ns.Print(string.format(L["     Header: %s | POI map: %s (%s)"], header, tostring(poiMap), (poiInfo and poiInfo.name) or L["None"]))
        end
    end
    if count == 0 then
        ns.Print(L["No active quests found in quest log."])
    end
end

local function PrintHelp()
    ns.Print("|cff00c0ffBleakfiber's Quest Tracker|r")
    local lines = {
        { "/bfq", L["Open the settings"] },
        { "/bfq standalone", L["Open the standalone settings window"] },
        { "/bfq onboard", L["Open the setup walkthrough"] },
        { "/bfq lock | unlock", L["Lock or unlock the tracker position"] },
        { "/bfq toggle", L["Expand or collapse the tracker"] },
        { "/bfq hide | show | togglehide", L["Hide or show the tracker (/bfqhide also works)"] },
        { "/bfq reset", L["Reset the tracker position"] },
        { "/bfq profile [name]", L["Show or switch the active profile"] },
        { "/bfq lang [code]", L["Show or set the language (e.g. deDE, auto)"] },
        { "/bfq testitem", L["Show or hide a test quest item button"] },
        { "/bfq questid [id]", L["Check whether a quest is new in WoW Forever"] },
        { "/bfq debug", L["Toggle debug & chat output"] },
        { "/bfq pos | sharetest | poi", L["Print position, quest sharing, or zone diagnostics"] },
        { "/bfq way x y [name]", L["Set a custom waypoint (also /bfqway)"] },
    }
    for _, line in ipairs(lines) do
        ns.Print(string.format("  |cff00ff00%s|r - %s", line[1], line[2]))
    end
end

local function HandleSlashCommands(msg)
    local command, rest = (msg or ""):match("^(%S*)%s*(.-)$")
    command = string.lower(command or "")

    if command == "lock" then
        ns.Tracker:SetLocked(true)
    elseif command == "unlock" then
        ns.Tracker:SetLocked(false)
    elseif command == "reset" then
        ns.Tracker:ResetPosition()
        ns.db.itemButtonPosition = nil
        if ns.StandaloneTracker then ns.StandaloneTracker:UpdateItemButtonVisibility() end
    elseif command == "toggle" then
        ns.Tracker:ToggleCollapse()
    elseif command == "hide" then
        ns.Tracker:HideTracker()
    elseif command == "show" then
        ns.Tracker:ShowTracker()
    elseif command == "togglehide" or command == "visibility" then
        ns.Tracker:ToggleVisibility()
    elseif command == "profile" then
        if rest ~= "" then
            ns.SwitchToProfile(rest)
            ns.Notify(string.format(L["Switched profile to: %s"], rest))
        else
            ns.Notify(string.format(L["Active Profile: %s"], ns.dbObject:GetCurrentProfile()))
        end
    elseif command == "lang" or command == "language" then
        if rest ~= "" then
            local code = (rest:lower() == "auto") and "auto" or rest
            ns.dbObject.global.language = code
            local active = ns.SetLanguage(code)
            ns.Notify(string.format(L["Language set to %s. Reload the interface (/reload) to apply everywhere."], ns.LANGUAGE_NAMES[active] or active))
        else
            local active = ns.GetActiveLanguage()
            ns.Notify(string.format(L["Current language: %s"], ns.LANGUAGE_NAMES[active] or active))
        end
    elseif command == "debug" then
        local enabled = not ns.IsChatOutputEnabled()
        ns.dbObject.global.chatOutput = enabled
        ns.Notify(string.format(L["Debug & chat output: %s"], ColorOnOff(enabled)))
        Config:SyncAll()
    elseif command == "pos" or command == "position" then
        ns.HintChatOutput()
        PrintPositionDebug()
    elseif command == "sharetest" or command == "testshare" then
        ns.HintChatOutput()
        PrintShareDiagnostics()
    elseif command == "poi" or command == "testzone" or command == "crosszone" then
        ns.HintChatOutput()
        PrintZoneDiagnostics()
    elseif command == "questid" then
        local questID = tonumber(rest)
        local title
        if not questID then
            -- The quest under the mouse, otherwise the active quest
            local st = ns.StandaloneTracker
            for qID, block in pairs(st.activeBlocks or {}) do
                if block:IsVisible() and block:IsMouseOver() then
                    questID = qID
                    break
                end
            end
            questID = questID or ns.activeQuestID
        end
        if not questID then
            ns.Notify(L["Hover a quest in the tracker, or type /bfq questid <quest ID>."])
            return
        end
        title = ns.API.GetTitleForQuestID(questID) or string.format(L["Quest #%d"], questID)
        local verdict = ns.API.IsForeverQuest(questID) and L["New in WoW Forever"] or L["Original Classic quest"]
        ns.Notify(string.format(L["%s (ID %d): %s"], title, questID, verdict))
    elseif command == "testitem" then
        local st = ns.StandaloneTracker
        if st:SetItemPreview(not st.itemPreview) then
            ns.Notify(st.itemPreview and L["Test quest item button shown."] or L["Test quest item button hidden."])
            Config:SyncAll()
        end
    elseif command == "onboard" or command == "onboarding" then
        ns.Onboarding:ShowWizard()
    elseif command == "standalone" then
        Config:ToggleConfigFrame()
    elseif command == "config" or command == "options" or command == "" then
        local hub = _G.BleakfibersAddonConfigForever
        if hub and hub.OpenToModule and not IsShiftKeyDown() then
            hub:OpenToModule("BleakfibersQuestTracker")
        else
            Config:ToggleConfigFrame()
        end
    elseif ns.WayfinderModule and ns.WayfinderModule.HandleTrackerSubcommand
        and ns.WayfinderModule:HandleTrackerSubcommand(command, rest) then
        return
    else
        ns.HintChatOutput()
        PrintHelp()
    end
end

SLASH_BLEAKFIBERQUESTTRACKER1 = "/bfq"
SLASH_BLEAKFIBERQUESTTRACKER2 = "/bleaktracker"
SLASH_BLEAKFIBERQUESTTRACKER3 = "/bqt"
SlashCmdList["BLEAKFIBERQUESTTRACKER"] = HandleSlashCommands

SLASH_BLEAKFIBERTRACKERHIDE1 = "/bfqhide"
SLASH_BLEAKFIBERTRACKERHIDE2 = "/bfhide"
SlashCmdList["BLEAKFIBERTRACKERHIDE"] = function()
    HandleSlashCommands("togglehide")
end

ns:RegisterCallback("ON_INITIALIZE", function()
    Config:RegisterSettingsPanel()
end)

ns:RegisterCallback("PROFILE_CHANGED", function()
    Config:SyncAll()
end)
