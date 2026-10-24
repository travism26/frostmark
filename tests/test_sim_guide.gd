## The first-outing guide: the hint path advancing on its events, contextual tips on their
## conditions and cooldowns, dismissing it, and every character after the first starting
## with it off.
extends "res://tests/run.gd".TestCase

const H := preload("res://tests/sim_helpers.gd")
const SimScript := preload("res://sim/sim.gd")
const Vocab := preload("res://sim/vocab.gd")


static func _hints(events: Array[Dictionary]) -> Array:
	var out := []
	for e in H.of_kind(events, Vocab.EV_HINT):
		out.append(e["hint"])
	return out


static func _tips(events: Array[Dictionary], id: String) -> Array[Dictionary]:
	return H.where(events, Vocab.EV_TIP, "tip", id)


func test_guide_table_shape() -> void:
	assert_eq(GuideTable.step_count(), 4)
	for s in GuideTable.STEPS:
		assert_true(str(s["text"]) != "", "%s has text" % s["id"])
		assert_true(str(s["trigger"]["event"]) != "", "%s has a trigger" % s["id"])
	for id in GuideTable.TIPS:
		var tip: Dictionary = GuideTable.TIPS[id]
		assert_true(str(tip["text"]) != "", "%s has text" % id)
		assert_true(int(tip["cooldown"]) > 0, "%s has a cooldown" % id)
		assert_true(tip.has("triggers") or tip.has("condition"), "%s has a trigger" % id)


func test_a_new_character_starts_on_the_first_hint() -> void:
	var sim := SimScript.new()
	assert_true(sim.hints_on())
	assert_eq(sim.hint(), "walk")


func test_the_hint_path_advances_on_its_events_in_order() -> void:
	var sim := SimScript.new()
	# Walking is the first step.
	var events := H.walk_to(sim, H.OUTSIDE)
	assert_eq(_hints(events), ["chop"], "a walk finishes the walk step")
	assert_eq(sim.hint(), "chop")
	# Cutting a pine is the second.
	sim.command(Vocab.GATHER, {"object_id": "tree_3"})
	events = H.run_until_idle(sim, 300)
	assert_eq(_hints(events), ["bank"])
	assert_true(H.pack_count(sim, "logs") > 0)
	# Walking the logs home through the gate is the third.
	sim.command(Vocab.CROSS_GATE)
	events = H.run_until_idle(sim, 100)
	assert_eq(H.of_kind(events, Vocab.EV_RETURNED).size(), 1)
	assert_eq(_hints(events), ["craft"])
	# Making a pickaxe at the workbench from the logs still in the pack is the last.
	assert_true(H.pack_count(sim, "logs") >= 3, "the logs came home in the pack")
	assert_eq(H.stash_count(sim, "logs"), 0, "and none went to the stash")
	sim.command(Vocab.INTERACT, {"object_id": "workbench"})
	H.run_until_idle(sim, 60)
	assert_true(sim.command(Vocab.SMITH, {"recipe": "wooden_pickaxe"})["ok"])
	events = H.run(sim, 1)
	assert_eq(_hints(events), [""], "the path is walked")
	assert_eq(sim.hint(), "")
	assert_true(sim.hints_on(), "tips stay on after the path")


func test_an_empty_return_does_not_finish_the_return_step() -> void:
	var sim := SimScript.new()
	H.walk_to(sim, H.OUTSIDE)
	sim.state["guide"]["step"] = 2
	assert_eq(sim.hint(), "bank")
	var events := H.walk_to(sim, [0.5, 6.5])
	assert_eq(H.of_kind(events, Vocab.EV_RETURNED).size(), 1, "it is still a return")
	assert_eq(_hints(events), [], "but with nothing carried it teaches nothing")
	H.walk_to(sim, H.OUTSIDE)
	H.set_pack(sim, [{"item": "logs", "count": 3}])
	events = H.walk_to(sim, [0.5, 6.5])
	assert_eq(_hints(events), ["craft"], "a return with logs does")


func test_a_step_only_listens_for_its_own_event() -> void:
	var sim := SimScript.new()
	sim.command(Vocab.INTERACT, {"object_id": "workbench"})
	H.run_until_idle(sim, 60)
	assert_eq(sim.hint(), "chop", "the walk to the bench was the walk step")
	H.set_pack(sim, [{"item": "logs", "count": 3}])
	sim.command(Vocab.SMITH, {"recipe": "wooden_pickaxe"})
	var events := H.run(sim, 1)
	assert_eq(H.of_kind(events, Vocab.EV_CRAFTED).size(), 1)
	assert_eq(_hints(events), [], "crafting early does not skip ahead")
	assert_eq(sim.hint(), "chop")


