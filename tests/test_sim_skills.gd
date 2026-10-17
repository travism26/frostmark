## The skills: mining and fishing gather with their tools, cooking works at any fire and
## burns less with level, smithing turns ore into bronze and refuses iron.
extends "res://tests/run.gd".TestCase

const H := preload("res://tests/sim_helpers.gd")
const SimScript := preload("res://sim/sim.gd")
const Vocab := preload("res://sim/vocab.gd")


## A new character with `tool` in the tool slot (and nothing else), standing at the outpost.
func _with_tool(tool: String) -> Sim:
	var sim := SimScript.new()
	var snap := sim.snapshot()
	snap["inventory"]["equipment"]["tool"] = tool
	sim.restore(snap)
	return sim


func _set_level(sim: Sim, skill: String, level: int) -> void:
	var snap := sim.snapshot()
	snap["skills"][skill] = {"xp": SkillTable.xp_for_level(level), "level": level}
	sim.restore(snap)


func _gather_all(sim: Sim, id: String) -> Array[Dictionary]:
	var result := sim.command(Vocab.GATHER, {"object_id": id})
	assert_true(result["ok"], "%s: %s" % [id, result["reason"]])
	return H.run_until_idle(sim, 400)


func test_the_skills_panel_has_all_eight() -> void:
	assert_eq(SkillTable.NAMES, [
		SkillTable.WOODCUTTING, SkillTable.MINING, SkillTable.FISHING, SkillTable.COOKING,
		SkillTable.SMITHING, SkillTable.MELEE, SkillTable.RANGED, SkillTable.MAGIC,
	])


func test_mining_a_rock_yields_ore_and_mining_xp() -> void:
	var sim := _with_tool("wooden_pickaxe")
	var events := _gather_all(sim, "copper_1")
	var yield_count := int(WorldDef.NODE_KINDS[WorldDef.KIND_COPPER_ROCK]["yield"])
	assert_eq(H.pack_count(sim, "copper_ore"), yield_count)
	assert_eq(int(sim.state["skills"]["mining"]["xp"]), yield_count * int(WorldDef.NODE_KINDS[WorldDef.KIND_COPPER_ROCK]["xp"]))
	assert_eq(int(sim.state["skills"]["woodcutting"]["xp"]), 0, "only mining trains")
	var gathered := H.of_kind(events, Vocab.EV_GATHERED)
	assert_eq(gathered[0]["skill"], SkillTable.MINING)
	assert_eq(H.of_kind(events, Vocab.EV_NODE_DEPLETED).size(), 1)
	_gather_all(sim, "tin_1")
	assert_eq(H.pack_count(sim, "tin_ore"), int(WorldDef.NODE_KINDS[WorldDef.KIND_TIN_ROCK]["yield"]))


func test_mining_needs_a_pickaxe() -> void:
	var sim := SimScript.new()  # a new character carries only the axe
	assert_eq(sim.command(Vocab.GATHER, {"object_id": "copper_1"})["reason"], Vocab.REASON_NO_TOOL)
	assert_eq(sim.command(Vocab.INTERACT, {"object_id": "tin_2"})["reason"], Vocab.REASON_NO_TOOL)


func test_iron_needs_mining_level_and_a_bronze_pickaxe() -> void:
	var sim := _with_tool("wooden_pickaxe")
	assert_eq(sim.command(Vocab.GATHER, {"object_id": "iron_1"})["reason"], Vocab.REASON_TOOL_TOO_WEAK, "wood will not cut iron")
	sim = _with_tool("bronze_pickaxe")
	assert_eq(sim.command(Vocab.GATHER, {"object_id": "iron_1"})["reason"], Vocab.REASON_LEVEL_TOO_LOW)
	_set_level(sim, SkillTable.MINING, int(WorldDef.NODE_KINDS[WorldDef.KIND_IRON_ROCK]["level"]))
	H.place(sim, [38.5, 9.5])
	_gather_all(sim, "iron_1")
	assert_eq(H.pack_count(sim, "iron_ore"), int(WorldDef.NODE_KINDS[WorldDef.KIND_IRON_ROCK]["yield"]))


