# Sleeping Bag Timer

A WoW Forever addon that shows the current character how long until the Cozy Sleeping Bag pays out its next buff stack while they are sleeping on it.

## Language

**Cozy Sleeping Bag**:
The item (ID 211527) that, when used, places a bag on the ground for the character to sleep on.
_Avoid_: Bedroll, bag (alone, ambiguous with inventory bags)

**Placed Bag**:
The sleeping bag object on the ground after a character uses the Cozy Sleeping Bag item. It lasts about 10 minutes. Party members can sleep on it too, but the addon only cares about the character's own Placed Bag.
_Avoid_: Bag (alone)

**Sleeping**:
The state of a character lying down on a placed Cozy Sleeping Bag. The addon only matters while a character is Sleeping.
_Avoid_: Resting, laying down, camping

**Stack**:
One application of the **Well-Rested** buff, which gives +1% experience from kills and quests for 2 hours and can stack up to 3 times.

**Refresh**:
What a minute of Sleeping does once a character already has 3 Stacks: it resets the buff's duration to 2 hours without adding a Stack.

**Sleep Timer**:
The countdown shown while Sleeping. It runs one minute for each Stack still missing, or one minute until the Refresh at 3 Stacks. It restarts from the current Stack count every time the character lies down.
_Avoid_: Stack timer, rest timer

**Fully Stacked**:
The state after the Sleep Timer finishes while the character is still Sleeping.

**Bag Cooldown**:
The 1 hour wait after using the Cozy Sleeping Bag before it can be used again.

**Rested XP**:
WoW's standard bonus experience pool. Logging out while Sleeping grants it. It is unrelated to Stacks.
_Avoid_: Well-Rested (that is the Stack buff)

**Rested**:
The game state shown by the rested icon on the portrait. A character is Rested in inns, in cities, and while Sleeping. It is how the addon notices Sleeping.
_Avoid_: Resting
