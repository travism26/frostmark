# Frostmark

A top-down extraction game: you leave a safe outpost, gather and fight in a frozen wilderness, and bring what you carry home safe by walking back through the gate.

## Language

### Carrying

**Pack**:
The slots you carry items in. Its contents are safe inside the walls but at risk whenever you are outside them, including anything left in it from the last trip.
_Avoid_: Bag, backpack, inventory (inventory is the pack plus worn equipment)

**Stash**:
The outpost's storage, and the only place an item is safe for good. Nothing in it is lost on death.
_Avoid_: Bank, chest, storage

**Carry weight**:
The kilograms you are carrying: everything in the pack plus everything worn.
_Avoid_: Load, encumbrance

**Carry limit**:
The carry weight above which you are overweight. It is the limit that ends a trip; pack slots are only a loose cap.
_Avoid_: Weight cap, max weight

**Overweight**:
Carrying more than the carry limit. You walk slower but can still carry more; there is no hard cap.
_Avoid_: Encumbered, overloaded

**Kit**:
What you carry to use rather than to put away: gear (anything you can equip), ammo, and cooked food.
_Avoid_: Loadout, gear set

**Haul**:
Everything in the pack that is not kit: materials, raw food, and anything else you gathered or looted.
_Avoid_: Loot (loot is what enemies drop)

**Return**:
Crossing the outpost gate inward. It makes you safe but moves nothing; depositing is a separate step at the stash.
_Avoid_: Banking, extraction

### The world

**Node**:
One thing you gather from: a tree, a rock, a fishing hole. It runs out after a few gathers and regrows.
_Avoid_: Resource, vein

**Spot**:
A small group of nodes at one place, usually two: two rocks, or two fishing holes.
_Avoid_: Cluster, patch

**Mine**:
A fixed place where many rocks (about six) of one or two kinds stand together, often guarded. Its rocks yield no more than anywhere else; there are just more of them.
_Avoid_: Hotspot, quarry, mining area

### Gear

**Gear tier**:
The rung a piece of gear sits on: wooden, bronze, iron, then steel. It shows on the character.
_Avoid_: Metal tier, smithing tier, material

**Smithing cap**:
The highest gear tier you can smith right now, raised by outpost upgrades. Found gear can sit above it.
_Avoid_: Smithing tier, craft limit

### Outpost

**Outpost upgrade**:
A step in the outpost tech tree, paid in materials and built inside the outpost.
_Avoid_: Building, structure

**Pack frame**:
The outpost upgrade that raises the carry limit.
_Avoid_: Backpack upgrade

**Bloomery**:
The outpost upgrade that raises the smithing cap from bronze to iron. It is optional: nothing past it requires it.
_Avoid_: Smelter, iron forge

### Combat

**Feint**:
A blow an enemy telegraphs exactly like a real one that then lands nothing: no hit, no miss, no damage. Its next blow is telegraphed on the feint tick, so reading through a feint is part of the counter.
_Avoid_: Fake attack, bluff, fake-out
