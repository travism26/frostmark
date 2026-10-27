## Feature probe: rings and travel (features/rings-and-travel.md). The test-mode character, at
## the spots its `ring=` links use, walks through the ring-three gate and the dungeon's mouth,
## and from the outpost attunes nothing new but travels home by the ring-one waystone.
##   AC1 ring gate: one click on the open ring-three gate walks into ring three, once, and saves
##   AC2 dungeon mouth: one click on the mouth walks into the ring-one dungeon, once, and saves
##   AC3 waystone travel: from the outpost travel is refused not_at_waystone; by the attuned
##       waystone it starts a channel and lands at [0.5, 12.5] outside the gate, not a return;
##       a blow during the channel breaks it (archers that followed the player south do)
##   AC4 sleeping waystone: a new character's travel is refused as upgrade_missing
extends "res://tools/verify/probe_base.gd"

const H := preload("res://tests/sim_helpers.gd")
const Vocab := preload("res://sim/vocab.gd")


func run() -> void:
	var three := Sim.new()
	three.command(Vocab.IMPORT_SAVE, {"code": FieldKit.code(null, FieldKit.RING_SPOTS["three"])})
	three.drain_events()
	var gate := three.command(Vocab.INTERACT, {"object_id": "ring_three_gate"})
	var walk := H.run_until_idle(three, 300)
	var first := H.of_kind(walk, Vocab.EV_RING_THREE_REACHED)
	grade("AC1", gate["ok"] and three.state["player"]["region"] == WorldDef.REGION_RING_THREE
		and first.size() == 1 and first[0]["object_id"] == "ring_three_gate"
		and H.where(walk, Vocab.EV_SAVED, "reason", "ring_three").size() == 1,
		{"command": gate, "region": three.state["player"]["region"],
		"reached": first, "saved": H.of_kind(walk, Vocab.EV_SAVED)})

	var dungeon := Sim.new()
	dungeon.command(Vocab.IMPORT_SAVE, {"code": FieldKit.code(null, FieldKit.RING_SPOTS["dungeon"])})
	dungeon.drain_events()
	var mouth := dungeon.command(Vocab.INTERACT, {"object_id": "ring_one_dungeon_mouth"})
	var inward := H.run_until_idle(dungeon, 300)
	var reached := H.of_kind(inward, Vocab.EV_DUNGEON_REACHED)
	grade("AC2", mouth["ok"] and reached.size() == 1 and "ring_one_dungeon" in dungeon.state["dungeons_reached"]
		and H.where(inward, Vocab.EV_SAVED, "reason", "ring_one_dungeon").size() == 1,
		{"command": mouth, "region": dungeon.state["player"]["region"], "reached": reached,
		"saved": H.of_kind(inward, Vocab.EV_SAVED)})

	var home := Sim.new()
	home.command(Vocab.IMPORT_SAVE, {"code": FieldKit.code()})
	home.drain_events()
	var too_far := home.command(Vocab.TRAVEL, {"object_id": "ring_one_waystone"})
	grade("AC3", not too_far["ok"] and too_far["reason"] == "not_at_waystone", {"from_outpost": too_far})
	home.command(Vocab.INTERACT, {"object_id": "ring_one_waystone"})
	var out := H.run_until_idle(home, 600)
	# The stone is out of the archers' reach, but archer_1 and archer_5 see the player on the walk
	# south and follow: their arrows break the first channel, and the player fights back
	# (auto-retaliate) until it can channel unbroken.
	var travel := {}
	var channel: Array[Dictionary] = []
	var broken := 0
	for attempt in 6:
		travel = home.command(Vocab.TRAVEL, {"object_id": "ring_one_waystone"})
		channel = H.run(home, Sim.TRAVEL_TICKS + 2)
		if not H.of_kind(channel, Vocab.EV_TRAVELLED).is_empty():
			break
		broken += H.where(channel, Vocab.EV_ACTIVITY_STOPPED, "reason", "interrupted").size()
		H.run(home, 40)
		home.command(Vocab.INTERACT, {"object_id": "ring_one_waystone"})
		H.run_until_idle(home, 200)
	var landed := H.of_kind(channel, Vocab.EV_TRAVELLED)
	var started := H.of_kind(channel, Vocab.EV_TRAVEL_STARTED)
	grade("AC3", travel["ok"] and started.size() == 1 and landed.size() == 1
		and landed[0]["to"] == [0.5, 12.5] and not home.in_outpost()
		and home.state["player"]["region"] == WorldDef.REGION_INNER_RING
		and H.of_kind(channel, Vocab.EV_RETURNED).is_empty(),
		{"arrived": H.of_kind(out, Vocab.EV_ARRIVED), "command": travel, "travel_started": started,
		"travelled": landed,
		"interrupted": broken, "region": home.state["player"]["region"], "pos": home.state["player"]["pos"]})

	var fresh := Sim.new()
	var refused := fresh.command(Vocab.TRAVEL, {"object_id": "ring_one_waystone"})
	grade("AC4", not refused["ok"] and refused["reason"] == "upgrade_missing", {"command": refused})
