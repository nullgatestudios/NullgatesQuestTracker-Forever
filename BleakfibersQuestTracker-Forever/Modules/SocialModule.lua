local addonName, ns = ...

-- Localized Lua & WoW API bindings for performance & garbage reduction
local pairs, ipairs, type, tonumber, pcall = pairs, ipairs, type, tonumber, pcall
local string_format, string_lower = string.format, string.lower
local GetTime = GetTime
local PlaySound, PlaySoundFile = PlaySound, PlaySoundFile
local C_Timer, CreateFrame = C_Timer, CreateFrame
local IsInGroup, IsInRaid = IsInGroup, IsInRaid
local UnitExists, UnitName, UnitIsUnit, UnitIsConnected = UnitExists, UnitName, UnitIsUnit, UnitIsConnected

local API = ns.API
local L = ns.L
local wipe = ns.wipe

local SocialModule = {}
ns.SocialModule = SocialModule
ns:RegisterModule("SocialModule", SocialModule)

-- Sound effect presets with direct CASC FileDataIDs and SoundKit IDs
-- Sound effect presets with SoundKit IDs, classic sound names, and audio file paths
local SOUND_PRESETS = {
    -- Classic Subtle Sounds (Used for Objective Progress - Exactly 5 subtle Classic choices)
    whisper_ping = {
        name = "Whisper Ping (TellMessage)",
        kit = (SOUNDKIT and SOUNDKIT.TELL_MESSAGE) or 3081,
        soundName = "TellMessage",
        files = {
            "Sound\\Interface\\iTellMessage.ogg",
            "Sound\\Interface\\iTellMessage.wav",
            567431,
        },
    },
    coins = {
        name = "Gold Coin Ding",
        kit = (SOUNDKIT and SOUNDKIT.LOOT_COIN_DING) or 895,
        soundName = "LootCoinDing",
        files = {
            "Sound\\Interface\\LootCoinDing.ogg",
            "Sound\\Interface\\LootCoinDing.wav",
            567425,
        },
    },
    loot_clink = {
        name = "Loot Coin Clink",
        kit = (SOUNDKIT and SOUNDKIT.IG_BACKPACK_COIN_SELECT) or 880,
        soundName = "igBackPackCoinSelect",
        files = {
            "Sound\\Interface\\igBackPackCoinSelect.ogg",
            "Sound\\Interface\\igBackPackCoinSelect.wav",
        },
    },
    map_ping = {
        name = "Mini-Map Ping",
        kit = (SOUNDKIT and SOUNDKIT.MAP_PING) or 3175,
        soundName = "MapPing",
        files = {
            "Sound\\Interface\\MapPing.ogg",
            "Sound\\Interface\\MapPing.wav",
            567439,
        },
    },
    item_click = {
        name = "Subtle Click",
        kit = (SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON) or 856,
        soundName = "igMainMenuOptionCheckBoxOn",
        files = {
            "Sound\\Interface\\uChatScrollButton.ogg",
            "Sound\\Interface\\uChatScrollButton.wav",
        },
    },

    -- Quest Complete Sounds
    peon = {
        name = "Peon: \"Work complete!\"",
        kit = (SOUNDKIT and SOUNDKIT.UI_PEON_BUILDING_COMPLETE_01) or 6199,
        soundName = "PeonBuildingComplete1",
        files = {
            "Sound\\Creature\\Peon\\PeonBuildingComplete1.ogg",
            "Sound\\Creature\\Peon\\PeonBuildingComplete1.wav",
            558132,
        },
    },
    quest_complete = {
        name = "Classic Quest Complete Chime",
        kit = (SOUNDKIT and SOUNDKIT.IG_QUEST_LIST_COMPLETE) or 618,
        soundName = "igQuestListComplete",
        files = {
            "Sound\\Interface\\igQuestListComplete.ogg",
            "Sound\\Interface\\igQuestListComplete.wav",
            567400,
        },
    },
    level_up = {
        name = "Level Up Fanfare",
        kit = (SOUNDKIT and SOUNDKIT.LEVEL_UP) or 888,
        soundName = "LevelUp",
        files = {
            "Sound\\Interface\\LevelUp.ogg",
            "Sound\\Interface\\LevelUp.wav",
        },
    },
    raid_warning = {
        name = "Raid Warning Chime",
        kit = (SOUNDKIT and SOUNDKIT.RAID_WARNING) or 8959,
        soundName = "RaidWarning",
        files = {
            "Sound\\Interface\\RaidWarning.ogg",
            "Sound\\Interface\\RaidWarning.wav",
        },
    },
    ready_check = {
        name = "Ready Check Chime",
        kit = (SOUNDKIT and SOUNDKIT.READY_CHECK) or 8960,
        soundName = "ReadyCheck",
        files = {
            "Sound\\Interface\\ReadyCheck.ogg",
            "Sound\\Interface\\ReadyCheck.wav",
        },
    },
    pvp_horn = {
        name = "PvP Queue Horn",
        kit = (SOUNDKIT and SOUNDKIT.PVP_THROUGH_QUEUE) or 8456,
        soundName = "PVPThroughQueue",
        files = {
            "Sound\\Interface\\PVPThroughQueue.ogg",
            "Sound\\Interface\\PVPThroughQueue.wav",
        },
    },
    custom_beep = {
        name = "Bleakfiber Beep (Custom)",
        files = {
            "Interface\\AddOns\\" .. addonName .. "\\Media\\Sounds\\beep.wav",
            "Interface\\AddOns\\BleakfibersQuestTracker-Forever\\Media\\Sounds\\beep.wav",
        },
    },
    beep = {
        name = "Bleakfiber Beep (beep.wav)",
        files = {
            "Interface\\AddOns\\" .. addonName .. "\\Media\\Sounds\\beep.wav",
            "Interface\\AddOns\\BleakfibersQuestTracker-Forever\\Media\\Sounds\\beep.wav",
        },
    },
    click = {
        name = "Bleakfiber Click (click.wav)",
        files = {
            "Interface\\AddOns\\" .. addonName .. "\\Media\\Sounds\\click.wav",
            "Interface\\AddOns\\BleakfibersQuestTracker-Forever\\Media\\Sounds\\click.wav",
        },
    },
}

