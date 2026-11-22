# Detect Sleeping from our own bag cast plus becoming Rested while standing still

The game gives no direct signal that a character is Sleeping: no aura appears until the first Stack arrives a minute later. So we infer Sleeping. It starts when the character becomes Rested within 10 minutes (the Placed Bag's lifetime) of casting the Cozy Sleeping Bag's use spell themselves, while standing still, and not at the same moment as an area change. It ends when the character stops being Rested. Testing in game confirmed that the Rested state turns on when a character lies on the bag and off when they stand up.

## Consequences

- Sleeping on a party member's Placed Bag is not detected, because we never see their cast. We chose this deliberately to keep things simple.
- Sleeping while already Rested (bag placed in an inn or city) is not detected, because nothing visibly changes. We accept that no Sleep Timer shows there.
- Walking into an inn or city with a fresh Placed Bag nearby must not start a false Sleep Timer. Two checks cover this:
  - **Standing still.** An inn's Rested area can begin without any area change (seen in game), but the character is moving when they cross into it, and a character lying on the bag is not.
  - **No area change at the same moment.** This covers Rested states that come from the zone itself, such as cities.
