local addonName, ns = ...

-- Localized Lua & WoW API bindings for performance
local CreateFrame = CreateFrame
local IsShiftKeyDown = IsShiftKeyDown
local IsInGroup = IsInGroup

local API = ns.API

local QuestAutomationModule = {}
ns.QuestAutomationModule = QuestAutomationModule
ns:RegisterModule("QuestAutomationModule", QuestAutomationModule)

local eventFrame = CreateFrame("Frame")
QuestAutomationModule.eventFrame = eventFrame
QuestAutomationModule.isEnabled = false

local function GetConfig()
    return ns.db.questAutomation
end

local function IsBypassed(cfg)
    return cfg.shiftBypass ~= false and IsShiftKeyDown()
end

-- A quest offered by another player (party share) rather than by an NPC or object
local function IsSharedQuestOffer()
    return UnitExists("questnpc") and UnitIsPlayer("questnpc") and true or false
end

-- ===========================================================================
-- Quest Automation Handlers
-- ===========================================================================

local function OnQuestAccepted(questID)
    local cfg = GetConfig()
    if not cfg.autoShare or IsBypassed(cfg) or not questID then return end
    if not (IsInGroup and IsInGroup()) then return end

    -- Share shortly after accepting so the quest log has the new entry
    C_Timer.After(0.3, function()
        if API.IsQuestPushable(questID) then
            API.ShareQuest(questID)
        end
    end)
end

local function OnQuestDetail()
    local cfg = GetConfig()
    if IsBypassed(cfg) then return end
    if QuestFlagsPVP and QuestFlagsPVP() then return end -- PvP-flagging quests always need a confirmation

    -- Auto-accept quests are already accepted by the server; acknowledging just closes the dialog
    if QuestGetAutoAccept and QuestGetAutoAccept() then
        if cfg.autoAcceptNPC and AcknowledgeAutoAcceptQuest then
            AcknowledgeAutoAcceptQuest()
        end
        return
    end

    if IsSharedQuestOffer() then
        if cfg.autoAcceptShared then
            AcceptQuest()
        end
    elseif cfg.autoAcceptNPC then
        AcceptQuest()
    end
end

local function OnQuestProgress()
    local cfg = GetConfig()
    if not cfg.autoTurnIn or IsBypassed(cfg) then return end
    if IsQuestCompletable and IsQuestCompletable() then
        CompleteQuest()
    end
end

local function OnQuestComplete()
    local cfg = GetConfig()
    if not cfg.autoTurnIn or IsBypassed(cfg) then return end

    -- Quests that cost money ask for confirmation in Blizzard's UI; leave those to the player
    if GetQuestMoneyToGet and (GetQuestMoneyToGet() or 0) > 0 then return end

    -- Multiple reward choices: pause so the player can pick their reward
    local numChoices = (GetNumQuestChoices and GetNumQuestChoices()) or 0
    if numChoices > 1 then return end

    -- Matches Blizzard's QuestRewardCompleteButton: index 1 for a single choice, 0 when there is none
    GetQuestReward(numChoices == 1 and 1 or 0)
end

local function OnGossipShow()
    local cfg = GetConfig()
    if not cfg.autoAcceptNPC or IsBypassed(cfg) then return end
    if C_GossipInfo and C_GossipInfo.GetAvailableQuests then
        local available = C_GossipInfo.GetAvailableQuests()
        if available and #available == 1 and not available[1].isTrivial then
            C_GossipInfo.SelectAvailableQuest(available[1].questID)
        end
    end
end

local function OnQuestGreeting()
    local cfg = GetConfig()
    if not cfg.autoAcceptNPC or IsBypassed(cfg) then return end
    if GetNumAvailableQuests and GetNumAvailableQuests() == 1 then
        SelectAvailableQuest(1)
    end
end

-- ===========================================================================
-- Lifecycle & Event Handlers
-- ===========================================================================

local handlers = {
    QUEST_ACCEPTED = function(arg1, arg2)
        -- Modern clients pass questID; older clients pass (questLogIndex, questID)
        OnQuestAccepted(arg2 or arg1)
    end,
    QUEST_DETAIL = OnQuestDetail,
    QUEST_PROGRESS = OnQuestProgress,
    QUEST_COMPLETE = OnQuestComplete,
    GOSSIP_SHOW = OnGossipShow,
    QUEST_GREETING = OnQuestGreeting,
}

local function OnEvent(_, event, ...)
    local handler = handlers[event]
    if handler then handler(...) end
end

function QuestAutomationModule:Enable()
    if self.isEnabled then return end
    self.isEnabled = true
    for event in pairs(handlers) do
        eventFrame:RegisterEvent(event)
    end
    eventFrame:SetScript("OnEvent", OnEvent)
end

function QuestAutomationModule:Disable()
    if not self.isEnabled then return end
    self.isEnabled = false
    eventFrame:UnregisterAllEvents()
    eventFrame:SetScript("OnEvent", nil)
end

function QuestAutomationModule:Initialize()
    if not ns.IsModuleEnabled("questAutomation") then
        self:Disable()
        return
    end
    self:Enable()
end
