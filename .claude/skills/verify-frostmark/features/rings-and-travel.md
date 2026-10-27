# Rings and travel

The world opens outward through gates: an open ring gate walks the player through to the next ring, the first time announced and saved; a dungeon's mouth walks into the dungeon the same way. Waystones, once built and attuned, channel the player back to just outside the outpost gate, unless a blow breaks the channel. Travel is not a return: the player still has to walk in.

## Sub-features

- AC1 `ring-gate`: one click on the open ring-three gate walks into ring three, emits `ring_three_reached` once with `object_id` `ring_three_gate`, saves with reason `ring_three`.
- AC2 `dungeon-mouth`: one click on the ring-one dungeon's mouth walks in, emits `dungeon_reached` once, saves with reason `ring_one_dungeon`.
- AC3 `waystone-travel`: from inside the outpost travel is refused `not_at_waystone`; by the attuned ring-one waystone it emits `travel_started` and lands at `[0.5, 12.5]`, outside the gate in the inner ring, with no `returned`; a blow during the channel stops it `interrupted`.
- AC4 `sleeping-waystone`: a new character's travel is refused `upgrade_missing`.

## How to get to it (user POV)

- Click an open ring gate (`ring_two_gate`, `ring_three_gate`) or the dungeon's mouth (`ring_one_dungeon_mouth`).
- Walk up to a waystone (`ring_one_waystone`, `ring_two_waystone`) once to attune it, then **Travel to the outpost** beside it.
- Test-code links with `ring=two`, `ring=three` or `ring=dungeon` start the test character in front of each (the code map, `docs/testing.md`).

## Driving it with probe.sh

Preconditions:

- `tools/check.sh` passes on this checkout.
- The probe imports the test-mode character: at `FieldKit.RING_SPOTS["three"]` for AC1, `["dungeon"]` for AC2, and in the outpost for AC3. AC4 uses `Sim.new()`.

- **All four.** Run `.claude/skills/verify-frostmark/scripts/probe.sh .claude/skills/verify-frostmark/probes/rings_travel.gd`. `PASS rings_travel.gd`: region `ring_three`, one `ring_three_reached`, saved `ring_three`; one `dungeon_reached` `ring_one_dungeon`, saved `ring_one_dungeon`; `not_at_waystone` from the outpost, then one `travel_started` and `travelled` to `[0.5, 12.5]`, region `inner_ring`, `interrupted` 1 first (today); `upgrade_missing`.
- **Ring gate.** `sim.command(Vocab.INTERACT, {"object_id": "ring_three_gate"})`, `H.run_until_idle(sim, 300)`.
- **Waystone.** `INTERACT` `ring_one_waystone` (walks from the outpost, about 600 ticks cap), then `sim.command(Vocab.TRAVEL, {"object_id": "ring_one_waystone"})` and `H.run(sim, Sim.TRAVEL_TICKS + 2)`. `travel_started`, then `travelled`.
- **Screen.** `web.sh import dungeon_mouth`, then `web.sh shot dungeon_mouth`: a new ring-one character stands on ring one's side of the dungeon's mouth. `tools/ring_codes.txt`'s `ring_three` is a different character, a new one already inside ring three, so it shows the ring, not the gate. For the test character before the ring-three gate, open its `ring=three` test link (needs the local seed `tools/test_codes.local.cfg`, absent on most machines) or put the full code from the map's "test mode at the ring-three gate" entry (`tools/test_codes.local.md`, `docs/testing.md` The code map) in a file and `web.sh import --file <path>`.

## Gotchas

- The ring-one waystone stands out of every archer's reach, but the walk there from the outpost passes in sight of `archer_1` and `archer_5`: both notice the player (cause `sight`) and follow. Observed live: at the first channel they were 8.6 m and 11 m off, engaged, and closed to shoot from 7.6 m and less; the first arrow broke the channel. The probe lets auto-retaliate kill them and channels again (up to 6 tries; the second succeeds today). A probe that travels once and expects `travelled` fails here, and that failure is the rule working. A character who reaches the stone unseen channels unbroken.
- The test character has ring two already reached, so walking through the ring-two gate emits no `ring_two_reached`; use the ring-three spot for a first-time gate.
- `travel` refuses `not_at_waystone` farther than 1.5 m: walk there with `INTERACT` first.
- The dungeon's way out refuses `way_out_shut` while its boss stands; leaving the dungeon belongs with boss fights, not mapped yet.
