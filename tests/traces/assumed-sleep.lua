-- Hand-written trace of the event sequence the addon was designed around.
-- Use the bag, lie down a few seconds later, gain a Stack, stand up.
SleepingBagTimerDebugLog = {
    { t = 100, e = "PLAYER_ENTERING_WORLD", a = { false, false }, resting = false },
    { t = 110, e = "UNIT_SPELLCAST_SUCCEEDED", a = { "player", "Cast-guid", 429961 }, resting = false },
    { t = 115, e = "PLAYER_UPDATE_RESTING", a = {}, resting = true },
    { t = 175, e = "UNIT_AURA", a = { "player" }, resting = true, stacks = 1, exp = 3775 },
    { t = 200, e = "PLAYER_UPDATE_RESTING", a = {}, resting = false, stacks = 1, exp = 3775 },
}
