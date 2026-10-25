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
		assert_true(r.has("tier"), "%s has a tier" % id)
		assert_true(r["tier"] == "" or ItemTable.TIERS.has(r["tier"]), "%s's tier is a gear tier or none" % id)


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



## At the workbench with `pack` in the pack and `stash` in the stash.
func _at_workbench_with_stash(pack: Array, stash: Array) -> Sim:
	var sim := _at_workbench(pack)
	var slots := Inventory.empty_slots(Sim.STASH_START_SLOTS)
	for e in stash:
		Inventory.add(slots, e["item"], int(e["count"]))
	H.patch(sim, {"stash": {"capacity": Sim.STASH_START_SLOTS, "slots": slots}})
	return sim


func test_craft_takes_the_inputs_from_the_stash_first() -> void:
	var sim := _at_workbench_with_stash([{"item": "logs", "count": 3}], [{"item": "logs", "count": 2}])
	assert_true(sim.command(Vocab.SMITH, {"recipe": "wooden_club"})["ok"], "the stash and the pack make 4 logs")
	H.run(sim, 1)
	assert_eq(H.stash_count(sim, "logs"), 0, "the stash pays first")
	assert_eq(H.pack_count(sim, "logs"), 1, "the pack pays the rest")
	assert_eq(H.pack_count(sim, "wooden_club"), 1, "the output goes to the pack")
	assert_eq(H.stash_count(sim, "wooden_club"), 0)


func test_craft_from_the_stash_alone_leaves_the_pack() -> void:
	var sim := _at_workbench_with_stash([{"item": "logs", "count": 3}], [{"item": "logs", "count": 6}])
	assert_true(sim.command(Vocab.SMITH, {"recipe": "wooden_club"})["ok"])
	H.run(sim, 1)
	assert_eq(H.stash_count(sim, "logs"), 2)
	assert_eq(H.pack_count(sim, "logs"), 3, "the pack is untouched while the stash has enough")


func test_craft_from_the_stash_still_needs_room_in_the_pack() -> void:
	var full: Array = []
	for i in Sim.PACK_SLOTS:
		full.append({"item": "copper_ore", "count": 1})
	var sim := _at_workbench_with_stash(full, [{"item": "logs", "count": 4}])
	assert_eq(sim.command(Vocab.SMITH, {"recipe": "wooden_club"})["reason"], Vocab.REASON_PACK_FULL)
	assert_eq(H.stash_count(sim, "logs"), 4, "nothing is taken")


func test_craft_room_is_checked_once_the_inputs_are_out() -> void:
	var full: Array = []
	for i in Sim.PACK_SLOTS - 1:
		full.append({"item": "copper_ore", "count": 1})
	full.append({"item": "logs", "count": 1})
	var sim := _at_workbench_with_stash(full, [{"item": "logs", "count": 3}])
	assert_true(sim.command(Vocab.SMITH, {"recipe": "wooden_club"})["ok"], "the last pack log frees its slot")
	H.run(sim, 1)
	assert_eq(H.pack_count(sim, "wooden_club"), 1)
	assert_eq(H.stash_count(sim, "logs"), 0)


func test_smithing_count_sums_the_stash_and_the_pack_inside() -> void:
	var sim := _at_workbench_with_stash([{"item": "logs", "count": 3}], [{"item": "logs", "count": 2}])
	assert_eq(sim.smithing_count("logs"), 5)
	H.walk_to(sim, H.OUTSIDE)
	assert_eq(sim.smithing_count("logs"), 3, "outside the walls only the pack counts")

func test_craft_needs_the_inputs() -> void:
	var sim := _at_workbench([{"item": "logs", "count": 1}])
	assert_eq(sim.command(Vocab.SMITH, {"recipe": "wooden_club"})["reason"], Vocab.REASON_MISSING_INPUTS)
	assert_eq(sim.command(Vocab.SMITH, {"recipe": "mithril_sword"})["reason"], Vocab.REASON_UNKNOWN_RECIPE)


func test_craft_needs_the_workbench() -> void:
	var sim := SimScript.new()
	H.set_pack(sim, [{"item": "logs", "count": 6}])
	assert_eq(sim.command(Vocab.SMITH, {"recipe": "wooden_club"})["reason"], Vocab.REASON_NOT_AT_WORKBENCH, "at the spawn")
	H.walk_to(sim, H.OUTSIDE)
	assert_eq(sim.command(Vocab.SMITH, {"recipe": "wooden_club"})["reason"], Vocab.REASON_NOT_AT_WORKBENCH, "outside")


# --- Fur pieces ----------------------------------------------------------------------------

## The three fur pieces as the ticket gives them (#141): wolf pelts and xp, all at smithing 3.
const FUR := {"fur_hood": [2, 10], "fur_coat": [3, 20], "fur_legs": [2, 10]}


