-- Run with: luajit tests/logic_spec.lua
local SBT = dofile("SleepingBagTimer/SleepingBagTimer.lua")
local L = SBT.Logic

local failures = 0
local function check(name, actual, expected)
    if actual ~= expected then
        failures = failures + 1
        print(("FAIL %s: expected %s, got %s"):format(name, tostring(expected), tostring(actual)))
    else
        print("ok   " .. name)
    end
end

-- Sleep Timer duration per current Stack count
check("0 Stacks -> 3:00", L.SleepTimerDuration(0), 180)
check("1 Stack -> 2:00", L.SleepTimerDuration(1), 120)
check("2 Stacks -> 1:00", L.SleepTimerDuration(2), 60)
check("3 Stacks -> 1:00 until Refresh", L.SleepTimerDuration(3), 60)

-- A new Stack re-anchors the countdown
do
    local t = L.NewTimer(1000, 0, nil)
    L.OnAura(t, 1058, 1, 4658) -- Stack arrives 2s early
    check("re-anchor after early Stack", L.Remaining(t, 1058), 120)
    check("total unchanged", t.total, 180)
    L.OnAura(t, 1118, 2, 4718)
    L.OnAura(t, 1178, 3, 4778)
    check("Fully Stacked on reaching 3", t.fullyStacked, true)
    check("Fully Stacked remaining is 0", L.Remaining(t, 1179), 0)
end

-- Refresh at 3 Stacks completes the timer
do
    local t = L.NewTimer(1000, 3, 3000)
    L.OnAura(t, 1030, 3, 3000) -- unrelated aura update
    check("no Refresh yet", t.fullyStacked, false)
    L.OnAura(t, 1060, 3, 4660)
    check("Fully Stacked on Refresh", t.fullyStacked, true)
end

-- Deadline passing also means Fully Stacked
do
    local t = L.NewTimer(1000, 2, 2000)
    check("counting down", L.Remaining(t, 1030), 30)
    check("deadline passes", L.Remaining(t, 1061), 0)
    check("Fully Stacked after deadline", t.fullyStacked, true)
end

check("format 2:15", L.FormatTime(134.2), "2:15")
check("format 0:00", L.FormatTime(0), "0:00")

if failures > 0 then
    print(failures .. " failure(s)")
    os.exit(1)
end
print("all passed")
