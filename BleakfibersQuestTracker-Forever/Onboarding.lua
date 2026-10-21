local addonName, ns = ...

-- Localized Lua APIs
local ipairs = ipairs
local string_format = string.format
local CreateFrame, UIParent = CreateFrame, UIParent

local L = ns.L

local Onboarding = {}
ns.Onboarding = Onboarding

local onboardingFrame = nil
local currentStep = 1

local function MarkCompleted()
    if ns.db then ns.db.onboardingCompleted = true end
end

local function ApplyBackdrop(frame)
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false,
        tileSize = 16,
        edgeSize = 14,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    frame:SetBackdropColor(0.05, 0.07, 0.10, 0.95)
    frame:SetBackdropBorderColor(0.00, 0.75, 1.00, 0.85)
end

local function Refresh()
    ns.ApplyAllSettings()
    if ns.Config and ns.Config.SyncAll then ns.Config:SyncAll() end
end

-- ---------------------------------------------------------------------------
-- Step definitions (text is looked up when the step is first built, so it
-- follows the chosen language)
-- ---------------------------------------------------------------------------
local function Toggle(label, desc, get, set)
    return { type = "toggle", label = label, desc = desc, get = get, set = set }
end

local function DBToggle(group, key, label, desc)
    return Toggle(label, desc,
        function() return ns.db[group][key] == true end,
        function(v) ns.db[group][key] = v end)
end

local function DBToggleDefaultOn(group, key, label, desc)
    return Toggle(label, desc,
        function() return ns.db[group][key] ~= false end,
        function(v) ns.db[group][key] = v end)
end

local function SoundChoice(label, desc, enableKey, choiceKey, sounds, preview)
    return {
        type = "sound", label = label, desc = desc,
        get = function() return ns.db.sound[enableKey] ~= false end,
        set = function(v) ns.db.sound[enableKey] = v end,
        getChoice = function() return ns.db.sound[choiceKey] end,
        setChoice = function(v) ns.db.sound[choiceKey] = v end,
        sounds = sounds,
        preview = preview,
    }
end

