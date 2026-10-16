# The Frostmark simulation

Everything that is a rule lives in `sim/`, as RefCounted scripts with no Node, scene, Input, rendering or autoload dependency. The presentation in `scenes/` is glue: it turns clicks into commands and events into motion and text. Tests under `tests/test_*.gd` drive the simulation through `command()` and `step()` only. This is the seam that would later move to a server for co-op.

| File | Holds |
|------|-------|
| `sim/sim.gd` (`Sim`) | All game state, `command()`, `step()`, `drain_events()`, `snapshot()`, `restore()` |
| `sim/world_def.gd` (`WorldDef`) | The world as data: walkability grid, named regions, object placements |
| `sim/grid_path.gd` (`GridPath`) | A* over the grid plus line-of-sight smoothing |
| `sim/vocab.gd` (`SimVocab`) | Every command kind, event kind, interaction action and rejection reason as a constant |
| `sim/items.gd` (`ItemTable`) | Every item kind: label, stack size, weight, value, equipment slot, tool kind, tier |
| `sim/recipes.gd` (`RecipeTable`) | Workbench recipes: inputs, output, required skill and level, required upgrade |
| `sim/skills.gd` (`SkillTable`) | The seven skill names and the one experience curve they share |
| `sim/inventory.gd` (`Inventory`) | Static helpers over slot arrays: room, stacking, weight, removal |
| `sim/save_code.gd` (`SaveCode`) | Save-code encoding and decoding, and the forward migrations between state versions |

## Tick

`Sim.TICK_SECONDS` is 0.5 s. `step()` advances exactly one tick and is the only place game state changes (`import_save` and `restore()` replace the whole state, which is a load, not a rule). The presentation accumulates frame time and calls `step()` once per tick, then drains events. Nothing in the rules reads wall-clock time, and the one random roll (a gathering attempt) comes from a generator kept in the state, so the same commands at the same ticks give the same state.

One tick runs, in order: queued inventory commands, movement (and banking when the walk enters the outpost), the gathering activity, node regrowth, then warmth and health. If the tick reached a save point it ends with one `saved` event.

Walking consumes `Sim.WALK_PER_TICK` metres of path per tick (4 m/s, so 2 m). A path of 6 m arrives on the third tick. Carrying more than `Sim.CARRY_LIMIT` kg (pack plus equipment) cuts that to `Sim.OVERWEIGHT_SPEED` (60%).

## Commands

`sim.command(kind, args)` returns `{ok, reason}`. Commands only record intent; the next `step()` acts on it. A rejected command also emits `command_rejected`. The inventory commands (`deposit`, `withdraw`, `drop`, `equip`, `smith`) are validated at once, so the return value is meaningful, then queued in `state.pending` and applied, re-validated, at the start of the next tick. `sim.check(kind, args)` answers the same validation without queuing, for greying out buttons.

| Command | Args | Slice | Does |
|---------|------|-------|------|
| `move_to` | `{pos: [x, z]}` | 2 | Walk to a ground point (see snapping below) |
| `interact` | `{object_id}` | 2 | Walk to an object and start its action (see actions below) |
| `gather` | `{object_id}` | 3 | `interact` restricted to gatherable nodes: walk there, then gather until the node is spent or the pack is full |
| `cross_gate` | `{}` | 3 | Walk through the nearest gate to 2.5 m beyond it on the other side |
| `deposit` | `{index, count?}` | 3 | Pack slot to the stash, as many as fit. Inside the outpost only |
| `withdraw` | `{index, count?}` | 3 | Stash slot to the pack, as many as fit. Inside the outpost only |
| `drop` | `{index, count?}` | 3 | Leave items from a pack slot in the snow. They are gone |
| `equip` | `{index}` or `{unequip: slot}` | 3 | Equip a pack item into its slot, swapping the old one into that pack slot; or unequip into the pack |
| `smith` | `{recipe}` | 3 | Craft a recipe standing at the workbench inside the outpost |
| `export_save` | `{}` | 3 | Returns `{ok, reason, code}`: the state as a save code. Changes nothing |
| `import_save` | `{code}` | 3 | Validates, migrates and loads a save code, replacing the state at once. Emits `saved` (reason `import_save`) or `save_rejected` |
| `cook`, `build` | | later | Reserved: answered with `not_implemented` |
| `eat`, `attack` | | 4 | Reserved: answered with `not_implemented` |

