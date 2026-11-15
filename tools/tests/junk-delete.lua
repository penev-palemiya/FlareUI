local base = arg[1] or "."
local state, click, loader
local function band(a, b)
    local result, place = 0, 1
    while a > 0 and b > 0 do
        if a % 2 == 1 and b % 2 == 1 then result = result + place end
        a, b, place = math.floor(a / 2), math.floor(b / 2), place * 2
    end
    return result
end
bit = { band = band }
Enum = { ItemQuality = { Poor = 0 }, LootSlotType = { Item = 1 }, BagIndex = { Keyring = -1, ReagentBag = 5 } }
local ns = { L = setmetatable({}, { __index = function(_, key) return key end }), db = { profile = { tweaks = { deleteJunkWhenFull = true } } } }
function CreateFrame()
    loader = { RegisterEvent = function() end, UnregisterAllEvents = function() end }
    function loader:SetScript(_, fn) self.event = fn end
    return loader
end
local itemButton = { HookScript = function(_, _, fn) click = fn end }
local element = { GetSlotIndex = function() return state.index or 1 end }
function itemButton:GetParent() return element end
LootFrame = { ScrollBox = {} }
ScrollUtil = { AddAcquiredFrameCallback = function(_, callback) callback({ Item = itemButton }) end }
function InCombatLockdown() return state.combat or false end
function IsModifiedClick() return state.modified or false end
function GetLootSlotType() return state.lootType or 1 end
function GetLootSlotLink() return state.lootLink end
function GetLootSlotInfo() return 1, "loot", state.quantity, state.currency, 1, state.lootLocked end
function GetCursorInfo()
    if state.cursor then return "item", state.cursor.id, state.cursor.link end
end
function CursorHasItem() return state.cursor ~= nil end
function ClearCursor() state.cleared = true; state.cursor = nil end
function DeleteCursorItem() if not state.refuseDelete then state.deleted = true; state.cursor = nil end end
C_Item = {
    GetItemInfoInstant = function() return state.lootID end,
    GetItemUniquenessByID = function() return state.unique, nil, state.limit, state.category end,
    GetItemFamily = function() if state.apiError then error("item family failure") end return state.family end,
    GetItemMaxStackSizeByID = function() return state.maxStack end,
    GetItemInfo = function() return nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,state.price end,
}
C_Container = {
    GetContainerNumSlots = function(bag) return state.bags[bag] and 1 or 0 end,
    GetContainerNumFreeSlots = function(bag) local b = state.bags[bag]; return b.free, b.family end,
    GetContainerItemInfo = function(bag) return state.bags[bag].item end,
    GetContainerItemQuestInfo = function() return state.quest end,
    PickupContainerItem = function(bag)
        state.picked = true
        local info = state.bags[bag].item
        state.cursor = { id = state.cursorMismatch and 999 or info.itemID, link = info.hyperlink }
        if not state.stillOccupied then state.bags[bag].item = nil; state.bags[bag].free = 1 end
        if state.afterPickup then state.afterPickup() end
    end,
}
local module = assert(loadfile(base .. "/Modules/JunkDelete.lua"))
module("FlareUI", ns)
loader.event(loader, "PLAYER_LOGIN")
assert(click)
local originalPrint = print
print = function() end
local count = 0
local function reset()
    state = { lootLink = "loot:101", lootID = 101, quantity = 1, lootLocked = false, family = 4, maxStack = 20,
        price = 5, unique = false, quest = { isQuestItem = false, isActive = false }, bags = {
            [0] = { family = 0, free = 0, item = { itemID = 10, stackCount = 1, quality = 0, isLocked = false, hasLoot = false, hasNoValue = false, hyperlink = "junk:10" } }
        } }
    ns.db.profile.tweaks.deleteJunkWhenFull = true
end
local function run(name, mutate, expect)
    reset()
    if mutate then mutate() end
    local ok, err = pcall(click, itemButton)
    assert(ok, name .. ": " .. tostring(err))
    assert((state.deleted == true) == expect, name .. ": deleted=" .. tostring(state.deleted))
    if name == "delete refused" or name == "cursor mismatch" or name == "loot changed after pickup" then
        assert(state.cleared, name .. ": cursor not cleared")
    end
    count = count + 1
end
run("general bag", nil, true)
run("compatible specialty", function() state.bags[0].family = 4 end, true)
run("incompatible specialty", function() state.bags[0].family = 2 end, false)
run("unknown loot id", function() state.lootID = nil end, false)
run("missing link", function() state.lootLink = nil end, false)
run("unique item", function() state.unique = true end, false)
run("unknown uniqueness", function() state.unique = nil end, false)
run("limited item", function() state.category = 12 end, false)
run("unknown family", function() state.family = nil end, false)
run("unknown stack size", function() state.maxStack = nil end, false)
run("unknown bag family", function() state.bags[0].family = nil end, false)
run("loot locked", function() state.lootLocked = true end, false)
run("loot lock unknown", function() state.lootLocked = nil end, false)
run("loot quantity unknown", function() state.quantity = nil end, false)
run("loot quantity too large", function() state.quantity = 21 end, false)
run("loot currency", function() state.currency = 1 end, false)
run("empty slot mismatches free count", function() state.bags[0].item = nil end, false)
run("reagent bag has room", function() state.bags[5] = { family = 4, free = 1 } end, false)
run("keyring has room", function() state.bags[-1] = { family = 4, free = 1 } end, false)
run("unconfirmed pickup", function() state.stillOccupied = true end, false)
run("free general slot", function() state.bags[0].free = 1 end, false)
run("partial stack", function() state.bags[0].item.itemID = 101; state.bags[0].item.stackCount = 19 end, false)
run("partial stack too small", function() state.quantity = 5; state.bags[0].item.itemID = 101; state.bags[0].item.stackCount = 19 end, false)
run("locked junk", function() state.bags[0].item.isLocked = true end, false)
run("junk with contents", function() state.bags[0].item.hasLoot = true end, false)
run("quest item", function() state.quest.isQuestItem = true end, false)
run("quest id", function() state.quest.questID = 12 end, false)
run("unknown quest status", function() state.quest = nil end, false)
run("unknown price", function() state.price = nil end, false)
run("combat", function() state.combat = true end, false)
run("modifier", function() state.modified = true end, false)
run("cursor occupied", function() state.cursor = {id = 4} end, false)
run("feature disabled", function() ns.db.profile.tweaks.deleteJunkWhenFull = false end, false)
run("api error", function() state.apiError = true end, false)
run("delete refused", function() state.refuseDelete = true end, false)
run("cursor mismatch", function() state.cursorMismatch = true end, false)
run("loot changed after pickup", function() state.afterPickup = function() state.quantity = 2 end end, false)
run("loot row reused after pickup", function() state.afterPickup = function() state.index = 2 end end, false)
run("combat after pickup", function() state.afterPickup = function() state.combat = true end end, false)
run("bag changed after pickup", function() state.afterPickup = function() state.bags[0].family = 2 end end, false)
print = originalPrint
print("PASS: " .. count .. " junk deletion scenarios")