-- Aliases in SOUND_PRESETS
SOUND_PRESETS["Bleakfiber Beep"] = SOUND_PRESETS.beep
SOUND_PRESETS["Bleakfiber Click"] = SOUND_PRESETS.click

-- Sounds stay muted for a moment after login / loading screens
local soundSuppressedUntil = GetTime() + 2.0 -- Mute completion sounds during initial load
local lastSoundPlayTime = 0

-- Volume scaling controller (Temporarily adjusts playback channel CVar if < 100%)
local activeVolumeAdjustments = {}

local function PlaySoundWithVolume(playFunc, channel, volumePercent)
    channel = channel or "Master"
    volumePercent = tonumber(volumePercent) or 100
    if volumePercent > 100 then volumePercent = 100 end
    if volumePercent < 5 then volumePercent = 5 end

    -- Direct playback if at full volume or CVars unavailable
    if volumePercent >= 98 or not SetCVar or not GetCVar then
        playFunc(channel)
        return
    end

    local cvar = (channel == "SFX" and "Sound_SFXVolume")
        or (channel == "Ambience" and "Sound_AmbienceVolume")
        or (channel == "Music" and "Sound_MusicVolume")
        or "Sound_MasterVolume"

    local currentCVar = tonumber(GetCVar(cvar)) or 1.0

    if not activeVolumeAdjustments[cvar] then
        activeVolumeAdjustments[cvar] = {
            base = currentCVar,
            timer = nil,
        }
    end

    local state = activeVolumeAdjustments[cvar]
    local ratio = volumePercent / 100.0
    local targetVol = math.max(0.01, math.min(1.0, state.base * ratio))

    SetCVar(cvar, tostring(targetVol))
    playFunc(channel)

    if state.timer and state.timer.Cancel then
        state.timer:Cancel()
    end

    local restoreDelay = 1.2
    if C_Timer and C_Timer.NewTimer then
        state.timer = C_Timer.NewTimer(restoreDelay, function()
            SetCVar(cvar, tostring(state.base))
            activeVolumeAdjustments[cvar] = nil
        end)
    elseif C_Timer and C_Timer.After then
        C_Timer.After(restoreDelay, function()
            SetCVar(cvar, tostring(state.base))
            activeVolumeAdjustments[cvar] = nil
        end)
    end
end