local STEPS = {
    {
        title = "1. Choose a Visual Preset",
        desc = "Select an aesthetic theme. DataBars inherit your tracker styling by default, and every color, font, and border can be customized later in /bfq.",
        items = {
            { type = "preset", label = "Modern Dark Glass (Default)", desc = "Sleek semi-transparent dark backdrop with clean 1px border and class accents.", apply = function() ns.Config:ApplyModernGlassPreset() end },
            { type = "preset", label = "Classic WoW Plus", desc = "Traditional Blizzard parchment border with authentic cream paper backdrop and high contrast.", apply = function() ns.Config:ApplyClassicPreset() end },
            { type = "preset", label = "Ultra Minimalist", desc = "Zero background borders, compact typography, maximum screen real estate.", apply = function() ns.Config:ApplyMinimalPreset() end },
        },
    },
    {
        title = "2. Feature Modules",
        desc = "Turn addon modules on or off according to your preference. Disabled modules unload live with zero memory or event overhead.",
        items = {
            Toggle("Wayfinder Navigation", "Floating 3D HUD waypoint arrow & inline mini tracker arrows pointing to active objectives.",
                function() return ns.IsModuleEnabled("wayfinder") end, function(v) ns.SetModuleEnabled("wayfinder", v) end),
            Toggle("DataBars Suite", "Experience Bar, Precision Coordinates & Location Bar, and Quest Timer Bar.",
                function() return ns.IsModuleEnabled("databars") end, function(v) ns.SetModuleEnabled("databars", v) end),
            Toggle("Quest Automation", "Optional auto-accept and auto-turn-in for quests.",
                function() return ns.IsModuleEnabled("questAutomation") end, function(v) ns.SetModuleEnabled("questAutomation", v) end),
            Toggle("Quality of Life (QoL)", "Fast Auto Loot, junk item vendor selling, and auto repair.",
                function() return ns.IsModuleEnabled("qol") end, function(v) ns.SetModuleEnabled("qol", v) end),
        },
    },
    {
        title = "3. Quest Items & Countdown Timers",
        desc = "Configure usable quest items and timed objective displays:",
        items = {
            {
                type = "choice",
                label = "Quest Item Button Placement",
                options = {
                    { key = "outside_left", label = "Left Side (Outside Tracker)" },
                    { key = "inside_right", label = "Right Side (Inside Tracker)" },
                },
                get = function() return ns.db.itemButtonPlacement end,
                set = function(v)
                    ns.db.itemButtonPlacement = v
                    ns.db.itemButtonPosition = nil
                end,
            },
            Toggle("Show Timers in Objective Text (e.g. [04:12])", "Only shown on quests that have an active countdown timer.",
                function() return ns.db.showTimerInObjectives ~= false end,
                function(v) ns.db.showTimerInObjectives = v end),
        },
    },
    {
        title = "4. Quest Automation",
        desc = "Streamline your quest interactions. All automation pauses while you hold Shift:",
        items = {
            DBToggle("questAutomation", "autoAcceptNPC", "Auto Accept NPC Quests", "Automatically accept available quests when speaking with quest-givers."),
            DBToggle("questAutomation", "autoAcceptShared", "Auto Accept Shared Quests", "Automatically accept quests shared by party or raid members."),
            DBToggle("questAutomation", "autoTurnIn", "Auto Turn-In Quests (1 or Less Choice)", "Automatically complete and turn in quests offering 1 or 0 reward choices. Multi-choice rewards remain open for manual selection."),
            DBToggle("questAutomation", "autoShare", "Auto-Share Quests", "Automatically share newly accepted quests with your party when grouped."),
            DBToggleDefaultOn("questAutomation", "shiftBypass", "Shift-Key Bypass", "Hold Shift while talking to an NPC to temporarily pause all automated accepting and turning in."),
        },
    },
    {
        title = "5. Quality of Life (QoL)",
        desc = "Configure automatic merchant utilities and looting:",
        items = {
            DBToggleDefaultOn("qol", "fastAutoLoot", "Fast Auto Loot", "Loots everything instantly whenever the game's Auto Loot is active (Interface options or the auto-loot modifier key)."),
            DBToggle("qol", "autoSellJunk", "Auto Vendor Grey / Junk Items", "Automatically sells poor-quality junk items at merchants."),
            DBToggle("qol", "autoRepair", "Auto-Repair Equipment", "Automatically repairs damaged gear whenever visiting an armorer or repair merchant."),
            DBToggle("qol", "useGuildRepair", "Use Guild Bank for Repairs", "Charges repairs to your guild bank allowance if available, falling back to personal funds if unavailable."),
            DBToggleDefaultOn("qol", "shiftBypass", "Shift-Key Bypass", "Hold Shift while opening a merchant window to temporarily pause auto-selling and auto-repairing."),
        },
    },
    {
        title = "6. Social & Audio Feedback",
        desc = "Configure party chat notifications and audio feedback cues:",
        footer = "Pro Tip: Hold Shift while talking to an NPC or merchant to temporarily bypass automation. Type /bfq onboard anytime to revisit this walkthrough.",
        items = {
            Toggle("Announce Quest Progress to Party Chat", "Sends a short message to your party when you finish a quest.",
                function() return ns.db.social.announceToParty == true end,
                function(v)
                    ns.db.social.announceToParty = v
                    if v then
                        ns.db.social.announceQuestComplete = true
                    end
                end),
            SoundChoice("Play Objective Progress Sound", "Gentle audio cue whenever an objective progresses (e.g. looting 3/4 quest items).",
                "enableObjectiveSound", "objectiveSoundChoice", {
                    { key = "whisper_ping", label = "Whisper Ping" },
                    { key = "coins", label = "Gold Coin Ding" },
                    { key = "loot_clink", label = "Loot Coin Clink" },
                    { key = "map_ping", label = "Mini-Map Ping" },
                    { key = "item_click", label = "Subtle Click" },
                }, function(v) ns.SocialModule:PlayPreviewObjectiveSound(v) end),
            SoundChoice("Play Quest Complete Sound", "Audio fanfare when all objectives are finished and the quest is ready for turn-in.",
                "enableCompleteSound", "soundChoice", {
                    { key = "peon", label = "Peon: \"Work complete!\"" },
                    { key = "quest_complete", label = "Classic Quest Complete" },
                    { key = "whisper_ping", label = "Whisper Ping" },
                    { key = "coins", label = "Gold Coin Ding" },
                    { key = "level_up", label = "Level Up Fanfare" },
                    { key = "ready_check", label = "Ready Check Chime" },
                }, function(v) ns.SocialModule:PlayPreviewSound(v) end),
        },
    },
}

