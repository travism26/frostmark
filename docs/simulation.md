# The Frostmark simulation

Everything that is a rule lives in `sim/`, as RefCounted scripts with no Node, scene, Input, rendering or autoload dependency. The presentation in `scenes/` is glue: it turns clicks into commands and events into motion and text. Tests under `tests/test_*.gd` drive the simulation through `command()` and `step()` only. This is the seam that would later move to a server for co-op.

| File | Holds |
|------|-------|
| `sim/sim.gd` (`Sim`) | All game state, `command()`, `step()`, `drain_events()`, `snapshot()`, `restore()` |
| `sim/world_def.gd` (`WorldDef`) | The world as data: walkability grid, named regions, object placements |
| `sim/grid_path.gd` (`GridPath`) | A* over the grid plus line-of-sight smoothing |
| `sim/vocab.gd` (`SimVocab`) | Every command kind, event kind and rejection reason as a constant |

## Tick

`Sim.TICK_SECONDS` is 0.5 s. `step()` advances exactly one tick and is the only place state changes. The presentation accumulates frame time and calls `step()` once per tick, then drains events. Nothing in the rules reads wall-clock time, so the same commands at the same ticks give the same state.

Walking consumes `Sim.WALK_PER_TICK` metres of path per tick (4 m/s, so 2 m). A path of 6 m arrives on the third tick.

## Commands

`sim.command(kind, args)` returns `{ok, reason}`. Commands only record intent; the next `step()` acts on it. A rejected command also emits `command_rejected`.

| Command | Args | Slice | Does |
|---------|------|-------|------|
| `move_to` | `{pos: [x, z]}` | 2 | Walk to a ground point (see snapping below) |
| `interact` | `{object_id}` | 2 | Walk to an object and start its action. The action is `none` until the object's slice lands |
| `gather`, `cook`, `smith`, `equip`, `drop`, `deposit`, `withdraw`, `build`, `cross_gate`, `export_save`, `import_save` | | 3 | Reserved: answered with `not_implemented` |
| `eat`, `attack` | | 4 | Reserved: answered with `not_implemented` |

Any other kind is `unknown_command`. Rejection reasons for movement: `bad_args`, `outside_world` (off the grid), `not_walkable` (no free cell within `SNAP_RADIUS_CELLS`), `unreachable` (no route), `unknown_object`.

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

Reserved for later slices, named in `SimVocab` now: `gathered`, `levelled`, `crafted`, `equipped`, `ate`, `dropped`, `deposited`, `withdrew`, `built`, `took_damage`, `enemy_telegraphed`, `enemy_died`, `died`, `banked`, `warmth_changed`, `saved`, `save_rejected`.

## State shape

`Sim.state` is one plain-data Dictionary (ints, floats, strings, arrays, dictionaries only). Positions are `[x, z]` ground-plane metres. Camera state is never in it.

```
{
  "version": 1,
  "tick": 0,
  "player": {
    "pos": [0.5, 4.5],
    "facing": [0.0, 1.0],        # unit direction on the ground plane
    "path": [[x, z], ...],       # waypoints still to walk, empty when idle
    "target_object": "",         # object id of a pending interact, "" otherwise
    "region": "outpost"
  }
}
```

`snapshot()` returns a deep copy. `restore(snap)` replaces the state from a copy and returns false, leaving the state untouched, when `version` is not one it can read. A snapshot survives `JSON.stringify` and `JSON.parse_string`; later slices build the browser save and the export code on it. Later slices add `inventory`, `stash`, `skills`, `warmth`, `health`, `upgrades`, `enemies` and `nodes` as sibling keys under the same version rule.

## The world as data

`WorldDef.outpost()` builds the slice-2 world. A `WorldDef` has:

- A grid of `cols` x `rows` square cells of `cell_size` (64 x 64 cells of 1 m, origin at `[-32, -32]`), rasterised by `bake()` from the solids and blocking objects.
- `solids`: walls as `{id, kind, min, max, height}` rectangles.
- `objects`: typed markers by id, `{kind, label, min, max, height, blocks}`. Slice 2 has `gate`, `fire`, `stash`, `workbench`.
- `regions`: named polygons in precedence order, first match wins: `outpost` (the walled square), `inner_ring` (out to 24 m), `ring_one` (the rest of the grid). Only the outpost is populated now.
- `spawn`: where a new state puts the player.

The presentation draws the same solids and objects, so the picture and the walkability grid cannot disagree.

## How the presentation glues on

`scenes/game_root.gd` owns one `Sim`:

- `_process` adds frame time to an accumulator and calls `step()` for each whole tick, then `drain_events()`.
- Each `moved` event's `path` is replayed over the following tick by elapsed fraction, so the character glides between tick positions and turns at corners instead of cutting them.
- A left click is queued and resolved in `_physics_process` with a physics ray. A hit on a body carrying an `object_id` meta becomes `interact`, any other hit becomes `move_to` at the hit point.
- `arrived`, `interacted`, `region_changed` and `command_rejected` become one line of HUD text.
- The orbit camera (`scenes/orbit_camera.gd`) follows the character's rendered position and keeps its own yaw and distance.

## Adding a rule in a later slice

1. Add the command and event names to `SimVocab` if they are not there yet.
2. Add the state under a new key in `new_state()` and normalise it in `restore()`.
3. Handle the command in `Sim.command()` (validate, record intent) and the behaviour in `step()`.
4. Write the test first under `tests/`, driving only `command()` and `step()`.
5. Bind the new events in `game_root.gd`.
