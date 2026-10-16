## The workbench: recipes as data, crafting with the smith command.
extends "res://tests/run.gd".TestCase

const H := preload("res://tests/sim_helpers.gd")
const SimScript := preload("res://sim/sim.gd")
const Vocab := preload("res://sim/vocab.gd")


func _at_workbench(entries: Array) -> Sim:
	var sim := SimScript.new()
	sim.command(Vocab.INTERACT, {"object_id": "workbench"})
	H.run_until_idle(sim, 60)
	H.set_pack(sim, entries)
	sim.drain_events()
	return sim


func test_recipe_table_shape() -> void:
	for id in RecipeTable.ids():
		var r := RecipeTable.get_recipe(id)
		for key in ["inputs", "output", "skill", "level", "upgrade"]:
			assert_true(r.has(key), "%s has %s" % [id, key])
		assert_true(SkillTable.NAMES.has(r["skill"]))
		assert_true(ItemTable.has(r["output"]["item"]))


func test_craft_consumes_inputs_and_produces_output() -> void:
	var sim := _at_workbench([{"item": "logs", "count": 6}])
	var result := sim.command(Vocab.SMITH, {"recipe": "wooden_club"})
	assert_true(result["ok"], result["reason"])
	var events := H.run(sim, 1)
	var needed := int(RecipeTable.get_recipe("wooden_club")["inputs"]["logs"])
	assert_eq(H.pack_count(sim, "logs"), 6 - needed)
	assert_eq(H.pack_count(sim, "wooden_club"), 1)
	var crafted := H.of_kind(events, Vocab.EV_CRAFTED)
	assert_eq(crafted.size(), 1)
	assert_eq(crafted[0]["item"], "wooden_club")
	assert_eq(H.of_kind(events, Vocab.EV_SAVED)[0]["reason"], "craft", "crafting saves")


func test_craft_frees_the_input_slot_for_the_output() -> void:
	var full: Array = []
	for i in Sim.PACK_SLOTS:
		full.append({"item": "logs", "count": 4})
	var sim := _at_workbench(full)
	assert_true(sim.command(Vocab.SMITH, {"recipe": "wooden_club"})["ok"], "a spent stack makes room")
	H.run(sim, 1)
	assert_eq(H.pack_count(sim, "wooden_club"), 1)


func test_craft_needs_the_inputs() -> void:
	var sim := _at_workbench([{"item": "logs", "count": 1}])
	assert_eq(sim.command(Vocab.SMITH, {"recipe": "wooden_club"})["reason"], Vocab.REASON_MISSING_INPUTS)
	assert_eq(sim.command(Vocab.SMITH, {"recipe": "steel_sword"})["reason"], Vocab.REASON_UNKNOWN_RECIPE)


func test_craft_needs_the_workbench() -> void:
	var sim := SimScript.new()
	H.set_pack(sim, [{"item": "logs", "count": 6}])
	assert_eq(sim.command(Vocab.SMITH, {"recipe": "wooden_club"})["reason"], Vocab.REASON_NOT_AT_WORKBENCH, "at the spawn")
	H.walk_to(sim, H.OUTSIDE)
	assert_eq(sim.command(Vocab.SMITH, {"recipe": "wooden_club"})["reason"], Vocab.REASON_NOT_AT_WORKBENCH, "outside")
