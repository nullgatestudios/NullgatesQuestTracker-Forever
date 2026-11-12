---------------------------------------------------------------------------
-- One-time migration from the pre-rebrand SavedVariables store
--
-- v1.3.0 renamed the add-on folder to "NullgatesQuestTracker-Forever", which
-- also renamed its SavedVariables file. WoW names SavedVariables files after
-- the add-on folder, so the renamed add-on could not see the settings players
-- still had in "BleakfiberTrackerDB" and everyone seemed to start from scratch.
--
-- v1.3.1 ships a tiny stub add-on (folder "BleakfibersQuestTracker-Forever")
-- whose only job is to declare "## SavedVariables: BleakfiberTrackerDB" so the
-- client keeps loading the old file into the global. This file then copies that
-- store into "NullgatesQuestTrackerDB" exactly once, before Core.lua builds the
-- AceDB object, so all further settings/profile migrations run on the imported
-- data as usual.
--
-- Both stores are AceDB-3.0 with the same layout, so a deep copy is all that is
-- required here; Core.lua's MIGRATIONS then upgrade the imported profiles (v4
-- renames the old Bleak* shared media names).
--
-- This file (and the stub folder) can be deleted once the rebrand is long past;
-- removing it only stops the one-time copy. It is always safe to run again: the
-- copy is skipped when the new store already holds data, and the old global is
-- cleared after a successful import so it is never applied twice.
---------------------------------------------------------------------------
local addonName, ns = ...

local OLD_DB = "BleakfiberTrackerDB"
local NEW_DB = "NullgatesQuestTrackerDB"
local OLD_FOLDER = "BleakfibersQuestTracker-Forever"

-- Recursively copies a value (the old store holds nested profile/global tables)
local function DeepCopy(source)
    if type(source) ~= "table" then return source end
    local copy = {}
    for key, value in pairs(source) do
        copy[key] = DeepCopy(value)
    end
    return copy
end

-- True when the value is a table with at least one entry
local function HasData(value)
    return type(value) == "table" and next(value) ~= nil
end

-- Copies the old store into the new one. Returns one of:
--   "migrated" - old settings were imported
--   "skipped"  - the new store already has settings (never overwritten)
--   "none"     - no old settings to import
--   "error"    - the copy failed (reported, add-on continues with defaults)
function ns.MigrateFromBleakfiber()
    if ns._migrationRan then return ns._migrationResult end
    ns._migrationRan = true

    local ok, result = pcall(function()
        local oldStore = _G[OLD_DB]
        local newStore = _G[NEW_DB]

        -- Fresh install, or the legacy stub is no longer installed
        if not HasData(oldStore) then
            return "none"
        end

        -- Never overwrite settings the player already has in the new store
        if HasData(newStore) then
            return "skipped"
        end

        local imported = DeepCopy(oldStore)
        imported._migratedFrom = OLD_FOLDER
        imported._migratedVersion = "1.2.4"
        _G[NEW_DB] = imported

        -- Clear the old global so the stub writes an empty file on logout and the
        -- copy can never be applied twice. The stub folder itself stays in place.
        _G[OLD_DB] = nil

        return "migrated"
    end)

    if not ok then
        ns._migrationResult = "error"
        if ns.ReportError then
            ns.ReportError(addonName .. " SavedVariables migration", result)
        end
        return "error"
    end

    ns._migrationResult = result
    return result
end
