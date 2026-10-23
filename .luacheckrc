-- Luacheck configuration for Bleakfiber's Quest Tracker - Forever
-- Run locally:  luacheck BleakfibersQuestTracker-Forever
std = "lua51+wow"
max_line_length = false
codes = true

exclude_files = {
    "**/Libs/**",
    "**/reference/**",
    "scratch/**",
    "zips/**",
}

ignore = {
    "211/addonName",   -- every file receives (addonName, ns) from the TOC loader
    "212",             -- unused arguments are normal in WoW event/script handlers
    "213",             -- unused loop variables (for _, v in ...)
    "431",             -- shadowing an upvalue (self, i, ...)
    "432",             -- shadowing an upvalue argument
    "542",             -- empty if branch (used for readability in event routers)
}

-- Globals this addon intentionally creates
globals = {
    "BleakfiberTrackerDB",
    "BleakfiberCustomSounds",
    "BleakfibersQuestTrackerForever",
    "BleakfiberQuestTracker",
    "Bleakfiber_ToggleTracker",
    "Bleakfiber_HideTracker",
    "Bleakfiber_ShowTracker",
    "SlashCmdList",
    "StaticPopupDialogs",
    "UISpecialFrames",
    "ColorPickerFrame",
    "GameTooltip",
    "DropDownList1",
    "DropDownList2",
    "SLASH_BLEAKFIBERQUESTTRACKER1",
    "SLASH_BLEAKFIBERQUESTTRACKER2",
    "SLASH_BLEAKFIBERQUESTTRACKER3",
    "SLASH_BLEAKFIBERTRACKERHIDE1",
    "SLASH_BLEAKFIBERTRACKERHIDE2",
}

-- WoW API & FrameXML globals the addon reads
stds.wow = {
    read_globals = {
        table = { fields = { "wipe" } },
        string = { fields = { "trim", "split" } },
    },
}

