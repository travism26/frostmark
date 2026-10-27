# Balance: reaching the bandit captain

The brief's first playable ends at the bandit captain, and a new character should reach him in about thirty minutes, inside one evening session ([game-brief.md](game-brief.md#first-playable), [roadmap.md](roadmap.md) section 5). This file records how that was measured and what was tuned to get there, in [#26](https://github.com/travism26/frostmark/issues/26). The rules and every number live in [simulation.md](simulation.md).

Each mechanic that moved the run has its own heading below, in a group by what it changes, and each gives the estimate before and after it. A change that re-measures the run adds its table under the heading of the mechanic it changed, or a new heading at the end of that mechanic's group, never at the end of the file, so two changes to different mechanics land in different places.

## How it is measured

A person cannot be timed here, so a script plays a new character through the simulation's command interface, as a first-time player would, and adds an allowance for what a person does that the character does not. The run is `tests/test_balance.gd`, on the moves in `tests/play_bot.gd`. Re-measure with:

```
godot --headless -s tests/run.gd -- balance
```

It prints the phase table below and fails when the estimate leaves 26 to 34 minutes. When a cost, a node or an enemy changes, run it again and update this file.

### The player it plays

It plays sensibly but not perfectly, the way someone new to the game would:

- It follows the guide: cut pines, walk the logs home through the gate, craft at the workbench from the logs in the pack.
- It turns home when the cold tip shows (warmth 90), not at the last moment.
- It gathers whole stacks of ten rather than the exact cost.
- It makes a wooden helm, body and legs before its first fight, then drops them once the bronze set is on, because by then the stash is full.
- It cooks every fish it catches, eats below half health, and takes its food, bow, arrows, staff and shards out before each trip into ring one.
- It clicks Deposit haul at the stash on each return and before each outing, so its kit stays in the pack from trip to trip.
- It smiths straight from what the stash and the pack hold, without withdrawing the inputs first.
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
| A click in a panel (withdraw, deposit, Deposit haul, smith, build, equip, eat, cook, drop) | 3 s | Opening the stash or workbench, finding the item in the grid, reading its tooltip |
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

### Levers measured and left alone

Each was tried on its own against the same run:

