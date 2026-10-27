## Feature probe: combat (features/combat.md). The test-mode character, loaded by its save code,
## walks out to the west wolf pack, kills a wolf, picks up what it dropped and eats to heal.
##   AC1 fight: attack kills wolf_1 with melee hits from the player's sword; its pack mate wolf_2 notices
##   AC2 loot: the wolf drops a wolf_pelt pile and walking onto it puts the pelt in the pack
##   AC3 eat: cooked char lands as `ate` and heals over the following ticks
##   AC4 no fighting from inside: attack from inside the outpost is refused as in_outpost
extends "res://tools/verify/probe_base.gd"

const H := preload("res://tests/sim_helpers.gd")
const Vocab := preload("res://sim/vocab.gd")


func run() -> void:
	var sim := Sim.new()
	var imported := sim.command(Vocab.IMPORT_SAVE, {"code": FieldKit.code()})
	sim.drain_events()

	var inside := sim.command(Vocab.ATTACK, {"enemy_id": "wolf_1"})
	grade("AC4", imported["ok"] and not inside["ok"] and inside["reason"] == "in_outpost",
		{"import": imported, "command": inside})

	sim.command(Vocab.CROSS_GATE, {})
	H.run_until_idle(sim, 200)
	var attack := sim.command(Vocab.ATTACK, {"enemy_id": "wolf_1"})
	var fight: Array[Dictionary] = []
	for i in 600:
		fight.append_array(H.run(sim, 1))
		if not H.where(fight, Vocab.EV_ENEMY_DIED, "enemy_id", "wolf_1").is_empty():
			break
	var my_hits := H.where(H.where(fight, Vocab.EV_HIT, "attacker", Vocab.PLAYER), Vocab.EV_HIT, "target", "wolf_1")
	var melee := H.where(my_hits, Vocab.EV_HIT, "style", "melee")
	var died := H.where(fight, Vocab.EV_ENEMY_DIED, "enemy_id", "wolf_1")
	var pack_mate := H.where(fight, Vocab.EV_ENEMY_NOTICED, "enemy_id", "wolf_2")
	grade("AC1", attack["ok"] and died.size() == 1 and my_hits.size() > 0
		and melee.size() == my_hits.size() and pack_mate.size() > 0,
		{"command": attack, "hits": my_hits, "died": died, "wolf_2_noticed": pack_mate,
		"health": int(sim.state["health"])})

	var drops := H.of_kind(fight, Vocab.EV_LOOT_DROPPED)
	var picked: Array[Dictionary] = []
	if not drops.is_empty():
		sim.command(Vocab.INTERACT, {"object_id": drops[0]["loot_id"]})
		picked = H.of_kind(H.run_until_idle(sim, 200), Vocab.EV_PICKED_UP)
	grade("AC2", drops.size() > 0 and drops[0]["item"] == "wolf_pelt" and picked.size() > 0
		and H.pack_count(sim, "wolf_pelt") > 0,
		{"dropped": drops, "picked_up": picked})

	H.patch(sim, {"health": 40})
	var food := -1
	var pack: Array = sim.state["inventory"]["pack"]
	for i in pack.size():
		if pack[i] != null and pack[i]["item"] == "cooked_char":
			food = i
	var eat := sim.command(Vocab.EAT, {"index": food})
	var meal := H.run(sim, 12)
	grade("AC3", eat["ok"] and H.of_kind(meal, Vocab.EV_ATE).size() == 1
		and H.of_kind(meal, Vocab.EV_HEALED).size() > 0 and int(sim.state["health"]) > 40,
		{"command": eat, "ate": H.of_kind(meal, Vocab.EV_ATE), "health": [40, int(sim.state["health"])]})
