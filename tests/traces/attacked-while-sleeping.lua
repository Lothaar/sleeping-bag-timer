-- Sleeping, then a mob attacks: combat starts and an aura change arrives before Rested ends.
-- Auras are secret in combat, so the addon must not read them; the bar hides once Rested ends.
SleepingBagTimerDebugLog = {
    { t = 100, e = "PLAYER_ENTERING_WORLD", a = { false, false }, resting = false },
    { t = 110, e = "UNIT_SPELLCAST_SUCCEEDED", a = { "player", "Cast-guid", 429961 }, resting = false },
    { t = 115, e = "PLAYER_UPDATE_RESTING", a = {}, resting = true },
    { t = 140, e = "PLAYER_REGEN_DISABLED", a = {}, resting = true, combat = true },
    { t = 140.1, e = "UNIT_AURA", a = { "player" }, resting = true, combat = true },
    { t = 140.2, e = "PLAYER_UPDATE_RESTING", a = {}, resting = false, combat = true },
}