func test_fishing_needs_a_rod_and_yields_raw_fish() -> void:
	var sim := SimScript.new()
	assert_eq(sim.command(Vocab.GATHER, {"object_id": "fishing_hole"})["reason"], Vocab.REASON_NO_TOOL)
	sim = _with_tool("fishing_rod")
	_gather_all(sim, "fishing_hole")
	var yield_count := int(WorldDef.NODE_KINDS[WorldDef.KIND_FISHING_HOLE]["yield"])
	assert_eq(H.pack_count(sim, "raw_fish"), yield_count)
	assert_eq(int(sim.state["skills"]["fishing"]["xp"]), yield_count * int(WorldDef.NODE_KINDS[WorldDef.KIND_FISHING_HOLE]["xp"]))


func test_the_ice_hole_and_frost_pines_need_levels() -> void:
	var sim := _with_tool("fishing_rod")
	assert_eq(sim.command(Vocab.GATHER, {"object_id": "ice_hole"})["reason"], Vocab.REASON_LEVEL_TOO_LOW)
	_set_level(sim, SkillTable.FISHING, 3)
	assert_true(sim.command(Vocab.GATHER, {"object_id": "ice_hole"})["ok"])
	sim = SimScript.new()
	assert_eq(sim.command(Vocab.GATHER, {"object_id": "frost_pine_1"})["reason"], Vocab.REASON_LEVEL_TOO_LOW)
	_set_level(sim, SkillTable.WOODCUTTING, 3)
	assert_true(sim.command(Vocab.GATHER, {"object_id": "frost_pine_1"})["ok"])


func test_a_better_tool_gathers_faster_and_surer() -> void:
	assert_true(Sim.gather_ticks(1, 1) < Sim.gather_ticks(1, 0), "bronze is quicker than wood")
	assert_true(Sim.gather_chance(1, 1) > Sim.gather_chance(1, 0), "and surer")
	assert_true(Sim.gather_ticks(1, 2) <= Sim.gather_ticks(1, 1))
	assert_true(Sim.gather_ticks(9, 0) < Sim.gather_ticks(1, 0), "levels speed gathering too")
	assert_true(Sim.gather_chance(9, 0) > Sim.gather_chance(1, 0))
	var wooden := _with_tool("wooden_axe")
	var bronze := _with_tool("bronze_axe")
	var ticks := []
	for sim in [wooden, bronze]:
		sim.command(Vocab.GATHER, {"object_id": "tree_3"})
		var n := 0
		while H.pack_count(sim, "logs") < 4 and n < 400:
			sim.step()
			n += 1
		ticks.append(n)
	assert_true(ticks[1] < ticks[0], "a bronze axe fells a pine sooner (%d vs %d ticks)" % [ticks[1], ticks[0]])


# --- Cooking ------------------------------------------------------------------------------

## Beside the outpost fire with `entries` in the pack.
func _at_the_fire(entries: Array) -> Sim:
	var sim := SimScript.new()
	sim.command(Vocab.INTERACT, {"object_id": "fire"})
	H.run_until_idle(sim, 40)
	H.set_pack(sim, entries)
	sim.drain_events()
	return sim


func test_cooking_at_the_fire_turns_raw_fish_into_cooked_fish() -> void:
	var sim := _at_the_fire([{"item": "raw_fish", "count": 6}])
	_set_level(sim, SkillTable.COOKING, 20)  # past the burn range
	assert_true(sim.command(Vocab.COOK, {"index": 0})["ok"])
	var events := H.run(sim, 6 * Sim.COOK_TICKS + 2)
	assert_eq(H.pack_count(sim, "raw_fish"), 0)
	assert_eq(H.pack_count(sim, "cooked_fish"), 6)
	var cooked := H.of_kind(events, Vocab.EV_COOKED)
	assert_eq(cooked.size(), 6)
	assert_false(cooked[0]["burnt"])
	var xp := int(RecipeTable.cooking("raw_fish")["xp"])
	assert_eq(int(sim.state["skills"]["cooking"]["xp"]), SkillTable.xp_for_level(20) + 6 * xp)
	var stopped := H.of_kind(events, Vocab.EV_ACTIVITY_STOPPED)
	assert_eq(stopped[-1]["reason"], Vocab.REASON_NOTHING_LEFT)