- **Enemy stats.** Wolves at 24 health instead of 15 added 0:12, and archers at 28 instead of 20 added 0:02. Fights in ring one are a small part of the clock either way, so health is not the lever for the target.
- **Experience curve, node regrowth, recipe costs and warmth drain.** The safe ring already holds most of the sim time (gathering for the first tools, the forge and the bars). Slowing any of these would add minutes where nothing is at risk. Changing the curve or the drain would also retune every skill and every trip in both rings. Armour recipes keep the prices [#38](https://github.com/travism26/frostmark/issues/38) gave them.

### Knock-on numbers

- The build-from-scratch character's stash (docs/testing.md) needs one more slot for the summed upgrade costs: 23 instead of 22.
- `tests/test_pacing.gd`, the planner's route, fights the pack by the ice hole and mines 12 iron for the winch. It reaches the fallen captain at tick 1789 (14.9 minutes), up from 1602 (13.3 minutes), still inside its window of 1200 to 2700 ticks. Its ring-two half keeps the wooden bow unless the captain dropped a better one: it used to rely on a lucky drop. It takes 1776 ticks, inside its window. At the 45 kg carry limit the captain falls at tick 1704 (14.2 minutes) and the ring-two half takes 1653 ticks (13.8 minutes), both still inside their windows.

## Carrying

How much the pack holds and what happens to it at the gate.

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

### Home safe without banking

[#107](https://github.com/travism26/frostmark/issues/107) stopped the gate banking the pack. The bot now clicks Deposit haul on each return and before each outing instead of taking its kit back out of the stash, and crafts its first pickaxe and rod from the logs it carried home, as the guide's craft step now says. The route is otherwise the same:

| Phase | Sim time | World clicks | Panel clicks | Outings | Firsts | Allowance | Estimate |
|-------|----------|--------------|--------------|---------|--------|-----------|----------|
| first tools | 0:36 | 8 | 2 | 1 | 2 | 1:12 | 1:48 |
| inner ring | 4:12 | 24 | 7 | 2 | 2 | 2:19 | 6:31 |
| bronze and a wooden set | 0:55 | 8 | 25 | 1 | 8 | 3:51 | 4:46 |
| first fights | 1:12 | 16 | 12 | 1 | 0 | 1:28 | 2:40 |
| iron, armour and the winch | 6:09 | 51 | 33 | 4 | 6 | 6:11 | 12:20 |
| to the captain | 0:15 | 2 | 1 | 1 | 0 | 0:27 | 0:42 |
| captain fight | 0:29 | 3 | 7 | 0 | 0 | 0:27 | 0:56 |
| **to the captain** | **13:18** | | | | | **15:28** | **28:46** |

The estimate is two seconds shorter, 28:46 instead of 28:48, and the run still dies no times and beats the captain. Panel clicks moved the most. The withdrawals of tools, armour and arrows before each outing are gone: 3 to 2 for the first tools, 40 to 33 for the iron phase, and 5 to 1 on the road to the captain. The Deposit haul clicks add 2 each to the bronze phase and the first fights. Sim time rose 20 seconds, almost all in the iron phase (5:48 to 6:09). The fewer clicks shift every later tick, so the run meets ring one's enemies at other moments and waits on regrowth at other moments. Nothing in the rules was retuned. With half the allowance it is 21:02, with half as much again 36:30.

`tests/test_pacing.gd` reaches the fallen captain at tick 1664 (13.9 minutes), down from 1715, and its ring-two half takes 1751 ticks, up from 1715, both inside their windows. The ring-two half needed three changes, because kit no longer leaves the pack at the gate and the shifted timing gives the captain a different drop (two iron swords rather than an iron sword and iron legs):

- It heals to full at the outpost fire before each trip into ring two, rather than heading out at 80 health.
- It fishes and cooks once more before the keep. The food it carried out on the earlier trips was eaten, and none waits in the stash.
- Before smithing steel it puts the fishing rod, staff, shards and the bronze it outgrew in the stash, to free pack slots.

Without these it died once or twice in ring two.
## The workbench

Where smithing takes its inputs from.

### Smithing from the stash

[#99](https://github.com/travism26/frostmark/issues/99) let the workbench take its inputs from the stash first, then the pack, the way an upgrade pays. The bot no longer withdraws ore, logs and ice crystals before smithing; it still withdraws raw fish to cook, and food, weapons and arrows before an outing. The route is otherwise the same:

| Phase | Sim time | World clicks | Panel clicks | Outings | Firsts | Allowance | Estimate |
|-------|----------|--------------|--------------|---------|--------|-----------|----------|
| first tools | 0:36 | 8 | 2 | 1 | 2 | 1:12 | 1:48 |
| inner ring | 4:12 | 24 | 7 | 2 | 2 | 2:19 | 6:31 |
| bronze and a wooden set | 0:53 | 8 | 20 | 1 | 8 | 3:36 | 4:29 |
| first fights | 1:12 | 16 | 12 | 1 | 0 | 1:28 | 2:40 |
| iron, armour and the winch | 6:06 | 51 | 31 | 4 | 6 | 6:05 | 12:11 |
| to the captain | 0:15 | 2 | 1 | 1 | 0 | 0:27 | 0:42 |
| captain fight | 0:29 | 3 | 7 | 0 | 0 | 0:27 | 0:56 |
| **to the captain** | **13:13** | | | | | **15:07** | **28:20** |

The estimate drops 26 seconds, from 28:46 to 28:20, and stays inside 26 to 34 minutes. Panel clicks moved: 25 to 20 in the bronze phase (the copper, tin, logs and ice crystal withdrawals) and 33 to 31 in the iron phase (the copper and tin). Sim time drops 5 seconds, the ticks those withdrawals took. With half the allowance it is 20:47, with half as much again 35:54. The run still dies no times and beats the captain. No number was retuned.

`tests/test_pacing.gd` drops its withdrawals of ore, coal, logs, ice crystals and the troll hide before smithing as well. It reaches the fallen captain at tick 1656 (13.8 minutes), down from 1664, and its ring-two half takes 1740 ticks, down from 1751, both inside their windows. It has to drop them: a part withdrawal, such as 6 of the stash's logs, now stays in the pack while the stash pays first, and the pack ran out of room for the steel armour.

## Where the ore and fish are

Where the rocks and fishing holes stand, and what guards them.

### Copper and tin round the inner ring

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

### Iron and trout spots in ring one

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

### The guarded mine in ring one

[#113](https://github.com/travism26/frostmark/issues/113) put a mine of three copper and three tin rocks against ring one's west cliff, north of the watch post, and moved `witch_2` from the north-west flank to its mouth, within earshot of every side of every rock. A visit there is 12 copper and 12 tin ore, but only after the witch. The run takes none of it: it mines its bronze in the inner ring before its first fight, and none of its ring-one trips passes the mine or the witch, so the measured run is unchanged at 28:48 and `tests/test_pacing.gd` still reaches the fallen captain at tick 1715. No number was retuned.

## The ring-one dungeon

The dungeon sits off the timed route, so the measured run and `tests/test_pacing.gd` don't change.

### The great frost bear

[#217](https://github.com/travism26/frostmark/issues/217): the dungeon's boss. 700 health, claws (melee, so magic has the edge), swipe 9, maul 20 (heavy), smash 26 (heavy, a front mark 4 m deep), stomp 24 (heavy, a ring mark 3.5 m round it), both marks told two ticks ahead, and below 350 health a phase that rears, roars and calls in two wolves. It drops 6 iron ore and 4 wolf pelts every time and comes back 600 ticks after it falls.

It is fought in `tests/test_great_frost_bear.gd` by the boss test code's character (docs/testing.md): melee, ranged and magic at 20, iron helm, body and legs (3 defence), an iron staff, 100 health and five cooked trout, starting beside it. Both fighters strike whenever they can (the wolves first once they come in) and eat a trout below half health. The numbers below are what the tests print (`test_the_reader_steps_off_every_mark_and_beats_the_bear`, `test_the_non_reader_standing_still_takes_the_smash_and_stomp_and_dies`).

| Fight | Result |
|-------|--------|
| Reader: holds the staff and steps off every mark the tick it is told (to the bear's side for a smash, a metre past the ring for a stomp) | The bear falls on the 80th tick (40 s); 45 health at the lowest, 76 at the end, one trout eaten. It steps off 12 marks and none lands; the two wolves come in at half health and are killed first |
| Non-reader: holds the staff and stands its ground | Dies on the 59th tick, all five trout eaten, with the bear on 106. All eleven of its marks land |

What each of its blows does to that character, by the weapon it holds (`test_swapping_style_changes_its_claws_by_the_triangle_but_never_its_smash_or_stomp`):

| Blow | Staff | Sword | Bow (up close) |
|------|-------|-------|----------------|
| Swipe 9 | 2 | 6 | 11 |
| Maul 20 (heavy) | 7 | 17 | 27 |
| Smash 26 (heavy, front mark) | 23 | 23 | 23 |
| Stomp 24 (heavy, ring mark) | 21 | 21 | 21 |

Why each number:

- **Health 700, measured.** It was first set at 420, with a smash of 26 and a stomp of 22. There the reader won in 47 ticks, but the non-reader standing still also won, in 43 ticks: it ate its five trout and ended on 79, its lowest 36. At 600, with the smash at 30 and the stomp at 26, standing still died with the bear on 96, but those marks hit harder than the ice troll's crush (below). With the marks at 26 and 24, 600 let the non-reader scrape a win on 1 health, 660 killed it with the bear on 89, and 700 with the bear on 106, the margin kept. The reader still wins in 40 seconds with three quarters of its health left, a little longer than the bandit captain fight on the timed route. It is more than the Frost tyrant's 600, but the ring-one character deals 21 a hit with the edge (an iron staff's 8 and 6 for level 20, times 1.5) every other tick, where the tyrant's reference character deals 35 (a steel staff's 10 and 13 for level 40), and the bear never answers a swap, so its fight runs longer than the tyrant's 34 ticks but is far simpler to read. 700 is far above any other ring-one kind (the captain's 240).
- **Swipe 9 and maul 20.** The maul is the heaviest aimed blow in ring one, over the captain's cleave 17, so a player who walks in with the wrong style feels it: 27 a maul with a bow up close. With the staff the bear's claws are an annoyance, 2 and 7, so the fight's real damage is in the marks.
- **Smash 26 and stomp 24.** The heaviest blows in ring one, and over the maul, so the bear's heaviest blow is above every ring-one kind's. The smash equals the ice troll's crush, the hardest blow outside ring three (`tests/test_ring_two.gd` holds that), and no more. Through iron armour they land for 23 and 21, so five of them take a full health bar and standing in them is what kills.
- **Smash 4 m deep, stomp 3.5 m round.** A player beside the bear (1.2 m from its centre) steps off a smash by walking about 2 m round to its side, in one tick, and off a stomp by walking more than 2.3 m straight out, in two ticks, so each is a decision inside its two-tick warning, as the spec asks. Both are bigger than a one-tick mark may be; the bear has none.
- **Two wolves at half health.** Ring one's own kind, 15 health each: they bite an iron-armoured player for 1, and die to one staff hit each, so they turn the fight (the reader breaks off the bear for two hits) without stalling it.
- **6 iron ore and 4 wolf pelts.** Two iron rocks' worth of ore and four wolves' pelts, so a kill pays half the ring-two winch's 12 ore and most of its 5 pelts, and a little more than the dungeon's own two rocks. No rare drop: the pile is fixed, as the spec asks.
- **Respawn 600 ticks** (five minutes), the captain's, so it is up again on the next run through the dungeon.

## Ring three

Ring three's enemies are deadlier by being harder to read, not by having more health ([#173](https://github.com/travism26/frostmark/issues/173)). They sit past the timed route, so the measured run and `tests/test_pacing.gd` don't change. Each enemy's fight is measured by a reader and a non-reader in `tests/test_ring_three.gd`: the reference character (steel head to foot, every combat skill at 40, 100 health, five cooked trout) against one enemy, deterministic like every fight.

### The bar

[#198](https://github.com/travism26/frostmark/issues/198) set one bar for every ring-three fight, a line at 60 health, counted in **damage taken** over the whole fight rather than health left:

- **The reader** wins, ends with more than 60 health, and takes under 40.
- **The non-reader** dies, or takes 40 or more: what would leave it at 60 or below had it not eaten.

Damage taken is every point that landed on the player (blows, area blows and burning ground), whatever a meal put back afterwards. A trout heals 40 over five ticks, so the health left measures the pack as much as the reading: the knight's sword-swinger ends on 36 without a meal and on 92 eating on every heavy, and it takes 64 either way. Meals spent tracks the eating rule the test gives the non-reader, not the reading, and time to kill barely moves (the reader and the non-reader kill the archer, the knight and the seer within one to three ticks of each other). The tests use `READER_KEEPS` (60) and `NON_READER_TAKES` (40) in `tests/test_ring_three.gd`.

So the food and the meal take no lever. The reference character keeps five trout, the trout keeps its 40 over five ticks, and the non-readers keep eating as each ticket wrote them; the bar no longer sees the meals. A smaller heal would move rings one and two and the timed run, and fewer trout would only shift the eating fights' health left, which the bar does not count.

What the bar did need was health for the two kinds that died before their trick was played. At 70 the archer died to the reference bow on the seventh tick, before its bluff; at 60 the seer died on the third, before the blade it conjures in answer had closed. Swept with everything else held (the non-reader eats on every heavy; the seer's no-meal non-reader takes the same):

| Health | Archer: reader taken / non-reader taken (ticks) | Seer: reader taken / non-reader taken (ticks) |
|--------|-----------------------------------------------|-----------------------------------------------|
| 60 | | 0 / 0 (3) |
| 70 | 14 / 21 (7) | |
| 80 | 15 / 21 (7) | |
| 90 | 15 / 21 (7) | 0 / 0 (5) |
| 100 | **15 / 42 (10)** | 0 / 0 (5) |
| 110 | 22 / 42 (10) | 1 / 11 (7) |
| 120 | | **1 / 43 (9)** |
| 130 | | 1 / 43 (11) |
| 150 | 22 / 63 (15) | 9 / 54 (13) |
| 180 | 22 / 63 (17) | 9 / 86 (17) |

The archer is now 100, the least that meets the bar and the ceiling of about 100 its ticket set, and the seer 120, the least that meets it and the knight's health. Their damage, timing and cycles are unchanged, so the readability floor (`tests/test_sim_telegraphs.gd`) and its top-up are as they were. A bar of 60 taken (the old "below 40 health" without a meal) would have needed the archer at 150 and the seer at 180.

| Enemy | Reader: health left, taken, meals | Non-reader: taken, meals, health left |
|-------|------------------------------------|---------------------------------------|
| Snowveil archer (100) | 100, 15, 1 | 42, 3, 100 (eats on every heavy) |
| Frostbound knight (120) | 86, 14, 0 (98, 2, 0 from range) | 64, 0, 36 (no meal); 64, 2, 92 (eats on every heavy) |
| Aurora seer (120) | 99, 1, 0 | 43, 0, 57 (no meal); 43, 1, 73 (eats on every heavy) |
| Frost tyrant (600) | 100, 38, 1 | dies with the sword, the bow or the staff, 290 to 304 taken, five meals |

### The Snowveil archer

[#181](https://github.com/travism26/frostmark/issues/181): 100 health (70 until #198), quick shot 7, piercing shot 22 (heavy), kiting inside 4 m, and a bluffed second piercing shot. The numbers in the fights below are what the tests print.

| Fight | Result |
|-------|--------|
| Reader: steel sword from 6 m, pins it against the ridge, eats on rest ticks only | The archer falls on the eighth tick; 86 health at the lowest, 100 at the end, 15 taken (the reader ate once) |
| Non-reader: steel bow from 8 m, eats on every heavy telegraph | The archer falls on the tenth tick; 87 health at the lowest, 100 at the end, 42 taken, three meals, one of them on the bluff |

Both clear the bar. At 70 health the archer died to the reference character's bow on the seventh tick, before its bluff was ever played, and the non-reader took 21; with #181's ticket asking for "below 40 health or dead", a meal healing 40 over five ticks against a piercing shot that lands for 18 (22 less 4 armour) put any health-left bar out of reach. At 100 it lives to play the bluff: the non-reader eats on it, takes the real shot straight after, and takes 42 in all. Its meals still leave it on full health, which is why the bar counts damage taken.

### The Frostbound knight

[#180](https://github.com/travism26/frostmark/issues/180): 120 health, hack 12, rime cleave 28 (heavy), a wind-up before the first cleave, a bluffed second cleave and a quick phase below 50 % health (no wind-ups). The numbers below are what the tests print.

| Fight | Result |
|-------|--------|
| Reader: steel staff, in the blade's reach | The knight falls on the seventh tick; 86 health at the end (two hacks of 2 and one cleave of 10, all into the staff's edge) |
| Reader: steel staff, from 5.5 m | The knight falls on the seventh tick; 98 health at the end |
| Non-reader: steel sword, in reach, swinging, no meal | The knight falls on the ninth tick; 36 health at the end (hack 8, cleave 24, hack 8, cleave 24) |
| Non-reader: the same, eating a trout the tick after any heavy is told | The knight falls on the tenth tick; 76 health at the lowest, 92 at the end |

The reader clears the bar, taking 14 (2 from range), and both non-readers take 64. The swinger without a meal also clears the ticket's own bar of below 40. That took one retune: with the ticket's hack of 10 the swinger ended at exactly 40, not below it, so the hack is 12. Health stayed at 120.

Two things the numbers show:

- **The reference staff outruns the knight's first wind-up.** Four casts of 35 (23, 1.5 times for the staff's edge) fell a 120-health knight in seven ticks, and the second takes it under 60 on the third tick, the tick it would declare its first wind-up. The reader's step back from a wind-up is pinned on its own (`test_stepping_back_from_the_wind_up_makes_the_committed_cleave_miss`) rather than by the fight, which never gets there. The wind-ups and the bluff are for a player who deals less than the reference character, with a lower tier or fewer levels.
- **A meal decides a swinger's health left, not what it took**: a trout heals 40 over five ticks in a fight of ten, so the non-reader that eats on every heavy ends at 92, but it takes the same 64 as the one that does not eat. That is why the bar counts damage taken ([#198](https://github.com/travism26/frostmark/issues/198)).

### The Aurora seer

[#182](https://github.com/travism26/frostmark/issues/182): 120 health (60 until #198), aurora bolt 8, aurora lance 22 (heavy), ice slash 10, ice rend 24 (heavy), and answers: a bow turned on its staff is answered with a conjured blade, a staff turned on the blade with its staff raised again, with 8 ticks between answers. The numbers below are what the tests print.

| Fight | Result |
|-------|--------|
| Reader: steel bow from 5 m, swaps to a steel staff on `conjure_blade`, back to the bow on `raise_aurora`, eats on rest ticks only | The seer falls on the seventh tick; 99 health at the end, 1 taken |
| Non-reader: steel bow throughout, no meal | The seer falls on the ninth tick; 57 health at the end, 43 taken |
| Non-reader: the same, eating a trout the tick after any heavy is told | The seer falls on the ninth tick; 65 at the lowest, 73 at the end, 43 taken, one meal |

Both clear the bar. At 60 health neither could be told apart: the reference bow shoots 35 at a staff (23, 1.5 times for the edge), two shots two ticks apart took the seer's 60, and the first lands on the tick it notices the player, so the seer was dead on the third tick, before the blade that answers the bow had closed the 5 m, let alone struck. Nothing in its damage or timing could change that, since it never got to a blow, so [#198](https://github.com/travism26/frostmark/issues/198) raised its health to 120, the least that meets the bar. Now the blade closes and lands on the bow-holder, and the reader that swaps to the staff on the answer takes 1.

With the other numbers held and only the seer's health raised, the same fights come out in health left:

| Seer health | Reader | Non-reader, no meal | Non-reader, eating on every heavy |
|-------------|--------|---------------------|-----------------------------------|
| 60 | 100 left, 3 ticks | 100 left, 3 ticks | 100 left, 3 ticks |
| 120 | 99 left, 7 ticks | 57 left, 9 ticks | 73 left (65 at the lowest), 9 ticks |
| 150 | 91 left, 9 ticks | 46 left, 13 ticks | 86 left (65 at the lowest), 13 ticks |
| 180 | 91 left, 11 ticks | 14 left, 17 ticks | 86 left (62 at the lowest), 17 ticks |

So the ticket's bar of below 40 for a non-reader that does not eat was met somewhere between 150 and 180 health, and the non-reader that eats on every heavy ends well above 40 at every health. Counted in damage taken (40 or more), the bar is met from 120.

### The Frost tyrant

[#183](https://github.com/travism26/frostmark/issues/183): ring three's boss. 600 health, three weapons by stance (greatblade, warbow, staff), slash 12, glacier cleave 32 (heavy, wound up), loose 10, hail volley 28 (heavy, bluffed once), rime bolt 10, whiteout 28 (heavy), answers to every counter-swap with 10 ticks between them, and below 300 health a second phase with no wind-up, fewer rests, two bluffs and 6 ticks between answers. [#218](https://github.com/travism26/frostmark/issues/218) gave it area blows: a stomp ring 26 (3 m) and a greatblade smash front 30 (3.5 m) with the greatblade, arrow rain 20 dropped on the player (2.5 m) with the warbow, falling ice 26 dropped on the player (2.5 m) with the staff, leaving the ground burning for 5 ticks at 8 a tick, and in the second phase ice shards 16 (a 1.5 m drop told one tick out) with the warbow and the staff. Every area blow lands through armour alone, so the reference character's steel takes 4 off each, a burn included. The reference character carries a steel sword, bow and staff and five trout. The numbers below are what the tests print (`test_the_reader_reads_every_stance_and_beats_the_tyrant`, `test_the_reader_standing_on_its_marks_dies`, `test_the_non_reader_holding_one_style_dies`).

| Fight | Result |
|-------|--------|
| Reader: opens with the staff beside it, swaps to the counter on every stance, steps back on the wind-up, does nothing on a feint, eats on rest ticks below 70, and steps to the nearest open ground off each mark as it is told, holding its swing until the blow lands | The tyrant falls on the 49th tick; 62 health at the lowest, 100 at the end, 38 taken, one trout eaten. It stepped off 9 marks and none struck it. It answered 7 times, and 11 of the reader's swaps came inside an answer's cooldown |
| The same reader standing on its marks | Dies on the 17th tick, with the tyrant on 282. Four blows and five ticks on the burning ground struck it, 106 damage of the 119 it took, and it never ate: its swaps draw so many answers that no rest came round |
| Non-reader: steel sword throughout, eating below half health | Dies on the 34th tick, with the tyrant on 264 |
| Non-reader: steel bow throughout, the same | Dies on the 37th tick, with the tyrant on 307 |
| Non-reader: steel staff throughout, the same | Dies on the 35th tick, with the tyrant on 296 |

Before #218 the reader won on the 34th tick with 75 left and the non-readers died on the 39th to 43rd. Three things the numbers show:

- **Reading the counters is no longer enough.** The reader standing on its marks is the reader from before #218, which won. The first area blows tried (16 to 24, burning at 5) left it on 53 at the end, because steel took the burn to 1 a tick and the reader's answers skipped the blows set at the end of each stance. The blows were raised to the numbers above and each set straight after its stance, where an answer does not skip it. That reader now dies in under half the time the stepping one takes to win.
- **Stepping off costs time, not health.** The stepping reader's fight is 15 ticks longer than before #218: on every mark it walks off and waits out the blow, and while the tyrant is rooted only a staff or a bow still reaches it. It ends on full health, because nothing it can step off struck it. The hollow's ridges close two sides, so a reader that only steps straight away from a stomp is cornered against them and struck; the reader takes the nearest open ground instead.
- **Health still matters.** At 600 the tyrant outlasts every single style. Whichever weapon the non-reader holds, the tyrant answers its edge with the weapon that beats it, and now each mark lands on a non-reader who stands still, so every one dies a few ticks sooner than before. The reader re-counters every answer inside the cooldown and spends almost all of the fight on the right side. It never meets the wind-up, as before: each greatblade it faces is an answer it re-counters with the staff, so the tyrant is drawn off the greatblade before its cleave comes round. The step back is pinned on its own (`test_stepping_back_from_its_wind_up_makes_the_committed_cleave_miss`).

The non-reader's bar here is death, the ticket's wording, and it holds with a meal in the pack: five trout do not carry one style through a 600-health fight, each non-reader taking 290 to 304 before it falls. The reader takes 38, under [#198](https://github.com/travism26/frostmark/issues/198)'s 40, the closest any reader comes to the line.

## Off the timed route

What the run deliberately leaves out, and why.

### The Bloomery

[#117](https://github.com/travism26/frostmark/issues/117) lets the workbench make all eight iron items once the Bloomery is built. The Bloomery stays off the timed route, and the run doesn't build it, for three reasons:

- **The captain falls to bronze.** The run beats him in bronze armour with a bronze sword and a wooden bow and staff, with no deaths, so iron is a choice to arm up further, not a step the route needs.
- **Iron costs extra trips.** One sweep of ring one's iron rocks is 12 ore, which is the winch's 12. The Bloomery takes 4 more, and a kit of a weapon, a full armour set and a pickaxe takes 7 bars, 14 ore. All eight iron items take 12 bars, 24 ore. That is two more sweeps past the archers and wolves, with ore carried home through ring one.
- **The target measures the shortest way to the captain.** Putting an optional detour on the timed route would measure a player who chose to take longer.

So the measured run and `tests/test_pacing.gd` don't change: 12:58 of sim time and a 28:48 estimate, and the planner's captain falls at tick 1715 with its ring-two half taking 1715 ticks. Iron drops are unchanged too. A rare drop or the captain's guaranteed piece is still a shortcut past the smithing.

### Fur pieces

[#142](https://github.com/travism26/frostmark/issues/142) lets worn fur slow the warmth drain: a full fur set makes a full gauge last 540 ticks instead of 360. Fur is optional and stays off the timed route. The run doesn't make it: its trips already turn home on the cold tip with warmth to spare, fur takes nothing off a hit, and the pelts it would cost are the Armoury's, the Pack frame's and the winch's. So the measured run and `tests/test_pacing.gd` don't change.

### Set pieces in the uncommon bands

[#249](https://github.com/travism26/frostmark/issues/249) puts each ring's found set pieces into its uncommon band beside the iron pieces: 12 mid pieces in ring one's (20 in all), 14 mid-high pieces in ring two's (22 in all), and 14 high pieces in ring three's, which ring three's Snowveil archers, Frostbound knights and Aurora seers now roll against at 10 % each. Every kind keeps its chance of landing in its band, and every piece in a band is drawn evenly until #243 sets the odds, so a ring-one kill that lands gives an iron piece 8 times in 20 rather than every time, and a ring-two kill 8 times in 22. No reference character wears a set piece, and the timed route wears smithed tiers.

The balance run (`tests/test_balance.gd`) doesn't change: 13:13 of sim time and a 28:20 estimate, the same as before. The play bot picks up what drops near it, and the planner's seeded run in `tests/test_pacing.gd` lands the captain's rare roll on a Hearthguard helm (1 kg) where it drew a second iron sword (4 kg). Its captain still falls at tick 1656 (13.8 minutes); its ring-two half, carrying 3 kg less, takes 1726 ticks, down from 1740, inside its window.
