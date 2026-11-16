local timers, frames, outputs = {}, {}, {}
local elapsedFrame
UIParent = { GetCenter = function() return 500, 300 end }
function canaccessvalue(v) return v ~= "secret" end
function InCombatLockdown() return false end
C_Timer = { After = function(_, f) timers[#timers + 1] = f end }
SlashCmdList = { FLAREUI = function(v) outputs[#outputs + 1] = v end }
C_CombatText = { GetCurrentEventInfo = function() return 123 end }
COMBAT_TEXT_DODGE = "Dodge"
COMBAT_TEXT_BLOCK = "Block"
local function font()
    local o = {}
    function o:SetJustifyH() end
    function o:SetShadowOffset() end
    function o:SetText(v) self.value = v end
    function o:SetTextColor(...) self.color = {...} end
    function o:ClearAllPoints() end
    function o:SetPoint(...) self.point = {...} end
    function o:SetAlpha(v) self.alpha = v end
    function o:Show() self.shown = true end
    function o:Hide() self.shown = false end
    function o:SetShown(v) self.shown = v end
    return o
end
function CreateFrame()
    local f = { scripts = {}, fonts = {} }
    function f:SetSize(w,h) self.width,self.height = w,h end
    function f:SetPoint() end
    function f:SetMovable() end
    function f:SetClampedToScreen() end
    function f:EnableMouse(v) self.mouse = v end
    function f:RegisterForDrag() end
    function f:SetScript(k,v) self.scripts[k] = v end
    function f:RegisterUnitEvent(e, unit) self.event, self.unit = e, unit end
    function f:UnregisterEvent() self.event = nil end
    function f:CreateFontString() local o = font(); self.fonts[#self.fonts+1] = o; return o end
    function f:StopMovingOrSizing() end
    function f:StartMoving() end
    function f:GetCenter() return 510, 320 end
    frames[#frames + 1] = f
    return f
end
local ns = { modules = {}, db = { profile = {} } }
assert(loadfile("Modules/CombatFeedback.lua"))("FlareUI", ns)
ns.CombatFeedback:Init()
local frame = frames[1]
assert(frame.mouse == false and frame.width == 220 and frame.height == 180 and frame.event == nil and #frame.fonts == 7)
for _, f in ipairs(timers) do f() end
SlashCmdList.FLAREUI("unrelated")
assert(outputs[1] == "unrelated")
SlashCmdList.FLAREUI("combattext")
assert(frame.event == "UNIT_COMBAT" and frame.unit == "player")
SlashCmdList.FLAREUI("combattext move")
assert(frame.mouse == true)
frame.scripts.OnDragStop(frame)
assert(ns.db.profile.combatFeedback.x == 10 and ns.db.profile.combatFeedback.y == 20)
SlashCmdList.FLAREUI("combattext move")
assert(frame.mouse == false)
SlashCmdList.FLAREUI("combattext offset damage 54")
SlashCmdList.FLAREUI("combattext offset defense 15")
SlashCmdList.FLAREUI("combattext test")
for _ = 1, 200 do
    if frame.scripts.OnUpdate then frame.scripts.OnUpdate(frame, 0.02) end
    local positions = {}
    for _, text in ipairs(frame.fonts) do
        if text.shown and text.point and text.point[1] == "BOTTOMLEFT" then positions[#positions+1] = text.point[5] end
    end
    table.sort(positions)
    for i = 2, #positions do assert(positions[i] - positions[i-1] >= 23.99) end
    assert(#positions <= 6)
end
assert(frame.scripts.OnUpdate == nil)
frame.scripts.OnEvent(frame, "UNIT_COMBAT", "player", "secret")
assert(frame.scripts.OnUpdate == nil)
frame.scripts.OnEvent(frame, "UNIT_COMBAT", "player", "DODGE")
assert(frame.scripts.OnUpdate)
frame.scripts.OnUpdate(frame, 0.02)
local found
for _, text in ipairs(frame.fonts) do if text.shown and text.value == "Dodge" then found = text; break end end
assert(found and found.point[4] == 15 and found.color[2] > found.color[1])
frame.scripts.OnEvent(frame, "UNIT_COMBAT", "player", "WOUND", nil, 123)
for _ = 1, 30 do frame.scripts.OnUpdate(frame, 0.02) end
for _, text in ipairs(frame.fonts) do if text.shown and text.value == "-123" then found = text; break end end
assert(found and found.point[4] == 54 and found.color[1] > found.color[2])
frame.scripts.OnEvent(frame, "UNIT_COMBAT", "player", "HEAL", nil, 55)
frame.scripts.OnEvent(frame, "UNIT_COMBAT", "player", "WOUND", nil, "secret")
frame.scripts.OnEvent(frame, "UNIT_COMBAT", "target", "WOUND", nil, 5)
for _ = 1, 100 do frame.scripts.OnEvent(frame, "UNIT_COMBAT", "player", "DODGE") end
for _ = 1, 500 do
    if frame.scripts.OnUpdate then frame.scripts.OnUpdate(frame, 0.02) end
    local ys = {}
    for _, text in ipairs(frame.fonts) do
        if text.shown and text.point and text.point[1] == "BOTTOMLEFT" then ys[#ys+1] = text.point[5] end
    end
    table.sort(ys)
    assert(#ys <= 6)
    for i = 2, #ys do assert(ys[i] - ys[i-1] >= 23.99) end
end
assert(frame.scripts.OnUpdate == nil)
assert(#frame.fonts == 7)
frame.scripts.OnEvent(frame, "UNIT_COMBAT", "player", "HEAL", nil, 55)
frame.scripts.OnUpdate(frame, 0.02)
local heal
for _, text in ipairs(frame.fonts) do if text.shown and text.value == "+55" then heal = text end end
assert(heal and heal.color[2] > heal.color[1])
frame.scripts.OnEvent(frame, "UNIT_COMBAT", "player", "WOUND", nil, "secret")
for _ = 1, 15 do frame.scripts.OnUpdate(frame, 0.02) end
local fallback
for _, text in ipairs(frame.fonts) do if text.shown and text.value == "DAMAGE" then fallback = true end end
assert(fallback)
SlashCmdList.FLAREUI("combattext debug")
frame.scripts.OnEvent(frame, "UNIT_COMBAT", "player", "secret", "secret", "secret")
frame.scripts.OnEvent(frame, "UNIT_COMBAT", "player", "WOUND", "secret", "secret")
SlashCmdList.FLAREUI("combattext debug")
SlashCmdList.FLAREUI("combattext")
assert(frame.event == nil)
print("PASS: shared stream, burst spacing, capacity, move, offsets, routing and secret input")