func test_cooking_at_level_one_burns_some_and_trains_on_the_rest() -> void:
	var sim := _at_the_fire([{"item": "raw_fish", "count": 10}, {"item": "raw_fish", "count": 10}])
	sim.command(Vocab.COOK, {"index": 0})
	var events := H.run(sim, 20 * Sim.COOK_TICKS + 2)
	var cooked := H.of_kind(events, Vocab.EV_COOKED)
	assert_eq(cooked.size(), 20, "the whole kind is cooked, both stacks")
	var burnt := 0
	for e in cooked:
		burnt += 1 if e["burnt"] else 0
	assert_true(burnt > 0, "a novice burns some")
	assert_true(burnt < 20, "but not all")
	assert_eq(H.pack_count(sim, "cooked_fish"), 20 - burnt, "burnt fish is lost")
	assert_eq(int(sim.state["skills"]["cooking"]["xp"]), (20 - burnt) * int(RecipeTable.cooking("raw_fish")["xp"]), "only good food trains")


func test_the_burn_chance_falls_with_level() -> void:
	var last := 101
	for level in range(1, 15):
		var chance := Sim.burn_chance("raw_fish", level)
		assert_true(chance <= last, "level %d burns no more than level %d" % [level, level - 1])
		last = chance
	assert_true(Sim.burn_chance("raw_fish", 1) > Sim.burn_chance("raw_fish", 5))
	assert_eq(Sim.burn_chance("raw_fish", 20), 0, "a master never burns fish")
	assert_true(Sim.burn_chance("raw_trout", 3) > Sim.burn_chance("raw_fish", 3), "trout is harder")


func test_cooking_needs_a_fire_and_raw_food() -> void:
	var sim := SimScript.new()
	H.place(sim, H.OUTSIDE)
	H.set_pack(sim, [{"item": "raw_fish", "count": 2}, {"item": "logs", "count": 3}, {"item": "raw_trout", "count": 1}])
	assert_eq(sim.command(Vocab.COOK, {"index": 0})["reason"], Vocab.REASON_NOT_AT_FIRE)
	assert_eq(sim.command(Vocab.COOK, {"index": 1})["reason"], Vocab.REASON_NOT_COOKABLE)
	assert_eq(sim.command(Vocab.COOK, {"index": 5})["reason"], Vocab.REASON_EMPTY_SLOT)
	sim.command(Vocab.LIGHT_FIRE)
	H.run(sim, 1)
	assert_true(sim.command(Vocab.COOK, {"index": 0})["ok"], "any fire will do, a field fire too")
	assert_eq(sim.command(Vocab.COOK, {"index": 2})["reason"], Vocab.REASON_LEVEL_TOO_LOW, "trout needs cooking level 3")


func test_walking_off_stops_cooking() -> void:
	var sim := _at_the_fire([{"item": "raw_fish", "count": 5}])
	sim.command(Vocab.COOK, {"index": 0})
	H.run(sim, Sim.COOK_TICKS)
	sim.command(Vocab.MOVE_TO, {"pos": [-6.5, 5.5]})
	var events := H.run(sim, 10)
	assert_true(H.of_kind(events, Vocab.EV_COOKED).is_empty(), "no more cooking once walking")
	assert_eq(H.pack_count(sim, "raw_fish"), 4)


func test_raw_fish_is_food_but_worse_than_cooked() -> void:
	assert_true(ItemTable.heal("raw_fish") > 0, "edible")
	assert_true(ItemTable.heal("raw_fish") < ItemTable.heal("cooked_fish"))
	assert_true(ItemTable.heal("raw_trout") < ItemTable.heal("cooked_trout"))
	assert_true(ItemTable.heal("cooked_trout") > ItemTable.heal("cooked_fish"), "the better fish heals more")


# --- Smithing -----------------------------------------------------------------------------

func _at_workbench(entries: Array, upgrades: Array = []) -> Sim:
	var sim := SimScript.new()
	H.patch(sim, {"upgrades": upgrades})
	sim.command(Vocab.INTERACT, {"object_id": "workbench"})
	H.run_until_idle(sim, 60)
	H.set_pack(sim, entries)
	sim.drain_events()
	return sim


