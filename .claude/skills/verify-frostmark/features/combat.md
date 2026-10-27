# Combat

Out past the walls a player clicks an enemy to close to the weapon's reach and strike on every ready tick until it dies. A dead enemy may drop a pile to pick up. Eating food heals over the following ticks. Nothing is fought from inside the outpost.

## Sub-features

- AC1 `fight`: attacking `wolf_1` with the test character's steel sword lands player hits (style `melee`) until `enemy_died`; its pack mate `wolf_2` gets `enemy_noticed` (cause `pack`).
- AC2 `loot`: the wolf's `loot_dropped` `wolf_pelt` pile goes into the pack on walking onto it (`picked_up`).
- AC3 `eat`: eating cooked char emits `ate` and `healed`, and health rises.
- AC4 `no-fight-inside`: an attack ordered from inside the outpost is refused `in_outpost`.

## How to get to it (user POV)

- Click an enemy to attack it with the weapon in hand; auto-retaliate (on by default) fights back when hit while standing still.
- Click a loot pile to pick it up.
- Click a food item in the side panel's **Pack** tab to eat it.

## Driving it with probe.sh

Preconditions:

- `tools/check.sh` passes on this checkout.
- The probe imports the test-mode character (`FieldKit.code()`): steel gear, every skill at 99, 5 cooked char in the pack, in the outpost.

- **All four.** Run `.claude/skills/verify-frostmark/scripts/probe.sh .claude/skills/verify-frostmark/probes/combat.gd`. `PASS combat.gd`: `in_outpost`; `enemy_died` for `wolf_1` after at least one player hit, every one `melee`; `enemy_noticed` for `wolf_2` with cause `pack`; `loot_dropped` `wolf_pelt` then `picked_up`; `ate` cooked char and health 40 → above 40.
- **Fight.** `CROSS_GATE`, then `sim.command(Vocab.ATTACK, {"enemy_id": "wolf_1"})` and step until `enemy_died` (cap 600 ticks).
- **Loot.** `sim.command(Vocab.INTERACT, {"object_id": "<loot_id from loot_dropped>"})`, walk. `picked_up`.
- **Eat.** `sim.command(Vocab.EAT, {"index": <slot of cooked_char>})`, `H.run(sim, 12)`. `ate`, then `healed` events.
- **Counters.** For the style edge (a blade up close beats a bow, a bow at range beats a blade), read the `multiplier` on `hit` events: a bandit archer's arrow on the sword-holding player is 1.5 at range and 0.5 once the player is up close; the player's sword on the archer is 1.5.

## Gotchas

- The test character kills a wolf in one hit, so AC1 proves the attack path, not fight balance; balance is `tests/test_balance.gd`.
- `wolf_1` runs with `wolf_2` (the west pack): AC1 requires `enemy_noticed` for `wolf_2` (cause `pack`). The sim is deterministic, and it held on three runs in a row; if a retune makes it flaky, move it back to a gotcha rather than loosening the kill check.
- The probe sets health to 40 with `H.patch` to make the meal's healing visible: arrangement, not the step under test.
- In the browser, enemies near a loaded ring code start fighting at once (a ring-one import has lost health to an archer by the first screenshot).
