# Gather and return

The core loop: walk out through the outpost gate into the cold, gather from a node until it is spent, walk back in to be home safe (nothing moves, the game saves), and put the haul in the stash while kit stays in the pack.

## Sub-features

- AC1 `head-out`: crossing the gate leaves the outpost for the inner ring and warmth starts to drain.
- AC2 `gather`: clicking a pine walks to it and chops it out: 4 logs in the pack, 10 woodcutting xp each, then `activity_stopped` reason `depleted`.
- AC3 `home-safe`: walking back in emits `returned` with the pack, moves nothing, and saves with reason `gate`.
- AC4 `deposit-haul`: at the stash, Deposit haul moves the logs to the stash, leaves kit (gear, ammo, cooked food) in the pack, and saves.

## How to get to it (user POV)

- Click the south gate itself to cross it (`CROSS_GATE`). A click on the ground beyond it is a plain `MOVE_TO` that walks out through the gap; any walk back into the outpost, by gate click or ground click, is a return.
- Click a pine (`tree_1`..`tree_10` in the inner ring): the click sends `INTERACT {object_id}`, and chopping starts on arrival.
- Click the stash inside the walls, then **Deposit haul** in its panel.

## Driving it with probe.sh

Preconditions:

- `tools/check.sh` passes on this checkout.
- The probe starts from `Sim.new()`: a new character in the outpost with the wooden axe worn, an empty pack and the starting stash (bow, arrows, cooked fish). It puts a wooden club and 2 cooked fish in the pack with `H.set_pack` as kit for the trip.

- **All four.** Run `.claude/skills/verify-frostmark/scripts/probe.sh .claude/skills/verify-frostmark/probes/gather_return.gd`. `PASS gather_return.gd`, and its four `PROBE` lines show: region `inner_ring` and warmth below 360; exactly 4 `gathered`, 4 logs, xp 0 → 40, stopped `depleted` on `tree_1`; one `returned` with the kit and `{logs, 4}`, one `gate` save, pack unchanged; one `deposited_haul` with `stayed: []`, stash logs 0 → 4, the club and fish still in the pack and the stash's kit counts unchanged.
- **Head out.** `sim.command(Vocab.CROSS_GATE, {})`, then `H.run_until_idle(sim, 200)`. A `region_changed` from `outpost` to `inner_ring`.
- **Gather.** `sim.command(Vocab.INTERACT, {"object_id": "tree_1"})` (what the click sends), then `H.run_until_idle(sim, 400)`. 4 `gathered` events and `activity_stopped` with reason `depleted`.
- **Home safe.** `CROSS_GATE` again. One `returned`, then `saved` with reason `gate`.
- **Deposit haul.** `sim.command(Vocab.INTERACT, {"object_id": "stash"})`, walk, then `sim.command(Vocab.DEPOSIT_HAUL, {})` and `H.run(sim, 2)`. `deposited_haul` with the logs in `items` and `stayed` empty, kit left in the pack, and `saved` with reason `deposit_haul`.

## Gotchas

- Inventory commands queue and land on the next tick: step at least once before reading the pack or stash.
- `deposit_haul` refuses `not_in_outpost` outside the walls and `no_haul` when only kit is left; neither is a bug.
- A pine gives 4 logs then stays spent until it regrows: a second gather on the same tree in one probe is refused `depleted`.
- In the browser, a new character's first hint is the walk hint ("Click the ground to walk. Q and E turn the camera, and the wheel zooms."); the pine hint "Walk out through the south gate and click a pine to cut logs." shows only after the first move. That is the screen's half of this feature, unproved by the probe.
- `deposited_haul`'s `stayed` lists haul that did not fit the stash, not kit; kit never appears in the event.
- The new stash already holds cooked fish: compare stash counts before and after, not against 0.
