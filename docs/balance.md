# Balance: reaching the bandit captain

The brief's first playable ends at the bandit captain, and a new character should reach him in about thirty minutes, inside one evening session ([game-brief.md](game-brief.md#first-playable), [roadmap.md](roadmap.md) section 5). This file records how that was measured and what was tuned to get there, in [#26](https://github.com/travism26/frostmark/issues/26). The rules and every number live in [simulation.md](simulation.md).

## How it is measured

A person cannot be timed here, so a script plays a new character through the simulation's command interface, as a first-time player would, and adds an allowance for what a person does that the character does not. The run is `tests/test_balance.gd`, on the moves in `tests/play_bot.gd`. Re-measure with:

```
godot --headless -s tests/run.gd -- balance
```

It prints the phase table below and fails when the estimate leaves 26 to 34 minutes. When a cost, a node or an enemy changes, run it again and update this file.

### The player it plays

It plays sensibly but not perfectly, the way someone new to the game would:

- It follows the guide: cut pines, walk the logs home through the gate, craft at the workbench.
- It turns home when the cold tip shows (warmth 90), not at the last moment.
- It gathers whole stacks of ten rather than the exact cost.
- It makes a wooden helm, body and legs before its first fight, then drops them once the bronze set is on, because by then the stash is full.
- It cooks every fish it catches, eats below half health, and takes its food, bow, arrows, staff and shards out before each trip into ring one.
- It gathers for each upgrade from the cost the Upgrades tab shows, so a repriced upgrade changes the route instead of breaking it, and builds the Stash cellar when the stash runs out of room.
- It uses all eight skills: woodcutting, mining, fishing, cooking, smithing, melee (bronze sword), ranged (the starting bow) and magic (a wooden staff).

### The phases

| Phase | From | To |
|-------|------|----|
| First tools | A new character in the outpost | A wooden pickaxe and a fishing rod crafted |
| Inner ring | Heading out with them | The stash shelves and the forge built |
| Bronze and a wooden set | The forge | Bronze bars, a bronze pickaxe and sword, a wooden staff and shards, a wooden set worn |
| First fights | Heading into ring one | Home from the near archer and three wolf packs |
| Iron, armour and the winch | Home again | The armoury, a bronze set worn and the ring-two gate winch built |
| To the captain | Kitted for the road south | The captain turns to fight |
| Captain fight | He turns to fight | He falls (reported, not counted in the thirty minutes) |

The clock stops when the captain is engaged, because the brief's target is reaching him. The fight is still played out, to check that the kit is enough to win.

### The allowance for a person

The simulation only counts what the character does: walking, gathering, cooking, fighting, standing by a fire. A person also chooses where to click, reads panels and plans trips. The run counts each of these and charges a fixed time for it:

| What | Allowance | Why |
|------|-----------|-----|
| A click in the world (a node, an enemy, a door, a fire) | 2 s | Spotting the next target after the last one runs out, turning the camera, aiming the click |
| A click in a panel (withdraw, deposit, smith, build, equip, eat, cook, drop) | 3 s | Opening the stash or workbench, finding the item in the grid, reading its tooltip |
| An outing | 20 s | Deciding where to go and what to bring, and watching the cold on the way |
| A recipe smithed or an upgrade built for the first time | 15 s | Reading its cost and what it unlocks |

These are a first-time player's numbers, not a practised one's, because the brief's target is a new character. The allowance comes to slightly more than the sim time. That is a big share, so the run also prints the estimate with half the allowance and with half as much again. At the 45 kg carry limit the route lands at 20:48 and 36:07 on those, so the target holds for a quicker or slower player, though not for a speedrunner.

## The measured run

