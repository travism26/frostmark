## Feature probe: gather and return (features/gather-and-return.md). A new character walks out,
## chops a pine, walks home through the gate and deposits the haul at the stash.
##   AC1 head out: crossing the gate leaves the outpost and the cold starts
##   AC2 gather: clicking tree_1 (INTERACT, as a click does) chops it out: 4 logs, +40 xp, depleted
##   AC3 home safe: walking back in is a return that moves nothing and saves at the gate
##   AC4 deposit haul: the logs go to the stash, the kit in the pack stays there, and it saves
extends "res://tools/verify/probe_base.gd"

const H := preload("res://tests/sim_helpers.gd")
const Vocab := preload("res://sim/vocab.gd")


func run() -> void:
	var sim := Sim.new()
	# Kit carried on the trip (gear and cooked food, ItemTable.is_kit): deposit_haul must leave it.
	var kit := [{"item": "wooden_club", "count": 1}, {"item": "cooked_fish", "count": 2}]
	H.set_pack(sim, kit)
	var warmth0 := int(sim.state["warmth"])
	var stash_logs0 := H.stash_count(sim, "logs")
	var pack_logs0 := H.pack_count(sim, "logs")

	sim.command(Vocab.CROSS_GATE, {})
	var out := H.run_until_idle(sim, 200)
	out.append_array(H.run(sim, 20))
	var region := String(sim.state["player"]["region"])
	grade("AC1", region == WorldDef.REGION_INNER_RING and int(sim.state["warmth"]) < warmth0,
		{"region": region, "warmth": [warmth0, int(sim.state["warmth"])],
		"region_changed": H.of_kind(out, Vocab.EV_REGION_CHANGED)})

	var xp0 := int(sim.state["skills"]["woodcutting"]["xp"])
	var started := sim.command(Vocab.INTERACT, {"object_id": "tree_1"})
	var chop := H.run_until_idle(sim, 400)
	var gathered := H.of_kind(chop, Vocab.EV_GATHERED)
	var logs := H.pack_count(sim, "logs")
	var depleted := 0
	for e in H.of_kind(chop, Vocab.EV_ACTIVITY_STOPPED):
		if String(e.get("reason", "")) == "depleted" and String(e.get("object_id", "")) == "tree_1":
			depleted += 1
	grade("AC2", started["ok"] and gathered.size() == 4 and logs == pack_logs0 + 4
		and int(sim.state["skills"]["woodcutting"]["xp"]) == xp0 + 40 and depleted == 1,
		{"command": started, "gathered": gathered.size(), "pack_logs": logs,
		"xp": [xp0, int(sim.state["skills"]["woodcutting"]["xp"])],
		"stopped": H.of_kind(chop, Vocab.EV_ACTIVITY_STOPPED)})

	var pack_before: Array = sim.state["inventory"]["pack"].duplicate(true)
	sim.command(Vocab.CROSS_GATE, {})
	var back := H.run_until_idle(sim, 300)
	var returned := H.of_kind(back, Vocab.EV_RETURNED)
	var gate_saves := H.where(back, Vocab.EV_SAVED, "reason", "gate")
	grade("AC3", sim.in_outpost() and returned.size() == 1 and gate_saves.size() == 1
		and sim.state["inventory"]["pack"] == pack_before,
		{"in_outpost": sim.in_outpost(), "returned": returned, "gate_saves": gate_saves.size(),
		"pack_unchanged": sim.state["inventory"]["pack"] == pack_before})

	sim.command(Vocab.INTERACT, {"object_id": "stash"})
	H.run_until_idle(sim, 200)
	var stash_kit0 := {}
	for k in kit:
		stash_kit0[k["item"]] = H.stash_count(sim, k["item"])
	var queued := sim.command(Vocab.DEPOSIT_HAUL, {})
	var dep := H.run(sim, 2)
	var hauled := H.of_kind(dep, Vocab.EV_DEPOSITED_HAUL)
	var kit_kept := true
	for k in kit:
		kit_kept = kit_kept and H.pack_count(sim, k["item"]) == k["count"] \
			and H.stash_count(sim, k["item"]) == stash_kit0[k["item"]]
	grade("AC4", queued["ok"] and hauled.size() == 1 and H.pack_count(sim, "logs") == 0
		and H.stash_count(sim, "logs") == stash_logs0 + logs and kit_kept
		and (hauled[0]["stayed"] as Array).is_empty()
		and H.where(dep, Vocab.EV_SAVED, "reason", "deposit_haul").size() == 1,
		{"command": queued, "deposited_haul": hauled,
		"stash_logs": [stash_logs0, H.stash_count(sim, "logs")], "pack_logs": H.pack_count(sim, "logs"),
		"kit_kept": kit_kept, "pack": sim.state["inventory"]["pack"].filter(func(slot): return slot != null)})
