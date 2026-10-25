# The Frostmark simulation

Everything that is a rule lives in `sim/`, as RefCounted scripts with no Node, scene, Input, rendering or autoload dependency. The presentation in `scenes/` is glue: it turns clicks into commands and events into motion and text. Tests under `tests/test_*.gd` drive the simulation through `command()` and `step()` only. This is the seam that would later move to a server for co-op.

| File | Holds |
|------|-------|
| `sim/sim.gd` (`Sim`) | All game state, `command()`, `step()`, `drain_events()`, `snapshot()`, `restore()` |
| `sim/world_def.gd` (`WorldDef`) | The world as data: walkability grid, named regions, object placements |
| `sim/grid_path.gd` (`GridPath`) | A* over the grid (the engine's `AStarGrid2D`, built once per world) plus line-of-sight smoothing |
| `sim/vocab.gd` (`SimVocab`) | Every command kind, event kind, interaction action and rejection reason as a constant |
| `sim/items.gd` (`ItemTable`) | Every item kind: label, stack size, weight, value, equipment slot, tool kind, tier, weapon stats, armour defence, the `warmth` worn gear keeps out (`ItemTable.warmth(kind)`, 0 when absent), food healing |
| `sim/combat.gd` (`CombatTable`) | Combat as data: the style edge table, natural weapons, enemy kinds and their action cycles, noise radii, the damage arithmetic |
| `sim/recipes.gd` (`RecipeTable`) | Workbench recipes (inputs, output, required skill and level, required upgrade, metal tier) and the cooking table (raw item, cooked item, level, xp, burn chance) |
| `sim/upgrades.gd` (`UpgradeTable`) | The outpost tech tree: cost, prerequisites, effects, and whether an upgrade is locked in this version |
| `sim/skills.gd` (`SkillTable`) | The eight skill names and the one experience curve they share |
| `sim/inventory.gd` (`Inventory`) | Static helpers over slot arrays: room, stacking, weight, removal |
| `sim/guide.gd` (`GuideTable`) | The first-outing guide as data: the hint steps and their triggering events, the contextual tips with their triggers, conditions and cooldowns, and every line of their text |
| `sim/save_code.gd` (`SaveCode`) | Save-code encoding and decoding, and the forward migrations between state versions |
| `sim/save_watch.gd` (`SaveWatch`) | When to nudge the player about their save code: the long-play reminder and the warning when browser saves stop holding. Never saved |

## Tick

`Sim.TICK_SECONDS` is 0.5 s. `step()` advances exactly one tick and is the only place game state changes (`import_save` and `restore()` replace the whole state, which is a load, not a rule). The presentation accumulates frame time and calls `step()` once per tick, then drains events. Nothing in the rules reads wall-clock time, and the random rolls (a gathering attempt, a rare drop) come from a generator kept in the state, so the same commands at the same ticks give the same state.

One tick runs, in order: queued commands (a swap, a meal, a craft, a build, a field fire), the player closing on an attack target, movement (and the return when the walk enters the outpost), the gathering, cooking or waystone activity, combat (the player's swing, then every enemy in turn), node regrowth, loot decay, field fires burning out, then food healing, warmth, health and death. If the tick reached a save point it ends with one `saved` event.

Walking consumes `Sim.WALK_PER_TICK` metres of path per tick (4 m/s, so 2 m). A path of 6 m arrives on the third tick. Carrying more than `sim.carry_limit()` kg (pack plus equipment, `sim.carry_weight()`) cuts that to `Sim.OVERWEIGHT_SPEED` (60%); `sim.is_overweight()` says when. The carry limit is `Sim.BASE_CARRY_LIMIT` (45 kg) plus the `carry` effect of every built upgrade, worked out from the built upgrades each time, the way `sim.smithing_cap()` is, so it is not saved. There is no hard cap: an overweight player is slowed, not stopped.

## Commands

`sim.command(kind, args)` returns `{ok, reason}`. Commands only record intent; the next `step()` acts on it. A rejected command also emits `command_rejected`. The commands that change the inventory (`deposit`, `withdraw`, `deposit_haul`, `drop`, `equip`, `eat`, `smith`, `build`, `light_fire`) are validated at once, so the return value is meaningful, then queued in `state.pending` and applied, re-validated, at the start of the next tick. `sim.check(kind, args)` answers the same validation without queuing, for greying out buttons.

| Command | Args | Slice | Does |
|---------|------|-------|------|
| `move_to` | `{pos: [x, z]}` | 2 | Walk to a ground point (see snapping below) |
| `interact` | `{object_id}` | 2 | Walk to an object and start its action (see actions below). A loot pile id walks onto the pile and picks it up; a field fire id walks to its side |
| `gather` | `{object_id}` | 3 | `interact` restricted to gatherable nodes (trees, rocks, fishing holes): walk there, then gather until the node is spent or the pack is full |
| `cross_gate` | `{}` | 3 | Walk through the nearest gate to 2.5 m beyond it on the other side |
| `deposit` | `{index, count?}` | 3 | Pack slot to the stash, as many as fit. Inside the outpost only |
| `withdraw` | `{index, count?}` | 3 | Stash slot to the pack, as many as fit. Inside the outpost only |
| `deposit_haul` | `{}` | #106 | Every haul slot to the stash, as many as fit, leaving kit in the pack. Kit is gear (anything with an equipment slot), the ammo of any weapon, and cooked food (a cooking recipe's output), per `ItemTable.is_kit`; everything else, raw food included, is haul. Inside the outpost only |
| `drop` | `{index, count?}` | 3 | Leave items from a pack slot in the snow. They are gone |
| `equip` | `{index}` or `{unequip: slot}` | 3 | Equip a pack item into its slot, swapping the old one into that pack slot; or unequip into the pack |
| `smith` | `{recipe}` | 3 | Craft a recipe standing at the workbench inside the outpost, from the stash first, then the pack; the output goes to the pack |
| `cook` | `{index}` | 5 | Standing by any fire, cook that pack slot's raw food, one item every 2 ticks, until that kind runs out, the pack is full or the player walks off |
| `build` | `{upgrade}` | 5 | Build an outpost upgrade inside the outpost, paying its cost from the stash and your pack (the stash first) |
| `light_fire` | `{}` | 5 | Burn 3 logs from the pack into a field fire where the player stands (not inside the outpost) |
| `attack` | `{enemy_id}` | 4 | Close to the weapon's reach and strike on every ready tick until the enemy dies, the player walks or interacts elsewhere, or a bow runs out of arrows or a staff out of frost shards |
| `eat` | `{index}` | 4 | Eat one food item from a pack slot. Lands next tick, costs that tick's step and swing, heals over the food's ticks |
| `export_save` | `{}` | 3 | Returns `{ok, reason, code}`: the state as a save code. Changes nothing |
| `import_save` | `{code}` | 3 | Validates, migrates and loads a save code, replacing the state at once. Emits `saved` (reason `import_save`) or `save_rejected` |
| `set_hints` | `{on: bool}` | guide | Turns the first-outing guide off (the player dismissed it) or back on, where its path left off. Emits `hints_set`. At once, not queued |
| `new_character` | `{previous: String}` | guide | Replaces the state with a new character at once. The guide starts on only when `previous` (the browser save being replaced) is empty |
| `travel` | `{object_id}` | waystones | Standing by an awake, attuned waystone, channel for `Sim.TRAVEL_TICKS` ticks, then stand outside the outpost gate (see waystones below). `sim.travel_check(id)` answers the same validation without starting |
| `set_auto_retaliate` | `{on: bool}` | #60 | Turns auto-retaliate on (the default) or off (see attacking below). At once, not queued. Held in `sim.auto_retaliate`, outside the state, so it is never in a save and outlives `new_character` and `import_save` |

Any other kind is `unknown_command`. Rejection reasons for movement: `bad_args`, `outside_world` (off the grid), `not_walkable` (no free cell within `SNAP_RADIUS_CELLS`), `unreachable` (no route; no route crosses a ring gate), `unknown_object`. For gathering: `not_gatherable`, `depleted`, `no_tool`, `level_too_low`, `pack_full`. For the inventory: `empty_slot`, `not_equippable`, `pack_full`, `stash_full`, `not_in_outpost`. Deposit haul refuses `not_in_outpost`, `no_haul` (nothing in the pack but kit) and `stash_full` (none of the haul fits). Gathering also refuses `tool_too_weak` (iron, coal and rich iron need a bronze pickaxe or better). For crafting: `unknown_recipe`, `upgrade_missing` (the recipe's upgrade is not built; checked first, so the refusal names what to build), `tier_capped` (above the smithing cap), `not_at_workbench`, `level_too_low`, `missing_inputs` (from the stash and the pack), `pack_full` (no room for the output once the inputs are out). For cooking: `bad_args`, `empty_slot`, `not_cookable`, `not_at_fire`, `level_too_low`, `pack_full`. For building: `unknown_upgrade`, `already_built`, `upgrade_locked`, `upgrade_missing` (a prerequisite), `not_in_outpost`, `missing_inputs` (from the stash and the pack). For a field fire: `in_outpost`, `missing_inputs`. For combat: `unknown_enemy`, `target_dead`, `in_outpost` (nothing is fought from inside), `unreachable` (the enemy lives on the other side of a ring gate), `no_ammo` (a bow with no arrows or a staff with no frost shards in the pack). For eating: `empty_slot`, `not_food`, `already_eating` (one meal a tick). For save codes: `bad_code`, `bad_checksum`, `unsupported_version`, `bad_snapshot`. For the guide: `bad_args`. For travel: `unknown_object`, `not_waystone`, `upgrade_missing` (no built upgrade has woken that waystone), `not_attuned` (never visited), `not_at_waystone` (farther than 1.5 m from it).

### Interaction actions

`interacted.action` says what arriving at an object starts: `gather` for a node (the gathering activity begins at once), `warm` for the outpost fire or a field fire (`object_kind` is `campfire`; warming and cooking are by standing near it), `stash` and `craft` for the stash and the workbench (the presentation opens their panels), `pick_up` for a loot pile (`object_kind` is `loot`), `ring_gate` for a gate to ring two or ring three (when it is open, the player walks on through it to the other side, either way), `waystone` for a waystone (the first arrival attunes it), `none` for the outpost gate. The brazier past the ring-two gate and the fire past the ring-three gate are fires like the outpost's (`warm`).

### How a click becomes a walk

1. Off the grid: rejected.
2. The clicked cell is walkable: the destination is the exact click point.
3. The clicked cell is blocked (a wall, the fire): snap to the nearest walkable cell within 2 cells by distance, destination is that cell's centre. Further inside a solid than that: rejected.
4. A* routes from the player's cell to the destination cell (8-connected, no corner cutting, straight steps 1 and diagonal ones the square root of 2). No route: rejected.
5. The cell path is smoothed by line of sight with a 0.3 m margin, so open-floor walks are straight lines. Each leg tries the last waypoint first, else gallops 1, 2, 4, 8 ... waypoints ahead and halves back to the farthest one in sight, so a route across the whole world takes a few milliseconds and a click never stalls a frame.

`interact` picks the nearest routable approach cell: the ring of free cells around a blocking object, or the object's own cells when it does not block (the gate).

## Events

`drain_events()` returns every event since the last drain, oldest first, and clears the list. Each event is a Dictionary with a `kind` key.

| Event | Fields | When |
|-------|--------|------|
| `command_rejected` | `command, reason, args` | At command time |
| `path_set` | `from, to, length, object_id` | At command time, when a move or interact was accepted |
| `moved` | `from, to, path, facing` | Each tick the player moved. `path` is the polyline walked this tick, for the presentation to interpolate along |
| `arrived` | `pos, object_id` | The path ran out. `object_id` is `""` for a plain move |
| `interacted` | `object_id, object_kind, action` | Right after `arrived` at an interact target |
| `region_changed` | `from, to` | The player's region lookup changed (for example `outpost` to `inner_ring`) |
| `gathered` | `object_id, skill, item, count, xp` | A gathering attempt succeeded |
| `activity_stopped` | `activity, object_id, reason` | Gathering, cooking, attacking or travelling ended: `depleted`, `pack_full`, `no_tool`, `moved`, `target_dead`, `no_ammo`, `nothing_left`, `not_at_fire`, `interrupted` (a blow broke a waystone channel) or `died` |
| `node_depleted` | `object_id, respawn_tick` | A node gave its last yield |
| `node_respawned` | `object_id` | A spent node regrew |
| `levelled` | `skill, level` | A skill reached a new level |
| `crafted` | `recipe, item, count` | A recipe was made |
| `equipped` | `slot, item, previous` | Gear changed; `item` is `""` when unequipping |
| `dropped`, `deposited`, `withdrew` | `item, count` | Items moved |
| `deposited_haul` | `items, stayed` | Deposit haul moved `items` into the stash. Both are lists of `{item, count}`; `stayed` is haul the stash had no room for, left in the pack. Kit never appears in either |
| `returned` | `items, newly_affordable` | The player walked into the outpost. Nothing moves: `items` is the pack at that moment as a merged list of `{item, count}`, empty for an empty pack. `newly_affordable` lists the upgrade ids, in table order, that `upgrade_status()` reports as `can_build` now (stash and pack, since the pack counts inside the walls) and did not from the stash alone just before (never a built one or one missing a prerequisite); empty when nothing changed |
| `warmth_changed` | `warmth, max` | Warmth moved this tick |
| `took_damage` | `amount, cause, health` | Health fell. `cause` is `cold` or the enemy kind that hit |
| `ate` | `item, heal, ticks` | A meal landed |
| `healed` | `amount, health` | Food healed this tick |
| `died` | `cause, kept, lost, spare, pos` | Health hit zero. `kept` and `lost` are lists of `{item, count}`; `spare` is the item given back at the fire (`wooden_axe`) or `""` |
| `enemy_noticed` | `enemy_id, cause` | An idle enemy joined the fight: `sight`, `noise`, `pack` or `hit` |
| `enemy_telegraphed` | `enemy_id, action, style, damage, heavy, at` | An enemy declared an attack for tick `at`, which is always the next tick. A feint is told as the attack it pretends to be, with that attack's `action`, `style`, `damage` and `heavy` |
| `enemy_moved` | `enemy_id, from, to, path, facing` | An enemy moved this tick; `path` is the polyline it walked |
| `hit` | `attacker, target, amount, style, multiplier, health` | A blow landed. The player's id is `player`; `multiplier` is the style edge applied |
| `missed` | `attacker, target, action` | A telegraphed enemy attack found the player out of its reach |
| `enemy_feinted` | `enemy_id, action, style, at` | The blow telegraphed for tick `at` (this tick) was a feint and struck nothing. `action` and `style` are the attack it pretended to be, as it was told |
| `enemy_died` | `enemy_id, enemy_kind, pos` | An enemy's health ran out |
| `enemy_disengaged` | `enemy_id` | The player is in the outpost; the enemy heads home |
| `enemy_respawned` | `enemy_id, pos` | A dead enemy is back at home |
| `loot_dropped` | `loot_id, item, count, pos` | A pile landed where an enemy died |
| `picked_up` | `loot_id, item, count` | Some or all of a pile went into the pack |
| `loot_gone` | `loot_id` | A pile lay too long and the snow took it |
| `enemy_stance` | `enemy_id, action, style, at` | An enemy will change weapon on tick `at` (the captain drawing his bow or his sabre) or wind up (a troll, the tick before its crush), announced a tick ahead like an attack |
| `cooked` | `item, output, burnt, xp` | One raw item came off the fire; `output` is `""` when it burnt |
| `fire_lit`, `fire_out` | `fire_id, pos, expires_tick` / `fire_id` | A field fire was lit or burnt out |
| `built` | `upgrade, effects` | An outpost upgrade was built |
| `ring_gate_opened` | `object_id` | A ring gate's guardian is dead and its upgrade built |
| `ring_two_reached` | `object_id` | The player walked into ring two for the first time, through gate `object_id`. Once per character; it is not a return |
| `ring_three_reached` | `object_id` | The player walked into ring three for the first time, through gate `object_id`. Once per character; it is not a return |
| `waystone_attuned` | `object_id` | The player reached a waystone for the first time. Once per waystone |
| `travel_started` | `object_id, ticks` | At command time: channelling began and lands in `ticks` ticks unless broken |
| `travelled` | `object_id, from, to` | The channel finished: the player stands at `to`, outside the outpost gate. It is not a return |
| `saved` | `reason, tick` | A save point: `gate`, `deposit`, `withdraw`, `deposit_haul`, `craft`, `build`, `death`, `ring_two` (the first walk into ring two), `ring_three` (the first walk into ring three), `waystone` (attuning one, or arriving by one) or `import_save`. The presentation stores `sim.export_code()` |
| `save_rejected` | `reason` | An `import_save` failed |
| `hint` | `hint` | The guide moved to its next hint step (a `GuideTable` id), or `""` once the path is walked |
| `tip` | `tip` | A contextual tip fired (a `GuideTable.TIPS` id) |
| `hints_set` | `on` | The guide was turned off or back on |

## State shape

`Sim.state` is one plain-data Dictionary (ints, floats, strings, arrays, dictionaries only). Positions are `[x, z]` ground-plane metres. Camera state is never in it.

```
{
  "version": 11,
  "tick": 0,
  "rng": 1,                      # 31-bit generator state for gathering and drop rolls
  "player": {
    "pos": [0.5, 4.5],
    "facing": [0.0, 1.0],        # unit direction on the ground plane
    "path": [[x, z], ...],       # waypoints still to walk, empty when idle
    "target_object": "",         # object or loot id of a pending interact, "" otherwise
    "region": "outpost",
    "activity": {},              # {kind: "gather", object_id, progress}, {kind: "cook", item, progress}, {kind: "attack", object_id} or {kind: "travel", object_id, progress}
    "ready_tick": 0              # the first tick the player's weapon can swing again
  },
  "warmth": 360,                 # 0..Sim.WARMTH_MAX
  "health": 100,                 # 0..Sim.HEALTH_MAX
  "healing": [6, 6],             # food healing still to come, one entry per tick
  "inventory": {
    "pack": [null, {"item": "logs", "count": 4}, ...],   # exactly Sim.PACK_SLOTS (12) slots
    "equipment": {"weapon": "", "helm": "", "body": "", "legs": "", "tool": "wooden_axe", "quiver": "", "cape": ""}
  },
  "stash": {"capacity": 8, "slots": [...]},  # capacity slots, null when empty
  "skills": {"woodcutting": {"xp": 0, "level": 1}, ...},  # all eight
  "nodes": {"tree_1": {"left": 4, "respawn_tick": 0}, ...},
  "enemies": {"wolf_1": {"kind": "wolf", "pos": [x, z], "facing": [x, z], "health": 15,
              "mode": "idle", "next": {"action": "bite", "at": 12}, "step": 1, "phase": 0, "respawn_tick": 0}, ...},
  "loot": {"loot_1": {"item": "arrows", "count": 8, "pos": [x, z], "expires_tick": 640}, ...},
  "loot_seq": 1,                 # the last loot id handed out
  "fires": {"campfire_1": {"pos": [x, z], "expires_tick": 820}},  # burning field fires
  "fire_seq": 1,                 # the last field fire id handed out
  "bosses_defeated": ["captain"],  # guardians that have fallen at least once, kept for good
  "rings_reached": ["ring_two"], # rings beyond a ring gate walked into at least once
  "waystones": ["ring_one_waystone"],  # waystones visited (attuned), kept for good
  "upgrades": ["stash_shelves"], # built upgrade ids
  "pending": [],                 # queued inventory commands for the next tick
  "guide": {"on": true, "step": 0, "tips": {"cold": 640}}  # hint step reached; the tick each tip may fire again
}
```

`snapshot()` returns a deep copy. `restore(snap)` migrates an older snapshot forward, then replaces the state from a normalised copy: numbers JSON turned into floats come back as ints, unknown items are dropped, stacks are clamped, missing pieces get a new character's defaults. It returns false, leaving the state untouched, when the version is unknown or newer, or the player is unreadable. A snapshot survives `JSON.stringify` and `JSON.parse_string`. An enemy entry that is missing or unreadable loads at home, unhurt and idle.

## Rules and their numbers

How these numbers were measured against the brief's thirty minutes to the captain, and which ones were tuned for it, is in [balance.md](balance.md).

| Rule | Value |
|------|-------|
| Pack | 12 slots; logs, ore, bars, ice crystals, ring three's rare materials and fish stack to 10, arrows and frost shards to 100, gear never stacks |
| Carry limit | 45 kg, plus any built upgrade's `carry` effect (logs, copper, tin, coal, bronze bars and the rare materials 1 kg, iron ore, iron bars, steel bars and troll hides 2 kg, tools 1 to 3 kg, weapons 2 to 4 kg, armour pieces 1 to 3 kg, arrows and frost shards 0 kg); above it walking is 60% speed |
| Stash | 8 slots to start; the shelves, cellar and vault upgrades add 4 each, up to 20. A new character's stash holds a wooden bow, 30 arrows and 5 cooked fish |
| Experience curve | Shared by all eight skills: level L needs `50 * L * (L - 1) / 2` total xp (50, 150, 300, 500, ...), capped at 99. Levels never decrease |
| Gathering | One attempt takes `max(2, 4 - (level - 1) / 4 - tool)` ticks and succeeds with `min(95, 60 + 4 * (level - 1) + 10 * tool)` percent, where `tool` is the best carried tool's tier rank (wooden 0, bronze 1, iron 2, steel 3). Needs the node's tool (axe, pickaxe, rod) in the pack or the tool slot |
| Warmth | 360 points, draining 1 per tick outside the outpost (three minutes), in every ring. With `n` warmth worn (`sim.worn_warmth()`, the items' `warmth` summed over the equipment slots; 1 per fur piece) it drains on 6 (`Sim.WARMTH_PACE`) of every 6 + `n` ticks: a tick drains when ⌊(t+1)·6/(6+n)⌋ > ⌊t·6/(6+n)⌋, where t+1 is the tick's number, so a full gauge lasts 420, 480 or 540 ticks with one, two or three pieces worn. The pace comes from the tick count and what is worn, so nothing is saved for it and a swap counts from the next tick. No drain inside the outpost. Within 3 m of any fire (the outpost's, the brazier past the ring-two gate, a field fire) it refills 24 per tick and health refills 2 per tick |
| Field fire | 3 logs from the pack, lit where the player stands outside the outpost; warms and cooks like the outpost fire for 120 ticks (a minute), then goes out |
| Cold | At zero warmth health drains 1 per tick (50 s from full). At zero health the player dies by the death rule below |
| Cooking | One raw item every 2 ticks at any fire. Burn chance is the dish's base at its level, minus 5 per level above: raw fish 40% at cooking 1 (gone by level 9), 10 xp; raw trout needs cooking 3, 50% there, 18 xp; raw char needs cooking 5, 50% there, 26 xp. Burnt food is lost and gives no xp |
| Food | Raw fish heals 4 over 2 ticks, cooked fish 24 over 4, raw trout 6 over 2, cooked trout 40 over 5, raw char 8 over 2, cooked char 56 over 7, starting the tick it is eaten. Meals overlap by adding up |
| Smithing | At the workbench, the inputs taken from the stash first, then the pack (`sim.smithing_count(kind)` counts both), the output into the pack, which needs room for it once the inputs are out. The smithing cap is bronze until the Bloomery lifts it to iron, or the blast furnace to steel; the highest built lift wins. A recipe needs both its tier within the cap and its named upgrade built, so the blast furnace alone smelts no iron. Fur recipes have no tier ("", which ranks below every tier), so the cap never refuses them. Iron gear is smithed after the Bloomery and still drops as loot |

**Nodes** (each regrows `respawn` ticks after its last yield):

| Node | Where | Skill and level | Tool | Yields | Per node | Respawn | Xp |
|------|-------|-----------------|------|--------|----------|---------|----|
| Pine (tier 1) | 6 south of the gate, 4 north of the walls | woodcutting 1 | axe | logs | 4 | 90 | 10 |
| Copper rock (tier 1) | 4 in the inner ring, one in each spot of a copper and a tin rock: north by the fallen pine, east by the split rock, south east of the cairn, west by the dead giant, 15 to 22 m out and out of earshot of every enemy. 3 more in ring one's mine, with 3 tin rocks, against the west cliff north of the watch post: a visit there is 12 copper and 12 tin ore, and `witch_2` hears it from every side. No other copper or tin in ring one | mining 1 | pickaxe | copper ore | 4 | 100 | 10 |
| Tin rock (tier 1) | 4 in the inner ring, one beside each copper rock, and 3 in ring one's mine | mining 1 | pickaxe | tin ore | 4 | 100 | 10 |
| Fishing hole (tier 1) | 2 together north of the outpost | fishing 1 | rod | raw fish | 6 | 80 | 10 |
| Ice crystal (tier 1) | 2 north of the outpost, east and west | mining 2 | pickaxe | ice crystal | 3 | 120 | 14 |
| Frost pine (tier 2) | 4 in ring one, west | woodcutting 3 | axe | logs | 6 | 120 | 16 |
| Iron rock (tier 2) | 4 in ring one, in two spots of 2 far apart: east by the archer camp and south-west by the far wolf pack, clear of the cliffs and the road south. One sweep of both is 12 ore, the winch's iron | mining 3 | bronze pickaxe or better | iron ore | 3 | 150 | 18 |
| Ice hole (tier 2) | 6 in ring one, in three spots of 2: north by the north pack, east and west; none on the road south | fishing 3 | rod | raw trout | 5 | 120 | 16 |
| Coal seam (tier 3) | 4 in ring two's east wing, 1 in the far ruins | mining 5 | bronze pickaxe or better | coal | 4 | 150 | 22 |
| Rich iron vein (tier 3) | 3 in ring two's keep | mining 6 | bronze pickaxe or better | iron ore | 5 | 160 | 24 |
| Deep hole (tier 3) | 3 on ring two's frozen lake, west | fishing 5 | rod | raw char | 5 | 140 | 22 |

**Workbench recipes** (smithing):

| Recipe | Inputs | Level | Upgrade | Xp |
|--------|--------|-------|---------|----|
| Wooden club, axe, pickaxe, fishing rod | 4, 3, 3, 3 logs | 1 | none | 10 |
| 10 frost shards | 1 ice crystal | 1 | none | 8 |
| Wooden staff | 3 logs, 1 ice crystal | 1 | none | 12 |
| Wooden helm, body, legs | 2, 4, 2 logs | 2 | none | 5, 10, 5 |
| Bronze bar | 1 copper ore, 1 tin ore | 1 | Forge | 10 |
| 25 arrows | 2 logs, 1 bronze bar | 2 | Forge | 10 |
| Bronze axe, bronze pickaxe | 1 bronze bar, 2 logs | 2 | Forge | 15 |
| Bronze sword | 2 bronze bars, 1 log | 2 | Forge | 25 |
| Bronze bow | 2 bronze bars, 3 logs | 2 | Forge | 25 |
| Bronze staff | 2 bronze bars, 2 logs, 1 ice crystal | 2 | Forge | 25 |
| Bronze helm, body, legs | 1, 2, 1 bronze bars | 3 | Armoury | 10, 20, 10 |
| Fur hood, coat, leggings | 2, 3, 2 wolf pelts | 3 | Armoury | 10, 20, 10 |
| Iron bar | 2 iron ore | 3 | Bloomery | 18 |
| Iron axe, iron pickaxe | 1 iron bar, 2 logs | 3 | Bloomery | 22 |
| Iron sword | 2 iron bars, 1 log | 4 | Bloomery | 36 |
| Iron bow | 2 iron bars, 3 logs | 4 | Bloomery | 36 |
| Iron staff | 2 iron bars, 2 logs, 1 ice crystal | 4 | Bloomery | 36 |
| Iron helm, body, legs | 1, 2, 1 iron bars | 4 | Bloomery | 15, 30, 15 |
| Steel bar | 1 iron ore, 2 coal | 4 | Blast furnace | 25 |
| Steel axe, steel pickaxe | 1 steel bar, 2 logs | 4 | Blast furnace | 30 |
| Steel sword | 2 steel bars, 1 log | 5 | Blast furnace | 50 |
| Steel bow | 2 steel bars, 3 logs | 5 | Blast furnace | 50 |
| Steel helm, legs | 1 steel bar each | 5 | Blast furnace | 20 |
| Steel body | 1 steel bar, 1 troll hide | 5 | Blast furnace | 40 |

**Outpost upgrades** (paid from the stash and your pack, inside the outpost; the stash first). An upgrade's effects are keys in its `effects`: `stash` (slots added to the stash), `carry` (kilograms added to the carry limit), `recipes` (workbench recipes unlocked), `smithing_tier` (the highest tier the workbench works), `ring_gate` (the ring gate it readies) and `waystones` (the waystones it wakes). No upgrade has a `carry` effect yet.

| Upgrade | Cost | Needs | Effect |
|---------|------|-------|--------|
| Stash shelves | 8 logs | none | +4 stash slots |
| Forge | 6 logs, 3 copper ore, 3 tin ore | none | Unlocks bronze bars, arrows, bronze tools and weapons |
| Stash cellar | 10 logs, 2 bronze bars | Stash shelves | +4 stash slots |
| Armoury | 6 logs, 2 bronze bars, 3 wolf pelts | Forge | Unlocks the bronze helm, body and legs, and the fur hood, coat and leggings |
| Pack frame | 10 logs, 4 wolf pelts | Armoury | +15 kg carry limit, to 60 kg. Optional: nothing else needs it |
| Bloomery | 8 logs, 2 bronze bars, 4 iron ore | Armoury | Unlocks iron bars and iron tools, weapons and armour, and lifts the smithing cap to iron. Optional: nothing else needs it |
| Ring-two gate winch | 12 logs, 12 iron ore, 3 bronze bars, 5 wolf pelts | Armoury | Readies the gate to ring two; it opens once the captain has fallen |
| Blast furnace | 12 logs, 4 bronze bars, 6 coal, 2 troll hides | Ring-two gate winch | Unlocks steel bars, tools, weapons and armour, and lifts the smithing cap to steel |
| Ring-three gate hoist | 8 steel bars, 4 troll hides, 12 coal, 16 logs | Blast furnace | Opens the gate to ring three, which has no guardian |
| Waystones | 10 iron ore, 6 bronze bars, 10 logs | Ring-two gate winch | Wakes the waystones in ring one and ring two |
| Stash vault | 12 logs, 10 iron ore, 4 coal | Stash cellar, Ring-two gate winch | +4 stash slots |

`sim.upgrade_status()` answers, without changing anything, the status of every upgrade, keyed by id in table order: `built`, `can_build` (unlocked, every prerequisite built, the whole cost held) or `not_yet`. Inside the outpost the cost counts the stash and the pack together; outside it counts the stash alone, since carried loot is not safe until the gate. Each entry also carries `locked` (the table's text), `requires` (prerequisite ids not yet built), `cost` (every cost item as `{item, have, need}`, `have` counted that way), `short` (the cost entries that falls short of) and `reason` (what `check(build)` says now, so standing outside the outpost shows there). The Upgrades tab reads only this.

**Gear tiers** (every weapon, armour piece and tool has one, and it shows on the character):

| Tier | Melee | Ranged (arrows) | Magic (frost shards) | Armour defence (helm + body + legs = set) | Tools | Comes from |
|------|-------|-----------------|----------------------|-------------------------------------------|-------|------------|
| Wooden | club, power 5 | wooden bow, power 4 | wooden staff, power 4 | 0 + 1 + 0 = 1 | axe, pickaxe, fishing rod | the workbench, from logs (the staff also takes an ice crystal) |
| Bronze | sword, power 7 | bronze bow, power 6 | bronze staff, power 6 | 0 + 1 + 1 = 2 | axe, pickaxe | the workbench, after the forge (armour after the armoury) |
| Iron | sword, power 9 | iron bow, power 8 | iron staff, power 8 | 1 + 1 + 1 = 3 | axe, pickaxe | the workbench, after the Bloomery, from ring one's iron ore; also as loot, in both rings and from the captain |
| Steel | sword, power 11 | steel bow, power 10 | steel staff, power 10 | 1 + 2 + 1 = 4 | axe, pickaxe | the workbench, after the blast furnace, from ring two's coal |

Armour is three equipment slots, helm, body and legs, each taking its own piece; there are seven equipment slots in all (weapon, helm, body, legs, tool, quiver, cape). The quiver and cape are not armour slots, so nothing in them adds to worn defence; every item in the quiver slot is a ranged set quiver (two from #164, four from #165), and the only items in the cape slot are the Auroral Warden mantle and the Ruin Stalker shroud (#165) and the two magic set cloaks (#166; the slots came with [#161](https://github.com/travism26/frostmark/issues/161)). A full set of one tier weighs, is worth and costs what that tier's single armour did before the split ([#38](https://github.com/travism26/frostmark/issues/38)), and takes the same off a hit. Pieces of different tiers can be worn together.

Fur pieces (fur hood, fur coat, fur leggings; 1, 2 and 1 kg) go in the helm, body and legs slots like metal armour but have no gear tier and no defence: a full fur set takes nothing off a hit. Each carries `warmth` 1, so worn fur slows the warmth drain outside (see Warmth above); it changes nothing by a fire, inside the outpost or to the cold damage at zero warmth. They are a sideways choice to metal, made from wolf pelts at the workbench once the Armoury is built, and count toward carry weight like any armour.

A set item (`"set": "<set key>"`, read by `ItemTable.set_of`) is likewise a sideways piece with no tier until #138 places the sets on the ladder. Until #138 settles its stats and sources it takes the stats of the steel item of its slot and style, and has no recipe and no drop: it is reached only through the all-gear test code. A quiver or cape has no steel counterpart, so until #138 a quiver or cape set item takes weight 1, value 40, no defence and no warmth. The melee sets (#162) are Hearthguard (`hearthguard`), Wolfmark (`wolfmark`) and Ruinwarden (`ruinwarden`), and the melee top sets (#163) Emberheart (`emberheart`), Hoarfrost (`hoarfrost`), Auroral (`auroral`) and Trollbone (`trollbone`), each a helm, a body, legs and a weapon (a broadsword, a bearded axe, a greatsword, a forge hammer, an icicle greatsword, a glaive, a tusk cleaver; the kind is look only, the stats the steel sword's). The ranged sets (#164) are Trapper's Leathers (`trapper`), Wolfstalker (`wolfstalker`) and Steelpoint Ranger (`steelpoint`), each a helm, a body, legs and a bow with the steel bow's stats, and Wolfstalker and Steelpoint each a quiver under the quiver rule. The ranged top sets (#165) are Ember Hawk (`ember_hawk`), Auroral Warden (`auroral_warden`), Ruin Stalker's Shroud (`ruin_stalker`) and Glacier Sovereign (`glacier_sovereign`), each a hood, mask or crown in the helm slot, a jerkin, a kilt, a bow with the steel bow's stats and a quiver under the quiver rule, and Auroral Warden and Ruin Stalker each a cape (a mantle, a shroud) under the same rule. The magic sets (#166) are Shardweaver (`shardweaver`), Rimecaller (`rimecaller`) and Glacier Warden (`glacier_warden`), each a helm, a body, legs and a staff with the steel staff's stats (its head is look only), and Rimecaller and Glacier Warden each a cloak under the cape rule. The magic top sets (#167) are Hoarfrost Sovereign (`hoarfrost_sovereign`), Hearthfire Magus (`hearthfire_magus`), Aurora Shaman (`aurora_shaman`) and Ruinwarden (`ruinwarden_mage`, labelled Ruinwarden like the melee set of that name), each a crown, hood or antlers in the helm slot, a robe, legs, a staff with the steel staff's stats and a cloak under the cape rule.

Ring three's rare materials (#179) are rime steel (`rime_steel`), frost sinew (`frost_sinew`) and aurora glass (`aurora_glass`): haul with no slot and no tier, 1 kg, worth 25 and stacking to 10, like a troll hide. Each is meant to drop from one of ring three's enemy styles (melee, ranged, magic) and the Frost tyrant, and to feed that style's top sets; until those tickets land no enemy drops them and no recipe or upgrade spends them.

Item values, which decide what death keeps: logs 2, copper and tin ore 3, coal 6, iron ore 8, bronze bar 8, steel bar 30, raw fish 2, cooked fish 6, raw trout 4, cooked trout 12, raw char 6, cooked char 18, wolf pelt 8, troll hide 20, rime steel, frost sinew and aurora glass 25 each, ice crystal 4, arrows and frost shards 1 each; wooden axe 5, pickaxe and rod 6, club 12, wooden helm 3, legs 5, body 8, wooden bow 20, wooden staff 22; bronze helm 10, legs 16, axe and pickaxe 24, body 24, sword 40, bow 44, staff 46; iron helm 20, legs 30, body 40, axe and pickaxe 60, sword 80, bow 84, staff 86; steel helm 40, legs 60, body 80, axe and pickaxe 120, sword 160, bow 168, staff 172; fur hood 20, leggings 20, coat 30.

## Combat

Everything that fights is a combatant of one shape, `sim.combatant(id)`: `{id, kind, pos, health, health_max, weapon, style, reach, defence, next}`. The player's style comes from the weapon slot (fists when it is empty); an enemy's from its kind's weapon. `next` is the action declared for the coming tick as `{action, at}`; for a feint it shows the attack the feint pretends to be. Every blow, either way, goes through the same arithmetic.

**The style edge.** `CombatTable.EDGES` is keyed by (attacker style, defender style) and gives `{dealt, taken, range}`. With the edge, an attacker deals `dealt` times its damage and takes `taken` times the damage that defender deals back, while the two stand at `range`. The rule is the full triangle: melee beats ranged, ranged beats magic, magic beats melee, and the same style is neutral. Melee's edge on ranged holds within 1.5 m, where a blade reaches; beyond 1.5 m a bow keeps the slice-4 edge on a melee defender. Ranged's edge on magic and magic's edge on melee hold at any range. Every edge is dealt 1.5 and taken 0.5. A blow's multiplier is the attacker's `dealt` against the defender times the defender's `taken` against the attacker, so 1.5 with the edge, 0.5 into it and 1.0 neutral. Magic arrived as rows in the table; the arithmetic is unchanged.

| Attacker on defender | Within 1.5 m | Beyond 1.5 m |
|----------------------|--------------|--------------|
| Melee on ranged | 1.5 | 0.5 |
| Ranged on melee | 0.5 | 1.5 |
| Ranged on magic | 1.5 | 1.5 |
| Magic on ranged | 0.5 | 0.5 |
| Magic on melee | 1.5 | 1.5 |
| Melee on magic | 0.5 | 0.5 |
| Same style | 1.0 | 1.0 |

**Damage** is `max(1, round(base * multiplier) - defence)`. The player's base is the weapon's power plus 1 for every 3 levels of the style's skill above 1. An enemy's base is its action's damage. The defence of every armour piece worn, added up, comes off every hit (a full set: wooden 1, bronze 2, iron 3, steel 4).

| Weapon | Style | Power | Swings every | Reach |
|--------|-------|-------|--------------|-------|
| Fists (empty slot) | melee | 2 | 2 ticks | 1.5 m |
| Wooden club, bronze, iron, steel sword | melee | 5, 7, 9, 11 | 2 ticks | 1.5 m |
| Wooden, bronze, iron, steel bow | ranged | 4, 6, 8, 10, one arrow a shot | 2 ticks | 8 m |
| Wooden, bronze, iron, steel staff | magic | 4, 6, 8, 10, one frost shard a cast | 2 ticks | 6 m |

**Attacking.** `attack` sets the activity to `{kind: attack, object_id}`. Each tick the player walks to within 80% of the weapon's reach of the target, re-routing as it moves, then strikes on every tick at or after `ready_tick`; a swing sets `ready_tick` to the tick plus the weapon's speed. A bow's shot spends one arrow from the pack and a staff's cast one frost shard; either refuses with `no_ammo` when none are left, which also ends the attack. A hit grants 4 xp per point of damage to the style's skill (`melee`, `ranged` or `magic`).

**Auto-retaliate.** While it is on, a blow that lands on a player standing idle (no path to walk and no activity) sets the activity to an attack on the enemy that struck, exactly as `attack` would, so the player closes in and swings from the next tick. It never swaps weapons, so the style is whatever is in hand. A walking or busy player (gathering, cooking, channelling, already attacking) is left alone, and any later command replaces the attack as usual, so a move click always wins. It holds back, silently, wherever `attack` would refuse (inside the outpost, across the ring-two gate, a bow or staff with no ammunition).

**Swapping and eating** are queued commands, so both land at the start of the next tick. A swap ordered on the tick before a swing makes that swing in the new style. A meal costs the tick it lands on: the player neither steps nor swings, and the swing comes a tick later.

**Enemies** are idle at home, engaged, returning or dead.

| Kind | Health | Weapon | Speed | Sight | Action cycle | Drops | Rare drop |
|------|--------|--------|-------|-------|--------------|-------|-----------|
| Wolf | 15 | fangs (melee, 1.5 m) | 2.5 m a tick | 6 m | bite 3, rest, lunge 7 (heavy), rest | 1 wolf pelt | 5% |
| Bandit archer | 20 | wooden bow (ranged, 8 m) | 1.5 m a tick | 9 m | shot 4, rest, rest, aimed shot 9 (heavy), rest | 8 arrows | 10% |
| Frost witch | 18 | wooden staff (magic, 6 m) | 1.5 m a tick | 8 m | frost bolt 4, rest, rest, ice lance 9 (heavy), rest | 10 frost shards | 10% |
| Bandit captain | 240 | sabre (melee, 1.5 m), war bow (ranged, 8 m) and rime staff (magic, 6 m) by stance | 2 m a tick | 7 m | slash 8, rest, cleave 17 (heavy), rest, draws his bow, loose 7, rest, volley 16 (heavy), rest, raises his staff, rime bolt 7, rest, blizzard 16 (heavy), rest, draws his sabre | 20 arrows and one piece of iron gear (sword, bow, staff, helm, body or legs) | 25% |
| Ice troll | 90 | ice club (melee, 1.5 m) | 1.5 m a tick | 6 m | smash 8, rest, winds up, crush 26 (heavy), rest, rest | 1 troll hide | 15% |
| Ruin stalker | 35 | bone bow (ranged, 8 m); backs away inside 4 m | 1.5 m a tick | 10 m | dart 4, dart 4, rest, barbed volley 10 (heavy), rest, rest | 12 arrows, 1 coal | 10% |

- An idle enemy notices the player when the player is within its sight radius, within the radius of a noise the player made this tick (a gathering attempt carries 9 m, a blow struck or taken 12 m), or strikes it. When one member of a pack engages, the rest of the pack engages with it.
- Each tick an engaged enemy first carries out what it declared last tick: a move closes in toward the player, a rest does nothing, an attack lands as `hit` if the player is still in its reach and `missed` if not, and a feint strikes nothing (`enemy_feinted`). Then it declares the next tick: the next action of its cycle while the player is in its reach, else a move. Every attack it declares is telegraphed with an `enemy_telegraphed` event whose `at` is the next tick, so the warning always comes exactly one tick before the blow.
- Enemies never step into the outpost. While the player is inside, every engaged enemy disengages, walks home deaf to the player, and heals to full on arriving.
- Nothing notices, chases or fights across a ring gate. The gates part the world into bands (`Sim.BANDS`): the outpost, the inner ring and ring one are band 0, ring two band 1 and ring three band 2. An enemy whose home lies in another band from the player never notices them, an engaged one disengages (as for the outpost) the tick the player is across, and `attack` on one is `unreachable`.
- A dead enemy drops its loot where it fell, plus one rare item (an iron sword, helm, body, legs, bow, axe, pickaxe or staff, evenly) at the kind's rare-drop rate. Wolves, archers and witches come back at home 100 ticks later, stalkers 300, trolls 400, the captain 600.
- **The ice troll** winds up the tick before its crush: the wind-up is an `enemy_stance` a tick ahead, then the crush is telegraphed, so the heaviest blow in the game is seen two ticks out. A wind-up commits it: the crush is declared even if the player has stepped out of reach, and then misses. It is slow, so stepping back is the counter; a staff has the edge on it at any range and a bow at distance.
- **The ruin stalker** kites: on any tick it does not move, if the player is within 4 m it then backs one step (its speed) straight away, still facing them. A wall or anything else blocking that step stops it, so it can be cornered. Up close a blade has the edge on it; at range a bow is neutral, and a blade or a staff walks into its edge.
- **The captain** fights with three weapons. His cycle lists the weapon he holds for each action, so his style and reach follow his place in it: two sabre blows (the second heavy), then he draws his bow (an `enemy_stance` event, a tick ahead, in the ranged colour), two shots (the second heavy), then he raises his staff (in the magic colour), two casts (the second heavy), then he draws his sabre again. Each stance has its counter: magic, or a bow at distance, while he holds the sabre; a sword up close while he holds the bow; a bow while he holds the staff. He always drops one piece of iron gear. His first death is recorded in `bosses_defeated` for good, even after he respawns. Once the gate he guards stands open, a guardian that dies stays down: the way home from ring two is not barred again.

**Action keys.** Each entry in `CombatTable.ACTIONS` has a `label` and a base `damage`; an action with damage above 0 is an attack. `heavy` marks the attacks worth countering (a bigger ring and a louder cue). `stance` makes a rest that is announced a tick ahead with `enemy_stance` (the captain's weapon changes, a troll's wind-up). `windup` commits the enemy: the next action of its cycle is declared even with the player out of reach. `feint` names the attack the action pretends to be (`CombatTable.is_feint`, `CombatTable.shown_action`).

**Feints.** A feint is a telegraphed blow that never lands. It is declared from the cycle like the attack it pretends to be (in reach, or straight after a wind-up even out of reach) and told with an `enemy_telegraphed` event identical to that attack's, and `combatant(id).next` shows that attack, so nothing tells the two apart before the feint tick. The enemy's saved `next` keeps the feint itself, so a save taken mid-feint still feints. On the feint tick the enemy turns to the player and strikes nothing: no `hit`, no `missed`, an `enemy_feinted` instead. It makes no fight noise, sets off no auto-retaliate, breaks no waystone channel and grants no experience. The enemy then declares its next action as usual, so a real blow after a feint is telegraphed on the feint tick, one tick before it lands, and a kind that kites backs off after a feint tick as after any tick it did not move. The guide's `telegraph` tip fires on a feint's telegraph as on any blow's. No enemy feints yet; ring three's will. Until then the feint tests (`tests/test_sim_feints.gd`) define stand-in kinds through `CombatTable.add_stand_ins()`, which is empty in the game.

**Fight phases.** A kind may carry `phases`, an ordered list of `{below, actions, stances}` (`stances` optional, as on the kind itself), where `below` is a percentage of its health from 1 to 99, lower for each phase than the one before. Below a phase's mark the enemy changes into that phase's cycle, so the end of a fight is the most dangerous part: a heavy blow that gave two ticks of warning behind a wind-up can give one. Each enemy's state keeps `phase`: 0 on its kind's own cycle, then 1, 2 … into `phases`. Once a blow takes its health below a mark, the next declaration it makes from its cycle starts that phase's `actions` from the first, with `step` back at 0; a blow that crosses two marks starts the deeper phase. A move declared while the player is out of reach does not count, so the change always shows. Each phase's cycle begins with a stance, so the change is announced a tick ahead with `enemy_stance` (`CombatTable.phase_problems` refuses a phase that does not, and a mark outside 1 to 99). A blow already declared still lands, misses or feints as declared, and a phase never starts between a wind-up and the blow it committed. From then on the phase's `actions` and `stances` replace the kind's for the rest of that life (`CombatTable.cycle`, `CombatTable.stance_weapon`, `combatant(id)` and the declaration all read them), and the enemy never goes back to a shallower phase. `phase` is 0 again on a fresh enemy, at respawn, and when the enemy walks home and heals. No enemy has a phase yet; the stand-in phaser in `tests/sim_helpers.gd` carries the rule for `tests/test_sim_phases.gd`.

**The readability floor** (`tests/test_sim_telegraphs.gd`) runs every kind in `CombatTable.ENEMIES`, and the stand-in feinting and phased kinds, through long seeded fights against a player who swaps style and steps in and out of reach, and who strikes a kind with phases until it has fought in each. On every tick, every `hit` or `missed` from an enemy came on the tick an `enemy_telegraphed` from it named one tick earlier, and lands in the style it was told in; every change in an enemy's style (`combatant(id).style`) comes with an `enemy_stance` on the same tick, so it shows a tick before the stance and two before any blow in it; and no damage is dealt on a tick an `enemy_feinted` names. A phase change counts as a change of style when the new phase's first stance changes weapon; a respawned enemy starts afresh in its kind's own weapon.

**Loot** piles lie for 600 ticks (five minutes) and then the snow takes them. `interact` on a pile walks onto it and picks up as much as fits; the rest stays.

Ring two's enemies: a lone stalker in the yard behind the gate, west; a stalker at the gap in the outer wall in front of the keep; a troll by the frozen lake, west; a pair of trolls inside the keep; a pair of stalkers among the coal seams, east; and in the far ruins a troll (west) and a stalker (east).

Ring one's enemies: just past the southern pines, two wolves (`wolf_1`, `wolf_2`, the near pack) south-west, a pack of three farther west and a bandit archer (`archer_1`) south-east; farther out, a two-archer camp by the iron rocks (east), a wolf pair among the frost pines (west), a pack of three by the north ice holes, two lone archers flanking the road south, a lone frost witch out on each northern flank (`witch_1` north-east, `witch_2` north-west at the mouth of the mine), and the captain at the ring-two gate. The groups sit more than a fight's noise (12 m) apart, so each is fought on its own. Chopping the south-western pine is loud enough for the near pack to hear.

## Death

At zero health, from a blow or the cold, the player keeps the seven most valuable things they carry or wear (`DEATH_KEEPS`, one per equipment slot) and loses everything else for good. A stack is one thing, valued at its whole count (30 arrows are worth 30). On a tie what is worn comes first, then the earlier pack slot. Kept things stay where they were. The player wakes beside the outpost fire with full health and warmth; healing in progress and queued commands are cleared, every engaged enemy disengages, and skills, stash and upgrades are untouched. The workbench makes an axe only from logs, and logs need an axe, so if the death took the last axe and none is stashed, a spare wooden axe goes into the tool slot (or the pack when the slot is taken). The tick emits `died` and is a save point with reason `death`.

## The ring-two gate

The gate to ring two (`ring_two_gate`) stands in the cliffs at ring one's far southern edge. It always blocks the walkability grid like a wall, so no route, no click and no enemy ever crosses it. It is open once its guardian (`captain`) is in `bosses_defeated` and its upgrade (`ring_two_gate`) is built, in either order; whichever comes second emits `ring_gate_opened`, and an open gate never closes.

`interact` walks to it from either side. Arriving while it is open walks the player straight on through it to `Sim.RING_GATE_STEP` (3 m) past its centre on the far side, along its `outward` direction: a path the grid would never give. It is not a return; the haul is at risk until the outpost gate. The first time the player walks into the `ring_two` region, `ring_two_reached` is emitted, `ring_two` is added to `rings_reached`, and the tick is a save point (`ring_two`); the presentation shows a banner, not an ending. Arriving while the gate is barred does nothing but the `interacted` event.

## The ring-three gate

The gate to ring three (`ring_three_gate`) stands in the south-west of ring two's southern cliff, at x -40: more than 30 m from `ring_two_waystone` and out of sight of every ring-two home, so reaching it is not a forced fight but the walk back to the waystone still crosses ring two. It is shaped like the ring-two gate and sits in the cliff's outer half, so the alcove in front of it is ring two's and a walk through it ends clear of the line between the rings either way. It always blocks the grid. It has no `guardian`: `ring_gate_open` opens a gate without one on its upgrade alone, here the Ring-three gate hoist (`ring_three_gate`), and building that emits `ring_gate_opened`. The ring-two gate still needs both its captain and its winch.

Walking up to it works as at the ring-two gate (`Sim.RING_GATE_STEP` past it, either way). The first walk into the `ring_three` region emits `ring_three_reached`, adds `ring_three` to `rings_reached` and is a save point (`ring_three`); the presentation shows a banner, not an ending. A fire (`ring_three_fire`) burns a few metres in from the gate and warms and heals within `Sim.FIRE_REACH` like the brazier; warmth drains on the glacier as everywhere outside. Ring three has no waystone and no gathering nodes; ring two's waystone is the nearest way home. Its enemies arrive with their own tickets.

## Waystones

Two waystones stand in the rings: `ring_one_waystone` near ring one's far southern road, out of the captain's sight, and `ring_two_waystone` in ring two's far ruins south of the keep. Each is a blocking object, walked up to with `interact`. The first arrival attunes it for good: it joins `state.waystones`, `waystone_attuned` is emitted and the tick is a save point (`waystone`). Attuning works whether or not the stone is awake.

A waystone is awake once an upgrade whose `waystones` effect lists it is built (the Waystones upgrade lists both). `travel` from an awake, attuned waystone within 1.5 m sets the activity to `{kind: travel, object_id, progress}`, stops the walk and anything else under way, and emits `travel_started`. Each tick adds one to `progress`; on the `Sim.TRAVEL_TICKS`th (6, three seconds) the player stands `Sim.TRAVEL_GATE_STEP` (2.5 m) outside the outpost gate, facing it, `travelled` is emitted (and `region_changed`), every engaged enemy disengages and heads home, and the tick is a save point (`waystone`).

The channel is a way home, not a way out of a fight: a blow taken while channelling (any `hit` on the player; the cold does not count) stops it with `interrupted`, and so does walking, attacking, cooking or gathering. Telegraphs come a tick ahead and every enemy in reach strikes at least every three ticks, so six ticks of channelling only finish out of reach. **Travel is never a return.** It carries the player and the pack to the outside of the gate; the walk through it is still the player's, and that is the return.

## The first-outing guide

The brief rules out quests and dialogue, so the guide only says what to try next. `GuideTable.STEPS` is the hint path: walk, cut a pine, walk the logs back through the gate, craft at the workbench. Each step is done by its trigger event (`moved`; `gathered` of logs; `returned` with something in the pack; `crafted`). The craft step makes the pickaxe straight from the logs still in the pack, and only the current step listens, so doing things early never skips ahead. Every event is checked as it is emitted, so a rejected command counts at once. Each advance emits `hint`. `sim.hint()` is the current step's id, `""` when the guide is off or the path is walked.

`GuideTable.TIPS` are the contextual tips. `pack_full` fires on a gather or pick-up refused or stopped for a full pack; `telegraph` on an enemy's telegraphed blow; `cold` is a condition checked at the end of each tick: warmth at or below `GuideTable.COLD_WARMTH`, outside, and away from any fire. A tip that fires emits `tip` and stays quiet for its `cooldown` ticks. Tips keep firing after the path is walked, while the guide is on.

`set_hints` turns everything off or back on. `new_character` turns it off for every character after the first: the presentation passes the browser save it is about to replace. A character from before the guide existed migrates with it off.

## The gate and the return

Walls leave the gate as the only way into the outpost, so any walk whose region changes into `outpost` has crossed it inward: a return. It moves nothing. Inside the walls nothing can be lost, but only the stash is safe for good: whatever stays in the pack rides out on the next trip, under the usual death rule. The return emits `returned` with what the pack holds and the upgrades the pack now pays for, and makes the tick a save point (`gate`), even with an empty pack. Equipment stays worn. Putting things away is `deposit_haul` at the stash. Walking out starts the warmth drain because the region is no longer `outpost`.

## Saves

The simulation never touches the filesystem. It reports save points with `saved`; the presentation then stores `sim.export_code()` in `user://frostmark.save` (IndexedDB in the browser). The stored text and the code the player exports are the same format, so a damaged browser save is caught exactly like a bad pasted code.

A save code is base64 of `FM|<version>|<checksum>|<snapshot JSON>`. The JSON is compact with sorted keys. The checksum is the first 16 hex digits of SHA-256 over `<version>|<snapshot JSON>`: it catches typos, truncation and hand edits, and is not meant to stop a determined cheat. Decoding accepts only the canonical base64 of the decoded bytes, so every changed character is caught. It ignores whitespace from wrapped pastes, refuses codes from a newer build, and never raises an engine error.

`SaveCode.migrate(snap, target)` applies one step per version. Each step hard-codes the defaults of its own version, so retuning a constant later never changes what an old save migrates into. `1 -> 2` keeps the slice-2 tick and position and adds a new character's inventory, stash, skills, warmth, health and nodes. `2 -> 3` adds the swing timer, an empty healing queue, enemies (empty, so every enemy loads at home and idle) and ground loot, and puts the slice-4 starter kit (a wooden bow, 30 arrows, 5 cooked fish) into empty stash slots so a slice-3 character can fight too. What does not fit is not added. `3 -> 4` adds no field fires and no fallen guardians and changes nothing else: the stash keeps its capacity, known nodes and enemies keep their state, and the new ring-one nodes, enemies and the captain load full and at home. `4 -> 5` adds the first-outing guide switched off with its four steps walked, since a version-4 character has already been played. `5 -> 6` adds the magic skill at level 1 with no experience (an entry already there is kept) and changes nothing else: the ice crystals and frost witches load full and at home, and the captain carries on from the step of his cycle he was on. `6 -> 7` adds no rings reached and changes nothing else: ring two's nodes and monsters load full and at home, and a character who saw the old ending finds the gate open, with its first walk through still announced. `7 -> 8` adds no waystones visited and changes nothing else: the upgrade could not be built before, so every waystone sleeps until it is built and must be walked to once. `8 -> 9` only raises the version: a version-8 save cannot hold the Stash vault, so its upgrades and stash stay exactly as they were. `9 -> 10` splits the armour slot into helm, body and legs: each `<tier>_armour` becomes that tier's body piece wherever it is (worn, in the pack, in the stash, lying as loot or named by a queued command), and the helm and legs slots start empty. `10 -> 11` adds the quiver and cape slots, both empty, and changes nothing else. `11 -> 12` adds `phase: 0` to every saved enemy, since no enemy had a fight phase before, and changes nothing else; `restore()` puts a missing or out-of-range `phase` back to 0.

Every version ever shipped keeps a real save code in `tests/fixtures/save_v<N>.txt`, and `tests/test_save_fixtures.gd` imports each into the current build. **Each future version bump adds its fixture** (a code exported from the build that introduces the version) along with its migration step; old fixtures are never edited. The test fails when a version has no fixture.

A browser save can fail to hold: storage full, or blocked as in some private browsing (`OS.is_userfs_persistent()` is false, so writes last only until the page closes). The game keeps running and the save code is the fallback. `SaveWatch` counts ticks of play, not wall-clock time, so a paused game does not count down. It falls due every 5400 ticks (45 minutes) since the player last opened or copied their code or dismissed a reminder, and every 1800 ticks (15 minutes) while browser saves are failing. `stored(ok)` records each browser-save write and answers true only on the write that fails after storage was fine, so the warning shows once per failure rather than at every save point.

## The world as data

`WorldDef.outpost()` builds the world, rings around the outpost. A `WorldDef` has:

- A grid of `cols` x `rows` square cells of `cell_size` (128 x 256 cells of 1 m, origin at `[-64, -64]`, so ring two fits south of ring one and ring three south of ring two), rasterised by `bake()` from the solids and blocking objects.
- `solids`: `{id, kind, min, max, height}` rectangles: the outpost's palisade `wall`s, the `cliff`s that close ring one at 60 m (open only at the ring-two gate) and wall in ring two from 64 m to 124 m (open only at the ring-three gate) and ring three from 128 m to 188 m, rock `outcrop`s that make the walk out a route, ring two's `ruin` walls and pillars, ring three's pressure `ridge`s in the ice, and the keeper's tent (`decor`) in the outpost yard.
- `objects`: typed markers by id, `{kind, label, min, max, height, blocks}`. The outpost has `gate` (with an `outward` direction), `fire`, `stash` and `workbench`; the inner ring has `tree_1` to `tree_10`, `copper_4` to `copper_7` and `tin_4` to `tin_7` (the north, east, south and west spots), `fishing_hole` and `fishing_hole_2`, and `ice_crystal_1` and `ice_crystal_2`; ring one has `frost_pine_1` to `frost_pine_4`, `iron_1` and `iron_2` (the east spot) and `iron_4` and `iron_5` (the south-west spot), `ice_hole` and `ice_hole_2` to `ice_hole_6` (the north, east and west spots, two each, the old `ice_hole` in the north one), `copper_8` to `copper_10` and `tin_8` to `tin_10` (the mine), `ring_one_waystone` and `ring_two_gate` (with its `guardian` enemy id, `upgrade` id and `outward` direction); ring two has the `brazier` (a fire), `coal_1` to `coal_5`, `rich_iron_1` to `rich_iron_3`, `deep_hole_1` to `deep_hole_3`, `ring_two_waystone` and `ring_three_gate` (with its `upgrade` id and `outward` direction, and no guardian); ring three has `ring_three_fire`.
- `enemies`: placements by id, `{kind, home, pack}`. Every placement gets an entry in `state.enemies`; the kind's stats are in `CombatTable`. None lives in the inner ring. Ring one holds wolves, bandit archers, frost witches and the captain; ring two holds `troll_1` to `troll_4` and `stalker_1` to `stalker_5`.
- `NODE_KINDS`: per gatherable kind, its tier, the skill and required level, the tool and lowest tool tier, the item, yield, regrowth ticks and xp. Every placed object of such a kind gets an entry in `state.nodes`.
- `regions`: named polygons in precedence order, first match wins: `outpost` (the walled square), `inner_ring` (out to 24 m), `ring_one` (out to the cliffs at 60 m), `ring_two` (everything beyond, out to the outside of ring two's southern cliffs at 128 m, of which only the ruins south of the ring-two gate are walkable), `ring_three` (everything south of that: the glacier from x -60 to 60 and z 128 to 188). Ring one is only reached by walking through the inner ring, and rings two and three only through their gates.
- `spawn`: where a new state puts the player. `rescue`: where a dead player wakes, beside the fire.

The presentation draws the same solids and objects (as props, `scenes/props.gd`), so the picture and the walkability grid cannot disagree.

## How the presentation glues on

`scenes/game_root.gd` owns one `Sim`. It starts on the title screen (`scenes/title_screen.gd`): New character, Continue (when `user://frostmark.save` exists) and Import code. Continue and Import both go through `import_save`, so a bad browser save and a bad pasted code get the same clear message. The HUD (`scenes/hud.gd`) is one fixed side panel with tabs, in the RuneScape way: Pack (with the current style and its arrow or frost-shard count), Equipment (weapon, helm, body, legs, tool, quiver, cape), Skills (levels and xp bars), Upgrades and Settings (interface size, reduced motion, auto-retaliate, sound, Controls, Save code, credits), plus the warmth and health orbs and the field-fire button beside it, the stash and workbench panels that open when those are used (the stash panel's Deposit haul button is greyed whenever `check(deposit_haul)` would refuse), and the save-code panel. It turns button presses into commands: a pack click equips gear, eats food, or by a fire cooks raw food. Every glyph comes from the icon table (`scenes/icon_table.gd`: skill, item kind, tab, combat style and action -> a game-icons.net SVG under `assets/ui/game_icons/` and a badge tint, gear tinted by tier, fur pieces in a fur tint) and every hover tooltip from one control (`scenes/ui_tooltip.gd`: an item's tier, weight, value, what it crafts into, what it builds, for gear with `warmth` that it makes warmth last longer while worn, and what a click does; a skill's level, xp to go and next unlock). Labels in the world (rocks, trees, holes, loot, gates, idle enemies) show only under the mouse; an enemy in a fight keeps its name and health up. The death screen (`scenes/death_screen.gd`) lists exactly what was kept and lost. `scenes/save_store.gd` reads and writes the browser save, and counts a write as failed when it is short or storage does not outlive the page. The save notice (`scenes/save_notice.gd`) shows the long-play reminder or the not-saving warning with Copy save code, Show code and Dismiss; the title screen also says when the browser will not keep saves. Copying goes through `scenes/clipboard.gd`: in the browser, `navigator.clipboard.writeText` from the click, and the player is told whether it worked.

- `_process` adds frame time to an accumulator and calls `step()` for each whole tick, then `drain_events()`.
- Each `moved` and `enemy_moved` event's `path` is replayed over the following tick by elapsed fraction, so the character and the enemies glide between tick positions and turn at corners instead of cutting them.
- A left click is queued and resolved in `_physics_process` with a physics ray. A hit on a body carrying an `enemy_id` meta becomes `attack`, a hit on the gate becomes `cross_gate`, a hit on another body carrying an `object_id` meta (a placed object or a loot pile) becomes `interact`, any other hit becomes `move_to` at the hit point. Clicks on HUD widgets never reach the world.
- `enemy_telegraphed` lays a ring on the ground under the enemy in its style's colour (orange-red melee, blue ranged, violet magic, from `IconTable.STYLE_COLOURS`), bigger when heavy, and shows the blow's name over its head, until the tick it lands; `hit` and `missed` from an enemy then sweep a brief swing arc toward the character (`scenes/combat_cues.gd`, driven by those events alone). A feint's ring and name are the real blow's. On `enemy_feinted` the ring breaks off and the word over the enemy reads "Feint" until the tick ends (`GameRoot.cue_text`, `tests/test_telegraph_cue.gd`), unless the same tick telegraphs the enemy's next blow, which takes the ring and the word. Each enemy carries a name and health label; a dead one is hidden and unclickable until it respawns.
- Bows and staffs throw what they shoot (`scenes/projectiles.gd`, driven by the same events, `tests/test_projectiles.gd`): an arrow for a ranged blow and a frost shard for a magic one, each with a streak in its style's colour, and a small puff where it lands (one soft glow that fades in place under reduced motion). The player's shot is loosed on the player's `hit` and the enemy recoils when it lands. An enemy's shot is loosed from its `enemy_telegraphed` so it arrives on the tick the blow resolves, following the character; that tick's `hit` lands it on the character, `missed` drops it into the snow past them, and `enemy_feinted` shrinks it away in the air. Enemy archers, the ruin stalker, the frost witch and the captain's bow and staff all use them. Nothing in the rules or the save changes.
- `died` stops the ticking and shows the death screen until the player dismisses it.
- `enemy_stance` lays the same ring and shows the captain's change of weapon, or a troll's wind-up, over its head in the style's colour, and the captain's figure swaps the sabre, the bow and the staff in his hand.
- `returned`, `deposited_haul`, `levelled`, `crafted`, `built`, `ring_gate_opened`, `ring_two_reached`, `ring_three_reached`, `waystone_attuned` and `travelled` become a banner across the top (a `returned` banner reads "Home safe." plus what the pack holds, and adds "You can now build: ..." only when its `newly_affordable` list is not empty, and a `deposited_haul` banner names what was stored plus what stayed when the stash filled, `tests/test_bank_line.gd`); the rest become one line of status text. `saved` writes the browser save. `node_depleted` and `node_respawned` swap a node's prop between its full and spent look (a stump, a rock without ore, a frozen-over hole). `fire_lit` and `fire_out` add and remove a field fire.
- New character sends `new_character` with the browser save it replaces. `hint` and `tip` show in the guide panel (`scenes/guide_panel.gd`), bottom left; its Hide hints button sends `set_hints` off and saves. The help panel (`scenes/help_panel.gd`) lists the controls and the loop, opens from the title screen's Controls button and the HUD's Help button, holds the ticking while open, and in a game has a Show hints switch.
- Standing by a waystone shows the waystone panel (`scenes/waystone_panel.gd`), bottom centre: a Travel to the outpost button greyed out with the reason from `sim.travel_check()`, and the channel's progress while it runs. A waystone's runes glow once it is awake, and its label says asleep, visit to attune, or attuned.
- Equipped weapon, helm, body, legs, tool, quiver and cape are drawn on the character (`scenes/character_gear.gd`), each only while worn, in the palette and shapes of the item's entry in the gear-look table (`scenes/gear_look.gd`, keyed by item id; an item with no entry draws in magenta). Today's entries keep the tier looks: the helm on the head (a dome, banded from bronze, with a nose guard from iron), the body on the chest (a vest, with pauldrons from bronze), the legs on the hips (a kilt, with greaves on the shins from iron). Fur pieces, which have no tier, have their own shapes in a fur colour with a pale trim: a rounded hood framing the face, a coat with a thick collar ruff, and leggings with a fur band at each shin. The set looks are built from a kit of layered, non-round builders in `CharacterGear` (a peaked hood, an under-robe with coat panels, a cloak, a collar, stacked plates, a crystal, a fin, a prism stack, studs, edge trim, a sash, a ruff, faulds, tassets, a seam, a shard crown, antlers, a pouch, and eight hand-held weapons: a broadsword, a bearded axe, a greatsword, a forge hammer, a glaive, a cleaver, a longbow and a mage staff), each with its numbers in the same table and drawing at least two tones; a look's `glow` lights a builder's highlight through emission, and a crystal, a shard crown, a forge hammer or a mage staff may carry one small light and a few motes (a `CPUParticles3D` of 16 or fewer) when its entry asks. A set piece's entry names its base shape and `layers` more kit shapes over it (a band of studs, cheek guards and a crest on a helm; a sash, a ruff and pauldrons on a vest; faulds or tassets over a kilt), each placed by its own numbers, and its tone numbers pick the palette field (or a colour of the entry's own) each part is drawn in, so a set is tuned in its entries alone and every piece draws the same whatever the other slots wear. The melee sets (#162) draw this way: Hearthguard in blue steel, leather and brass; Wolfmark in dark iron under a grey pelt with a blood-red sash; Ruinwarden in old gold and verdigris with a crested, plumed helm, and only its chest rune and its greatsword's fuller glow (emission, no light, no motes). The melee top sets (#163) are the only melee sets allowed a light or particles: Emberheart in forge black with ember seams, a burning core with embers rising and the one light, on its forge hammer; Hoarfrost in ice over a dark-blue harness and white fur, a crown of glowing frost shards with frost motes and an icicle greatsword; Auroral in dusk violet with antlers, swept wings, aurora-green seams and a star with a shimmer of motes; Trollbone in bone over hide with tusks and a blood wrap, and no glow at all. The ranged sets (#164) draw the same way with no glow at all: Trapper's Leathers in tanned hide with a seamed hood and dark lacing; Wolfstalker in a grey pelt hood with ear points over dark leather, a pelt mantle and ragged pelt flaps, bone-banded; Steelpoint Ranger in a brimmed, pointed steel cap with one amber feather, square steel pauldrons and greaves on pine-green leather. Their bows are the one longbow kit shape (staves, string, grip, nocks and optional limb caps, a recurve by `tip_bend`), held in the left hand like the tier bows, which keep their model; their quivers are the quiver shape in the set's tones with its default geometry, so the back-layer clearance holds for them. The ranged top sets (#165) glow by emission only, each in its own colour, with no light and no motes: Ember Hawk in charcoal and gold with a beaked hood under a crest of ember-tipped feathers, feathered wings on the shoulders and amber chevrons down the chest; Auroral Warden in white hide over violet with a silver circlet, a tall aurora banner on the hood (lit in front, plain teal behind), silver clasps and shoulder plates, an aurora-lit kilt hem and a lined mantle; Ruin Stalker's Shroud in ink with a bone skull mask and violet eyes, bone spurs on the hood, rib plates across the chest, a hem of hanging bone spikes and a torn shroud; Glacier Sovereign in ice over deep sea with a crown of frost-lit crystal spikes, crystal pauldrons with glowing spurs, a frost gem at the chest and an ice hem. Their new kit parts are a fan of plumes (a crest or a wing of feathers, each quill tipped with a glowing bead), a longbow that may carry a lit string, lit stave edges and tip shards, a cloak with a lit lining rim, and a quiver whose fletching is a highlight so it glows with the look; the plumes and the lit bow and cloak numbers default off, so the earlier sets draw as before. One of every armour look, metal and fur, every kit-built weapon, and one of each kit shape are drawn in the shader warm-up behind the title screen. The magic sets (#166) draw with no light or motes, their glow emission alone on the parts the issue names: Shardweaver in undyed wool, a cowl with a rope brow band and a cream scarf, an open coat over an under-robe with cream-edged panels of two lengths, a pouch and a strapped satchel, and a pine staff with one raw shard lashed on with rope; Rimecaller in indigo, a peaked hood with a brow prism, frost-banded robes under frost shoulder plates and a frost collar, a book pouch and a hanging vial, a short cloak, and an ash staff forked round a floating prism; Glacier Warden in teal and silver, a three-prism crest, a glowing glyph band and a lit chest glyph, a third plate on the left shoulder, a tall collar, a scroll case, silver greaves with knee plates, a long silver-hemmed cloak, and an iron staff with a silver hoop holding a prism and a small one above it. Their staves are the one mage staff kit shape (a shaft, a grip band, a collar and a head of seven kinds: lashed, forked, ring, shard, brazier, antler or pillar), upright in the right hand like the tier staves, which keep their model; their cloaks are the cloak shape, so the back-layer clearance holds for them. The magic top sets (#167) are the only magic sets allowed a light or particles, and each carries exactly one of each, on its staff head (so a staff alone lights the snow in the set's colour and any other piece alone glows by emission only): Hoarfrost Sovereign in white and ice over steel blue, a bare head under a steel circlet with a fanned crown of frost shards, a jagged ice collar, shoulder shard clusters, a frost chest gem over hanging icicles, a long ice skirt, a forked white cloak and a short greatshard staff; Hearthfire Magus in charcoal and brass with ember glow, a peaked hood under a glowing halo with brass flame fins (the collar's hoop kind, drawn as the highlight), ember-banded robes, a lit lantern at the hip, an ember-hemmed cloak and a brazier staff with embers rising from its cup; Aurora Shaman in violet and bone, a bare head under a bone circlet with aurora-tipped antlers and one bone feather, a bone mantle hung with feathers, a bead belt, an aurora-lit hem, a green-lined cloak and an antler staff with a feather and beads; Ruinwarden in dusk and ruin stone with rune glow, a hooded stone mask with lit eye slits, a jagged stone back-plate, stone tassets and rune tablets, square stone greaves, a torn banner and a square broken pillar staff. One of every armour look, metal and fur, every kit-built weapon, and one of each kit shape are drawn in the shader warm-up behind the title screen.
- Props come from the CC0 Kenney Nature and Survival kits (`assets/models/`, credited in `docs/assets/CREDITS.md`), snow-capped by one shader (`scenes/shaders/snow_cap.gdshader`).
- What the world looks like at a point comes from the ring-look table (`scenes/ring_look.gd`): one look per ring and one for the outpost (palette tint, sky, fog colour and distance, sun and ambient colour, snow density, wind, aurora, ambience cue), resolved through the world definition's region lookup and blended across an 8 m band at every boundary. Each ring out is colder and darker. Lighting, fog, snowfall and dressing read it and keep no per-ring constants of their own. The atmosphere node (`scenes/atmosphere.gd`) applies the look at the character's position every frame: a fixed low dusk sun with long blue-violet shadows (there is no day-night cycle), depth fog, snow falling around the camera whose density and wind follow the look, a screen-space colour grade (`scenes/shaders/colour_grade.gdshader`) and, in the outer rings, a faint aurora band across the top of the view. Every fire lays a warm pool on the snow out to the edge of its warmth; only the four fires nearest the character carry a dynamic light. All of it runs on frame time and changes no rule.
- Sound (`scenes/audio_director.gd`) only listens. `scenes/audio_cues.gd` maps each event to its cue keys and each key to clips under `assets/audio/`: telegraphs and stance changes sound a cue per style (a blade drawn for melee, a bow creaking for ranged, lower and louder when heavy), a feint sounds its style's cue again cut short, blows thud, ranged blows and misses twang, `gathered` splashes for a fish, `cooked` and `crafted` clink, `built` sounds the upgrade's material (an axe for timber, a pick for stone, a hammer for iron, declared per upgrade in `scenes/yard_look.gd`; a shared built cue for an upgrade with none) under the rising level stinger, and `died`, `returned` and `levelled` play stingers. Footsteps follow the character's drawn movement; an axe or pickaxe strikes about once a second from the gathering `interacted` until `activity_stopped`; a wind-and-snow bed and the music follow `region_changed` (a quiet bed inside the walls, a tenser one outside); every fire crackles where it burns. Nothing plays before the first click or key press, which is when browsers allow audio. Volume, music volume and mute live in `user://frostmark_settings.cfg` (`scenes/audio_settings.gd`), set from the side panel's Settings tab, which also credits every clip and icon. Interface size (90, 100 or 125 %, applied as the window's content scale) and reduced motion live in the same file under their own section (`scenes/ui_settings.gd`); snowfall, screen shake and the frost vignette read `UiSettings.reduced_motion_on()` and change no rule.
- The orbit camera (`scenes/orbit_camera.gd`) follows the character's rendered position and keeps its own yaw and distance. The sun's shadows reach 1.6 orbit distances, just past the edge of the view.
- A wall, cliff or the gate between the camera and the character swaps to a see-through twin of its material, made with the block. Behind the title screen a tiny sample of every material (plain and instanced, with and without a fire's light), every label size and the HUD are drawn for a few frames, so the browser compiles shaders and rasterises fonts there rather than freezing mid-walk.

## Adding a rule in a later slice

1. Add the command and event names to `SimVocab` if they are not there yet.
2. Add the state under a new key in `new_state()` and normalise it in `restore()`.
3. Handle the command in `Sim.command()` (validate, record intent) and the behaviour in `step()`.
4. Write the test first under `tests/`, driving only `command()` and `step()`.
5. Bind the new events in `game_root.gd`.
