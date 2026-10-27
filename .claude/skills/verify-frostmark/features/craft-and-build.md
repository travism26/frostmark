# Craft and build

Inside the outpost a player smiths tools and gear at the workbench, from the stash first and then the pack, and builds outpost upgrades that unlock recipes, add stash slots or carry, raise the smithing tier, open ring gates or wake waystones. A recipe whose upgrade is not built, or a build the player cannot pay for, is refused with a reason the panel shows.

## Sub-features

- AC1 `smith`: the workbench makes a wooden pickaxe from 3 logs into the pack and saves with reason `craft`.
- AC2 `locked-recipe`: a bronze bar is refused `upgrade_missing` before the forge is built.
- AC3 `build`: the stash shelves take 8 logs, add 4 stash slots, emit `built` and save with reason `build`.
- AC4 `short-build`: the forge is refused `missing_inputs` and nothing is spent.

## How to get to it (user POV)

- Click the workbench inside the walls; its panel lists the recipes.
- Open the side panel's **Upgrades** tab inside the outpost and click an upgrade.

## Driving it with probe.sh

Preconditions:

- `tools/check.sh` passes on this checkout.
- The probe starts from `Sim.new()` with 11 logs put in the pack by `H.set_pack` (two stacks: 10 and 1).

- **All four.** Run `.claude/skills/verify-frostmark/scripts/probe.sh .claude/skills/verify-frostmark/probes/craft_build.gd`. `PASS craft_build.gd`: `interacted` with action `craft`, one `crafted` `wooden_pickaxe`, 8 logs left; `upgrade_missing`; `built` `stash_shelves` with effects exactly `{stash: 4}`, capacity exactly 8 → 12; `missing_inputs` with inventory, stash and upgrades (`["stash_shelves"]`) unchanged.
- **Smith.** `sim.command(Vocab.INTERACT, {"object_id": "workbench"})`, walk, `sim.command(Vocab.SMITH, {"recipe": "wooden_pickaxe"})`, `H.run(sim, 2)`. `crafted` and `saved` with reason `craft`.
- **Build.** `sim.command(Vocab.BUILD, {"upgrade": "stash_shelves"})`, `H.run(sim, 2)`. `built` and `saved` with reason `build`.
- **Everything built.** For a build-from-scratch run, import `FieldKit.bare_code()` and build every upgrade in prerequisite order (each after everything in its `requires`), as `tests/test_bare_mode.gd`'s `_build_order` works it out. Do not rely on table order: it happens to satisfy the prerequisites today, but nothing keeps it so.

## Gotchas

- A pack stack holds 10: `H.set_pack(sim, [{"item": "logs", "count": 11}])` gives 10 logs, not 11.
- `smith` needs the player at the workbench (`not_at_workbench`); `build` needs no station, only the player inside the walls. But `build` checks `unknown_upgrade`, `already_built`, `upgrade_locked` and `upgrade_missing` before `not_in_outpost`, so outside the walls a bad or locked id is refused with that reason, not `not_in_outpost`.
- `upgrade_missing` is checked before `missing_inputs`, so a refusal names what to build first.
- Costs and recipes live in `sim/upgrades.gd` and `sim/recipes.gd`; when they are retuned, update the counts in this file and the probe together.