read_globals = {
    -- Lua extensions provided by the WoW client
    "wipe", "tinsert", "tremove", "strsplit", "strtrim", "strmatch", "time", "date", "format",

    -- Libraries
    "LibStub",

    -- C_* namespaces
    "C_AddOns", "C_ChatInfo", "C_Container", "C_GossipInfo", "C_Item", "C_Map", "C_MerchantFrame",
    "C_NamePlate", "C_PlayerInfo", "C_QuestLog", "C_Reputation", "C_Spell", "C_SuperTrack",
    "C_TaxiMap", "C_Texture", "C_Timer", "C_TooltipInfo",

    -- Frames & mixins
    "BackdropTemplateMixin", "ChatFontNormal", "CreateColor", "CreateFrame", "CreateVector2D",
    "DEFAULT_CHAT_FRAME", "GameFontHighlightSmall",
    "InterfaceOptionsFrame", "MainMenuExpBar", "MainStatusTrackingBarContainer", "MenuUtil",
    "MerchantFrame", "Minimap", "MinimapBorderTop", "MinimapCluster", "MinimapZoneTextButton",
    "Mixin", "ObjectiveTrackerFrame", "OpacitySliderFrame", "QuestLogFrame", "QuestMapFrame",
    "QuestWatchFrame", "ReputationWatchBar", "SELECTED_CHAT_FRAME", "Settings", "SettingsPanel",
    "StatusTrackingBarManager", "UIErrorsFrame", "UIParent", "WorldFrame", "WorldMapFrame",

    -- Global functions
    "AbandonQuest", "AcceptQuest", "AcknowledgeAutoAcceptQuest", "AddQuestWatch", "BreakUpLargeNumbers",
    "CanGuildBankRepair", "CanMerchantRepair", "ChatEdit_InsertLink", "ClearOverrideBindings",
    "CloseDropDownMenus", "CloseWindows", "CompleteQuest", "EasyMenu", "GetAddOnMetadata",
    "GetBindingKey", "GetCVar", "GetCVarBool", "GetCoinTextureString", "GetContainerItemID",
    "GetContainerItemInfo", "GetContainerNumSlots", "GetCurrentBindingSet", "GetCursorPosition",
    "GetDifficultyColor", "GetGuildBankWithdrawMoney", "GetInstanceInfo", "GetItemCooldown",
    "GetItemInfo", "GetItemInfoInstant", "GetItemQualityColor", "GetItemSpell", "GetLocale",
    "GetLootSlotType", "GetMaxPlayerLevel", "GetMoney", "GetNumAvailableQuests", "GetNumGroupMembers",
    "GetNumLootItems", "GetNumQuestChoices", "GetNumQuestLeaderBoards", "GetNumQuestLogChoices",
    "GetNumQuestLogEntries", "GetNumQuestLogRewards", "GetNumSubgroupMembers", "GetPlayerFacing",
    "GetQuestDifficultyColor", "GetQuestGreenRange", "GetQuestID", "GetQuestLink",
    "GetQuestLogChoiceInfo", "GetQuestLogIndexByID", "GetQuestLogItemLink", "GetQuestLogLeaderBoard",
    "GetQuestLogPushable", "GetQuestLogQuestText", "GetQuestLogRewardHonor", "GetQuestLogRewardInfo",
    "GetQuestLogRewardMoney", "GetQuestLogRewardSpell", "GetQuestLogRewardXP", "GetQuestLogSelection",
    "GetQuestLogSpecialItemInfo", "GetQuestLogTitle", "GetQuestMoneyToGet", "GetQuestReward",
    "GetQuestTagInfo", "GetRealZoneText", "GetRepairAllCost", "GetSubZoneText", "GetText", "GetTime",
    "GetXPExhaustion", "GetZonePVPInfo", "GetZoneText", "HideUIPanel", "InCombatLockdown",
    "IsAddOnLoaded", "IsAltKeyDown", "IsControlKeyDown", "IsInGroup", "IsInInstance", "IsInRaid",
    "IsModifiedClick", "IsQuestCompletable", "IsQuestWatched", "IsShiftKeyDown", "IsUnitOnQuest",
    "LootSlot", "PlaySound", "PlaySoundFile", "QuestFlagsPVP", "QuestGetAutoAccept",
    "QuestIsFromAreaTrigger", "QuestLogPushQuest", "QuestLog_Update", "QuestMapFrame_OpenToQuestDetails",
    "QuestPOIGetIconInfo", "QuestWatch_Update", "RegisterAddonMessagePrefix", "RegisterStateDriver",
    "ReloadUI", "RemoveQuestWatch", "RepairAllItems", "SaveBindings", "SecureHandlerSetFrameRef",
    "SecureHandlerWrapScript", "SelectAvailableQuest", "SelectActiveQuest", "SelectQuestLogEntry",
    "SendChatMessage", "SetAbandonQuest", "SetBinding", "SetCVar", "SetOverrideBindingClick",
    "SetRaidTargetIconTexture", "ShowUIPanel", "StaticPopup_Hide", "StaticPopup_Show", "TakeTaxiNode",
    "TaxiNodeName", "ToggleDropDownMenu", "ToggleGameMenu", "ToggleQuestLog", "ToggleWorldMap",
    "UIDropDownMenu_AddButton", "UIDropDownMenu_CreateInfo", "UIDropDownMenu_Initialize",
    "UnitClass", "UnitEffectiveLevel", "UnitExists", "UnitFactionGroup", "UnitIsConnected",
    "UnitIsPlayer", "UnitIsUnit", "UnitLevel", "UnitName", "UnitOnTaxi", "UnitQuestTrivialLevelRange",
    "UnitXP", "UnitXPMax", "UnregisterStateDriver", "UseContainerItem", "geterrorhandler",
    "hooksecurefunc", "securecallfunction",

    -- Constants & tables
    "ACCEPT", "CANCEL", "OKAY", "CUSTOM_CLASS_COLORS", "DifficultyUtil", "GetQuestUiMapID", "OpenWorldMap", "ERR_NOT_IN_COMBAT", "ERR_QUEST_ACCEPTED_S",
    "ERR_QUEST_ALREADY_DONE_S", "ERR_QUEST_ALREADY_HAVE_S", "ERR_QUEST_BUSY_S", "ERR_QUEST_DECLINED_S",
    "ERR_QUEST_LOG_FULL_S", "ERR_QUEST_NOT_FOUND_S", "ERR_QUEST_PUSH_SUCCESS_S", "Enum",
    "ITEM_QUALITY_COLORS", "LE_PARTY_CATEGORY_INSTANCE", "LOCALIZED_CLASS_NAMES_FEMALE",
    "LOCALIZED_CLASS_NAMES_MALE", "MAX_QUESTLOG_QUESTS", "NO", "NUM_BAG_SLOTS", "QuestDifficultyColors",
    "QuestieDB", "RAID_CLASS_COLORS", "SOUNDKIT", "STANDARD_TEXT_FONT", "UNKNOWNOBJECT", "YES",
}
