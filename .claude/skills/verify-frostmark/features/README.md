# Frostmark verification map

The maintained source for verifying Frostmark as a player sees it. Read this index, then the feature file, then drive it with the commands there. `SKILL.md` has launch, doctor, evidence and cleanup.

## Baseline preconditions

- Probes: `godot` on the PATH (`tools/check.sh` passes). Every probe starts from `Sim.new()` (a new character in the outpost, empty pack, wooden axe worn) or from a test character imported by its code. Nothing persists between probes.
- Web: a pushed commit with a green CI run, served by `web.sh serve <sha>`, `web.sh doctor` clean. The isolated profile keeps its browser save between `open`s until `stop`.
- Never drive the user's Chrome or a server this run did not start.

## Driving conventions

- Rules through probes, screen through the web build. A world click in the browser depends on the camera, so a rule proved by clicking is unproved.
- Probe checks are `AC1..ACn` in the probe's header; the feature's Sub-features use the same numbers.
- Arrange with `restore()` helpers or an imported test character; then reach the state under test by commands only.
- Literal commands: run them as written from the repo root.

## Proof and skip reporting

- A probe proof is its `summary.txt` and `.log` under `$FROSTMARK_VERIFY_HOME/features/`, with `tree.txt` naming the commit and whether the tree was dirty.
- A web proof is a before and after screenshot and the console file under `$FROSTMARK_VERIFY_HOME/web/evidence/<sha7>/`.
- Name the feature, the sub-feature numbers and the entry point with each artifact.
- A journey that cannot run reports what it attempted and the missing precondition. Never report an entry point as verified through another one.

## Feature entry contract

Each feature file: an H1, one paragraph of player-visible behaviour, then exactly these H2s in order: `Sub-features`, `How to get to it (user POV)`, `Driving it with <harness>` (starting with `Preconditions:`, then labelled bullets pairing a player action with a command and its observable result), `Gotchas`. No implementation detail beyond stable handles: command and event names, object ids, ring codes, coordinates.

## Features

- [Gather and return](./gather-and-return.md): walk out, gather, walk home safe through the gate, deposit the haul.
- [Craft and build](./craft-and-build.md): smith at the workbench, build outpost upgrades, refusals when locked or short.
- [Combat](./combat.md): attack an enemy, loot, eat to heal, no fighting from inside the walls.
- [Rings and travel](./rings-and-travel.md): ring gates, the dungeon's mouth, waystone travel.
- [Save codes](./save-codes.md): export and import a code, damaged codes, test characters, the browser save and Continue.

Not yet mapped (add a file when you touch one): cooking and field fires, death and the death chest, the first-outing guide and tips, settings, boss fights and phases (the captain, the Frost tyrant, the great frost bear), the HUD's warmth and health orbs, gear and equipment (sets, the quiver and cape slots, fur warmth; `sim/items.gd`), advanced enemy moves (feints, answers, area blows, burning ground; `sim/combat.gd`).
