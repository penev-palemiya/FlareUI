local _, ns = ...
local L = ns.L

local JunkDelete = {}
ns.JunkDelete = JunkDelete

local BAGS = { 0, 1, 2, 3, 4 }

local function On()
    local tweaks = ns.db and ns.db.profile and ns.db.profile.tweaks
    return tweaks and tweaks.enabled ~= false and tweaks.deleteJunkWhenFull and true or false
end

local function Loot(index)
    if GetLootSlotType(index) ~= Enum.LootSlotType.Item then return end
    local link = GetLootSlotLink(index)
    if type(link) ~= "string" then return end
    local itemID = C_Item.GetItemInfoInstant(link)
    local _, _, quantity, currencyID, _, locked = GetLootSlotInfo(index)
    if type(itemID) ~= "number" or itemID <= 0 or type(quantity) ~= "number" or quantity < 1
        or quantity ~= math.floor(quantity) or currencyID or locked ~= false then return end
    local unique, categoryName, limit, category = C_Item.GetItemUniquenessByID(itemID)
    if unique ~= false or categoryName or limit or category then return end
    local family = C_Item.GetItemFamily(itemID)
    local maxStack = C_Item.GetItemMaxStackSizeByID(itemID)
    if type(family) ~= "number" or family < 0 or type(maxStack) ~= "number" or maxStack < 1
        or maxStack ~= math.floor(maxStack) or quantity > maxStack then return end
    return { link = link, itemID = itemID, quantity = quantity, family = family, maxStack = maxStack }
end

local function Compatible(family, bagFamily)
    return bagFamily == 0 or bit.band(family, bagFamily) ~= 0
end

local function FindJunk(loot)
    local best, bestBag, bestSlot
    if not (Enum.BagIndex and type(Enum.BagIndex.Keyring) == "number"
        and type(Enum.BagIndex.ReagentBag) == "number") then return end
    local bags = { unpack(BAGS) }
    bags[#bags + 1], bags[#bags + 2] = Enum.BagIndex.Keyring, Enum.BagIndex.ReagentBag
    for _, bag in ipairs(bags) do
        local slots = C_Container.GetContainerNumSlots(bag)
        if type(slots) ~= "number" or slots < 0 then return end
        if slots > 0 then
            local free, family = C_Container.GetContainerNumFreeSlots(bag)
            if type(free) ~= "number" or free < 0 or type(family) ~= "number" or family < 0 then return end
            local compatible = Compatible(loot.family, family)
            if compatible and free > 0 then return end
            local empty = 0
            for slot = 1, slots do
                local info = C_Container.GetContainerItemInfo(bag, slot)
                if info then
                    if type(info.itemID) ~= "number" or type(info.stackCount) ~= "number" or info.stackCount < 1 then return end
                    if info.itemID == loot.itemID and info.stackCount < loot.maxStack then return end
                    if bag >= 0 and bag <= 4 and compatible and info.quality == Enum.ItemQuality.Poor and info.isLocked == false
                        and info.hasLoot == false and type(info.hyperlink) == "string" then
                        local quest = C_Container.GetContainerItemQuestInfo(bag, slot)
                        if type(quest) ~= "table" or type(quest.isQuestItem) ~= "boolean" or type(quest.isActive) ~= "boolean" then return end
                        if not quest.isQuestItem and not quest.questID and not quest.isActive then
                            local price
                            if info.hasNoValue == true then
                                price = 0
                            elseif info.hasNoValue == false then
                                local sell = select(11, C_Item.GetItemInfo(info.itemID))
                                if type(sell) == "number" and sell >= 0 then price = sell * info.stackCount end
                            end
                            if price and (not best or price < best.price) then
                                best = { price = price, itemID = info.itemID, link = info.hyperlink, count = info.stackCount }
                                bestBag, bestSlot = bag, slot
                            end
                        end
                    end
                else
                    empty = empty + 1
                end
            end
            if empty ~= free then return end
        end
    end
    return best, bestBag, bestSlot
end

local function Ready(button)
    if not On() or InCombatLockdown() or GetCursorInfo() or IsModifiedClick() then return end
    local element = button:GetParent()
    local index = element and element.GetSlotIndex and element:GetSlotIndex()
    if type(index) ~= "number" then return end
    local loot = Loot(index)
    if not loot then return end
    local junk, bag, slot = FindJunk(loot)
    if not junk then return end
    return loot, junk, bag, slot, index
end

local function SameLoot(a, b)
    return a and b and a.link == b.link and a.itemID == b.itemID and a.quantity == b.quantity
        and a.family == b.family and a.maxStack == b.maxStack
end

local function BeforeLootClick(button)
    local ok, loot, junk, bag, slot, index = pcall(Ready, button)
    if not ok or not loot then return end
    local checked, again, nextJunk, nextBag, nextSlot, nextIndex = pcall(Ready, button)
    if not checked or not SameLoot(loot, again) or nextBag ~= bag or nextSlot ~= slot or nextIndex ~= index
        or not nextJunk or nextJunk.itemID ~= junk.itemID or nextJunk.link ~= junk.link
        or nextJunk.count ~= junk.count or nextJunk.price ~= junk.price then return end
    local picked = pcall(C_Container.PickupContainerItem, bag, slot)
    local safe, canDelete = pcall(function()
        local kind, cursorID, cursorLink = GetCursorInfo()
        local free, family = C_Container.GetContainerNumFreeSlots(bag)
        local remaining = C_Container.GetContainerItemInfo(bag, slot)
        local element = button:GetParent()
        return picked and element and element.GetSlotIndex and element:GetSlotIndex() == index and kind == "item" and cursorID == junk.itemID and cursorLink == junk.link
            and type(free) == "number" and free > 0 and remaining == nil
            and type(family) == "number" and Compatible(loot.family, family)
            and On() and not InCombatLockdown() and not IsModifiedClick() and SameLoot(loot, Loot(index))
    end)
    if safe and canDelete then
        local deleted = pcall(DeleteCursorItem)
        if deleted and not GetCursorInfo() then
            print("|cff00ccffFlareUI:|r " .. L["Deleted %s to make room."]:format(junk.link))
            return
        end
    end
    pcall(function() if CursorHasItem() then ClearCursor() end end)
end

local hooked = setmetatable({}, { __mode = "k" })
local function OnAcquired(a, b)
    local frame = b ~= nil and b or a
    local item = type(frame) == "table" and frame.Item
    if not item or hooked[item] then return end
    hooked[item] = true
    item:HookScript("PreClick", BeforeLootClick)
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    local box = _G.LootFrame and _G.LootFrame.ScrollBox
    if not (box and ScrollUtil and ScrollUtil.AddAcquiredFrameCallback) then return end
    ScrollUtil.AddAcquiredFrameCallback(box, OnAcquired, JunkDelete, true)
end)