Any other kind is `unknown_command`. Rejection reasons for movement: `bad_args`, `outside_world` (off the grid), `not_walkable` (no free cell within `SNAP_RADIUS_CELLS`), `unreachable` (no route), `unknown_object`. For gathering: `not_gatherable`, `depleted`, `no_tool`, `level_too_low`, `pack_full`. For the inventory: `empty_slot`, `not_equippable`, `pack_full`, `stash_full`, `not_in_outpost`. For crafting: `unknown_recipe`, `not_at_workbench`, `level_too_low`, `upgrade_missing`, `missing_inputs`, `pack_full`. For save codes: `bad_code`, `bad_checksum`, `unsupported_version`, `bad_snapshot`.

### Interaction actions

`interacted.action` says what arriving at an object starts: `gather` for a tree (the gathering activity begins at once), `warm` for the fire (warming is by standing near it), `stash` and `craft` for the stash and the workbench (the presentation opens their panels), `none` for the gate.

### How a click becomes a walk

1. Off the grid: rejected.
2. The clicked cell is walkable: the destination is the exact click point.
3. The clicked cell is blocked (a wall, the fire): snap to the nearest walkable cell within 2 cells by distance, destination is that cell's centre. Further inside a solid than that: rejected.
4. A* routes from the player's cell to the destination cell (8-connected, no corner cutting). No route: rejected.
5. The cell path is smoothed by line of sight with a 0.3 m margin, so open-floor walks are straight lines.

`interact` picks the nearest routable approach cell: the ring of free cells around a blocking object, or the object's own cells when it does not block (the gate).

## Events

`drain_events()` returns every event since the last drain, oldest first, and clears the list. Each event is a Dictionary with a `kind` key.

| Event | Fields | When |
|-------|--------|------|
| `command_rejected` | `command, reason, args` | At command time |
| `path_set` | `from, to, length, object_id` | At command time, when a move or interact was accepted |
| `moved` | `from, to, path, facing` | Each tick the player moved. `path` is the polyline walked this tick, for the presentation to interpolate along |
| `arrived` | `pos, object_id` | The path ran out. `object_id` is `""` for a plain move |
| `interacted` | `object_id, object_kind, action` | Right after `arrived` at an interact target. `action` is `none` in slice 2 |
| `region_changed` | `from, to` | The player's region lookup changed (for example `outpost` to `inner_ring`) |
| `gathered` | `object_id, skill, item, count, xp` | A gathering attempt succeeded |
| `activity_stopped` | `activity, object_id, reason` | Gathering ended: `depleted`, `pack_full`, `no_tool`, `moved` or `collapsed` |
| `node_depleted` | `object_id, respawn_tick` | A node gave its last yield |
| `node_respawned` | `object_id` | A spent node regrew |
| `levelled` | `skill, level` | A skill reached a new level |
| `crafted` | `recipe, item, count` | A recipe was made |
| `equipped` | `slot, item, previous` | Gear changed; `item` is `""` when unequipping |
| `dropped`, `deposited`, `withdrew` | `item, count` | Items moved |
| `banked` | `items, overflow` | The player walked into the outpost. Both are lists of `{item, count}`; overflow stayed in the pack because the stash was full |
| `warmth_changed` | `warmth, max` | Warmth moved this tick |
| `took_damage` | `amount, cause, health` | Health fell (only `cold` in this slice) |
| `collapsed` | `cause, pos` | Health hit zero; the player woke beside the outpost fire |
| `saved` | `reason, tick` | A save point: `gate`, `deposit`, `withdraw`, `craft` or `import_save`. The presentation stores `sim.export_code()` |
| `save_rejected` | `reason` | An `import_save` failed |

