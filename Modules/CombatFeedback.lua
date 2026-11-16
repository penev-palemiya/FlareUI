local _, ns = ...
local HUD = {}
ns.CombatFeedback = HUD
ns.modules.CombatFeedback = HUD

local WIDTH, HEIGHT, SPACING, SPEED, LIFE = 220, 180, 24, 120, 1.2
local MAX_VISIBLE, MAX_PENDING = 6, 24
local DEFENSE = { BLOCK = true, DODGE = true, PARRY = true, MISS = true, RESIST = true, ABSORB = true }
local frame, hint, db
local active, pending, pool = {}, {}, {}
local gap = SPACING / SPEED
local delay, debugEnabled = 0, false
local debugCounts = {}

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
    if not line then return end
    line.age = 0
    line.text:SetText(message.text)
    if message.category == "defense" then
        line.text:SetTextColor(0.55, 0.88, 0.62)
        line.x = db.defenseX
    elseif message.category == "damage" then
        line.text:SetTextColor(1, 0.30, 0.28)
        line.x = db.damageX
    else
        line.text:SetTextColor(0.35, 0.95, 0.45)
        line.x = db.defenseX
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
        if line.age >= LIFE then
            release(line)
            table.remove(active, i)
        else
            line.text:ClearAllPoints()
            line.text:SetPoint("BOTTOMLEFT", frame, "BOTTOM", line.x, y)
            line.text:SetAlpha(math.min(1, (LIFE - line.age) / 0.25))
        end
    end
    delay = math.max(0, delay - elapsed)
    if #pending > 0 and delay == 0 then
        spawn(table.remove(pending, 1))
        delay = gap
    end
    if #active == 0 and #pending == 0 then self:SetScript("OnUpdate", nil) end
end

local function event(_, _, unit, kind, flags, amount)
    if not db.enabled or not readable(unit) or unit ~= "player" or not readable(kind) or type(kind) ~= "string" then return end
    if debugEnabled and #kind <= 40 and kind:match("^[A-Z_]+$") then debugCounts[kind] = (debugCounts[kind] or 0) + 1 end
    if DEFENSE[kind] then
        local label = _G["COMBAT_TEXT_" .. kind] or _G[kind]
        if readable(label) and type(label) == "string" then add("defense", label) end
    elseif kind == "WOUND" or kind == "HEAL" then
        if not readable(amount) or amount == nil then
            add(kind == "WOUND" and "damage" or "heal", kind == "WOUND" and "DAMAGE" or "HEAL")
        elseif type(amount) == "number" then
            if amount > 0 then
                add(kind == "WOUND" and "damage" or "heal", (kind == "WOUND" and "-" or "+") .. tostring(amount))
                if kind == "WOUND" and readable(flags) and type(flags) == "string" then
                    local key = flags == "BLOCK_REDUCED" and "BLOCK" or flags
                    if key == "BLOCK" or key == "ABSORB" or key == "RESIST" then
                        local label = _G["COMBAT_TEXT_" .. key] or _G[key]
                        if readable(label) and type(label) == "string" then add("defense", label) end
                    end
                end
            elseif amount == 0 and kind == "WOUND" and readable(flags) and DEFENSE[flags] then
                local label = _G["COMBAT_TEXT_" .. flags] or _G[flags]
                if readable(label) and type(label) == "string" then add("defense", label) end
            end
        end
    end
end

function HUD.Command(text)
    local cmd, arg, value = text:match("^%s*(%S*)%s*(%S*)%s*(%S*)%s*$")
    cmd = (cmd or ""):lower()
    if cmd == "" then
        db.enabled = not db.enabled
        if db.enabled then
            frame:RegisterUnitEvent("UNIT_COMBAT", "player")
        else
            frame:UnregisterEvent("UNIT_COMBAT")
            for _, line in ipairs(active) do release(line) end
            active, pending, delay = {}, {}, 0
            frame:SetScript("OnUpdate", nil)
            frame.moving = false
            frame:StopMovingOrSizing()
            frame:EnableMouse(false)
            hint:Hide()
        end
        print("FlareUI combat text: " .. (db.enabled and "on" or "off"))
    elseif cmd == "debug" then
        debugEnabled = not debugEnabled
        print("FlareUI combat text debug: " .. (debugEnabled and "on" or "off"))
        if not debugEnabled then
            for kind, count in pairs(debugCounts) do print(kind .. ": " .. count) end
            debugCounts = {}
        end
    elseif cmd == "move" then
        if InCombatLockdown() then print("FlareUI: move unavailable in combat") return end
        frame.moving = not frame.moving
        frame:EnableMouse(frame.moving)
        hint:SetShown(frame.moving)
        if not frame.moving then frame:StopMovingOrSizing() end
    elseif cmd == "test" then
        add("damage", "-123")
        add("heal", "+85")
        for _, label in ipairs({ "BLOCK", "DODGE", "PARRY", "MISS", "ABSORB", "RESIST" }) do add("defense", label) end
    elseif cmd == "offset" and (arg == "damage" or arg == "defense") then
        local x = tonumber(value)
        if x and x >= -120 and x <= 120 then
            db[arg .. "X"] = x
            print("FlareUI combat text: " .. arg .. " X = " .. x)
        else
            print("FlareUI: offset must be between -120 and 120")
        end
    else
        print("/fui combattext | test | move | debug | offset damage|defense <x>")
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
    for i = 1, MAX_VISIBLE do
        local line = { text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge") }
        line.text:SetJustifyH("LEFT")
        line.text:SetShadowOffset(1, -1)
        line.text:Hide()
        pool[#pool + 1] = line
    end
    if db.enabled then frame:RegisterUnitEvent("UNIT_COMBAT", "player") end
    frame:SetScript("OnEvent", event)
    C_Timer.After(0, function()
        local previous = SlashCmdList.FLAREUI
        if not previous then return end
        SlashCmdList.FLAREUI = function(message)
            local command, sub = message:match("^%s*(%S+)%s*(.-)%s*$")
            if command and command:lower() == "combattext" then HUD.Command(sub) else previous(message) end
        end
    end)
end