-- ---------------------------------------------------------------------------
-- Widgets (each step is built once and reused)
-- ---------------------------------------------------------------------------
local function CreateLabelPair(parent, anchor, label, desc, xOffset)
    local title = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("LEFT", anchor, "RIGHT", xOffset or 6, 0)
    title:SetText(L[label])

    local d = parent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    d:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 28, -2)
    d:SetPoint("RIGHT", parent, "RIGHT", -10, 0)
    d:SetJustifyH("LEFT")
    d:SetText(desc and L[desc] or "")
    return title, d
end

local function CycleButton(parent, width, options, get, set, onChange)
    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetSize(width, 22)
    local function Sync()
        local cur = get()
        for _, opt in ipairs(options) do
            if opt.key == cur then
                btn:SetText(L[opt.label])
                return
            end
        end
        btn:SetText(L[options[1].label])
    end
    btn:SetScript("OnClick", function()
        local cur = get()
        local nextIndex = 1
        for i, opt in ipairs(options) do
            if opt.key == cur then
                nextIndex = (i % #options) + 1
                break
            end
        end
        set(options[nextIndex].key)
        Sync()
        if onChange then onChange(options[nextIndex].key) end
    end)
    btn.Sync = Sync
    Sync()
    return btn
end

local function BuildStep(content, step)
    local page = CreateFrame("Frame", nil, content)
    page:SetAllPoints(content)
    page.syncers = {}

    local h = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
    h:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0)
    h:SetText("|cffffd100" .. L[step.title] .. "|r")

    local desc = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", h, "BOTTOMLEFT", 0, -6)
    desc:SetPoint("RIGHT", page, "RIGHT", 0, 0)
    desc:SetJustifyH("LEFT")
    desc:SetText(L[step.desc])

    local y = -44
    for _, item in ipairs(step.items) do
        if item.type == "preset" then
            local btn = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
            btn:SetSize(190, 24)
            btn:SetPoint("TOPLEFT", page, "TOPLEFT", 0, y)
            btn:SetText(L[item.label])
            btn:SetScript("OnClick", function()
                item.apply()
                ns.Notify(string_format(L["Applied preset: %s"], L[item.label]))
            end)
            local pDesc = page:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            pDesc:SetPoint("LEFT", btn, "RIGHT", 12, 0)
            pDesc:SetPoint("RIGHT", page, "RIGHT", 0, 0)
            pDesc:SetJustifyH("LEFT")
            pDesc:SetText(L[item.desc])
            y = y - 46
        elseif item.type == "choice" then
            local label = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            label:SetPoint("TOPLEFT", page, "TOPLEFT", 0, y)
            label:SetText(L[item.label])
            local btn = CycleButton(page, 240, item.options, item.get, item.set, Refresh)
            btn:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -6)
            page.syncers[#page.syncers + 1] = btn.Sync
            y = y - 56
        else -- toggle / sound
            local cb = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
            cb:SetPoint("TOPLEFT", page, "TOPLEFT", 8, y)
            CreateLabelPair(page, cb, item.label, item.desc)
            local dropdown
            local function SyncCheck()
                cb:SetChecked(item.get())
                if dropdown then dropdown:SetEnabled(item.get()) end
            end
            cb:SetScript("OnClick", function(self)
                item.set(self:GetChecked() and true or false)
                SyncCheck()
                Refresh()
            end)
            page.syncers[#page.syncers + 1] = SyncCheck
            y = y - 52
            if item.type == "sound" then
                dropdown = CycleButton(page, 200, item.sounds, item.getChoice, item.setChoice, item.preview)
                dropdown:SetPoint("TOPLEFT", cb, "BOTTOMLEFT", 28, -18)
                page.syncers[#page.syncers + 1] = dropdown.Sync
                y = y - 30
            end
            SyncCheck()
        end
    end

    if step.footer then
        local foot = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        foot:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", 8, 8)
        foot:SetPoint("RIGHT", page, "RIGHT", 0, 0)
        foot:SetJustifyH("LEFT")
        foot:SetText("|cff00c0ff" .. L[step.footer] .. "|r")
    end
    return page
end

function Onboarding:CreateWizardFrame()
    if onboardingFrame then return onboardingFrame end

    local f = CreateFrame("Frame", "BleakfiberOnboardingWizard", UIParent, "BackdropTemplate")
    onboardingFrame = f
    f:SetSize(560, 460)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
    f:SetFrameStrata("DIALOG")
    f:SetFrameLevel(100)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetClampedToScreen(true)
    ApplyBackdrop(f)

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", f, "TOP", 0, -16)
    title:SetText("|cff00c0ffBleakfiber's Quest Tracker|r - " .. L["Setup Walkthrough"])

    local stepText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    stepText:SetPoint("TOP", title, "BOTTOM", 0, -4)
    f.stepText = stepText

    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
    closeBtn:SetScript("OnClick", function()
        f:Hide()
        MarkCompleted()
    end)

    local content = CreateFrame("Frame", nil, f)
    content:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -56)
    content:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -20, 56)
    f.content = content
    f.pages = {}

    local backBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    backBtn:SetSize(90, 24)
    backBtn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 20, 16)
    backBtn:SetText(L["Back"])
    backBtn:SetScript("OnClick", function()
        if currentStep > 1 then
            Onboarding:RenderStep(currentStep - 1)
        end
    end)
    f.backBtn = backBtn

    local nextBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    nextBtn:SetSize(90, 24)
    nextBtn:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -20, 16)
    nextBtn:SetScript("OnClick", function()
        if currentStep < #STEPS then
            Onboarding:RenderStep(currentStep + 1)
        else
            f:Hide()
            MarkCompleted()
            ns.Notify(L["Setup complete! Type /bfq anytime to open the full settings."], 0.2, 1.0, 0.2)
        end
    end)
    f.nextBtn = nextBtn

    local skipBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    skipBtn:SetSize(130, 24)
    skipBtn:SetPoint("BOTTOM", f, "BOTTOM", 0, 16)
    skipBtn:SetText(L["Skip Walkthrough"])
    skipBtn:SetScript("OnClick", function()
        f:Hide()
        MarkCompleted()
    end)

    return f
end

function Onboarding:RenderStep(step)
    local f = self:CreateWizardFrame()
    currentStep = step
    f.stepText:SetText(string_format(L["Step %d of %d"], step, #STEPS))
    f.backBtn:SetEnabled(step > 1)
    f.nextBtn:SetText(step == #STEPS and L["Finish"] or L["Next"])

    for i, page in pairs(f.pages) do
        page:SetShown(i == step)
    end
    local page = f.pages[step]
    if not page then
        page = BuildStep(f.content, STEPS[step])
        f.pages[step] = page
    end
    page:Show()
    for _, sync in ipairs(page.syncers) do sync() end
end

function Onboarding:ShowWizard()
    local f = self:CreateWizardFrame()
    f:Show()
    self:RenderStep(1)
end

-- First login onboarding
function Onboarding:CheckFirstTimeUser()
    if ns.db and not ns.db.onboardingCompleted then
        self:ShowWizard()
    end
end