Before tuning (the numbers on main before #26):

| Phase | Sim time | World clicks | Panel clicks | Outings | Firsts | Allowance | Estimate |
|-------|----------|--------------|--------------|---------|--------|-----------|----------|
| first tools | 0:37 | 8 | 3 | 1 | 2 | 1:15 | 1:52 |
| inner ring | 4:09 | 24 | 7 | 2 | 2 | 2:19 | 6:28 |
| bronze and a wooden set | 0:54 | 8 | 23 | 1 | 8 | 3:45 | 4:39 |
| first fights | 1:37 | 15 | 9 | 1 | 0 | 1:17 | 2:54 |
| iron, armour and the winch | 5:05 | 32 | 33 | 3 | 6 | 5:13 | 10:18 |
| to the captain | 0:26 | 2 | 5 | 1 | 0 | 0:39 | 1:05 |
| captain fight | 0:30 | 2 | 7 | 0 | 0 | 0:25 | 0:55 |
| **to the captain** | **12:47** | | | | | **14:28** | **27:15** |

After tuning:

| Phase | Sim time | World clicks | Panel clicks | Outings | Firsts | Allowance | Estimate |
|-------|----------|--------------|--------------|---------|--------|-----------|----------|
| first tools | 0:37 | 8 | 3 | 1 | 2 | 1:15 | 1:52 |
| inner ring | 4:09 | 24 | 7 | 2 | 2 | 2:19 | 6:28 |
| bronze and a wooden set | 0:54 | 8 | 23 | 1 | 8 | 3:45 | 4:39 |
| first fights | 1:37 | 15 | 9 | 1 | 0 | 1:17 | 2:54 |
| iron, armour and the winch | 6:26 | 36 | 39 | 4 | 6 | 5:59 | 12:25 |
| to the captain | 0:17 | 2 | 5 | 1 | 0 | 0:39 | 0:56 |
| captain fight | 0:30 | 2 | 7 | 0 | 0 | 0:25 | 0:55 |
| **to the captain** | **13:59** | | | | | **15:14** | **29:13** |

The run dies no times and beats the captain in 30 seconds of sim time.

## What was tuned

Before tuning the run came in at 27:15, nearly three minutes short, and only 1:37 of its 12:47 of sim time was spent in ring one, where the risk to carried loot is. So the time was added in ring one, by changing the price of the gate the captain guards:

| Number | Before | After | Effect on the estimate |
|--------|--------|-------|------------------------|
| Ring-two gate winch: iron ore | 8 | 12 | +0:47 alone. Three iron rocks give 9 a visit, so the twelve take a regrowth or a second visit by the archer camp |
| Ring-two gate winch: wolf pelts | 3 | 5 | +1:08 alone. The first three packs give 7 pelts and the armoury takes 3, so 5 more takes a trip to the pack by the ice hole |

Together they bring the run to 29:13. Both are ring-one loot carried home past the wolves and archers, so the extra minutes come with the tension the brief asks for, not with more chopping in the safe ring.

### The carry limit at 45 kg

[#108](https://github.com/travism26/frostmark/issues/108) raised the carry limit from 30 to 45 kg, and the run was measured again. The bot plays the same route and does not build the Pack frame, which is optional:

| Phase | Sim time | World clicks | Panel clicks | Outings | Firsts | Allowance | Estimate |
|-------|----------|--------------|--------------|---------|--------|-----------|----------|
| first tools | 0:37 | 8 | 3 | 1 | 2 | 1:15 | 1:52 |
| inner ring | 4:02 | 24 | 7 | 2 | 2 | 2:19 | 6:21 |
| bronze and a wooden set | 0:54 | 8 | 23 | 1 | 8 | 3:45 | 4:39 |
| first fights | 1:11 | 16 | 10 | 1 | 0 | 1:22 | 2:33 |
| iron, armour and the winch | 6:09 | 36 | 39 | 4 | 6 | 5:59 | 12:08 |
| to the captain | 0:17 | 2 | 5 | 1 | 0 | 0:39 | 0:56 |
| captain fight | 0:30 | 2 | 7 | 0 | 0 | 0:25 | 0:55 |
| **to the captain** | **13:09** | | | | | **15:19** | **28:28** |

The estimate drops 0:45, from 29:13 to 28:28, and stays inside 26 to 34 minutes. The run still dies no times and beats the captain in 30 seconds. The minutes come off the walking: at 30 kg the bot spent part of the inner ring, its first fights and the iron trips overweight, at 60% speed, and at 45 kg it walks those stretches at full speed. Nothing else was retuned.

### Levers measured and left alone

Each was tried on its own against the same run:

- **Enemy stats.** Wolves at 24 health instead of 15 added 0:12, and archers at 28 instead of 20 added 0:02. Fights in ring one are a small part of the clock either way, so health is not the lever for the target.
- **Experience curve, node regrowth, recipe costs and warmth drain.** The safe ring already holds most of the sim time (gathering for the first tools, the forge and the bars). Slowing any of these would add minutes where nothing is at risk. Changing the curve or the drain would also retune every skill and every trip in both rings. Armour recipes keep the prices [#38](https://github.com/travism26/frostmark/issues/38) gave them.

### Knock-on numbers

- The build-from-scratch character's stash (docs/testing.md) needs one more slot for the summed upgrade costs: 23 instead of 22.
- `tests/test_pacing.gd`, the planner's route, fights the pack by the ice hole and mines 12 iron for the winch. It reaches the fallen captain at tick 1789 (14.9 minutes), up from 1602 (13.3 minutes), still inside its window of 1200 to 2700 ticks. Its ring-two half keeps the wooden bow unless the captain dropped a better one: it used to rely on a lucky drop. It takes 1776 ticks, inside its window. At the 45 kg carry limit the captain falls at tick 1704 (14.2 minutes) and the ring-two half takes 1653 ticks (13.8 minutes), both still inside their windows.

## Re-measured: copper and tin round the inner ring

[#111](https://github.com/travism26/frostmark/issues/111) moved copper and tin off the outpost walls into four spots of one copper and one tin rock, one on each side of the inner ring 15 to 22 m out, and gave the north fishing hole a second hole beside it. The run mines copper north, east, then south, and tin south, east, then north, so a stack of each is a walk round the outpost rather than a step off the wall:

| Phase | Sim time | World clicks | Panel clicks | Outings | Firsts | Allowance | Estimate |
|-------|----------|--------------|--------------|---------|--------|-----------|----------|
| first tools | 0:37 | 8 | 3 | 1 | 2 | 1:15 | 1:52 |
| inner ring | 4:12 | 24 | 7 | 2 | 2 | 2:19 | 6:31 |
| bronze and a wooden set | 0:54 | 8 | 23 | 1 | 8 | 3:45 | 4:39 |
| first fights | 1:11 | 16 | 10 | 1 | 0 | 1:22 | 2:33 |
| iron, armour and the winch | 6:20 | 36 | 39 | 4 | 6 | 5:59 | 12:19 |
| to the captain | 0:17 | 2 | 5 | 1 | 0 | 0:39 | 0:56 |
| captain fight | 0:30 | 2 | 7 | 0 | 0 | 0:25 | 0:55 |
| **to the captain** | **13:30** | | | | | **15:19** | **28:49** |

Measured at the 45 kg carry limit, the estimate rises 21 seconds, from 28:28 to 28:49, all of it walking between spots: 10 s more in the inner-ring phase and 11 s more on the second bronze trip in the iron phase. The first tools are cut from the southern pines, which did not move, so that phase is unchanged. With half the allowance it is 21:09, with half as much again 36:28. The clicks are the same, since a stack of ten still takes three rocks of each. No number was retuned.

`tests/test_pacing.gd` reaches the fallen captain at tick 1765 (14.7 minutes), up from 1704, and its ring-two half takes 1645 ticks, down from 1653, both inside their windows.

## Re-measured: iron and trout spots in ring one

[#112](https://github.com/travism26/frostmark/issues/112) split ring one's three-rock iron cluster into two spots of two rocks, one east by the archer camp where the cluster stood and one south-west by the far wolf pack, and gave ring one three spots of two ice holes, north, east and west. The run's iron trip mines the east spot, then the south-west one:

| Phase | Sim time | World clicks | Panel clicks | Outings | Firsts | Allowance | Estimate |
|-------|----------|--------------|--------------|---------|--------|-----------|----------|
| first tools | 0:37 | 8 | 3 | 1 | 2 | 1:15 | 1:52 |
| inner ring | 4:12 | 24 | 7 | 2 | 2 | 2:19 | 6:31 |
| bronze and a wooden set | 0:54 | 8 | 23 | 1 | 8 | 3:45 | 4:39 |
| first fights | 1:11 | 16 | 10 | 1 | 0 | 1:22 | 2:33 |
| iron, armour and the winch | 5:48 | 50 | 40 | 4 | 6 | 6:30 | 12:18 |
| to the captain | 0:17 | 2 | 5 | 1 | 0 | 0:39 | 0:56 |
| captain fight | 0:28 | 2 | 7 | 0 | 0 | 0:25 | 0:53 |
| **to the captain** | **12:58** | | | | | **15:50** | **28:48** |

The estimate is a second shorter, 28:48 instead of 28:49, but the iron phase changed underneath it. Four rocks of three ore are the winch's twelve in one sweep, so the run no longer stands by the old cluster waiting for a rock to regrow, and its sim time drops 32 seconds. The walk to the south-west spot passes the near archer, the near pack and the far pack, back since the first fights, so the run now fights them on the way. That adds 14 world clicks and one panel click, 31 seconds of allowance. With half the allowance it is 20:53, with half as much again 36:43. No number was retuned.

The play bot used to fight back only in ring two, so ring one could kill it mid-trip. It now fights whatever notices it anywhere outside the walls, with whatever it holds. `tests/test_pacing.gd` takes food on its iron trip for the same reason. It reaches the fallen captain at tick 1715 (14.3 minutes), down from 1765, and its ring-two half takes 1715 ticks, up from 1645: the extra fights in ring one shift the run's seeded rolls, so the captain fight and the ring-two fights land differently. Both stay inside their windows.

## Off the timed route: the Bloomery

[#117](https://github.com/travism26/frostmark/issues/117) lets the workbench make all eight iron items once the Bloomery is built. The Bloomery stays off the timed route, and the run doesn't build it, for three reasons:

- **The captain falls to bronze.** The run beats him in bronze armour with a bronze sword and a wooden bow and staff, with no deaths, so iron is a choice to arm up further, not a step the route needs.
- **Iron costs extra trips.** One sweep of ring one's iron rocks is 12 ore, which is the winch's 12. The Bloomery takes 4 more, and a kit of a weapon, a full armour set and a pickaxe takes 7 bars, 14 ore. All eight iron items take 12 bars, 24 ore. That is two more sweeps past the archers and wolves, with ore carried home through ring one.
- **The target measures the shortest way to the captain.** Putting an optional detour on the timed route would measure a player who chose to take longer.

So the measured run and `tests/test_pacing.gd` don't change: 12:58 of sim time and a 28:48 estimate, and the planner's captain falls at tick 1715 with its ring-two half taking 1715 ticks. Iron drops are unchanged too. A rare drop or the captain's guaranteed piece is still a shortcut past the smithing.

## The guarded mine in ring one

[#113](https://github.com/travism26/frostmark/issues/113) put a mine of three copper and three tin rocks against ring one's west cliff, north of the watch post, and moved `witch_2` from the north-west flank to its mouth, within earshot of every side of every rock. A visit there is 12 copper and 12 tin ore, but only after the witch. The run takes none of it: it mines its bronze in the inner ring before its first fight, and none of its ring-one trips passes the mine or the witch, so the measured run is unchanged at 28:48 and `tests/test_pacing.gd` still reaches the fallen captain at tick 1715. No number was retuned.