func test_the_cold_tip_fires_outside_and_respects_its_cooldown() -> void:
	var sim := SimScript.new()
	H.walk_to(sim, H.OUTSIDE)
	H.patch(sim, {"warmth": GuideTable.COLD_WARMTH + 2})
	var events := H.run(sim, 1)
	assert_eq(_tips(events, "cold").size(), 0, "not cold yet")
	events = H.run(sim, 2)
	assert_eq(_tips(events, "cold").size(), 1, "fires as warmth reaches the line")
	events = H.run(sim, 20)
	assert_eq(_tips(events, "cold").size(), 0, "quiet within its cooldown")
	var ready := int(sim.state["guide"]["tips"]["cold"])
	assert_eq(ready - int(sim.state["tick"]), int(GuideTable.TIPS["cold"]["cooldown"]) - 21, "fired 21 ticks ago")
	H.patch(sim, {"tick": ready - 2, "warmth": GuideTable.COLD_WARMTH, "health": Sim.HEALTH_MAX})
	assert_eq(_tips(H.run(sim, 1), "cold").size(), 0, "a tick short of the cooldown")
	assert_eq(_tips(H.run(sim, 1), "cold").size(), 1, "fires again once the cooldown has passed")


func test_the_cold_tip_stays_quiet_inside() -> void:
	var sim := SimScript.new()
	H.walk_to(sim, H.INSIDE_COLD_CORNER)
	H.patch(sim, {"warmth": 10})
	assert_eq(_tips(H.run(sim, 5), "cold").size(), 0, "safe inside the walls")


func test_the_pack_full_tip_fires_on_a_full_pack() -> void:
	var sim := SimScript.new()
	var full := []
	for i in Sim.PACK_SLOTS:
		full.append({"item": "copper_ore", "count": ItemTable.stack_size("copper_ore")})
	H.set_pack(sim, full)
	sim.drain_events()
	var result := sim.command(Vocab.GATHER, {"object_id": "tree_3"})
	assert_eq(result["reason"], Vocab.REASON_PACK_FULL)
	var events := sim.drain_events()
	assert_eq(_tips(events, "pack_full").size(), 1, "the refusal fires the tip at once")
	sim.command(Vocab.GATHER, {"object_id": "tree_3"})
	assert_eq(_tips(sim.drain_events(), "pack_full").size(), 0, "not again within its cooldown")


func test_the_telegraph_tip_fires_on_an_enemy_cue() -> void:
	var sim := SimScript.new()
	H.place(sim, [-7.5, 26.5])  # two metres from wolf_1: seen, and it closes in
	var events := H.run(sim, 10)
	assert_true(H.of_kind(events, Vocab.EV_ENEMY_TELEGRAPHED).size() > 1, "the wolf keeps telegraphing")
	assert_eq(_tips(events, "telegraph").size(), 1, "one tip, then its cooldown")


func test_dismissing_turns_hints_and_tips_off() -> void:
	var sim := SimScript.new()
	assert_true(sim.command(Vocab.SET_HINTS, {"on": false})["ok"])
	var set := H.of_kind(sim.drain_events(), Vocab.EV_HINTS_SET)
	assert_eq(set.size(), 1)
	assert_eq(set[0]["on"], false)
	assert_eq(sim.hint(), "")
	var events := H.walk_to(sim, H.OUTSIDE)
	H.patch(sim, {"warmth": 10})
	events.append_array(H.run(sim, 5))
	assert_eq(H.of_kind(events, Vocab.EV_HINT).size(), 0, "no hint steps")
	assert_eq(H.of_kind(events, Vocab.EV_TIP).size(), 0, "no tips")
	# The choice is saved with the character.
	var loaded := SimScript.new()
	assert_true(loaded.command(Vocab.IMPORT_SAVE, {"code": sim.export_code()})["ok"])
	assert_false(loaded.hints_on(), "still off after a reload")
	# And can be undone, picking up where the path left off.
	sim.command(Vocab.SET_HINTS, {"on": true})
	assert_eq(sim.hint(), "walk", "the walk happened while the guide was off")


func test_set_hints_needs_a_bool() -> void:
	var sim := SimScript.new()
	assert_eq(sim.command(Vocab.SET_HINTS, {})["reason"], Vocab.REASON_BAD_ARGS)
	assert_eq(sim.command(Vocab.SET_HINTS, {"on": "no"})["reason"], Vocab.REASON_BAD_ARGS)
	assert_true(sim.hints_on())


func test_a_second_character_starts_with_hints_off() -> void:
	var first := SimScript.new()
	H.walk_to(first, H.OUTSIDE)
	var previous := first.export_code()
	var second := SimScript.new()
	assert_true(second.command(Vocab.NEW_CHARACTER, {"previous": previous})["ok"])
	assert_false(second.hints_on(), "the guide is for the first character only")
	assert_eq(second.hint(), "")
	assert_eq(second.state["tick"], 0, "a fresh character")
	assert_eq(second.state["player"]["region"], WorldDef.REGION_OUTPOST)
	# A dismissed guide stays off too: the next character also had one before it.
	first.command(Vocab.SET_HINTS, {"on": false})
	var third := SimScript.new()
	third.command(Vocab.NEW_CHARACTER, {"previous": first.export_code()})
	assert_false(third.hints_on())


func test_a_first_character_starts_with_hints_on() -> void:
	var sim := SimScript.new()
	H.walk_to(sim, H.OUTSIDE)
	assert_true(sim.command(Vocab.NEW_CHARACTER, {"previous": ""})["ok"])
	assert_true(sim.hints_on())
	assert_eq(sim.hint(), "walk", "a new character starts the path over")
	assert_eq(sim.command(Vocab.NEW_CHARACTER, {"previous": 7})["reason"], Vocab.REASON_BAD_ARGS)
