# Detect Sleeping from our own bag cast plus becoming Rested

The game gives no direct signal that a character is Sleeping: no aura appears until the first Stack arrives a minute later. So we infer Sleeping. It starts when the character becomes Rested within 10 minutes (the Placed Bag's lifetime) of casting the Cozy Sleeping Bag's use spell themselves, provided no area change happened at the same moment. It ends when the character stops being Rested. Testing in game confirmed that the Rested state turns on when a character lies on the bag and off when they stand up.

## Consequences

- Sleeping on a party member's Placed Bag is not detected, because we never see their cast. We chose this deliberately to keep things simple.
- Sleeping while already Rested (bag placed in an inn or city) is not detected, because nothing visibly changes. We accept that no Sleep Timer shows there.
- Becoming Rested at the same moment as an area change is ignored, so walking into an inn or city with a fresh Placed Bag nearby does not start a false Sleep Timer.