function SocialModule:PlaySoundKey(choice, channel, volume)
    if not choice or choice == "" or choice == "none" or choice == "disabled" then
        return
    end

    channel = channel or "Master"
    volume = tonumber(volume) or 100

    local preset = SOUND_PRESETS[choice]

    PlaySoundWithVolume(function(ch)
        local played = false

        -- 1. Try runtime SOUNDKIT table first if preset has a known kit
        if SOUNDKIT and PlaySound and preset then
            local kitConst = (choice == "peon" and SOUNDKIT.UI_PEON_BUILDING_COMPLETE_01)
                or (choice == "quest_complete" and SOUNDKIT.IG_QUEST_LIST_COMPLETE)
                or (choice == "level_up" and SOUNDKIT.LEVEL_UP)
                or (choice == "raid_warning" and SOUNDKIT.RAID_WARNING)
                or (choice == "ready_check" and SOUNDKIT.READY_CHECK)
                or (choice == "map_ping" and SOUNDKIT.MAP_PING)
                or (choice == "item_click" and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
                or (choice == "pvp_horn" and SOUNDKIT.PVP_THROUGH_QUEUE)
                or (choice == "whisper_ping" and SOUNDKIT.TELL_MESSAGE)
                or (choice == "coins" and SOUNDKIT.LOOT_COIN_DING)
                or (choice == "loot_clink" and SOUNDKIT.IG_BACKPACK_COIN_SELECT)
            if kitConst then
                local ok, willPlay = pcall(PlaySound, kitConst, ch)
                if ok and willPlay ~= false then
                    played = true
                else
                    local ok2, willPlay2 = pcall(PlaySound, kitConst, "Master")
                    if ok2 and willPlay2 ~= false then
                        played = true
                    else
                        local ok3, willPlay3 = pcall(PlaySound, kitConst)
                        if ok3 and willPlay3 ~= false then
                            played = true
                        end
                    end
                end
            end
        end

        -- 2. Try numeric preset.kit
        if not played and preset and preset.kit and PlaySound then
            local ok, willPlay = pcall(PlaySound, preset.kit, ch)
            if ok and willPlay ~= false then
                played = true
            else
                local ok2, willPlay2 = pcall(PlaySound, preset.kit, "Master")
                if ok2 and willPlay2 ~= false then
                    played = true
                else
                    local ok3, willPlay3 = pcall(PlaySound, preset.kit)
                    if ok3 and willPlay3 ~= false then
                        played = true
                    end
                end
            end
        end

        -- 3. Try legacy sound name string via PlaySound
        if not played and preset and preset.soundName and PlaySound then
            local ok, willPlay = pcall(PlaySound, preset.soundName, ch)
            if ok and willPlay ~= false then
                played = true
            else
                local ok2 = pcall(PlaySound, preset.soundName)
                if ok2 then
                    played = true
                end
            end
        end

        -- 4. Try PlaySoundFile with exact paths and FileDataIDs from preset
        if not played and preset and preset.files and PlaySoundFile then
            for _, file in ipairs(preset.files) do
                local ok, willPlay = pcall(PlaySoundFile, file, ch)
                if ok and willPlay ~= false then
                    played = true
                    break
                else
                    local ok2, willPlay2 = pcall(PlaySoundFile, file, "Master")
                    if ok2 and willPlay2 ~= false then
                        played = true
                        break
                    else
                        local ok3, willPlay3 = pcall(PlaySoundFile, file)
                        if ok3 and willPlay3 ~= false then
                            played = true
                            break
                        end
                    end
                end
            end
        end

        -- 5. Try ns.FetchSound (resolves custom slot keys custom1..custom99, LSM sound names, or direct file paths)
        if not played and ns.FetchSound and PlaySoundFile then
            local file = ns.FetchSound(choice)
            if file and type(file) == "string" and file ~= "" then
                local ok, willPlay = pcall(PlaySoundFile, file, ch)
                if ok and willPlay ~= false then
                    played = true
                else
                    local ok2, willPlay2 = pcall(PlaySoundFile, file, "Master")
                    if ok2 and willPlay2 ~= false then
                        played = true
                    else
                        local ok3, willPlay3 = pcall(PlaySoundFile, file)
                        if ok3 and willPlay3 ~= false then
                            played = true
                        end
                    end
                end
            end
        end

        -- 6. Direct file path fallback if choice contains path or extension
        if not played and type(choice) == "string" and (choice:find("%.wav$") or choice:find("%.ogg$") or choice:find("%.mp3$") or choice:find("\\") or choice:find("/")) and PlaySoundFile then
            local ok, willPlay = pcall(PlaySoundFile, choice, ch)
            if ok and willPlay ~= false then
                played = true
            else
                local ok2, willPlay2 = pcall(PlaySoundFile, choice, "Master")
                if ok2 and willPlay2 ~= false then
                    played = true
                else
                    local ok3, willPlay3 = pcall(PlaySoundFile, choice)
                    if ok3 and willPlay3 ~= false then
                        played = true
                    end
                end
            end
        end

        -- 7. Fallback ONLY if choice was explicitly "peon"
        if not played and choice == "peon" and PlaySoundFile then
            local peonPreset = SOUND_PRESETS.peon
            if peonPreset and peonPreset.files then
                for _, file in ipairs(peonPreset.files) do
                    local ok, willPlay = pcall(PlaySoundFile, file, ch)
                    if ok and willPlay ~= false then break end
                end
            end
        end
    end, channel, volume)
end

function SocialModule:PlaySoundFileWithVolume(soundFile, channel, volume)
    if not soundFile or soundFile == "" then return end
    channel = channel or "Master"
    volume = tonumber(volume) or 100

    if ns.FetchSound then
        soundFile = ns.FetchSound(soundFile)
    end

    PlaySoundWithVolume(function(ch)
        local ok, willPlay = pcall(PlaySoundFile, soundFile, ch)
        if not ok or willPlay == false then
            local ok2, willPlay2 = pcall(PlaySoundFile, soundFile, "Master")
            if not ok2 or willPlay2 == false then
                pcall(PlaySoundFile, soundFile)
            end
        end
    end, channel, volume)
end

local function GetSoundDB()
    return ns.db and ns.db.sound
end

function SocialModule:PlayCompletionSound()
    local now = GetTime()
    if soundSuppressedUntil and now < soundSuppressedUntil then return end
    if lastSoundPlayTime and (now - lastSoundPlayTime) < 0.25 then return end

    local sdb = GetSoundDB()
    if sdb and sdb.enableCompleteSound == false then return end
    lastSoundPlayTime = now

    local channel = (sdb and sdb.completeSoundChannel) or "Master"
    local volume = (sdb and sdb.completeSoundVolume) or 100
    local choice = (sdb and sdb.soundChoice) or "peon"
    self:PlaySoundKey(choice, channel, volume)
end

function SocialModule:PlayObjectiveSound()
    local now = GetTime()
    if soundSuppressedUntil and now < soundSuppressedUntil then return end
    if lastSoundPlayTime and (now - lastSoundPlayTime) < 0.25 then return end

    local sdb = GetSoundDB()
    if sdb and sdb.enableObjectiveSound == false then return end
    lastSoundPlayTime = now

    local channel = (sdb and sdb.objectiveSoundChannel) or "Master"
    local volume = (sdb and sdb.objectiveSoundVolume) or 100
    local choice = (sdb and sdb.objectiveSoundChoice) or "whisper_ping"
    self:PlaySoundKey(choice, channel, volume)
end

function SocialModule:PlayPreviewSound(choice, channel, volume)
    local sdb = GetSoundDB()
    channel = channel or (sdb and sdb.completeSoundChannel) or "Master"
    volume = volume or (sdb and sdb.completeSoundVolume) or 100
    choice = choice or (sdb and sdb.soundChoice) or "peon"
    self:PlaySoundKey(choice, channel, volume)
end

function SocialModule:PlayPreviewObjectiveSound(choice, channel, volume)
    local sdb = GetSoundDB()
    channel = channel or (sdb and sdb.objectiveSoundChannel) or "Master"
    volume = volume or (sdb and sdb.objectiveSoundVolume) or 100
    choice = choice or (sdb and sdb.objectiveSoundChoice) or "whisper_ping"
    self:PlaySoundKey(choice, channel, volume)
end

--------------------------------------------------------------------------------
-- QUEST & OBJECTIVE COMPLETION DETECTION (sounds & party announcements)
--------------------------------------------------------------------------------
-- questStates[questID] = { complete = bool, finished = { [index] = bool }, counts = { [index] = n } }
local questStates = {}
local objectiveScratch = {}
local seenThisScan = {}

local function AnnouncePartyMessage(msg)
    if GetTime() < soundSuppressedUntil then return end
    local social = ns.db.social
    if not social.announceToParty then return end
    if not (IsInGroup and IsInGroup()) then return end

    local chatType = "PARTY"
    if IsInRaid and IsInRaid() then
        chatType = "RAID"
    elseif LE_PARTY_CATEGORY_INSTANCE and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        chatType = "INSTANCE_CHAT"
    end
    SendChatMessage(msg, chatType)
end

local function GetObjectiveCounts(obj)
    if obj.numFulfilled ~= nil and obj.numRequired ~= nil then
        return tonumber(obj.numFulfilled) or 0, tonumber(obj.numRequired) or 1
    end
    local text = obj.text
    if text then
        local c, m = text:match("(%d+)%s*/%s*(%d+)")
        if c and m then
            return tonumber(c) or 0, tonumber(m) or 1
        end
    end
    return obj.finished and 1 or 0, 1
end

local function CheckForCompletions()
    local isSuppressed = GetTime() < soundSuppressedUntil
    local social = ns.db.social
    local questJustCompleted = false
    local objectiveJustProgressed = false
    local info = {}

    wipe(seenThisScan)
    for i = 1, API.GetNumQuestLogEntries() do
        local row = API.GetQuestInfo(i, info)
        local questID = row and not row.isHeader and row.questID
        if questID then
            seenThisScan[questID] = true
            local title = row.title or L["Quest"]
            local objectives = API.GetQuestObjectives(questID, i, objectiveScratch)
            local isFinished = (row.isComplete == 1) or API.IsQuestComplete(questID, i, objectives)

            local state = questStates[questID]
            local isNew = (state == nil)
            if isNew then
                state = { finished = {}, counts = {} }
                questStates[questID] = state
            end

            -- Whole quest completion
            if isFinished and state.complete == false and not isSuppressed then
                questJustCompleted = true
                if social.announceQuestComplete ~= false then
                    AnnouncePartyMessage(string_format(L["[BFQ] %s (Complete)"], title))
                end
            end
            state.complete = isFinished and true or false

            -- Individual objective progress & completion
            for j, obj in ipairs(objectives) do
                local cur, maxVal = GetObjectiveCounts(obj)
                local wasFinished = state.finished[j]
                local wasCount = state.counts[j]
                state.counts[j] = cur

                if obj.finished then
                    if wasFinished == false and not isSuppressed then
                        if not isFinished then
                            objectiveJustProgressed = true
                        end
                        if social.announceObjectiveComplete ~= false then
                            AnnouncePartyMessage(string_format(L["[BFQ] %s: %s (Complete)"], title, obj.text or L["Objective"]))
                        end
                    end
                    state.finished[j] = true
                else
                    state.finished[j] = false
                    if not isNew and wasCount ~= nil and cur > wasCount and not isSuppressed then
                        objectiveJustProgressed = true
                        if social.announceObjectiveProgress then
                            local label = obj.text or L["Objective"]
                            if label:find("%d+%s*/%s*%d+") then
                                AnnouncePartyMessage(string_format("[BFQ] %s: %s", title, label))
                            else
                                AnnouncePartyMessage(string_format("[BFQ] %s: %s (%d/%d)", title, label, cur, maxVal))
                            end
                        end
                    end
                end
            end
        end
    end
    API.ReleaseObjectives(objectiveScratch)

    -- Forget quests that left the log
    for questID in pairs(questStates) do
        if not seenThisScan[questID] then
            questStates[questID] = nil
        end
    end

    if not isSuppressed then
        if questJustCompleted then
            SocialModule:PlayCompletionSound()
        elseif objectiveJustProgressed then
            SocialModule:PlayObjectiveSound()
        end
    end
end

-- Coalesces bursts of QUEST_LOG_UPDATE / UI_INFO_MESSAGE into one scan
local completionScanPending = false
local function RunCompletionScan()
    completionScanPending = false
    CheckForCompletions()
end

local function RequestCompletionScan()
    if completionScanPending then return end
    completionScanPending = true
    C_Timer.After(0.1, RunCompletionScan)
end

--------------------------------------------------------------------------------
-- QUEST SHARING & PARTY STATUS
--------------------------------------------------------------------------------
-- In-memory only: [questID] = { have = { [lowercase name] = true } }. Cleared on leaving the group.
ns.partyQuestData = {}

-- Normalize character name (lowercase, strip realm and whitespace)
local function CleanName(name)
    if not name or name == "" or name == UNKNOWNOBJECT then return "" end
    local raw = name:match("^([^-]+)") or name
    raw = raw:match("^%s*(.-)%s*$") or raw
    if raw == "" or raw == UNKNOWNOBJECT then return "" end
    return string_lower(raw)
end

local lastManuallySharedQuestID = nil
local lastManuallySharedTime = 0

function SocialModule:ShareQuest(questID, questLogIndex)
    if not (IsInGroup and IsInGroup()) then
        ns.Notify(L["You are not in a group."], 1.0, 0.3, 0.3)
        return false
    end
    if not questID then return false end

    lastManuallySharedQuestID = questID
    lastManuallySharedTime = GetTime()

    -- Blizzard only reports a quest as shareable once it is the selected quest
    if C_QuestLog and C_QuestLog.SetSelectedQuest then
        C_QuestLog.SetSelectedQuest(questID)
    end
    if not API.IsQuestPushable(questID, questLogIndex) then
        ns.Notify(L["This quest cannot be shared."], 1.0, 0.3, 0.3)
        return false
    end
    if API.ShareQuest(questID, questLogIndex) then
        ns.Notify(L["Shared quest with party."], 0.2, 1.0, 0.2)
        return true
    end
    ns.Notify(L["This quest cannot be shared."], 1.0, 0.3, 0.3)
    return false
end

function SocialModule:IsRecentlyShared(questID)
    return lastManuallySharedQuestID == questID and (GetTime() - lastManuallySharedTime) < 3.5
end

-- Escapes a localized Blizzard pattern such as "%s is already on that quest." into a Lua pattern
local function GlobalStringToPattern(globalPattern)
    if not globalPattern then return nil end
    local pat = globalPattern:gsub("([%(%)%.%[%]%*%+%-%?%^%$])", "%%%1")
    pat = pat:gsub("%%%%%d%%%$s", "(.-)"):gsub("%%%%s", "(.-)")
    return "^" .. pat .. "$"
end

local SHARE_FEEDBACK_PATTERNS = {}
for _, key in ipairs({
    "ERR_QUEST_ALREADY_HAVE_S", "ERR_QUEST_ALREADY_DONE_S", "ERR_QUEST_NOT_FOUND_S",
    "ERR_QUEST_ACCEPTED_S", "ERR_QUEST_DECLINED_S", "ERR_QUEST_LOG_FULL_S",
    "ERR_QUEST_BUSY_S", "ERR_QUEST_PUSH_SUCCESS_S",
}) do
    local pat = GlobalStringToPattern(_G[key])
    if pat then
        SHARE_FEEDBACK_PATTERNS[#SHARE_FEEDBACK_PATTERNS + 1] = pat
    end
end

-- Records which party members already have a quest from Blizzard's share feedback messages
local function HandleQuestShareSystemFeedback(msg)
    if not msg or not lastManuallySharedQuestID then return end
    if (GetTime() - lastManuallySharedTime) > 8 then return end

    local playerName
    for _, pat in ipairs(SHARE_FEEDBACK_PATTERNS) do
        playerName = msg:match(pat)
        if playerName then break end
    end
    if type(playerName) ~= "string" then return end

    local clean = CleanName(playerName)
    if clean == "" then return end
    local entry = ns.partyQuestData[lastManuallySharedQuestID]
    if not entry then
        entry = { have = {} }
        ns.partyQuestData[lastManuallySharedQuestID] = entry
    end
    entry.have[clean] = true
    if ns.StandaloneTracker then
        ns.StandaloneTracker:RequestUpdate()
    end
end

local function ColorizeName(rawName, classFile)
    local color = classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
    if color and color.colorStr then
        return string_format("|c%s%s|r", color.colorStr, rawName)
    elseif color and color.r then
        return ns.ColorToHex(color) .. rawName .. "|r"
    end
    return rawName
end

-- Detailed party quest status for tooltips and badges
function SocialModule:GetPartyQuestDetails(questID, questLogIndex)
    if not questID or not (IsInGroup and IsInGroup()) then return nil end
    local numMembers = (GetNumGroupMembers and GetNumGroupMembers()) or 0
    if numMembers <= 1 then return nil end

    questLogIndex = questLogIndex or API.GetLogIndexForQuestID(questID)
    local isPushable = API.IsQuestPushable(questID, questLogIndex)
    local haveData = (ns.partyQuestData[questID] and ns.partyQuestData[questID].have)

    local onQuest, missing = {}, {}
    local isRaid = IsInRaid and IsInRaid()
    local count = isRaid and numMembers or ((GetNumSubgroupMembers and GetNumSubgroupMembers()) or (numMembers - 1))
    local prefix = isRaid and "raid" or "party"

    for i = 1, count do
        local unit = prefix .. i
        if UnitExists(unit) and not UnitIsUnit(unit, "player") then
            local rawName = UnitName(unit)
            if rawName and rawName ~= "" and rawName ~= UNKNOWNOBJECT then
                local isOnQuest = API.IsUnitOnQuest(unit, questID, questLogIndex)
                    or (haveData and haveData[CleanName(rawName)]) or false
                local _, classFile = UnitClass(unit)
                local entry = {
                    unit = unit,
                    name = rawName,
                    coloredName = ColorizeName(rawName, classFile),
                    class = classFile,
                    isConnected = UnitIsConnected(unit),
                    isOnQuest = isOnQuest,
                }
                if isOnQuest then
                    onQuest[#onQuest + 1] = entry
                else
                    missing[#missing + 1] = entry
                end
            end
        end
    end

    return {
        totalGroupMembers = numMembers,
        onQuest = onQuest,
        missing = missing,
        onQuestCount = #onQuest,
        missingCount = #missing,
        isPushable = isPushable,
    }
end

-- Number of party members missing a quest, and whether it can be shared with them
function SocialModule:GetMissingPartyInfo(questID, questLogIndex)
    local details = self:GetPartyQuestDetails(questID, questLogIndex)
    if not details then
        return 0, false
    end
    return details.missingCount, details.isPushable
end

--------------------------------------------------------------------------------
-- EVENT INITIALIZATION
--------------------------------------------------------------------------------
function SocialModule:Initialize()
    local eventFrame = CreateFrame("Frame")
    self.eventFrame = eventFrame
    for _, event in ipairs({
        "PLAYER_ENTERING_WORLD", "QUEST_ACCEPTED", "QUEST_WATCH_UPDATE", "QUEST_LOG_UPDATE",
        "UNIT_QUEST_LOG_CHANGED", "QUEST_REMOVED", "CHAT_MSG_SYSTEM", "UI_INFO_MESSAGE",
        "GROUP_ROSTER_UPDATE", "GROUP_LEFT",
    }) do
        eventFrame:RegisterEvent(event)
    end

    local rosterUpdatePending = false
    local function RosterUpdate()
        rosterUpdatePending = false
        if ns.StandaloneTracker then ns.StandaloneTracker:RequestUpdate() end
    end

    eventFrame:SetScript("OnEvent", function(_, event, arg1)
        if event == "PLAYER_ENTERING_WORLD" then
            -- Seed the caches silently after loading screens
            soundSuppressedUntil = GetTime() + 2.0
            RequestCompletionScan()
            if not (IsInGroup and IsInGroup()) then
                wipe(ns.partyQuestData)
            end
        elseif event == "QUEST_LOG_UPDATE" or event == "QUEST_WATCH_UPDATE" or event == "QUEST_ACCEPTED" then
            RequestCompletionScan()
        elseif event == "UNIT_QUEST_LOG_CHANGED" then
            if arg1 == "player" then
                RequestCompletionScan()
            elseif ns.StandaloneTracker then
                ns.StandaloneTracker:RequestUpdate()
            end
        elseif event == "QUEST_REMOVED" then
            if arg1 then
                questStates[arg1] = nil
                ns.partyQuestData[arg1] = nil
            end
        elseif event == "CHAT_MSG_SYSTEM" then
            HandleQuestShareSystemFeedback(arg1)
        elseif event == "UI_INFO_MESSAGE" then
            RequestCompletionScan()
        elseif event == "GROUP_ROSTER_UPDATE" then
            if not rosterUpdatePending then
                rosterUpdatePending = true
                C_Timer.After(0.5, RosterUpdate)
            end
        elseif event == "GROUP_LEFT" then
            wipe(ns.partyQuestData)
            if ns.StandaloneTracker then ns.StandaloneTracker:RequestUpdate() end
        end
    end)

    -- Initial silent population of the completion cache
    CheckForCompletions()
end