Reserved for later slices, named in `SimVocab` now: `ate`, `built`, `enemy_telegraphed`, `enemy_died`, `died`.

## State shape

`Sim.state` is one plain-data Dictionary (ints, floats, strings, arrays, dictionaries only). Positions are `[x, z]` ground-plane metres. Camera state is never in it.

```
{
  "version": 2,
  "tick": 0,
  "rng": 1,                      # 31-bit generator state for gathering rolls
  "player": {
    "pos": [0.5, 4.5],
    "facing": [0.0, 1.0],        # unit direction on the ground plane
    "path": [[x, z], ...],       # waypoints still to walk, empty when idle
    "target_object": "",         # object id of a pending interact, "" otherwise
    "region": "outpost",
    "activity": {}               # {kind: "gather", object_id, progress} while gathering
  },
  "warmth": 360,                 # 0..Sim.WARMTH_MAX
  "health": 100,                 # 0..Sim.HEALTH_MAX
  "inventory": {
    "pack": [null, {"item": "logs", "count": 4}, ...],   # exactly Sim.PACK_SLOTS (12) slots
    "equipment": {"weapon": "", "armour": "", "tool": "wooden_axe"}
  },
  "stash": {"capacity": 8, "slots": [...]},  # capacity slots, null when empty
  "skills": {"woodcutting": {"xp": 0, "level": 1}, ...},  # all seven
  "nodes": {"tree_1": {"left": 4, "respawn_tick": 0}, ...},
  "upgrades": [],                # built upgrade ids (none buildable yet)
  "pending": []                  # queued inventory commands for the next tick
}
```

`snapshot()` returns a deep copy. `restore(snap)` migrates an older snapshot forward, then replaces the state from a normalised copy: numbers JSON turned into floats come back as ints, unknown items are dropped, stacks are clamped, missing pieces get a new character's defaults. It returns false, leaving the state untouched, when the version is unknown or newer, or the player is unreadable. A snapshot survives `JSON.stringify` and `JSON.parse_string`. Slice 4 adds `enemies` under the same version rule.

## Rules and their numbers

| Rule | Value |
|------|-------|
| Pack | 12 slots; logs stack to 10, gear never stacks |
| Carry limit | 20 kg (logs 1 kg, axe 2 kg, club 3 kg); above it walking is 60% speed |
| Stash | 8 slots to start; upgrades raise it in a later slice |
| Trees | Six pines 4 to 12 m south of the gate. Each yields 4 logs, then regrows 90 ticks (45 s) later |
| Woodcutting | One attempt takes `max(2, 4 - (level - 1) / 4)` ticks and succeeds with `min(95, 60 + 4 * (level - 1))` percent; 10 xp per log. Needs an axe in the pack or the tool slot |
| Experience curve | Shared by all seven skills: level L needs `50 * L * (L - 1) / 2` total xp (50, 150, 300, 500, ...), capped at 99. Levels never decrease |
| Warmth | 360 points, draining 1 per tick outside the outpost (three minutes). No drain inside the outpost. Within 3 m of a fire it refills 24 per tick and health refills 2 per tick |
| Cold | At zero warmth health drains 1 per tick (50 s from full). At zero health the player wakes beside the outpost fire with full health and the pack intact; this is not the gate, so nothing is banked |
| Recipe | Wooden club: 4 logs at the workbench, smithing level 1, no upgrade, no xp yet |

## The gate and banking

Walls leave the gate as the only way into the outpost, so any walk whose region changes into `outpost` has crossed it inward. That moves every pack slot into the stash (filling existing stacks first), leaves what does not fit in the pack as overflow, emits `banked`, and makes the tick a save point. Equipment is worn, not banked. Walking out starts the warmth drain because the region is no longer `outpost`.

