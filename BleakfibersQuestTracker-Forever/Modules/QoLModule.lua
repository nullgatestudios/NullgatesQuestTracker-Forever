local addonName, ns = ...

-- Localized Lua & WoW API bindings for performance
local CreateFrame, GetTime = CreateFrame, GetTime
local IsShiftKeyDown = IsShiftKeyDown
local GetNumLootItems, LootSlot = GetNumLootItems, LootSlot

local API = ns.API

local QoLModule = {}
ns.QoLModule = QoLModule
ns:RegisterModule("QoLModule", QoLModule)

local eventFrame = CreateFrame("Frame")
QoLModule.eventFrame = eventFrame
QoLModule.isEnabled = false

local function GetConfig()
    return ns.db.qol
end

-- ===========================================================================
-- 1. Fast Auto Loot
-- Only speeds up looting the game would already do automatically: it follows
-- the "Auto Loot" interface option and the auto-loot toggle modifier key.
-- ===========================================================================

local lastLootTime = 0

local function IsAutoLootActive(autoLootArg)
    if autoLootArg ~= nil then
        return autoLootArg and true or false
    end
    local autoLootDefault = GetCVarBool and GetCVarBool("autoLootDefault")
    local toggleHeld = IsModifiedClick and IsModifiedClick("AUTOLOOTTOGGLE")
    return (autoLootDefault and not toggleHeld) or (not autoLootDefault and toggleHeld)
end

local function ProcessFastAutoLoot(autoLootArg)
    if not GetConfig().fastAutoLoot then return end
    if not IsAutoLootActive(autoLootArg) then return end

    -- LOOT_READY can fire more than once for the same window
    local now = GetTime()
    if now - lastLootTime < 0.3 then return end
    lastLootTime = now

    for i = GetNumLootItems(), 1, -1 do
        LootSlot(i)
    end
end

-- ===========================================================================
-- 2. Auto Sell Grey / Junk Items
-- ===========================================================================

local function ProcessAutoSellJunk(cfg)
    if not cfg.autoSellJunk then return end

    if C_MerchantFrame and C_MerchantFrame.SellAllJunkItems then
        C_MerchantFrame.SellAllJunkItems()
        return
    end

    for bag = 0, API.NUM_BAG_SLOTS do
        for slot = 1, (API.GetContainerNumSlots(bag) or 0) do
            local itemID, _, _, _, quality, hasNoValue = API.GetContainerItemInfo(bag, slot)
            if itemID and quality == 0 and not hasNoValue and API.UseContainerItem then
                API.UseContainerItem(bag, slot)
            end
        end
    end
end

-- ===========================================================================
-- 3. Auto Repair
-- ===========================================================================

local function ProcessAutoRepair(cfg)
    if not cfg.autoRepair then return end
    if not (CanMerchantRepair and CanMerchantRepair()) then return end

    local cost, canRepair = GetRepairAllCost()
    if not canRepair or not cost or cost <= 0 then return end

    if cfg.useGuildRepair and CanGuildBankRepair and CanGuildBankRepair() then
        local withdrawLimit = (GetGuildBankWithdrawMoney and GetGuildBankWithdrawMoney()) or 0
        if withdrawLimit == -1 or withdrawLimit >= cost then
            RepairAllItems(true)
            return
        end
    end

    if (GetMoney() or 0) >= cost then
        RepairAllItems(false)
    end
end

-- ===========================================================================
-- Lifecycle & Event Handlers
-- ===========================================================================

local function OnEvent(_, event, arg1)
    if event == "LOOT_READY" then
        ProcessFastAutoLoot(arg1)
    elseif event == "MERCHANT_SHOW" then
        local cfg = GetConfig()
        if cfg.shiftBypass ~= false and IsShiftKeyDown() then return end
        ProcessAutoSellJunk(cfg)
        ProcessAutoRepair(cfg)
    end
end

function QoLModule:Enable()
    if self.isEnabled then return end
    self.isEnabled = true
    eventFrame:RegisterEvent("LOOT_READY")
    eventFrame:RegisterEvent("MERCHANT_SHOW")
    eventFrame:SetScript("OnEvent", OnEvent)
end

function QoLModule:Disable()
    if not self.isEnabled then return end
    self.isEnabled = false
    eventFrame:UnregisterAllEvents()
    eventFrame:SetScript("OnEvent", nil)
end

function QoLModule:Initialize()
    if not ns.IsModuleEnabled("qol") then
        self:Disable()
        return
    end
    self:Enable()
end
