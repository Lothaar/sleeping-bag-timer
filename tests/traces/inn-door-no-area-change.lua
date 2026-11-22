-- Reported in game: bag used, then walking into an inn started the Sleep Timer.
-- An inn's Rested area can begin without an area change, so the only difference from
-- lying down is that the character is moving (speed 7 = running) when Rested begins.
EXPECT_SHOWN = false
SleepingBagTimerDebugLog = {
    { t = 100, e = "PLAYER_ENTERING_WORLD", a = { false, false }, resting = false },
    { t = 110, e = "UNIT_SPELLCAST_SUCCEEDED", a = { "player", "Cast-guid", 429961 }, resting = false },
    { t = 160, e = "PLAYER_UPDATE_RESTING", a = {}, resting = true, speed = 7 },
}
