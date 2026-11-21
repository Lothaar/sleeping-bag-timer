# sleeping-bag-timer
Sleeping bag timer WoW Forever Addon

Shows a mirror-timer style bar at the top of the screen while you're Sleeping on your own Cozy Sleeping Bag. It counts down to your 3rd Well-Rested Stack, or to the Refresh if you already have 3. See `GLOSSARY.md` and `docs/adr/`.

## Install

Copy or symlink the `SleepingBagTimer/` folder into `World of Warcraft/<flavor>/Interface/AddOns/`.

## Tests

- Timer logic: `luajit tests/logic_spec.lua`
- Replay a recorded session against a mocked WoW Forever API: `luajit tests/replay.lua tests/traces/<trace>.lua`