## Saves

The simulation never touches the filesystem. It reports save points with `saved`; the presentation then stores `sim.export_code()` in `user://frostmark.save` (IndexedDB in the browser). The stored text and the code the player exports are the same format, so a damaged browser save is caught exactly like a bad pasted code.

A save code is base64 of `FM|<version>|<checksum>|<snapshot JSON>`. The JSON is compact with sorted keys. The checksum is the first 16 hex digits of SHA-256 over `<version>|<snapshot JSON>`: it catches typos, truncation and hand edits, and is not meant to stop a determined cheat. Decoding accepts only the canonical base64 of the decoded bytes, so every changed character is caught. It ignores whitespace from wrapped pastes, refuses codes from a newer build, and never raises an engine error.

`SaveCode.migrate(snap, target)` applies one step per version. Each step hard-codes the defaults of its own version, so retuning a constant later never changes what an old save migrates into. `1 -> 2` keeps the slice-2 tick and position and adds a new character's inventory, stash, skills, warmth, health and nodes.

## The world as data

`WorldDef.outpost()` builds the slice-2 world. A `WorldDef` has:

- A grid of `cols` x `rows` square cells of `cell_size` (64 x 64 cells of 1 m, origin at `[-32, -32]`), rasterised by `bake()` from the solids and blocking objects.
- `solids`: walls as `{id, kind, min, max, height}` rectangles.
- `objects`: typed markers by id, `{kind, label, min, max, height, blocks}`. The outpost has `gate` (with an `outward` direction), `fire`, `stash` and `workbench`; the inner ring has `tree_1` to `tree_6`.
- `NODE_KINDS`: per gatherable kind, the skill, required level, tool, item, yield, regrowth ticks and xp. Every placed object of such a kind gets an entry in `state.nodes`.
- `regions`: named polygons in precedence order, first match wins: `outpost` (the walled square), `inner_ring` (out to 24 m), `ring_one` (the rest of the grid).
- `spawn`: where a new state puts the player. `rescue`: where a collapsed player wakes, beside the fire.

The presentation draws the same solids and objects, so the picture and the walkability grid cannot disagree.

## How the presentation glues on

`scenes/game_root.gd` owns one `Sim`. It starts on the title screen (`scenes/title_screen.gd`): New character, Continue (when `user://frostmark.save` exists) and Import code. Continue and Import both go through `import_save`, so a bad browser save and a bad pasted code get the same clear message. The HUD (`scenes/hud.gd`) draws the warmth and health gauges, the skills readout (built from a list so it can show all seven), the pack and equipment, the stash and workbench panels and the save-code panel, and turns button presses into commands. `scenes/save_store.gd` reads and writes the browser save.

- `_process` adds frame time to an accumulator and calls `step()` for each whole tick, then `drain_events()`.
- Each `moved` event's `path` is replayed over the following tick by elapsed fraction, so the character glides between tick positions and turns at corners instead of cutting them.
- A left click is queued and resolved in `_physics_process` with a physics ray. A hit on the gate becomes `cross_gate`, a hit on another body carrying an `object_id` meta becomes `interact`, any other hit becomes `move_to` at the hit point. Clicks on HUD widgets never reach the world.
- `banked`, `levelled`, `crafted` and `collapsed` become a banner across the top; the rest become one line of status text. `saved` writes the browser save. `node_depleted` and `node_respawned` hide and show a tree's crown.
- The orbit camera (`scenes/orbit_camera.gd`) follows the character's rendered position and keeps its own yaw and distance.

## Adding a rule in a later slice

1. Add the command and event names to `SimVocab` if they are not there yet.
2. Add the state under a new key in `new_state()` and normalise it in `restore()`.
3. Handle the command in `Sim.command()` (validate, record intent) and the behaviour in `step()`.
4. Write the test first under `tests/`, driving only `command()` and `step()`.
5. Bind the new events in `game_root.gd`.
