-- Bag used, then the character walks into an inn: the bar must NOT show.
EXPECT_SHOWN = false
SleepingBagTimerDebugLog = {
    { t = 100, e = "PLAYER_ENTERING_WORLD", a = { false, false }, resting = false },
    { t = 110, e = "UNIT_SPELLCAST_SUCCEEDED", a = { "player", "Cast-guid", 429961 }, resting = false },
    { t = 200, e = "PLAYER_UPDATE_RESTING", a = {}, resting = true },
    { t = 200.2, e = "ZONE_CHANGED_INDOORS", a = {}, resting = true },
}