func test_wooden_tools_come_from_the_workbench_and_train_smithing() -> void:
	var sim := _at_workbench([{"item": "logs", "count": 10}])
	for id in ["wooden_pickaxe", "fishing_rod"]:
		assert_true(sim.command(Vocab.SMITH, {"recipe": id})["ok"], id)
		H.run(sim, 1)
	assert_eq(H.pack_count(sim, "wooden_pickaxe"), 1)
	assert_eq(H.pack_count(sim, "fishing_rod"), 1)
	var xp := int(RecipeTable.get_recipe("wooden_pickaxe")["xp"]) + int(RecipeTable.get_recipe("fishing_rod")["xp"])
	assert_eq(int(sim.state["skills"]["smithing"]["xp"]), xp)


func test_bronze_needs_the_forge() -> void:
	var sim := _at_workbench([{"item": "copper_ore", "count": 2}, {"item": "tin_ore", "count": 2}])
	assert_eq(sim.command(Vocab.SMITH, {"recipe": "bronze_bar"})["reason"], Vocab.REASON_UPGRADE_MISSING)
	sim = _at_workbench([{"item": "copper_ore", "count": 2}, {"item": "tin_ore", "count": 2}], ["forge"])
	assert_true(sim.command(Vocab.SMITH, {"recipe": "bronze_bar"})["ok"])
	var events := H.run(sim, 1)
	assert_eq(H.pack_count(sim, "bronze_bar"), 1)
	assert_eq(H.pack_count(sim, "copper_ore"), 1)
	assert_eq(H.pack_count(sim, "tin_ore"), 1)
	assert_eq(H.of_kind(events, Vocab.EV_CRAFTED)[0]["item"], "bronze_bar")
	assert_eq(int(sim.state["skills"]["smithing"]["xp"]), int(RecipeTable.get_recipe("bronze_bar")["xp"]))


func test_bronze_gear_needs_smithing_level() -> void:
	var sim := _at_workbench([{"item": "bronze_bar", "count": 4}, {"item": "logs", "count": 2}], ["forge"])
	assert_eq(sim.command(Vocab.SMITH, {"recipe": "bronze_sword"})["reason"], Vocab.REASON_LEVEL_TOO_LOW)
	_set_level(sim, SkillTable.SMITHING, 2)
	assert_true(sim.command(Vocab.SMITH, {"recipe": "bronze_sword"})["ok"])
	H.run(sim, 1)
	assert_eq(H.pack_count(sim, "bronze_sword"), 1)


func test_smithing_refuses_iron() -> void:
	var sim := _at_workbench([{"item": "iron_ore", "count": 10}], ["forge"])
	_set_level(sim, SkillTable.SMITHING, 50)
	assert_eq(sim.command(Vocab.SMITH, {"recipe": "iron_bar"})["reason"], Vocab.REASON_TIER_CAPPED)
	H.run(sim, 1)
	assert_eq(H.pack_count(sim, "iron_ore"), 10, "the ore is untouched")
	var capped := 0
	for id in RecipeTable.ids():
		if RecipeTable.get_recipe(id)["tier"] == ItemTable.TIER_IRON:
			capped += 1
			assert_eq(sim.command(Vocab.SMITH, {"recipe": id})["reason"], Vocab.REASON_TIER_CAPPED, id)
	assert_true(capped > 0, "the workbench lists iron, and refuses it")


func test_every_gathering_and_crafting_skill_feeds_the_next() -> void:
	# Gathering feeds crafting: every recipe input and every cooked dish comes from a node, a
	# recipe or ring one's loot.
	var sources := {"wolf_pelt": true, "arrows": true}
	for kind in WorldDef.NODE_KINDS:
		sources[WorldDef.NODE_KINDS[kind]["item"]] = true
	for id in RecipeTable.ids():
		sources[RecipeTable.get_recipe(id)["output"]["item"]] = true
	for id in RecipeTable.ids():
		for kind in RecipeTable.get_recipe(id)["inputs"]:
			assert_true(sources.has(kind), "%s's input %s can be had" % [id, kind])
	for raw in RecipeTable.COOKING:
		assert_true(sources.has(raw), "%s can be fished" % raw)
