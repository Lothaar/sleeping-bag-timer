-- Sleeping Bag Timer
-- Shows a Sleep Timer while the current character is Sleeping on their own
-- Placed Bag. See GLOSSARY.md and docs/adr/0001 for the domain and detection.

local ADDON_NAME, SBT = ...
SBT = SBT or {}

local BAG_ITEM_ID = 211527        -- Cozy Sleeping Bag
local BUFF_NAME = "Well-Rested"   -- the Stack buff
local MAX_STACKS = 3
local STACK_INTERVAL = 60         -- seconds of Sleeping per Stack / Refresh
local PLACED_BAG_LIFETIME = 600   -- a Placed Bag lasts about 10 minutes
local AREA_CHANGE_WINDOW = 1      -- seconds; Rested this close to an area change is ignored
local SETTLE_DELAY = 1            -- wait this long before deciding, so area events can arrive

---------------------------------------------------------------------------
-- Pure timer logic (no WoW API; exercised by tests/logic_spec.lua)
---------------------------------------------------------------------------

local Logic = {}
SBT.Logic = Logic

-- Seconds of Sleeping until Fully Stacked, given the current Stack count.
function Logic.SleepTimerDuration(stacks)
    if stacks >= MAX_STACKS then
        return STACK_INTERVAL -- one minute until the Refresh
    end
    return (MAX_STACKS - stacks) * STACK_INTERVAL
end

-- Creates the state of a Sleep Timer that starts at `now` with `stacks`.
function Logic.NewTimer(now, stacks, expiration)
    local duration = Logic.SleepTimerDuration(stacks)
    return {
        total = duration,
        deadline = now + duration,
        stacks = stacks,
        expiration = expiration,
        fullyStacked = false,
    }
end

-- Applies an aura observation to the timer. Re-anchors on each new Stack,
-- and becomes Fully Stacked on reaching 3 Stacks or on a Refresh at 3 Stacks.
function Logic.OnAura(timer, now, stacks, expiration)
    if timer.fullyStacked then
        timer.stacks, timer.expiration = stacks, expiration
        return timer
    end

    local gainedStack = stacks > timer.stacks
    local refreshed = stacks >= MAX_STACKS and timer.stacks >= MAX_STACKS
        and expiration and timer.expiration and expiration > timer.expiration + 1

    if (gainedStack and stacks >= MAX_STACKS) or refreshed then
        timer.fullyStacked = true
    elseif gainedStack then
        timer.deadline = now + (MAX_STACKS - stacks) * STACK_INTERVAL
    end

    timer.stacks, timer.expiration = stacks, expiration
    return timer
end

-- Seconds remaining, never negative. Reaching zero also means Fully Stacked.
function Logic.Remaining(timer, now)
    if timer.fullyStacked then return 0 end
    local remaining = timer.deadline - now
    if remaining <= 0 then
        timer.fullyStacked = true
        return 0
    end
    return remaining
end

function Logic.FormatTime(seconds)
    local s = math.ceil(seconds)
    return string.format("%d:%02d", math.floor(s / 60), s % 60)
end

-- Stop here when loaded outside the game (tests).
if not CreateFrame then return SBT end

---------------------------------------------------------------------------
-- WoW API wrappers
---------------------------------------------------------------------------

local GetItemSpell = (C_Item and C_Item.GetItemSpell) or GetItemSpell

-- Returns name, applications, expirationTime of the player's index-th buff, or nil.
-- WoW Forever lacks C_UnitAuras.GetPlayerAuraBySpellName, so we scan buffs by index
-- with whichever API the client has.
local function PlayerBuff(index)
    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        local aura = C_UnitAuras.GetAuraDataByIndex("player", index, "HELPFUL")
        if aura then return aura.name, aura.applications, aura.expirationTime end
        return nil
    end
    local name, _, count, _, _, expirationTime = (UnitAura or UnitBuff)("player", index, "HELPFUL")
    return name, count, expirationTime
end

local function ReadStacks()
    for index = 1, 40 do
        local name, stacks, expirationTime = PlayerBuff(index)
        if not name then break end
        if name == BUFF_NAME then
            -- A single application can be reported as 0.
            if not stacks or stacks < 1 then stacks = 1 end
            return stacks, expirationTime
        end
    end
    return 0, nil
end

local function BagSpellID()
    local _, spellID = GetItemSpell(BAG_ITEM_ID)
    return spellID
end

---------------------------------------------------------------------------
-- Bar styled like the Blizzard mirror timer (breath / fatigue)
---------------------------------------------------------------------------

local bar = CreateFrame("Frame", "SleepingBagTimerBar", UIParent)
bar:SetSize(206, 26)
bar:SetPoint("TOP", UIParent, "TOP", 0, -96)
bar:SetFrameStrata("HIGH")
bar:Hide()

local status = CreateFrame("StatusBar", nil, bar)
status:SetSize(195, 13)
status:SetPoint("TOP", bar, "TOP", 0, -2)
status:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
status:SetStatusBarColor(0.0, 0.39, 0.88)
status:SetMinMaxValues(0, 1)

local background = status:CreateTexture(nil, "BACKGROUND")
background:SetAllPoints(status)
background:SetColorTexture(0, 0, 0, 0.5)

