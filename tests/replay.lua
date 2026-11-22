-- Replays a SleepingBagTimerDebugLog trace through the real addon with a mocked WoW API.
-- Usage: luajit tests/replay.lua <trace.lua>
-- Traces in tests/traces/captured-*.lua were recorded in game by temporary instrumentation
-- (commit 7894e8f); the synthetic entries it wrote (CAST_CHECK, AFTER_*, ...) are skipped.
-- Exits 1 (red) if the Sleep Timer bar never appears while the trace has the character Sleeping.

local tracePath = assert(arg[1], "usage: luajit tests/replay.lua <trace.lua>")

-- Clock, rested state, aura, deferred timers ------------------------------------
local now, resting, aura = 0, false, nil
local pending = {}
local luaErrors = {}

local function runTimersUntil(t)
    table.sort(pending, function(a, b) return a.at < b.at end)
    while pending[1] and pending[1].at <= t do
        local job = table.remove(pending, 1)
        local saved = now
        now = job.at
        local ok, err = pcall(job.fn)
        if not ok then luaErrors[#luaErrors + 1] = err end
        now = math.max(saved, now)
    end
end

-- Mock frames -------------------------------------------------------------------
local frames = {}
local function newFrame(name)
    local f = { shown = true, scripts = {}, events = {}, name = name }
    f.everShown = false
    setmetatable(f, { __index = function(_, k) return function() end end })
    function f:Show() self.shown = true; self.everShown = true end
    function f:Hide() self.shown = false end
    function f:IsShown() return self.shown end
    function f:SetScript(k, fn) self.scripts[k] = fn end
    function f:RegisterEvent(e) self.events[e] = true end
    function f:RegisterUnitEvent(e) self.events[e] = true end
    function f:CreateTexture() return newFrame() end
    function f:CreateFontString() local fs = newFrame(); function fs:SetText(t) self.text = t end; return fs end
    frames[#frames + 1] = f
    if name then _G[name] = f end
    return f
end

CreateFrame = function(_, name) return newFrame(name) end
UIParent = newFrame("UIParent")
GetTime = function() return now end
IsResting = function() return resting end
C_Timer = { After = function(delay, fn) pending[#pending + 1] = { at = now + delay, fn = fn } end }
C_Item = { GetItemSpell = function(id) if id == 211527 then return "Unroll Bag", 429961 end end }
-- WoW Forever (16001): C_UnitAuras exists, but without GetPlayerAuraBySpellName (captured trace,
-- Lua error at line 91). GetAuraDataByIndex exists, but auras are secret in combat: calling it
-- then raises "Auras cannot be accessed when secret while tainted" (in-game error report).
local inCombat = false
local speed = 0
GetUnitSpeed = function(unit) if unit == "player" then return speed end return 0 end
C_UnitAuras = {
    GetAuraDataByIndex = function(unit, index, filter)
        if inCombat then error("GetAuraDataByIndex(): Auras cannot be accessed when secret while tainted by 'SleepingBagTimer'") end
        if unit == "player" and index == 1 and aura and (filter == nil or filter == "HELPFUL") then
            return { name = "Well-Rested", applications = aura.applications, expirationTime = aura.expirationTime }
        end
    end,
}
InCombatLockdown = function() return inCombat end
UnitAffectingCombat = function(unit) return unit == "player" and inCombat end

-- Load the addon ---------------------------------------------------------------
local chunk = assert(loadfile("SleepingBagTimer/SleepingBagTimer.lua"))
chunk("SleepingBagTimer", {})

local bar = _G.SleepingBagTimerBar
local eventFrame
for _, f in ipairs(frames) do if f.scripts.OnEvent then eventFrame = f end end
assert(bar and eventFrame, "addon did not create its frames")

-- Load and replay the trace -----------------------------------------------------
local env = {}
assert(loadfile(tracePath, "t", env))()
local trace = assert(env.SleepingBagTimerDebugLog, "trace file has no SleepingBagTimerDebugLog")

local SYNTHETIC = { DECIDE_REST = true, SETTLED = true, CAST_CHECK = true, LUA_ERROR = true }
local sleptAt, replayed = nil, 0
for _, entry in ipairs(trace) do
    local e = entry.e
    if not SYNTHETIC[e] and not e:match("^AFTER_") and not e:match("^ADDON_LOADED") then
        runTimersUntil(entry.t)
        now, resting, inCombat, speed = entry.t, entry.resting, entry.combat or false, entry.speed or 0
        aura = entry.stacks and { applications = entry.stacks, expirationTime = entry.exp } or nil
        if e == "PLAYER_UPDATE_RESTING" and resting then sleptAt = sleptAt or entry.t end
        local ok, err = pcall(eventFrame.scripts.OnEvent, eventFrame, e, unpack(entry.a or {}))
        if not ok then luaErrors[#luaErrors + 1] = err end
        replayed = replayed + 1
    elseif e == "LUA_ERROR" then
        print("trace recorded a Lua error in game: " .. tostring(entry.a and entry.a[1]))
    end
end
runTimersUntil(math.huge)

print(("replayed %d events, rested at %s, bar ever shown: %s"):format(replayed, tostring(sleptAt), tostring(bar.everShown)))
for _, err in ipairs(luaErrors) do print("Lua error during replay: " .. tostring(err)) end
if #luaErrors > 0 then print("RED: Lua error(s) during replay"); os.exit(1) end
local expectShown = env.EXPECT_SHOWN
if expectShown == nil then expectShown = true end -- real captures: the user lay down on their bag
if bar.everShown ~= expectShown then
    print("RED: bar shown = " .. tostring(bar.everShown) .. ", expected " .. tostring(expectShown))
    os.exit(1)
end
print("GREEN")
