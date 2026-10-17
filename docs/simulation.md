# The Frostmark simulation

Everything that is a rule lives in `sim/`, as RefCounted scripts with no Node, scene, Input, rendering or autoload dependency. The presentation in `scenes/` is glue: it turns clicks into commands and events into motion and text. Tests under `tests/test_*.gd` drive the simulation through `command()` and `step()` only. This is the seam that would later move to a server for co-op.

| File | Holds |
|------|-------|
| `sim/sim.gd` (`Sim`) | All game state, `command()`, `step()`, `drain_events()`, `snapshot()`, `restore()` |
| `sim/world_def.gd` (`WorldDef`) | The world as data: walkability grid, named regions, object placements |
| `sim/grid_path.gd` (`GridPath`) | A* over the grid (the engine's `AStarGrid2D`, built once per world) plus line-of-sight smoothing |
| `sim/vocab.gd` (`SimVocab`) | Every command kind, event kind, interaction action and rejection reason as a constant |
| `sim/items.gd` (`ItemTable`) | Every item kind: label, stack size, weight, value, equipment slot, tool kind, tier, weapon stats, armour defence, food healing |
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

One tick runs, in order: queued commands (a swap, a meal, a craft, a build, a field fire), the player closing on an attack target, movement (and banking when the walk enters the outpost), the gathering, cooking or waystone activity, combat (the player's swing, then every enemy in turn), node regrowth, loot decay, field fires burning out, then food healing, warmth, health and death. If the tick reached a save point it ends with one `saved` event.

Walking consumes `Sim.WALK_PER_TICK` metres of path per tick (4 m/s, so 2 m). A path of 6 m arrives on the third tick. Carrying more than `Sim.CARRY_LIMIT` kg (pack plus equipment) cuts that to `Sim.OVERWEIGHT_SPEED` (60%).

## Commands

`sim.command(kind, args)` returns `{ok, reason}`. Commands only record intent; the next `step()` acts on it. A rejected command also emits `command_rejected`. The commands that change the inventory (`deposit`, `withdraw`, `drop`, `equip`, `eat`, `smith`, `build`, `light_fire`) are validated at once, so the return value is meaningful, then queued in `state.pending` and applied, re-validated, at the start of the next tick. `sim.check(kind, args)` answers the same validation without queuing, for greying out buttons.

| Command | Args | Slice | Does |
|---------|------|-------|------|
| `move_to` | `{pos: [x, z]}` | 2 | Walk to a ground point (see snapping below) |
| `interact` | `{object_id}` | 2 | Walk to an object and start its action (see actions below). A loot pile id walks onto the pile and picks it up; a field fire id walks to its side |
| `gather` | `{object_id}` | 3 | `interact` restricted to gatherable nodes (trees, rocks, fishing holes): walk there, then gather until the node is spent or the pack is full |
| `cross_gate` | `{}` | 3 | Walk through the nearest gate to 2.5 m beyond it on the other side |
| `deposit` | `{index, count?}` | 3 | Pack slot to the stash, as many as fit. Inside the outpost only |
| `withdraw` | `{index, count?}` | 3 | Stash slot to the pack, as many as fit. Inside the outpost only |
| `drop` | `{index, count?}` | 3 | Leave items from a pack slot in the snow. They are gone |
| `equip` | `{index}` or `{unequip: slot}` | 3 | Equip a pack item into its slot, swapping the old one into that pack slot; or unequip into the pack |
| `smith` | `{recipe}` | 3 | Craft a recipe standing at the workbench inside the outpost, from the pack |
| `cook` | `{index}` | 5 | Standing by any fire, cook that pack slot's raw food, one item every 2 ticks, until that kind runs out, the pack is full or the player walks off |
| `build` | `{upgrade}` | 5 | Build an outpost upgrade inside the outpost, paying its cost from the stash |
| `light_fire` | `{}` | 5 | Burn 3 logs from the pack into a field fire where the player stands (not inside the outpost) |
| `attack` | `{enemy_id}` | 4 | Close to the weapon's reach and strike on every ready tick until the enemy dies, the player walks or interacts elsewhere, or a bow runs out of arrows or a staff out of frost shards |
| `eat` | `{index}` | 4 | Eat one food item from a pack slot. Lands next tick, costs that tick's step and swing, heals over the food's ticks |
| `export_save` | `{}` | 3 | Returns `{ok, reason, code}`: the state as a save code. Changes nothing |
| `import_save` | `{code}` | 3 | Validates, migrates and loads a save code, replacing the state at once. Emits `saved` (reason `import_save`) or `save_rejected` |
| `set_hints` | `{on: bool}` | guide | Turns the first-outing guide off (the player dismissed it) or back on, where its path left off. Emits `hints_set`. At once, not queued |
| `new_character` | `{previous: String}` | guide | Replaces the state with a new character at once. The guide starts on only when `previous` (the browser save being replaced) is empty |
| `travel` | `{object_id}` | waystones | Standing by an awake, attuned waystone, channel for `Sim.TRAVEL_TICKS` ticks, then stand outside the outpost gate (see waystones below). `sim.travel_check(id)` answers the same validation without starting |

Any other kind is `unknown_command`. Rejection reasons for movement: `bad_args`, `outside_world` (off the grid), `not_walkable` (no free cell within `SNAP_RADIUS_CELLS`), `unreachable` (no route; no route crosses the ring-two gate), `unknown_object`. For gathering: `not_gatherable`, `depleted`, `no_tool`, `level_too_low`, `pack_full`. For the inventory: `empty_slot`, `not_equippable`, `pack_full`, `stash_full`, `not_in_outpost`. Gathering also refuses `tool_too_weak` (iron, coal and rich iron need a bronze pickaxe or better). For crafting: `unknown_recipe`, `tier_capped` (above the smithing cap: bronze until the blast furnace, then steel), `not_at_workbench`, `level_too_low`, `upgrade_missing`, `missing_inputs`, `pack_full`. For cooking: `bad_args`, `empty_slot`, `not_cookable`, `not_at_fire`, `level_too_low`, `pack_full`. For building: `unknown_upgrade`, `already_built`, `upgrade_locked`, `upgrade_missing` (a prerequisite), `not_in_outpost`, `missing_inputs` (from the stash). For a field fire: `in_outpost`, `missing_inputs`. For combat: `unknown_enemy`, `target_dead`, `in_outpost` (nothing is fought from inside), `unreachable` (the enemy lives on the other side of the ring-two gate), `no_ammo` (a bow with no arrows or a staff with no frost shards in the pack). For eating: `empty_slot`, `not_food`, `already_eating` (one meal a tick). For save codes: `bad_code`, `bad_checksum`, `unsupported_version`, `bad_snapshot`. For the guide: `bad_args`. For travel: `unknown_object`, `not_waystone`, `upgrade_missing` (no built upgrade has woken that waystone), `not_attuned` (never visited), `not_at_waystone` (farther than 1.5 m from it).

### Interaction actions

`interacted.action` says what arriving at an object starts: `gather` for a node (the gathering activity begins at once), `warm` for the outpost fire or a field fire (`object_kind` is `campfire`; warming and cooking are by standing near it), `stash` and `craft` for the stash and the workbench (the presentation opens their panels), `pick_up` for a loot pile (`object_kind` is `loot`), `ring_gate` for the gate to ring two (when it is open, the player walks on through it to the other side, either way), `waystone` for a waystone (the first arrival attunes it), `none` for the outpost gate. The brazier past the ring-two gate is a fire like the outpost's (`warm`).

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
| `banked` | `items, overflow` | The player walked into the outpost. Both are lists of `{item, count}`; overflow stayed in the pack because the stash was full |
| `warmth_changed` | `warmth, max` | Warmth moved this tick |
| `took_damage` | `amount, cause, health` | Health fell. `cause` is `cold` or the enemy kind that hit |
| `ate` | `item, heal, ticks` | A meal landed |
| `healed` | `amount, health` | Food healed this tick |
| `died` | `cause, kept, lost, spare, pos` | Health hit zero. `kept` and `lost` are lists of `{item, count}`; `spare` is the item given back at the fire (`wooden_axe`) or `""` |
| `enemy_noticed` | `enemy_id, cause` | An idle enemy joined the fight: `sight`, `noise`, `pack` or `hit` |
| `enemy_telegraphed` | `enemy_id, action, style, damage, heavy, at` | An enemy declared an attack for tick `at`, which is always the next tick |
| `enemy_moved` | `enemy_id, from, to, path, facing` | An enemy moved this tick; `path` is the polyline it walked |
| `hit` | `attacker, target, amount, style, multiplier, health` | A blow landed. The player's id is `player`; `multiplier` is the style edge applied |
| `missed` | `attacker, target, action` | A telegraphed enemy attack found the player out of its reach |
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
| `ring_two_reached` | `object_id` | The player walked into ring two for the first time, through gate `object_id`. Once per character; nothing is banked |
| `waystone_attuned` | `object_id` | The player reached a waystone for the first time. Once per waystone |
| `travel_started` | `object_id, ticks` | At command time: channelling began and lands in `ticks` ticks unless broken |
| `travelled` | `object_id, from, to` | The channel finished: the player stands at `to`, outside the outpost gate. Nothing is banked |
| `saved` | `reason, tick` | A save point: `gate`, `deposit`, `withdraw`, `craft`, `build`, `death`, `ring_two` (the first walk into ring two), `waystone` (attuning one, or arriving by one) or `import_save`. The presentation stores `sim.export_code()` |
| `save_rejected` | `reason` | An `import_save` failed |
| `hint` | `hint` | The guide moved to its next hint step (a `GuideTable` id), or `""` once the path is walked |
| `tip` | `tip` | A contextual tip fired (a `GuideTable.TIPS` id) |
| `hints_set` | `on` | The guide was turned off or back on |

## State shape

`Sim.state` is one plain-data Dictionary (ints, floats, strings, arrays, dictionaries only). Positions are `[x, z]` ground-plane metres. Camera state is never in it.

```
{
  "version": 8,
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
    "equipment": {"weapon": "", "armour": "", "tool": "wooden_axe"}
  },
  "stash": {"capacity": 8, "slots": [...]},  # capacity slots, null when empty
  "skills": {"woodcutting": {"xp": 0, "level": 1}, ...},  # all eight
  "nodes": {"tree_1": {"left": 4, "respawn_tick": 0}, ...},
  "enemies": {"wolf_1": {"kind": "wolf", "pos": [x, z], "facing": [x, z], "health": 15,
              "mode": "idle", "next": {"action": "bite", "at": 12}, "step": 1, "respawn_tick": 0}, ...},
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

| Rule | Value |
|------|-------|
| Pack | 12 slots; logs, ore, bars, ice crystals and fish stack to 10, arrows and frost shards to 100, gear never stacks |
| Carry limit | 30 kg (logs, copper, tin, coal and bronze bars 1 kg, iron ore, steel bars and troll hides 2 kg, tools 1 to 3 kg, weapons 2 to 4 kg, armour 4 to 7 kg, arrows and frost shards 0 kg); above it walking is 60% speed |
| Stash | 8 slots to start; the shelves and cellar upgrades add 4 each. A new character's stash holds a wooden bow, 30 arrows and 5 cooked fish |
| Experience curve | Shared by all eight skills: level L needs `50 * L * (L - 1) / 2` total xp (50, 150, 300, 500, ...), capped at 99. Levels never decrease |
| Gathering | One attempt takes `max(2, 4 - (level - 1) / 4 - tool)` ticks and succeeds with `min(95, 60 + 4 * (level - 1) + 10 * tool)` percent, where `tool` is the best carried tool's tier rank (wooden 0, bronze 1, iron 2, steel 3). Needs the node's tool (axe, pickaxe, rod) in the pack or the tool slot |
| Warmth | 360 points, draining 1 per tick outside the outpost (three minutes), in every ring. No drain inside the outpost. Within 3 m of any fire (the outpost's, the brazier past the ring-two gate, a field fire) it refills 24 per tick and health refills 2 per tick |
| Field fire | 3 logs from the pack, lit where the player stands outside the outpost; warms and cooks like the outpost fire for 120 ticks (a minute), then goes out |
| Cold | At zero warmth health drains 1 per tick (50 s from full). At zero health the player dies by the death rule below |
| Cooking | One raw item every 2 ticks at any fire. Burn chance is the dish's base at its level, minus 5 per level above: raw fish 40% at cooking 1 (gone by level 9), 10 xp; raw trout needs cooking 3, 50% there, 18 xp; raw char needs cooking 5, 50% there, 26 xp. Burnt food is lost and gives no xp |
| Food | Raw fish heals 4 over 2 ticks, cooked fish 24 over 4, raw trout 6 over 2, cooked trout 40 over 5, raw char 8 over 2, cooked char 56 over 7, starting the tick it is eaten. Meals overlap by adding up |
| Smithing | At the workbench from the pack. Capped at bronze: a recipe of a higher tier (steel) is refused with `tier_capped` until the blast furnace lifts the cap to steel. No recipe works iron: iron gear only drops |

**Nodes** (each regrows `respawn` ticks after its last yield):

| Node | Where | Skill and level | Tool | Yields | Per node | Respawn | Xp |
|------|-------|-----------------|------|--------|----------|---------|----|
| Pine (tier 1) | 6 south of the gate, 4 north of the walls | woodcutting 1 | axe | logs | 4 | 90 | 10 |
| Copper rock (tier 1) | 3 east of the outpost | mining 1 | pickaxe | copper ore | 4 | 100 | 10 |
| Tin rock (tier 1) | 3 west of the outpost | mining 1 | pickaxe | tin ore | 4 | 100 | 10 |
| Fishing hole (tier 1) | 1 north of the outpost | fishing 1 | rod | raw fish | 6 | 80 | 10 |
| Ice crystal (tier 1) | 2 north of the outpost, east and west | mining 2 | pickaxe | ice crystal | 3 | 120 | 14 |
| Frost pine (tier 2) | 4 in ring one, west | woodcutting 3 | axe | logs | 6 | 120 | 16 |
| Iron rock (tier 2) | 3 in ring one, east, by the archer camp | mining 3 | bronze pickaxe or better | iron ore | 3 | 150 | 18 |
| Ice hole (tier 2) | 1 in ring one, north | fishing 3 | rod | raw trout | 5 | 120 | 16 |
| Coal seam (tier 3) | 4 in ring two's east wing, 1 in the far ruins | mining 5 | bronze pickaxe or better | coal | 4 | 150 | 22 |
| Rich iron vein (tier 3) | 3 in ring two's keep | mining 6 | bronze pickaxe or better | iron ore | 5 | 160 | 24 |
| Deep hole (tier 3) | 3 on ring two's frozen lake, west | fishing 5 | rod | raw char | 5 | 140 | 22 |

**Workbench recipes** (smithing):

| Recipe | Inputs | Level | Upgrade | Xp |
|--------|--------|-------|---------|----|
| Wooden club, axe, pickaxe, fishing rod | 4, 3, 3, 3 logs | 1 | none | 10 |
| 10 frost shards | 1 ice crystal | 1 | none | 8 |
| Wooden staff | 3 logs, 1 ice crystal | 1 | none | 12 |
| Wooden armour | 8 logs | 2 | none | 20 |
| Bronze bar | 1 copper ore, 1 tin ore | 1 | Forge | 10 |
| 25 arrows | 2 logs, 1 bronze bar | 2 | Forge | 10 |
| Bronze axe, bronze pickaxe | 1 bronze bar, 2 logs | 2 | Forge | 15 |
| Bronze sword | 2 bronze bars, 1 log | 2 | Forge | 25 |
| Bronze bow | 2 bronze bars, 3 logs | 2 | Forge | 25 |
| Bronze staff | 2 bronze bars, 2 logs, 1 ice crystal | 2 | Forge | 25 |
| Bronze armour | 4 bronze bars | 3 | Armoury | 40 |
| Steel bar | 1 iron ore, 2 coal | 4 | Blast furnace | 25 |
| Steel axe, steel pickaxe | 1 steel bar, 2 logs | 4 | Blast furnace | 30 |
| Steel sword | 2 steel bars, 1 log | 5 | Blast furnace | 50 |
| Steel bow | 2 steel bars, 3 logs | 5 | Blast furnace | 50 |
| Steel armour | 3 steel bars, 1 troll hide | 5 | Blast furnace | 80 |

**Outpost upgrades** (paid from the stash, inside the outpost):

| Upgrade | Cost | Needs | Effect |
|---------|------|-------|--------|
| Stash shelves | 8 logs | none | +4 stash slots |
| Forge | 6 logs, 3 copper ore, 3 tin ore | none | Unlocks bronze bars, arrows, bronze tools and weapons |
| Stash cellar | 10 logs, 2 bronze bars | Stash shelves | +4 stash slots |
| Armoury | 6 logs, 2 bronze bars, 3 wolf pelts | Forge | Unlocks bronze armour |
| Ring-two gate winch | 12 logs, 8 iron ore, 3 bronze bars, 3 wolf pelts | Armoury | Readies the gate to ring two; it opens once the captain has fallen |
| Blast furnace | 12 logs, 4 bronze bars, 6 coal, 2 troll hides | Ring-two gate winch | Unlocks steel bars, tools, weapons and armour, and lifts the smithing cap to steel |
| Waystones | 10 iron ore, 6 bronze bars, 10 logs | Ring-two gate winch | Wakes the waystones in ring one and ring two |

**Gear tiers** (every weapon, armour and tool has one, and it shows on the character):

| Tier | Melee | Ranged (arrows) | Magic (frost shards) | Armour (defence) | Tools | Comes from |
|------|-------|-----------------|----------------------|------------------|-------|------------|
| Wooden | club, power 5 | wooden bow, power 4 | wooden staff, power 4 | wooden armour, 1 | axe, pickaxe, fishing rod | the workbench, from logs (the staff also takes an ice crystal) |
| Bronze | sword, power 7 | bronze bow, power 6 | bronze staff, power 6 | bronze armour, 2 | axe, pickaxe | the workbench, after the forge |
| Iron | sword, power 9 | iron bow, power 8 | iron staff, power 8 | iron armour, 3 | axe, pickaxe | only as loot, in both rings and from the captain |
| Steel | sword, power 11 | steel bow, power 10 | steel staff, power 10 | steel armour, 4 | axe, pickaxe | the workbench, after the blast furnace, from ring two's coal |

Item values, which decide what death keeps: logs 2, copper and tin ore 3, coal 6, iron ore 8, bronze bar 8, steel bar 30, raw fish 2, cooked fish 6, raw trout 4, cooked trout 12, raw char 6, cooked char 18, wolf pelt 8, troll hide 20, ice crystal 4, arrows and frost shards 1 each; wooden axe 5, pickaxe and rod 6, club 12, wooden armour 16, wooden bow 20, wooden staff 22; bronze axe and pickaxe 24, sword 40, bow 44, staff 46, armour 50; iron axe and pickaxe 60, sword 80, bow 84, staff 86, armour 90; steel axe and pickaxe 120, sword 160, bow 168, staff 172, armour 180.

## Combat

Everything that fights is a combatant of one shape, `sim.combatant(id)`: `{id, kind, pos, health, health_max, weapon, style, reach, defence, next}`. The player's style comes from the weapon slot (fists when it is empty); an enemy's from its kind's weapon. `next` is the action declared for the coming tick as `{action, at}`. Every blow, either way, goes through the same arithmetic.

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

**Damage** is `max(1, round(base * multiplier) - defence)`. The player's base is the weapon's power plus 1 for every 3 levels of the style's skill above 1. An enemy's base is its action's damage. Armour defence comes off every hit (wooden 1, bronze 2, iron 3, steel 4).

| Weapon | Style | Power | Swings every | Reach |
|--------|-------|-------|--------------|-------|
| Fists (empty slot) | melee | 2 | 2 ticks | 1.5 m |
| Wooden club, bronze, iron, steel sword | melee | 5, 7, 9, 11 | 2 ticks | 1.5 m |
| Wooden, bronze, iron, steel bow | ranged | 4, 6, 8, 10, one arrow a shot | 2 ticks | 8 m |
| Wooden, bronze, iron, steel staff | magic | 4, 6, 8, 10, one frost shard a cast | 2 ticks | 6 m |

**Attacking.** `attack` sets the activity to `{kind: attack, object_id}`. Each tick the player walks to within 80% of the weapon's reach of the target, re-routing as it moves, then strikes on every tick at or after `ready_tick`; a swing sets `ready_tick` to the tick plus the weapon's speed. A bow's shot spends one arrow from the pack and a staff's cast one frost shard; either refuses with `no_ammo` when none are left, which also ends the attack. A hit grants 4 xp per point of damage to the style's skill (`melee`, `ranged` or `magic`).

**Swapping and eating** are queued commands, so both land at the start of the next tick. A swap ordered on the tick before a swing makes that swing in the new style. A meal costs the tick it lands on: the player neither steps nor swings, and the swing comes a tick later.

**Enemies** are idle at home, engaged, returning or dead.

| Kind | Health | Weapon | Speed | Sight | Action cycle | Drops | Rare drop |
|------|--------|--------|-------|-------|--------------|-------|-----------|
| Wolf | 15 | fangs (melee, 1.5 m) | 2.5 m a tick | 6 m | bite 3, rest, lunge 7 (heavy), rest | 1 wolf pelt | 5% |
| Bandit archer | 20 | wooden bow (ranged, 8 m) | 1.5 m a tick | 9 m | shot 4, rest, rest, aimed shot 9 (heavy), rest | 8 arrows | 10% |
| Frost witch | 18 | wooden staff (magic, 6 m) | 1.5 m a tick | 8 m | frost bolt 4, rest, rest, ice lance 9 (heavy), rest | 10 frost shards | 10% |
| Bandit captain | 240 | sabre (melee, 1.5 m), war bow (ranged, 8 m) and rime staff (magic, 6 m) by stance | 2 m a tick | 7 m | slash 8, rest, cleave 17 (heavy), rest, draws his bow, loose 7, rest, volley 16 (heavy), rest, raises his staff, rime bolt 7, rest, blizzard 16 (heavy), rest, draws his sabre | 20 arrows and one piece of iron gear (sword, bow, staff or armour) | 25% |
| Ice troll | 90 | ice club (melee, 1.5 m) | 1.5 m a tick | 6 m | smash 8, rest, winds up, crush 26 (heavy), rest, rest | 1 troll hide | 15% |
| Ruin stalker | 35 | bone bow (ranged, 8 m); backs away inside 4 m | 1.5 m a tick | 10 m | dart 4, dart 4, rest, barbed volley 10 (heavy), rest, rest | 12 arrows, 1 coal | 10% |

- An idle enemy notices the player when the player is within its sight radius, within the radius of a noise the player made this tick (a gathering attempt carries 9 m, a blow struck or taken 12 m), or strikes it. When one member of a pack engages, the rest of the pack engages with it.
- Each tick an engaged enemy first carries out what it declared last tick: a move closes in toward the player, a rest does nothing, an attack lands as `hit` if the player is still in its reach and `missed` if not. Then it declares the next tick: the next action of its cycle while the player is in its reach, else a move. Every attack it declares is telegraphed with an `enemy_telegraphed` event whose `at` is the next tick, so the warning always comes exactly one tick before the blow.
- Enemies never step into the outpost. While the player is inside, every engaged enemy disengages, walks home deaf to the player, and heals to full on arriving.
- Nothing notices, chases or fights across the ring-two gate. An enemy whose home is on the other side of it from the player never notices them, an engaged one disengages (as for the outpost) the tick the player is across, and `attack` on one is `unreachable`.
- A dead enemy drops its loot where it fell, plus one rare item (an iron sword, armour, bow, axe, pickaxe or staff, evenly) at the kind's rare-drop rate. Wolves, archers and witches come back at home 100 ticks later, stalkers 300, trolls 400, the captain 600.
- **The ice troll** winds up the tick before its crush: the wind-up is an `enemy_stance` a tick ahead, then the crush is telegraphed, so the heaviest blow in the game is seen two ticks out. A wind-up commits it: the crush is declared even if the player has stepped out of reach, and then misses. It is slow, so stepping back is the counter; a staff has the edge on it at any range and a bow at distance.
- **The ruin stalker** kites: on any tick it does not move, if the player is within 4 m it then backs one step (its speed) straight away, still facing them. A wall or anything else blocking that step stops it, so it can be cornered. Up close a blade has the edge on it; at range a bow is neutral, and a blade or a staff walks into its edge.
- **The captain** fights with three weapons. His cycle lists the weapon he holds for each action, so his style and reach follow his place in it: two sabre blows (the second heavy), then he draws his bow (an `enemy_stance` event, a tick ahead, in the ranged colour), two shots (the second heavy), then he raises his staff (in the magic colour), two casts (the second heavy), then he draws his sabre again. Each stance has its counter: magic, or a bow at distance, while he holds the sabre; a sword up close while he holds the bow; a bow while he holds the staff. He always drops one piece of iron gear. His first death is recorded in `bosses_defeated` for good, even after he respawns. Once the gate he guards stands open, a guardian that dies stays down: the way home from ring two is not barred again.

**Loot** piles lie for 600 ticks (five minutes) and then the snow takes them. `interact` on a pile walks onto it and picks up as much as fits; the rest stays.

Ring two's enemies: a lone stalker in the yard behind the gate, west; a stalker at the gap in the outer wall in front of the keep; a troll by the frozen lake, west; a pair of trolls inside the keep; a pair of stalkers among the coal seams, east; and in the far ruins a troll (west) and a stalker (east).

Ring one's enemies: just past the southern pines, two wolves (`wolf_1`, `wolf_2`, the near pack) south-west, a pack of three farther west and a bandit archer (`archer_1`) south-east; farther out, a two-archer camp by the iron rocks (east), a wolf pair among the frost pines (west), a pack of three by the ice hole (north), two lone archers flanking the road south, a lone frost witch out on each northern flank (`witch_1` north-east, `witch_2` north-west), and the captain at the ring-two gate. The groups sit more than a fight's noise (12 m) apart, so each is fought on its own. Chopping the south-western pine is loud enough for the near pack to hear.

## Death

At zero health, from a blow or the cold, the player keeps the three most valuable things they carry or wear and loses everything else for good. A stack is one thing, valued at its whole count (30 arrows are worth 30). On a tie what is worn comes first, then the earlier pack slot. Kept things stay where they were. The player wakes beside the outpost fire with full health and warmth; healing in progress and queued commands are cleared, every engaged enemy disengages, and skills, stash and upgrades are untouched. The workbench makes an axe only from logs, and logs need an axe, so if the death took the last axe and none is stashed, a spare wooden axe goes into the tool slot (or the pack when the slot is taken). The tick emits `died` and is a save point with reason `death`.

## The ring-two gate

The gate to ring two (`ring_two_gate`) stands in the cliffs at ring one's far southern edge. It always blocks the walkability grid like a wall, so no route, no click and no enemy ever crosses it. It is open once its guardian (`captain`) is in `bosses_defeated` and its upgrade (`ring_two_gate`) is built, in either order; whichever comes second emits `ring_gate_opened`, and an open gate never closes.

`interact` walks to it from either side. Arriving while it is open walks the player straight on through it to `Sim.RING_GATE_STEP` (3 m) past its centre on the far side, along its `outward` direction: a path the grid would never give. Nothing is banked; the haul is at risk until the outpost gate. The first time the player walks into the `ring_two` region, `ring_two_reached` is emitted, `ring_two` is added to `rings_reached`, and the tick is a save point (`ring_two`); the presentation shows a banner, not an ending. Arriving while the gate is barred does nothing but the `interacted` event.

## Waystones

Two waystones stand in the rings: `ring_one_waystone` near ring one's far southern road, out of the captain's sight, and `ring_two_waystone` in ring two's far ruins south of the keep. Each is a blocking object, walked up to with `interact`. The first arrival attunes it for good: it joins `state.waystones`, `waystone_attuned` is emitted and the tick is a save point (`waystone`). Attuning works whether or not the stone is awake.

A waystone is awake once an upgrade whose `waystones` effect lists it is built (the Waystones upgrade lists both). `travel` from an awake, attuned waystone within 1.5 m sets the activity to `{kind: travel, object_id, progress}`, stops the walk and anything else under way, and emits `travel_started`. Each tick adds one to `progress`; on the `Sim.TRAVEL_TICKS`th (6, three seconds) the player stands `Sim.TRAVEL_GATE_STEP` (2.5 m) outside the outpost gate, facing it, `travelled` is emitted (and `region_changed`), every engaged enemy disengages and heads home, and the tick is a save point (`waystone`).

The channel is a way home, not a way out of a fight: a blow taken while channelling (any `hit` on the player; the cold does not count) stops it with `interrupted`, and so does walking, attacking, cooking or gathering. Telegraphs come a tick ahead and every enemy in reach strikes at least every three ticks, so six ticks of channelling only finish out of reach. **Travel never banks.** It carries the player and the pack to the outside of the gate; the walk through it is still the player's, and that banks as always.

## The first-outing guide

The brief rules out quests and dialogue, so the guide only says what to try next. `GuideTable.STEPS` is the hint path: walk, cut a pine, walk the logs back through the gate, craft at the workbench. Each step is done by its trigger event (`moved`; `gathered` of logs; `banked` with something in it; `crafted`), and only the current step listens, so doing things early never skips ahead. Every event is checked as it is emitted, so a rejected command counts at once. Each advance emits `hint`. `sim.hint()` is the current step's id, `""` when the guide is off or the path is walked.

`GuideTable.TIPS` are the contextual tips. `pack_full` fires on a gather or pick-up refused or stopped for a full pack; `telegraph` on an enemy's telegraphed blow; `cold` is a condition checked at the end of each tick: warmth at or below `GuideTable.COLD_WARMTH`, outside, and away from any fire. A tip that fires emits `tip` and stays quiet for its `cooldown` ticks. Tips keep firing after the path is walked, while the guide is on.

`set_hints` turns everything off or back on. `new_character` turns it off for every character after the first: the presentation passes the browser save it is about to replace. A character from before the guide existed migrates with it off.

## The gate and banking

Walls leave the gate as the only way into the outpost, so any walk whose region changes into `outpost` has crossed it inward. That moves every pack slot into the stash (filling existing stacks first), leaves what does not fit in the pack as overflow, emits `banked`, and makes the tick a save point. Equipment is worn, not banked. Walking out starts the warmth drain because the region is no longer `outpost`.

## Saves

The simulation never touches the filesystem. It reports save points with `saved`; the presentation then stores `sim.export_code()` in `user://frostmark.save` (IndexedDB in the browser). The stored text and the code the player exports are the same format, so a damaged browser save is caught exactly like a bad pasted code.

A save code is base64 of `FM|<version>|<checksum>|<snapshot JSON>`. The JSON is compact with sorted keys. The checksum is the first 16 hex digits of SHA-256 over `<version>|<snapshot JSON>`: it catches typos, truncation and hand edits, and is not meant to stop a determined cheat. Decoding accepts only the canonical base64 of the decoded bytes, so every changed character is caught. It ignores whitespace from wrapped pastes, refuses codes from a newer build, and never raises an engine error.

`SaveCode.migrate(snap, target)` applies one step per version. Each step hard-codes the defaults of its own version, so retuning a constant later never changes what an old save migrates into. `1 -> 2` keeps the slice-2 tick and position and adds a new character's inventory, stash, skills, warmth, health and nodes. `2 -> 3` adds the swing timer, an empty healing queue, enemies (empty, so every enemy loads at home and idle) and ground loot, and puts the slice-4 starter kit (a wooden bow, 30 arrows, 5 cooked fish) into empty stash slots so a slice-3 character can fight too. What does not fit is not added. `3 -> 4` adds no field fires and no fallen guardians and changes nothing else: the stash keeps its capacity, known nodes and enemies keep their state, and the new ring-one nodes, enemies and the captain load full and at home. `4 -> 5` adds the first-outing guide switched off with its four steps walked, since a version-4 character has already been played. `5 -> 6` adds the magic skill at level 1 with no experience (an entry already there is kept) and changes nothing else: the ice crystals and frost witches load full and at home, and the captain carries on from the step of his cycle he was on. `6 -> 7` adds no rings reached and changes nothing else: ring two's nodes and monsters load full and at home, and a character who saw the old ending finds the gate open, with its first walk through still announced. `7 -> 8` adds no waystones visited and changes nothing else: the upgrade could not be built before, so every waystone sleeps until it is built and must be walked to once.

Every version ever shipped keeps a real save code in `tests/fixtures/save_v<N>.txt`, and `tests/test_save_fixtures.gd` imports each into the current build. **Each future version bump adds its fixture** (a code exported from the build that introduces the version) along with its migration step; old fixtures are never edited. The test fails when a version has no fixture.

A browser save can fail to hold: storage full, or blocked as in some private browsing (`OS.is_userfs_persistent()` is false, so writes last only until the page closes). The game keeps running and the save code is the fallback. `SaveWatch` counts ticks of play, not wall-clock time, so a paused game does not count down. It falls due every 5400 ticks (45 minutes) since the player last opened or copied their code or dismissed a reminder, and every 1800 ticks (15 minutes) while browser saves are failing. `stored(ok)` records each browser-save write and answers true only on the write that fails after storage was fine, so the warning shows once per failure rather than at every save point.

## The world as data

`WorldDef.outpost()` builds the world, rings around the outpost. A `WorldDef` has:

- A grid of `cols` x `rows` square cells of `cell_size` (128 x 192 cells of 1 m, origin at `[-64, -64]`, so ring two fits south of ring one), rasterised by `bake()` from the solids and blocking objects.
- `solids`: `{id, kind, min, max, height}` rectangles: the outpost's palisade `wall`s, the `cliff`s that close ring one at 60 m (open only at the ring-two gate) and wall in ring two from 64 m to 124 m, rock `outcrop`s that make the walk out a route, ring two's `ruin` walls and pillars, and the keeper's tent (`decor`) in the outpost yard.
- `objects`: typed markers by id, `{kind, label, min, max, height, blocks}`. The outpost has `gate` (with an `outward` direction), `fire`, `stash` and `workbench`; the inner ring has `tree_1` to `tree_10`, `copper_1` to `copper_3`, `tin_1` to `tin_3`, `fishing_hole` and `ice_crystal_1` and `ice_crystal_2`; ring one has `frost_pine_1` to `frost_pine_4`, `iron_1` to `iron_3`, `ice_hole`, `ring_one_waystone` and `ring_two_gate` (with its `guardian` enemy id, `upgrade` id and `outward` direction); ring two has the `brazier` (a fire), `coal_1` to `coal_5`, `rich_iron_1` to `rich_iron_3`, `deep_hole_1` to `deep_hole_3` and `ring_two_waystone`.
- `enemies`: placements by id, `{kind, home, pack}`. Every placement gets an entry in `state.enemies`; the kind's stats are in `CombatTable`. None lives in the inner ring. Ring one holds wolves, bandit archers, frost witches and the captain; ring two holds `troll_1` to `troll_4` and `stalker_1` to `stalker_5`.
- `NODE_KINDS`: per gatherable kind, its tier, the skill and required level, the tool and lowest tool tier, the item, yield, regrowth ticks and xp. Every placed object of such a kind gets an entry in `state.nodes`.
- `regions`: named polygons in precedence order, first match wins: `outpost` (the walled square), `inner_ring` (out to 24 m), `ring_one` (out to the cliffs at 60 m), `ring_two` (everything beyond, of which only the ruins south of the ring-two gate are walkable). Ring one is only reached by walking through the inner ring, and ring two only through its gate.
- `spawn`: where a new state puts the player. `rescue`: where a dead player wakes, beside the fire.

The presentation draws the same solids and objects (as props, `scenes/props.gd`), so the picture and the walkability grid cannot disagree.

## How the presentation glues on

`scenes/game_root.gd` owns one `Sim`. It starts on the title screen (`scenes/title_screen.gd`): New character, Continue (when `user://frostmark.save` exists) and Import code. Continue and Import both go through `import_save`, so a bad browser save and a bad pasted code get the same clear message. The HUD (`scenes/hud.gd`) draws the warmth and health gauges, the eight-skill panel with levels and xp bars, the pack and equipment, the current style and its arrow or frost-shard count, the stash, workbench and upgrades panels, the field-fire button and the save-code panel, and turns button presses into commands: a pack click equips gear, eats food, or by a fire cooks raw food. The death screen (`scenes/death_screen.gd`) lists exactly what was kept and lost. `scenes/save_store.gd` reads and writes the browser save, and counts a write as failed when it is short or storage does not outlive the page. The save notice (`scenes/save_notice.gd`) shows the long-play reminder or the not-saving warning with Copy save code, Show code and Dismiss; the title screen also says when the browser will not keep saves. Copying goes through `scenes/clipboard.gd`: in the browser, `navigator.clipboard.writeText` from the click, and the player is told whether it worked.

- `_process` adds frame time to an accumulator and calls `step()` for each whole tick, then `drain_events()`.
- Each `moved` and `enemy_moved` event's `path` is replayed over the following tick by elapsed fraction, so the character and the enemies glide between tick positions and turn at corners instead of cutting them.
- A left click is queued and resolved in `_physics_process` with a physics ray. A hit on a body carrying an `enemy_id` meta becomes `attack`, a hit on the gate becomes `cross_gate`, a hit on another body carrying an `object_id` meta (a placed object or a loot pile) becomes `interact`, any other hit becomes `move_to` at the hit point. Clicks on HUD widgets never reach the world.
- `enemy_telegraphed` shows the coming blow's name over the enemy, coloured by style (orange-red melee, blue ranged, violet magic) and larger with a `!` when heavy, until the tick it lands. Each enemy carries a name and health label; a dead one is hidden and unclickable until it respawns.
- `died` stops the ticking and shows the death screen until the player dismisses it.
- `enemy_stance` shows the captain's change of weapon, or a troll's wind-up, over its head in the style's colour, and the captain's figure swaps the sabre, the bow and the staff in his hand.
- `banked`, `levelled`, `crafted`, `built`, `ring_gate_opened`, `ring_two_reached`, `waystone_attuned` and `travelled` become a banner across the top; the rest become one line of status text. `saved` writes the browser save. `node_depleted` and `node_respawned` swap a node's prop between its full and spent look (a stump, a rock without ore, a frozen-over hole). `fire_lit` and `fire_out` add and remove a field fire.
- New character sends `new_character` with the browser save it replaces. `hint` and `tip` show in the guide panel (`scenes/guide_panel.gd`), bottom left; its Hide hints button sends `set_hints` off and saves. The help panel (`scenes/help_panel.gd`) lists the controls and the loop, opens from the title screen's Controls button and the HUD's Help button, holds the ticking while open, and in a game has a Show hints switch.
- Standing by a waystone shows the waystone panel (`scenes/waystone_panel.gd`), bottom centre: a Travel to the outpost button greyed out with the reason from `sim.travel_check()`, and the channel's progress while it runs. A waystone's runes glow once it is awake, and its label says asleep, visit to attune, or attuned.
- Equipped weapon, armour and tool are drawn on the character in their tier's material (`scenes/character_gear.gd`); armour also changes the silhouette by tier (vest, pauldrons, helm).
- Props come from the CC0 Kenney Nature and Survival kits (`assets/models/`, credited in `docs/assets/CREDITS.md`), snow-capped by one shader (`scenes/shaders/snow_cap.gdshader`).
- What the world looks like at a point comes from the ring-look table (`scenes/ring_look.gd`): one look per ring and one for the outpost (palette tint, sky, fog colour and distance, sun and ambient colour, snow density, wind, aurora, ambience cue), resolved through the world definition's region lookup and blended across an 8 m band at every boundary. Each ring out is colder and darker. Lighting, fog, snowfall and dressing read it and keep no per-ring constants of their own. The atmosphere node (`scenes/atmosphere.gd`) applies the look at the character's position every frame: a fixed low dusk sun with long blue-violet shadows (there is no day-night cycle), depth fog, snow falling around the camera whose density and wind follow the look, a screen-space colour grade (`scenes/shaders/colour_grade.gdshader`) and, in the outer rings, a faint aurora band across the top of the view. Every fire lays a warm pool on the snow out to the edge of its warmth; only the four fires nearest the character carry a dynamic light. All of it runs on frame time and changes no rule.
- Sound (`scenes/audio_director.gd`) only listens. `scenes/audio_cues.gd` maps each event to its cue keys and each key to clips under `assets/audio/`: telegraphs and stance changes sound a cue per style (a blade drawn for melee, a bow creaking for ranged, lower and louder when heavy), blows thud, ranged blows and misses twang, `gathered` splashes for a fish, `cooked`, `crafted` and `built` clink, and `died`, `banked` and `levelled` play stingers. Footsteps follow the character's drawn movement; an axe or pickaxe strikes about once a second from the gathering `interacted` until `activity_stopped`; a wind-and-snow bed and the music follow `region_changed` (a quiet bed inside the walls, a tenser one outside); every fire crackles where it burns. Nothing plays before the first click or key press, which is when browsers allow audio. Volume, music volume and mute live in `user://frostmark_settings.cfg` (`scenes/audio_settings.gd`), set from the HUD's Sound panel, which also credits every clip.
- The orbit camera (`scenes/orbit_camera.gd`) follows the character's rendered position and keeps its own yaw and distance. The sun's shadows reach 1.6 orbit distances, just past the edge of the view.
- A wall, cliff or the gate between the camera and the character swaps to a see-through twin of its material, made with the block. Behind the title screen a tiny sample of every material (plain and instanced, with and without a fire's light), every label size and the HUD are drawn for a few frames, so the browser compiles shaders and rasterises fonts there rather than freezing mid-walk.

## Adding a rule in a later slice

1. Add the command and event names to `SimVocab` if they are not there yet.
2. Add the state under a new key in `new_state()` and normalise it in `restore()`.
3. Handle the command in `Sim.command()` (validate, record intent) and the behaviour in `step()`.
4. Write the test first under `tests/`, driving only `command()` and `step()`.
5. Bind the new events in `game_root.gd`.
