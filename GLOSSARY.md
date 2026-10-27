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
_Avoid_: Loadout, gear set (a set is a named group of pieces)

**Haul**:
Everything in the pack that is not kit: materials, raw food, and anything else you gathered or looted.
_Avoid_: Loot (loot is what enemies drop)

**Return**:
Crossing the outpost gate inward. It makes you safe but moves nothing; depositing is a separate step at the stash.
_Avoid_: Banking, extraction

### The world

**Ring**:
One band of the wilderness around the outpost. Each ring is more dangerous and pays more than the one inside it.
_Avoid_: Zone, region

**Region**:
A whole separate land with its own outpost and rings: the frozen frontier is one, and a forest or a coast would be others.
_Avoid_: Area, map, world

**Dungeon**:
A pocket off a ring, entered by its mouth, with a boss at its end. It is harder than the ring it opens from, and nothing inside it is safe; you leave it back into that ring.
_Avoid_: Cave, instance, delve

**Gentle dungeon**:
A dungeon with a fire and a death chest just inside its mouth: the ring-one and ring-two dungeons.
_Avoid_: Easy dungeon

**Deep dungeon**:
A dungeon with neither a fire nor a death chest, where a death costs what it costs anywhere outside: the ring-three dungeon.
_Avoid_: Hard dungeon

**Mouth**:
Where you enter a dungeon from its ring. Nothing notices, chases or fights you across it.
_Avoid_: Entrance, portal, cave mouth

**Death chest**:
The chest just inside a gentle dungeon's mouth that holds what a death in that dungeon would have lost, until you fetch it or die there again.
_Avoid_: Gravestone, grave, loot box

**Way out**:
What opens at a dungeon's end each time its boss falls. It sets you down in the same ring, on the side nearest home.
_Avoid_: Portal, exit, shortcut

**Node**:
One thing you gather from: a tree, a rock, a fishing hole. It runs out after a few gathers and regrows.
_Avoid_: Resource, vein

**Spot**:
A small group of nodes at one place, usually two: two rocks, or two fishing holes.
_Avoid_: Cluster, patch

**Mine**:
A fixed place where many rocks (about six) of one or two kinds stand together, often guarded. Its rocks yield no more than anywhere else; there are just more of them.
_Avoid_: Hotspot, quarry, mining area

**Point of interest**:
A fixed place you find just by exploring, such as a wreck with a cache or a lore stone. It sets you no task.
_Avoid_: Landmark, secret, discovery

### Gear

**Gear tier**:
The rung a piece of gear sits on: wooden, bronze, iron, then steel. It shows on the character.
_Avoid_: Metal tier, smithing tier, material

**Smithing cap**:
The highest gear tier you can smith right now, raised by outpost upgrades. Found gear can sit above it.
_Avoid_: Smithing tier, craft limit

**Rare material**:
A material only ring three's enemies drop: rime steel, frost sinew or aurora glass, one for each combat style, each feeding that style's top gear sets.
_Avoid_: Rare drop, rare item (ring three's enemies drop it every kill; a rare drop comes from a rare roll)

**Set**:
A named group of gear pieces of one combat style that share a look. Each style has a mid, a mid-high and a high set, and four top sets.
_Avoid_: Gear set, outfit, armour set

**Top set**:
A set made at the workbench from ring three's rare materials, above steel.
_Avoid_: Endgame set, best-in-slot

**Set bonus**:
What wearing several pieces of one set gives on top of the pieces themselves. It grows as more pieces are worn, and each step adds to the ones before it.
_Avoid_: Set effect, full-set bonus

**Unique piece**:
A single named piece of gear that belongs to no set and carries one special effect. It is only ever found, from a rarity band.
_Avoid_: Unique, legendary, artifact

**Fur piece**:
Armour sewn from wolf pelts that slows the drain on your warmth but gives no defence. It has no gear tier, so it competes with metal armour at every stage.
_Avoid_: Fur armour, leather, lining

### Loot

**Pile**:
An item lying in the snow, from an enemy's loot or from the player's own drop. Anyone can pick it up until the snow takes it, a few minutes after it fell.
_Avoid_: Ground item, drop, loot (loot is what enemies drop)

**Loot table**:
What an enemy kind drops when it dies: its guaranteed loot, plus one rare roll.
_Avoid_: Drop table, loot list

**Rare roll**:
The single chance a kill gives at something beyond its guaranteed loot. It lands in at most one rarity band, or none. Pure chance, with no protection against bad luck.
_Avoid_: Bonus roll, proc, drop chance

**Rarity band**:
One rung of a rare roll: a set of odds and the pool of items it gives. A boss adds a band of pieces only it drops.
_Avoid_: Tier (a tier is a gear tier), rarity level

**Rare drop**:
Whatever a rare roll gives. It counts toward what a death keeps by its worth alone, with no rule of its own.
_Avoid_: Rare item, rare material (a rare material is ring three's guaranteed loot)

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

**Bounty**:
A short task posted at the outpost, such as killing five wolves, that pays a reward when done. It has no dialogue and no story.
_Avoid_: Quest, mission, task

### Combat

**Boss**:
The one enemy at a dungeon's end. Each time it falls, the dungeon's way out opens. It guards no ring gate.
_Avoid_: Guardian, raid boss

**Gate guardian**:
The enemy that stands at a ring gate and has to fall before the gate can open, like the bandit captain.
_Avoid_: Boss, gatekeeper

**Add**:
A lesser enemy of the ring's own kind that a boss calls into its fight once, when its health crosses a mark.
_Avoid_: Minion, summon, spawn

**Area blow**:
A boss's blow that strikes a marked patch of ground instead of the player. The boss is rooted from the moment it is told until it lands. Only stepping off the patch escapes it; no style or swap does.
_Avoid_: AOE, area attack, splash

**Ground mark**:
The red patch an area blow shows on the ground when it is told. It is exactly where the blow will land: in front of the boss, in a ring around it, or where the player stood.
_Avoid_: Telegraph circle, danger zone, hazard

**Burning ground**:
A patch some area blows leave behind, which keeps hurting anyone who stands on it for a few ticks.
_Avoid_: Fire (a fire warms), hazard, pool

**Ward**:
A boss's guard, from a health mark to the end of that phase, against every style but one: only the unwarded style hurts it.
_Avoid_: Immunity, shield, resistance

**Feint**:
A blow an enemy telegraphs exactly like a real one that then lands nothing: no hit, no miss, no damage. Its next blow is telegraphed on the feint tick, so reading through a feint is part of the counter.
_Avoid_: Fake attack, bluff, fake-out

**Fight phase**:
A change in how an enemy fights once its health falls below a mark: from then until it dies or heals, it works through a quicker cycle, so the end of a fight is the most dangerous part. The change is announced a tick ahead like a change of weapon.
_Avoid_: Enrage, rage mode, stage

**Answer**:
An enemy's switch of style in reply to the player's counter: the player swaps to the style with the edge on it, and on its next declaration it announces a stance into the style that beats theirs, early, instead of at its place in its cycle. It cannot answer again for a few ticks, and that gap is the player's opening.
_Avoid_: Counter-switch, adapt, react
