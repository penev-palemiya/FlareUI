local _, ns = ...
local HUD = {}
ns.CombatFeedback = HUD
ns.modules.CombatFeedback = HUD

local WIDTH, HEIGHT, SPACING, SPEED = 280, 132, 22, 70
local MAX_VISIBLE, MAX_PENDING = 6, 24
local DEFENSE = { BLOCK = true, DODGE = true, PARRY = true, MISS = true, EVADE = true, IMMUNE = true, RESIST = true, ABSORB = true,
    SPELL_BLOCK = true, SPELL_DODGE = true, SPELL_PARRY = true, SPELL_MISS = true, SPELL_EVADE = true, SPELL_IMMUNE = true,
    SPELL_RESIST = true, SPELL_ABSORB = true }
local DAMAGE = { DAMAGE = true, DAMAGE_CRIT = true, SPELL_DAMAGE = true, SPELL_DAMAGE_CRIT = true, DAMAGE_SHIELD = true }
local frame, hint, db
local active, pending, pool = {}, {}, {}
local gap = SPACING / SPEED
local delay = 0

local function readable(value)
    if canaccessvalue then return canaccessvalue(value) end
    if issecretvalue then return not issecretvalue(value) end
    return true
end

local function release(line)
    line.text:Hide()
    pool[#pool + 1] = line
end

local function add(category, text)
    if #pending >= MAX_PENDING then table.remove(pending, 1) end
    pending[#pending + 1] = { category = category, text = text }
    frame:SetScript("OnUpdate", HUD.Update)
end

local function spawn(message)
    if #active >= MAX_VISIBLE then release(table.remove(active, 1)) end
    local line = table.remove(pool)
    if not line then
        line = { text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge") }
        line.text:SetJustifyH("LEFT")
        line.text:SetShadowOffset(1, -1)
    end
    line.age = 0
    line.text:SetText(message.text)
    if message.category == "defense" then
        line.text:SetTextColor(0.55, 0.88, 0.62)
        line.x = db.defenseX
    else
        line.text:SetTextColor(1, 0.30, 0.28)
        line.x = db.damageX
    end
    line.text:ClearAllPoints()
    line.text:SetPoint("BOTTOMLEFT", frame, "BOTTOM", line.x, 0)
    line.text:SetAlpha(1)
    line.text:Show()
    active[#active + 1] = line
end

function HUD.Update(self, elapsed)
    for i = #active, 1, -1 do
        local line = active[i]
        line.age = line.age + elapsed
        local y = line.age * SPEED
        if y >= HEIGHT - SPACING then
            release(line)
            table.remove(active, i)
        else
            line.text:ClearAllPoints()
            line.text:SetPoint("BOTTOMLEFT", frame, "BOTTOM", line.x, y)
            line.text:SetAlpha(math.min(1, (HEIGHT - SPACING - y) / 28))
        end
    end
    delay = math.max(0, delay - elapsed)
    if #pending > 0 and delay == 0 then
        spawn(table.remove(pending, 1))
        delay = gap
    end
    if #active == 0 and #pending == 0 then self:SetScript("OnUpdate", nil) end
end

local function event(_, _, kind)
    if not readable(kind) or type(kind) ~= "string" then return end
    if DEFENSE[kind] then
        local key = kind:gsub("^SPELL_", "")
        local label = _G["COMBAT_TEXT_" .. key] or _G[key]
        if readable(label) and type(label) == "string" then add("defense", label) end
    elseif DAMAGE[kind] and C_CombatText and C_CombatText.GetCurrentEventInfo then
        local ok, amount = pcall(C_CombatText.GetCurrentEventInfo)
        if ok and readable(amount) and type(amount) == "number" and amount > 0 then
            add("damage", "-" .. tostring(amount))
        end
    end
end

function HUD.Command(text)
    local cmd, arg, value = text:match("^%s*(%S*)%s*(%S*)%s*(%S*)%s*$")
    cmd = (cmd or ""):lower()
    if cmd == "move" then
        if InCombatLockdown() then print("FlareUI: move unavailable in combat") return end
        frame.moving = not frame.moving
        frame:EnableMouse(frame.moving)
        hint:SetShown(frame.moving)
        if not frame.moving then frame:StopMovingOrSizing() end
    elseif cmd == "test" then
        add("defense", "DODGE")
        add("damage", "-123")
        add("defense", "BLOCK")
        add("damage", "-456")
    elseif cmd == "offset" and (arg == "damage" or arg == "defense") then
        local x = tonumber(value)
        if x and x >= -120 and x <= 120 then
            db[arg .. "X"] = x
            print("FlareUI combat text: " .. arg .. " X = " .. x)
        else
            print("FlareUI: offset must be between -120 and 120")
        end
    else
        print("/fui combattext move | test | offset damage|defense <x>")
    end
end

function HUD:Init()
    local profile = ns.db.profile
    profile.combatFeedback = profile.combatFeedback or {}
    db = profile.combatFeedback
    db.damageX = tonumber(db.damageX) or 40
    db.defenseX = tonumber(db.defenseX) or 12
    frame = CreateFrame("Frame", nil, UIParent)
    frame:SetSize(WIDTH, HEIGHT)
    frame:SetPoint("CENTER", UIParent, "CENTER", tonumber(db.x) or 0, tonumber(db.y) or 0)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(false)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) if self.moving and not InCombatLockdown() then self:StartMoving() end end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local x, y = self:GetCenter()
        local ux, uy = UIParent:GetCenter()
        if x and y and ux and uy then db.x, db.y = x - ux, y - uy end
    end)
    hint = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hint:SetPoint("CENTER")
    hint:SetText("Combat Feedback")
    hint:Hide()
    frame:RegisterEvent("COMBAT_TEXT_UPDATE")
    frame:SetScript("OnEvent", event)
    C_Timer.After(0, function()
        local previous = SlashCmdList.FLAREUI
        if not previous then return end
        SlashCmdList.FLAREUI = function(message)
            local sub = message:match("^%s*[Cc][Oo][Mm][Bb][Aa][Tt][Tt][Ee][Xx][Tt]%s*(.*)$")
            if sub then HUD.Command(sub) else previous(message) end
        end
    end)
end