## At the workbench with `upgrades` built, at smithing `level`, `pack` in the pack and `stash`
## in the stash.
func _at_workbench_for_fur(upgrades: Array, level: int, pack: Array, stash: Array = []) -> Sim:
	var sim := _at_workbench_with_stash(pack, stash)
	var snap := sim.snapshot()
	snap["upgrades"] = upgrades
	snap["skills"][SkillTable.SMITHING] = {"xp": SkillTable.xp_for_level(level), "level": level}
	sim.restore(snap)
	sim.drain_events()
	return sim


func test_fur_pieces_are_tierless_wolf_pelt_recipes_at_smithing_3() -> void:
	for id in FUR:
		var r := RecipeTable.get_recipe(id)
		assert_eq(r["inputs"], {"wolf_pelt": FUR[id][0]}, "%s's pelts" % id)
		assert_eq(int(r["xp"]), FUR[id][1], "%s's xp" % id)
		assert_eq(int(r["level"]), 3, "%s's smithing level" % id)
		assert_eq(r["skill"], SkillTable.SMITHING)
		assert_eq(r["upgrade"], "armoury")
		assert_eq(r["tier"], "", "%s has no tier" % id)
		assert_eq(r["output"], {"item": id, "count": 1})
		assert_eq(ItemTable.tier(id), "", "the %s itself has no tier" % id)
		assert_true(UpgradeTable.get_upgrade("armoury")["effects"]["recipes"].has(id), "the Armoury unlocks %s" % id)


func test_fur_pieces_are_refused_before_the_armoury_and_made_after_it() -> void:
	for id in FUR:
		var pelts: int = FUR[id][0]
		var sim := _at_workbench_for_fur(["forge"], 3, [{"item": "wolf_pelt", "count": pelts}])
		assert_eq(sim.command(Vocab.SMITH, {"recipe": id})["reason"], Vocab.REASON_UPGRADE_MISSING, "%s needs the Armoury" % id)
		sim = _at_workbench_for_fur(["forge", "armoury"], 3, [{"item": "wolf_pelt", "count": pelts}])
		var xp_before := int(sim.state["skills"][SkillTable.SMITHING]["xp"])
		assert_true(sim.command(Vocab.SMITH, {"recipe": id})["ok"], "%s is made after the Armoury" % id)
		var events := H.run(sim, 1)
		assert_eq(H.of_kind(events, Vocab.EV_CRAFTED)[0]["item"], id)
		assert_eq(H.pack_count(sim, id), 1, "one %s made" % id)
		assert_eq(H.pack_count(sim, "wolf_pelt"), 0, "%s took its %d pelts" % [id, pelts])
		assert_eq(int(sim.state["skills"][SkillTable.SMITHING]["xp"]) - xp_before, FUR[id][1], "%s grants its xp" % id)


func test_fur_pieces_take_their_pelts_from_the_stash_then_the_pack() -> void:
	var sim := _at_workbench_for_fur(["forge", "armoury"], 3, [{"item": "wolf_pelt", "count": 2}], [{"item": "wolf_pelt", "count": 2}])
	assert_true(sim.command(Vocab.SMITH, {"recipe": "fur_coat"})["ok"], "the stash and the pack make 3 pelts")
	H.run(sim, 1)
	assert_eq(H.stash_count(sim, "wolf_pelt"), 0, "the stash pays first")
	assert_eq(H.pack_count(sim, "wolf_pelt"), 1, "the pack pays the rest")
	assert_eq(H.pack_count(sim, "fur_coat"), 1)


func test_fur_pieces_need_smithing_3() -> void:
	for id in FUR:
		var sim := _at_workbench_for_fur(["forge", "armoury"], 2, [{"item": "wolf_pelt", "count": 3}])
		assert_eq(sim.command(Vocab.SMITH, {"recipe": id})["reason"], Vocab.REASON_LEVEL_TOO_LOW, "%s at smithing 2" % id)


func test_fur_is_never_refused_for_the_smithing_cap() -> void:
	var sim := _at_workbench_for_fur(["forge", "armoury"], 3, [{"item": "wolf_pelt", "count": 3}])
	assert_eq(sim.smithing_cap(), ItemTable.TIER_BRONZE, "the starting cap")
	for id in FUR:
		assert_eq(sim.check(Vocab.SMITH, {"recipe": id}), "", "%s at the bronze cap" % id)
	H.patch(sim, {"upgrades": ["forge", "armoury", "bloomery", "ring_two_gate", "blast_furnace"]})
	for id in FUR:
		assert_eq(sim.check(Vocab.SMITH, {"recipe": id}), "", "%s at the steel cap" % id)