local border = bar:CreateTexture(nil, "OVERLAY")
border:SetTexture("Interface\\CastingBar\\UI-CastingBar-Border")
border:SetSize(256, 64)
border:SetPoint("TOP", bar, "TOP", 0, 25)

local label = status:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
label:SetPoint("CENTER", status, "CENTER", 0, 1)

---------------------------------------------------------------------------
-- Sleeping detection and timer driving
---------------------------------------------------------------------------

local lastBagCastAt     -- GetTime() of our own Cozy Sleeping Bag cast
local lastAreaChangeAt  -- GetTime() of the latest area change
local timer             -- active Sleep Timer, nil when not Sleeping

local function Render()
    local now = GetTime()
    local remaining = Logic.Remaining(timer, now)
    if timer.fullyStacked then
        status:SetValue(1)
        label:SetText("Fully Stacked")
    else
        status:SetValue(remaining / timer.total)
        label:SetText("Sleeping  " .. Logic.FormatTime(remaining))
    end
end

local function StopSleeping()
    timer = nil
    bar:Hide()
end

local function StartSleeping(startedAt)
    local stacks, expiration = ReadStacks()
    timer = Logic.NewTimer(startedAt, stacks, expiration)
    Render()
    bar:Show()
end

local function CameFromAreaChange(restedAt)
    return lastAreaChangeAt and math.abs(restedAt - lastAreaChangeAt) <= AREA_CHANGE_WINDOW
end

local DebugLog -- [DEBUG-sbt]

local function OnBecameRested()
    local restedAt = GetTime()
    DebugLog("DECIDE_REST", lastBagCastAt or false, lastAreaChangeAt or false) -- [DEBUG-sbt]
    if not lastBagCastAt or restedAt - lastBagCastAt > PLACED_BAG_LIFETIME then return end
    -- Area events may arrive just after the Rested change, so decide a moment later.
    C_Timer.After(SETTLE_DELAY, function()
        DebugLog("SETTLED", restedAt, lastAreaChangeAt or false, timer and true or false) -- [DEBUG-sbt]
        if timer or not IsResting() then return end
        if CameFromAreaChange(restedAt) then return end
        StartSleeping(restedAt)
    end)
end

local elapsedSinceRender = 0
bar:SetScript("OnUpdate", function(_, elapsed)
    elapsedSinceRender = elapsedSinceRender + elapsed
    if elapsedSinceRender < 0.1 or not timer then return end
    elapsedSinceRender = 0
    Render()
end)

-- [DEBUG-sbt] event trace, saved to SleepingBagTimerDebugLog for replay in tests/replay.lua
local debugBuffer = {}
DebugLog = function(event, ...) -- [DEBUG-sbt]
    local stacks, exp = ReadStacks()
    debugBuffer[#debugBuffer + 1] = {
        t = GetTime(), e = event, a = { ... }, resting = IsResting(),
        stacks = stacks > 0 and stacks or nil, exp = exp,
        shown = bar:IsShown(),
    }
end -- [DEBUG-sbt]

local wasResting = false
local events = CreateFrame("Frame")

local OnEvent -- [DEBUG-sbt]
events:SetScript("OnEvent", function(self, event, ...) -- [DEBUG-sbt]
    if event == "ADDON_LOADED" and ... == ADDON_NAME then SleepingBagTimerDebugLog = debugBuffer end -- [DEBUG-sbt]
    if event == "ADDON_LOADED" then return end -- [DEBUG-sbt]
    DebugLog(event, ...) -- [DEBUG-sbt]
    local ok, err = pcall(OnEvent, self, event, ...) -- [DEBUG-sbt]
    if not ok then DebugLog("LUA_ERROR", tostring(err)) end -- [DEBUG-sbt]
    DebugLog("AFTER_" .. event) -- [DEBUG-sbt]
end) -- [DEBUG-sbt]

OnEvent = function(_, event, ...) -- [DEBUG-sbt] was: events:SetScript("OnEvent", function(_, event, ...)
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        local _, _, spellID = ...
        DebugLog("CAST_CHECK", spellID, BagSpellID()) -- [DEBUG-sbt]
        if spellID and spellID == BagSpellID() then
            lastBagCastAt = GetTime()
        end
    elseif event == "PLAYER_UPDATE_RESTING" then
        local resting = IsResting()
        if resting and not wasResting then
            OnBecameRested()
        elseif not resting and timer then
            StopSleeping()
        end
        wasResting = resting
    elseif event == "UNIT_AURA" then
        if timer then
            local stacks, expiration = ReadStacks()
            Logic.OnAura(timer, GetTime(), stacks, expiration)
            Render()
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        StopSleeping()
        lastAreaChangeAt = GetTime()
        wasResting = IsResting()
    else -- area change
        lastAreaChangeAt = GetTime()
    end
end -- [DEBUG-sbt] was: end)

events:RegisterEvent("ADDON_LOADED") -- [DEBUG-sbt]
events:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
events:RegisterUnitEvent("UNIT_AURA", "player")
events:RegisterEvent("PLAYER_UPDATE_RESTING")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("ZONE_CHANGED")
events:RegisterEvent("ZONE_CHANGED_INDOORS")
events:RegisterEvent("ZONE_CHANGED_NEW_AREA")
