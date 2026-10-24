## The outpost tech tree: build pays from the stash and, inside the outpost, the pack; prerequisites and locks are enforced,
## and each built upgrade applies its effect. Also the gear tiers it unlocks.
extends "res://tests/run.gd".TestCase

const H := preload("res://tests/sim_helpers.gd")
const SimScript := preload("res://sim/sim.gd")
const Vocab := preload("res://sim/vocab.gd")
const WorldDefScript := preload("res://sim/world_def.gd")


## A new character in the outpost whose stash holds `entries` and who has built `upgrades`.
func _with_stash(entries: Array, upgrades: Array = [], capacity := Sim.STASH_START_SLOTS) -> Sim:
	var sim := SimScript.new()
	var slots: Array = []
	slots.resize(capacity)
	for i in entries.size():
		slots[i] = entries[i]
	H.patch(sim, {"stash": {"capacity": capacity, "slots": slots}, "upgrades": upgrades})
	sim.drain_events()
	return sim


func test_the_table_is_well_formed() -> void:
	for id in UpgradeTable.ids():
		var u := UpgradeTable.get_upgrade(id)
		for key in ["label", "cost", "requires", "effects", "locked"]:
			assert_true(u.has(key), "%s has %s" % [id, key])
		for kind in u["cost"]:
			assert_true(ItemTable.has(kind), "%s costs a real item, %s" % [id, kind])
		for need in u["requires"]:
			assert_true(UpgradeTable.has(need), "%s requires a real upgrade, %s" % [id, need])
	for id in RecipeTable.ids():
		var needs: String = RecipeTable.get_recipe(id)["upgrade"]
		assert_true(needs == "" or UpgradeTable.has(needs), "%s is unlocked by a real upgrade" % id)


func test_the_first_playable_subset() -> void:
	var stash := 0
	var gate := false
	var waystones := false
	for id in UpgradeTable.ids():
		var u := UpgradeTable.get_upgrade(id)
		stash += int(u["effects"].get("stash", 0))
		gate = gate or u["effects"].get("ring_gate", "") == "ring_two_gate"
		waystones = waystones or u["effects"].has("waystones")
		assert_eq(u["locked"], "", "%s can be built" % id)
	assert_true(stash > 0, "stash capacity upgrades")
	assert_true(gate, "the ring-two gate upgrade")
	assert_true(waystones, "the waystone upgrade")


func test_a_met_upgrade_is_built_from_the_stash_and_applies() -> void:
	var sim := _with_stash([{"item": "logs", "count": 10}, {"item": "wooden_bow", "count": 1}])
	var cost := int(UpgradeTable.get_upgrade("stash_shelves")["cost"]["logs"])
	assert_true(sim.command(Vocab.BUILD, {"upgrade": "stash_shelves"})["ok"])
	var events := H.run(sim, 1)
	assert_eq(sim.state["upgrades"], ["stash_shelves"])
	assert_eq(H.stash_count(sim, "logs"), 10 - cost, "paid out of the stash")
	assert_eq(H.stash_count(sim, "wooden_bow"), 1, "the rest untouched")
	var more := int(UpgradeTable.get_upgrade("stash_shelves")["effects"]["stash"])
	assert_eq(int(sim.state["stash"]["capacity"]), Sim.STASH_START_SLOTS + more)
	assert_eq((sim.state["stash"]["slots"] as Array).size(), Sim.STASH_START_SLOTS + more, "the new slots are there")
	var built := H.of_kind(events, Vocab.EV_BUILT)
	assert_eq(built.size(), 1)
	assert_eq(built[0]["upgrade"], "stash_shelves")
	assert_eq(H.of_kind(events, Vocab.EV_SAVED)[0]["reason"], "build", "building is a save point")
	assert_eq(sim.command(Vocab.BUILD, {"upgrade": "stash_shelves"})["reason"], Vocab.REASON_ALREADY_BUILT)


func test_an_upgrade_with_unmet_prerequisites_is_refused() -> void:
	var lots := [
		{"item": "logs", "count": 10}, {"item": "logs", "count": 10}, {"item": "bronze_bar", "count": 10},
		{"item": "wolf_pelt", "count": 5}, {"item": "iron_ore", "count": 10},
	]
	var sim := _with_stash(lots)
	assert_eq(sim.command(Vocab.BUILD, {"upgrade": "armoury"})["reason"], Vocab.REASON_UPGRADE_MISSING, "needs the forge")
	assert_eq(sim.command(Vocab.BUILD, {"upgrade": "stash_cellar"})["reason"], Vocab.REASON_UPGRADE_MISSING, "needs the shelves")
	assert_eq(sim.command(Vocab.BUILD, {"upgrade": "ring_two_gate"})["reason"], Vocab.REASON_UPGRADE_MISSING)
	H.run(sim, 1)
	assert_eq(sim.state["upgrades"], [], "nothing was built")
	assert_eq(H.stash_count(sim, "logs"), 20, "nothing was paid")
	sim = _with_stash(lots, ["forge"])
	assert_true(sim.command(Vocab.BUILD, {"upgrade": "armoury"})["ok"], "with the forge built it goes ahead")


func test_the_status_query_lists_every_upgrade_in_table_order() -> void:
	var sim := _with_stash([])
	assert_eq(sim.upgrade_status().keys(), UpgradeTable.ids())


func test_a_built_upgrade_reports_built() -> void:
	var sim := _with_stash([], ["stash_shelves"], Sim.STASH_START_SLOTS + 4)
	var s: Dictionary = sim.upgrade_status()["stash_shelves"]
	assert_eq(s["status"], Vocab.UPGRADE_BUILT)
	assert_eq(s["reason"], Vocab.REASON_ALREADY_BUILT)


func test_an_affordable_unlocked_upgrade_can_be_built_now() -> void:
	var sim := _with_stash([{"item": "logs", "count": 9}])
	var s: Dictionary = sim.upgrade_status()["stash_shelves"]
	assert_eq(s["status"], Vocab.UPGRADE_CAN_BUILD)
	assert_eq(s["requires"], [])
	assert_eq(s["short"], [])
	assert_eq(s["cost"], [{"item": "logs", "have": 9, "need": 8}], "every cost item with what the stash holds")
	assert_eq(s["reason"], "", "Build would be accepted")


func test_outside_the_outpost_only_the_stash_counts() -> void:
	var sim := _with_stash([{"item": "logs", "count": 8}])
	H.place(sim, H.OUTSIDE)
	var s: Dictionary = sim.upgrade_status()["stash_shelves"]
	assert_eq(s["status"], Vocab.UPGRADE_CAN_BUILD, "a stash that covers the cost can build from anywhere")
	assert_eq(s["reason"], Vocab.REASON_NOT_IN_OUTPOST, "but Build is refused out there")
	sim = _with_stash([{"item": "logs", "count": 3}])
	H.set_pack(sim, [{"item": "logs", "count": 10}])
	H.place(sim, H.OUTSIDE)
	s = sim.upgrade_status()["stash_shelves"]
	assert_eq(s["status"], Vocab.UPGRADE_NOT_YET, "carried logs are not safe yet")
	assert_eq(s["cost"], [{"item": "logs", "have": 3, "need": 8}], "the pack is not counted")
	assert_eq(s["short"], [{"item": "logs", "have": 3, "need": 8}])


func test_inside_the_outpost_the_status_counts_the_stash_and_the_pack() -> void:
	var sim := _with_stash([{"item": "logs", "count": 3}])
	H.set_pack(sim, [{"item": "logs", "count": 5}, {"item": "copper_ore", "count": 2}])
	var shelves: Dictionary = sim.upgrade_status()["stash_shelves"]
	assert_eq(shelves["status"], Vocab.UPGRADE_CAN_BUILD)
	assert_eq(shelves["cost"], [{"item": "logs", "have": 8, "need": 8}], "3 stashed and 5 carried")
	assert_eq(shelves["short"], [])
	assert_eq(shelves["reason"], "", "Build would be accepted")
	var forge: Dictionary = sim.upgrade_status()["forge"]
	assert_eq(forge["short"], [{"item": "copper_ore", "have": 2, "need": 3}, {"item": "tin_ore", "have": 0, "need": 3}])
	assert_eq(forge["reason"], Vocab.REASON_MISSING_INPUTS)


func test_a_build_is_paid_partly_from_the_pack() -> void:
	var sim := _with_stash([{"item": "logs", "count": 3}, {"item": "wooden_bow", "count": 1}])
	H.set_pack(sim, [{"item": "logs", "count": 7}, {"item": "copper_ore", "count": 2}])
	assert_eq(sim.check(Vocab.BUILD, {"upgrade": "stash_shelves"}), "")
	assert_true(sim.command(Vocab.BUILD, {"upgrade": "stash_shelves"})["ok"])
	var events := H.run(sim, 1)
	assert_eq(sim.state["upgrades"], ["stash_shelves"])
	assert_eq(H.of_kind(events, Vocab.EV_BUILT).size(), 1)
	assert_eq(H.stash_count(sim, "logs"), 0, "the stash's 3 logs went first")
	assert_eq(H.pack_count(sim, "logs"), 2, "then 5 of the pack's 7")
	assert_eq(H.stash_count(sim, "wooden_bow"), 1, "the rest untouched")
	assert_eq(H.pack_count(sim, "copper_ore"), 2)


func test_a_build_pays_from_the_stash_before_the_pack() -> void:
	var sim := _with_stash([{"item": "logs", "count": 10}])
	H.set_pack(sim, [{"item": "logs", "count": 10}])
	assert_true(sim.command(Vocab.BUILD, {"upgrade": "stash_shelves"})["ok"])
	H.run(sim, 1)
	assert_eq(H.stash_count(sim, "logs"), 2, "the whole cost came out of the stash")
	assert_eq(H.pack_count(sim, "logs"), 10, "the pack was not touched")


func test_a_short_cost_reports_what_is_held_and_needed() -> void:
	var sim := _with_stash([{"item": "logs", "count": 10}, {"item": "copper_ore", "count": 1}])
	var s: Dictionary = sim.upgrade_status()["forge"]
	assert_eq(s["status"], Vocab.UPGRADE_NOT_YET)
	assert_eq(s["requires"], [])
	assert_eq(s["short"], [{"item": "copper_ore", "have": 1, "need": 3}, {"item": "tin_ore", "have": 0, "need": 3}])
	assert_eq(s["reason"], Vocab.REASON_MISSING_INPUTS)


func test_an_unmet_prerequisite_is_named() -> void:
	var lots := [{"item": "logs", "count": 10}, {"item": "logs", "count": 10}, {"item": "bronze_bar", "count": 10}]
	var sim := _with_stash(lots)
	var s: Dictionary = sim.upgrade_status()["stash_cellar"]
	assert_eq(s["status"], Vocab.UPGRADE_NOT_YET, "affordable but the shelves are not built")
	assert_eq(s["requires"], ["stash_shelves"])
	assert_eq(s["short"], [])
	assert_eq(s["reason"], Vocab.REASON_UPGRADE_MISSING)
	var winch: Dictionary = sim.upgrade_status()["ring_two_gate"]
	assert_eq(winch["requires"], ["armoury"])
	assert_eq(winch["short"], [
		{"item": "iron_ore", "have": 0, "need": 12}, {"item": "wolf_pelt", "have": 0, "need": 5},
	], "missing prerequisites and short items together")
	var built := _with_stash(lots, ["stash_shelves"], Sim.STASH_START_SLOTS + 4)
	assert_eq(built.upgrade_status()["stash_cellar"]["status"], Vocab.UPGRADE_CAN_BUILD, "once the shelves stand")


func test_the_status_query_changes_nothing() -> void:
	var sim := _with_stash([{"item": "logs", "count": 8}, {"item": "copper_ore", "count": 3}])
	var before := sim.snapshot()
	sim.upgrade_status()
	assert_eq(sim.snapshot(), before)
	assert_eq(sim.drain_events(), [], "no events")
	var statuses := sim.upgrade_status()
	statuses["stash_shelves"]["cost"][0]["have"] = 99
	assert_eq(sim.upgrade_status()["stash_shelves"]["cost"][0]["have"], 8, "a fresh answer each time")


## Walks `sim` out of the gate with `pack` and back in; the one `banked` event.
func _bank(sim: Sim, pack: Array) -> Dictionary:
	H.walk_to(sim, H.OUTSIDE)
	H.set_pack(sim, pack)
	var banked := H.of_kind(H.walk_to(sim, [0.5, 6.5]), Vocab.EV_BANKED)
	assert_eq(banked.size(), 1, "one banked event")
	return banked[0] if not banked.is_empty() else {}


func test_a_bank_that_unlocks_one_upgrade_names_it() -> void:
	var sim := _with_stash([{"item": "logs", "count": 4}])
	var banked := _bank(sim, [{"item": "logs", "count": 4}])
	assert_eq(banked["newly_affordable"], ["stash_shelves"], "8 logs now pay for the shelves")


func test_a_bank_that_unlocks_several_lists_them_in_table_order() -> void:
	var sim := _with_stash([])
	var banked := _bank(sim, [
		{"item": "logs", "count": 10}, {"item": "copper_ore", "count": 3}, {"item": "tin_ore", "count": 3},
	])
	assert_eq(banked["newly_affordable"], ["stash_shelves", "forge"])


func test_a_bank_that_unlocks_nothing_has_an_empty_list() -> void:
	var sim := _with_stash([])
	assert_eq(_bank(sim, [{"item": "logs", "count": 3}])["newly_affordable"], [], "still short of the shelves")
	assert_eq(_bank(sim, [])["newly_affordable"], [], "an empty pack changes nothing")
	_bank(sim, [{"item": "logs", "count": 5}])
	assert_eq(_bank(sim, [{"item": "logs", "count": 2}])["newly_affordable"], [], "the shelves were affordable already")


func test_a_bank_whose_overflow_completes_a_cost_names_it() -> void:
	var slots: Array = []
	for i in Sim.STASH_START_SLOTS:
		slots.append({"item": "wooden_bow", "count": 1})
	var sim := _with_stash(slots)
	var banked := _bank(sim, [{"item": "logs", "count": 8}])
	assert_eq(banked["items"], [], "the stash is full")
	assert_eq(banked["overflow"], [{"item": "logs", "count": 8}])
	assert_eq(banked["newly_affordable"], ["stash_shelves"], "the overflow inside the walls pays for the shelves")
	assert_eq(sim.check(Vocab.BUILD, {"upgrade": "stash_shelves"}), "")


func test_the_newly_affordable_list_skips_built_and_unmet_upgrades() -> void:
	var sim := _with_stash([], ["forge"])
	var banked := _bank(sim, [
		{"item": "logs", "count": 10}, {"item": "copper_ore", "count": 3}, {"item": "tin_ore", "count": 3},
		{"item": "bronze_bar", "count": 2},
	])
	assert_eq(banked["newly_affordable"], ["stash_shelves"],
		"not the forge (built) nor the cellar (shelves unbuilt), though the stash covers both")


func test_building_needs_the_materials_and_the_outpost() -> void:
	var sim := _with_stash([{"item": "logs", "count": 3}])
	assert_eq(sim.command(Vocab.BUILD, {"upgrade": "stash_shelves"})["reason"], Vocab.REASON_MISSING_INPUTS)
	H.set_pack(sim, [{"item": "logs", "count": 4}])
	assert_eq(sim.command(Vocab.BUILD, {"upgrade": "stash_shelves"})["reason"], Vocab.REASON_MISSING_INPUTS, "3 stashed and 4 carried are still short")
	sim = _with_stash([{"item": "logs", "count": 10}])
	H.set_pack(sim, [{"item": "logs", "count": 10}])
	H.place(sim, H.OUTSIDE)
	assert_eq(sim.command(Vocab.BUILD, {"upgrade": "stash_shelves"})["reason"], Vocab.REASON_NOT_IN_OUTPOST)
	sim = _with_stash([{"item": "logs", "count": 3}])
	H.set_pack(sim, [{"item": "logs", "count": 10}])
	H.place(sim, H.OUTSIDE)
	assert_eq(sim.check(Vocab.BUILD, {"upgrade": "stash_shelves"}), Vocab.REASON_NOT_IN_OUTPOST, "the pack does not count out there")
	assert_eq(sim.command(Vocab.BUILD, {"upgrade": "palace"})["reason"], Vocab.REASON_UNKNOWN_UPGRADE)


func test_waystones_need_the_gate_winch_first() -> void:
	var lots := [{"item": "logs", "count": 10}, {"item": "bronze_bar", "count": 10}, {"item": "iron_ore", "count": 10}]
	var sim := _with_stash(lots, ["stash_shelves", "forge", "armoury"])
	assert_eq(sim.command(Vocab.BUILD, {"upgrade": "waystone"})["reason"], Vocab.REASON_UPGRADE_MISSING)
	sim = _with_stash(lots, ["stash_shelves", "forge", "armoury", "ring_two_gate"])
	assert_true(sim.command(Vocab.BUILD, {"upgrade": "waystone"})["ok"])


func test_the_vault_is_the_stash_lines_third_step() -> void:
	var u := UpgradeTable.get_upgrade("stash_vault")
	assert_eq(u["label"], "Stash vault")
	assert_eq(u["effects"], {"stash": 4})
	assert_eq(u["requires"], ["stash_cellar", "ring_two_gate"], "needs the cellar and the winch")
	assert_true(int(u["cost"].get("iron_ore", 0)) > 0, "costs iron ore")
	for kind in u["cost"]:
		assert_eq(RecipeTable.ids().has(kind), false, "%s is gathered, not smithed" % kind)
	assert_eq(u["locked"], "")


## The vault's cost as stash entries, split into full stacks.
func _vault_cost() -> Array:
	var cost: Dictionary = UpgradeTable.get_upgrade("stash_vault")["cost"]
	var entries: Array = []
	for kind in cost:
		var left := int(cost[kind])
		while left > 0:
			var n := mini(left, ItemTable.stack_size(kind))
			entries.append({"item": kind, "count": n})
			left -= n
	return entries


func test_the_vault_needs_the_cellar_and_the_winch() -> void:
	var cost: Dictionary = UpgradeTable.get_upgrade("stash_vault")["cost"]
	var entries := _vault_cost()
	var winch_no_cellar := ["stash_shelves", "forge", "armoury", "ring_two_gate"]
	var cellar_no_winch := ["stash_shelves", "stash_cellar", "forge", "armoury"]
	for built in [winch_no_cellar, cellar_no_winch]:
		var sim := _with_stash(entries, built, 16)
		assert_eq(sim.command(Vocab.BUILD, {"upgrade": "stash_vault"})["reason"], Vocab.REASON_UPGRADE_MISSING)
		H.run(sim, 1)
		assert_false((sim.state["upgrades"] as Array).has("stash_vault"), "not built from %s" % str(built))
		for kind in cost:
			assert_eq(H.stash_count(sim, kind), int(cost[kind]), "nothing paid")


func test_the_vault_pays_from_the_stash_and_grows_it_to_20() -> void:
	var cost: Dictionary = UpgradeTable.get_upgrade("stash_vault")["cost"]
	var entries := _vault_cost()
	entries.append({"item": "wooden_bow", "count": 1})
	var built := ["stash_shelves", "stash_cellar", "forge", "armoury", "ring_two_gate"]
	var sim := _with_stash(entries, built, 16)
	assert_true(sim.command(Vocab.BUILD, {"upgrade": "stash_vault"})["ok"])
	var events := H.run(sim, 1)
	assert_eq(H.of_kind(events, Vocab.EV_BUILT)[0]["upgrade"], "stash_vault")
	assert_eq(int(sim.state["stash"]["capacity"]), 20)
	assert_eq((sim.state["stash"]["slots"] as Array).size(), 20, "the new slots are there")
	for kind in cost:
		assert_eq(H.stash_count(sim, kind), 0, "the vault took its %s" % kind)
	assert_eq(H.stash_count(sim, "wooden_bow"), 1, "the rest untouched")


func test_the_forge_unlocks_bronze_recipes() -> void:
	var cost: Dictionary = UpgradeTable.get_upgrade("forge")["cost"]
	var entries: Array = []
	for kind in cost:
		entries.append({"item": kind, "count": cost[kind]})
	var sim := _with_stash(entries)
	sim.command(Vocab.INTERACT, {"object_id": "workbench"})
	H.run_until_idle(sim, 60)
	H.set_pack(sim, [{"item": "copper_ore", "count": 1}, {"item": "tin_ore", "count": 1}])
	assert_eq(sim.check(Vocab.SMITH, {"recipe": "bronze_bar"}), Vocab.REASON_UPGRADE_MISSING)
	sim.command(Vocab.BUILD, {"upgrade": "forge"})
	H.run(sim, 1)
	assert_eq(sim.check(Vocab.SMITH, {"recipe": "bronze_bar"}), "", "the forge makes bronze possible")
	for kind in cost:
		assert_eq(H.stash_count(sim, kind), 0, "the forge took its %s" % kind)


## A character at the workbench with `upgrades` built, at smithing `level`, whose stash holds
## the Bloomery's logs and bronze bars and whose pack holds `ore` iron ore: the Bloomery's
## cost split between the two.
func _at_workbench_for_the_bloomery(upgrades: Array, ore: int, level := 3) -> Sim:
	var cost: Dictionary = UpgradeTable.get_upgrade("bloomery")["cost"]
	var sim := _with_stash([{"item": "logs", "count": cost["logs"]}, {"item": "bronze_bar", "count": cost["bronze_bar"]}], upgrades)
	var snap := sim.snapshot()
	snap["skills"][SkillTable.SMITHING] = {"xp": SkillTable.xp_for_level(level), "level": level}
	sim.restore(snap)
	sim.command(Vocab.INTERACT, {"object_id": "workbench"})
	H.run_until_idle(sim, 60)
	H.set_pack(sim, [{"item": "iron_ore", "count": ore}])
	sim.drain_events()
	return sim


func test_the_bloomery_is_built_after_the_armoury_from_the_stash_and_the_pack() -> void:
	var cost: Dictionary = UpgradeTable.get_upgrade("bloomery")["cost"]
	assert_eq(cost, {"logs": 8, "bronze_bar": 2, "iron_ore": 4})
	var sim := _at_workbench_for_the_bloomery(["stash_shelves", "forge"], 4)
	assert_eq(sim.command(Vocab.BUILD, {"upgrade": "bloomery"})["reason"], Vocab.REASON_UPGRADE_MISSING)
	assert_eq(sim.upgrade_status()["bloomery"]["requires"], ["armoury"], "the Armoury is named")
	H.run(sim, 1)
	assert_false((sim.state["upgrades"] as Array).has("bloomery"), "nothing was built")
	assert_eq(H.pack_count(sim, "iron_ore"), 4, "nothing was paid")
	sim = _at_workbench_for_the_bloomery(["stash_shelves", "forge", "armoury"], 4)
	assert_eq(sim.upgrade_status()["bloomery"]["status"], Vocab.UPGRADE_CAN_BUILD)
	assert_true(sim.command(Vocab.BUILD, {"upgrade": "bloomery"})["ok"])
	var built := H.of_kind(H.run(sim, 1), Vocab.EV_BUILT)
	assert_eq(built.size(), 1)
	assert_eq(built[0]["upgrade"], "bloomery")
	assert_eq(H.stash_count(sim, "logs"), 0, "the logs left the stash")
	assert_eq(H.stash_count(sim, "bronze_bar"), 0, "the bronze bars left the stash")
	assert_eq(H.pack_count(sim, "iron_ore"), 0, "the iron ore left the pack")


func test_the_bloomery_unlocks_the_iron_bar() -> void:
	var sim := _at_workbench_for_the_bloomery(["forge", "armoury"], 8)
	assert_eq(sim.check(Vocab.SMITH, {"recipe": "iron_bar"}), Vocab.REASON_UPGRADE_MISSING)
	sim.command(Vocab.BUILD, {"upgrade": "bloomery"})
	H.run(sim, 1)
	assert_eq(sim.check(Vocab.SMITH, {"recipe": "iron_bar"}), "", "the Bloomery makes iron possible")
	assert_true(sim.command(Vocab.SMITH, {"recipe": "iron_bar"})["ok"])
	var events := H.run(sim, 1)
	assert_eq(H.of_kind(events, Vocab.EV_CRAFTED)[0]["item"], "iron_bar")
	assert_eq(H.pack_count(sim, "iron_bar"), 1)
	assert_eq(H.pack_count(sim, "iron_ore"), 2, "two ore a bar: 8 less the Bloomery's 4 and this bar's 2")
	var low := _at_workbench_for_the_bloomery(["forge", "armoury", "bloomery"], 2, 2)
	assert_eq(low.check(Vocab.SMITH, {"recipe": "iron_bar"}), Vocab.REASON_LEVEL_TOO_LOW, "iron bars need smithing 3")


func test_the_smithing_cap_reads_bronze_then_iron_then_steel() -> void:
	var sim := _with_stash([], ["stash_shelves", "forge", "armoury"])
	assert_eq(sim.smithing_cap(), ItemTable.TIER_BRONZE)
	H.patch(sim, {"upgrades": ["stash_shelves", "forge", "armoury", "bloomery"]})
	assert_eq(sim.smithing_cap(), ItemTable.TIER_IRON, "the Bloomery lifts it to iron")
	H.patch(sim, {"upgrades": ["stash_shelves", "forge", "armoury", "bloomery", "ring_two_gate", "blast_furnace"]})
	assert_eq(sim.smithing_cap(), ItemTable.TIER_STEEL, "the blast furnace lifts it to steel")


func test_the_blast_furnace_alone_does_not_smelt_iron() -> void:
	var sim := _at_workbench_for_the_bloomery(["forge", "armoury", "ring_two_gate", "blast_furnace"], 2, 50)
	assert_eq(sim.smithing_cap(), ItemTable.TIER_STEEL)
	assert_eq(sim.check(Vocab.SMITH, {"recipe": "iron_bar"}), Vocab.REASON_UPGRADE_MISSING, "iron still needs the Bloomery")


func test_nothing_requires_the_bloomery() -> void:
	for id in UpgradeTable.ids():
		assert_false((UpgradeTable.get_upgrade(id)["requires"] as Array).has("bloomery"), "%s does not need the Bloomery" % id)
	assert_eq(UpgradeTable.get_upgrade("ring_two_gate")["requires"], ["armoury"], "the winch needs only the Armoury")


func test_the_bloomery_survives_death() -> void:
	var sim := _at_workbench_for_the_bloomery(["stash_shelves", "forge", "armoury"], 4)
	sim.command(Vocab.BUILD, {"upgrade": "bloomery"})
	H.run(sim, 1)
	H.place(sim, H.OUTSIDE)
	H.patch(sim, {"warmth": 0, "health": 1})
	assert_eq(H.of_kind(H.run(sim, 2), Vocab.EV_DIED).size(), 1)
	assert_true((sim.state["upgrades"] as Array).has("bloomery"), "the Bloomery still stands")
	assert_eq(sim.smithing_cap(), ItemTable.TIER_IRON)


## A character in the outpost with `upgrades` built, whose stash holds the Pack frame's logs
## and whose pack holds its wolf pelts: the cost split between the two.
func _in_the_outpost_for_the_pack_frame(upgrades: Array) -> Sim:
	var cost: Dictionary = UpgradeTable.get_upgrade("pack_frame")["cost"]
	var sim := _with_stash([{"item": "logs", "count": cost["logs"]}], upgrades)
	H.set_pack(sim, [{"item": "wolf_pelt", "count": cost["wolf_pelt"]}])
	sim.drain_events()
	return sim


## `sim`'s pack swapped for logs, a stack at a time, so it carries `kg` kilograms with what it
## wears.
func _carrying_logs(sim: Sim, kg: int) -> void:
	H.set_pack(sim, [])
	kg -= sim.carry_weight()
	var load: Array = []
	while kg > 0:
		load.append({"item": "logs", "count": mini(kg, ItemTable.stack_size("logs"))})
		kg -= ItemTable.stack_size("logs")
	H.set_pack(sim, load)


func test_the_pack_frame_is_built_after_the_armoury_from_the_stash_and_the_pack() -> void:
	var u := UpgradeTable.get_upgrade("pack_frame")
	assert_eq(u["label"], "Pack frame")
	assert_eq(u["cost"], {"logs": 10, "wolf_pelt": 4})
	assert_eq(u["requires"], ["armoury"])
	assert_eq(u["effects"], {"carry": 15})
	assert_eq(u["locked"], "")
	var sim := _in_the_outpost_for_the_pack_frame(["stash_shelves", "forge"])
	assert_eq(sim.command(Vocab.BUILD, {"upgrade": "pack_frame"})["reason"], Vocab.REASON_UPGRADE_MISSING)
	assert_eq(sim.upgrade_status()["pack_frame"]["requires"], ["armoury"], "the Armoury is named")
	H.run(sim, 1)
	assert_false((sim.state["upgrades"] as Array).has("pack_frame"), "nothing was built")
	assert_eq(H.pack_count(sim, "wolf_pelt"), 4, "nothing was paid")
	sim = _in_the_outpost_for_the_pack_frame(["stash_shelves", "forge", "armoury"])
	assert_eq(sim.upgrade_status()["pack_frame"]["status"], Vocab.UPGRADE_CAN_BUILD)
	assert_true(sim.command(Vocab.BUILD, {"upgrade": "pack_frame"})["ok"])
	var built := H.of_kind(H.run(sim, 1), Vocab.EV_BUILT)
	assert_eq(built.size(), 1)
	assert_eq(built[0]["upgrade"], "pack_frame")
	assert_eq(H.stash_count(sim, "logs"), 0, "the logs left the stash")
	assert_eq(H.pack_count(sim, "wolf_pelt"), 0, "the wolf pelts left the pack")


func test_the_pack_frame_raises_the_carry_limit_to_60() -> void:
	var sim := _in_the_outpost_for_the_pack_frame(["stash_shelves", "forge", "armoury"])
	assert_eq(sim.carry_limit(), 45)
	sim.command(Vocab.BUILD, {"upgrade": "pack_frame"})
	H.run(sim, 1)
	assert_eq(sim.carry_limit(), 60, "the next trip carries 15 kg more")
	_carrying_logs(sim, 60)
	assert_eq(sim.carry_weight(), 60)
	assert_false(sim.is_overweight(), "60 kg is at the limit, not over it")
	_carrying_logs(sim, 61)
	assert_true(sim.is_overweight(), "61 kg is over")


func test_the_pack_frame_survives_a_snapshot_and_restore() -> void:
	var sim := _in_the_outpost_for_the_pack_frame(["stash_shelves", "forge", "armoury"])
	sim.command(Vocab.BUILD, {"upgrade": "pack_frame"})
	H.run(sim, 1)
	var restored := SimScript.new()
	restored.restore(sim.snapshot())
	assert_eq(restored.carry_limit(), 60)
	_carrying_logs(restored, 60)
	assert_false(restored.is_overweight(), "60 kg is still within the limit after a restore")


func test_nothing_requires_the_pack_frame() -> void:
	for id in UpgradeTable.ids():
		assert_false((UpgradeTable.get_upgrade(id)["requires"] as Array).has("pack_frame"), "%s does not need the Pack frame" % id)
	assert_eq(UpgradeTable.get_upgrade("ring_two_gate")["requires"], ["armoury"], "the winch needs only the Armoury")


func test_upgrades_survive_death() -> void:
	var sim := _with_stash([{"item": "logs", "count": 10}])
	sim.command(Vocab.BUILD, {"upgrade": "stash_shelves"})
	H.run(sim, 1)
	H.place(sim, H.OUTSIDE)
	H.patch(sim, {"warmth": 0, "health": 1})
	var events := H.run(sim, 2)
	assert_eq(H.of_kind(events, Vocab.EV_DIED).size(), 1)
	assert_eq(sim.state["upgrades"], ["stash_shelves"])
	assert_eq(int(sim.state["stash"]["capacity"]), Sim.STASH_START_SLOTS + 4)


# --- Gear tiers ---------------------------------------------------------------------------

func test_three_visible_gear_tiers_for_every_slot_and_style() -> void:
	var seen := {}
	for kind in ItemTable.ITEMS:
		var slot := ItemTable.slot(kind)
		if slot == "":
			continue
		var tier := ItemTable.tier(kind)
		assert_true(ItemTable.tier_rank(tier) >= 0, "%s has a gear tier" % kind)
		var group := slot
		if slot == ItemTable.SLOT_WEAPON:
			group = ItemTable.ITEMS[kind]["style"]
		elif slot == ItemTable.SLOT_TOOL:
			group = ItemTable.tool(kind)
		seen["%s/%s" % [group, tier]] = true
	for group in ["melee", "ranged", "magic", ItemTable.SLOT_HELM, ItemTable.SLOT_BODY, ItemTable.SLOT_LEGS, ItemTable.TOOL_AXE, ItemTable.TOOL_PICKAXE]:
		for tier in ItemTable.TIERS:
			assert_true(seen.has("%s/%s" % [group, tier]), "a %s %s" % [tier, group])


func test_higher_tiers_are_stronger_and_worth_more() -> void:
	var lines := [
		["wooden_club", "bronze_sword", "iron_sword"], ["wooden_bow", "bronze_bow", "iron_bow"],
		["wooden_staff", "bronze_staff", "iron_staff"],
	]
	for line in lines:
		for i in range(1, line.size()):
			var lo: Dictionary = ItemTable.ITEMS[line[i - 1]]
			var hi: Dictionary = ItemTable.ITEMS[line[i]]
			assert_true(int(hi.get("power", hi.get("defence", 0))) > int(lo.get("power", lo.get("defence", 0))), "%s beats %s" % [line[i], line[i - 1]])
			assert_true(int(hi["value"]) > int(lo["value"]), "%s is worth more than %s" % [line[i], line[i - 1]])


## The single armour each tier had before #38: its defence, weight, value and recipe inputs.
## Iron armour had no recipe then; its set now takes the bronze set's four bars, in iron.
const SINGLE_ARMOUR := {
	"wooden": {"defence": 1, "weight": 4, "value": 16, "inputs": {"logs": 8}},
	"bronze": {"defence": 2, "weight": 5, "value": 50, "inputs": {"bronze_bar": 4}},
	"iron": {"defence": 3, "weight": 6, "value": 90, "inputs": {"iron_bar": 4}},
	"steel": {"defence": 4, "weight": 7, "value": 180, "inputs": {"steel_bar": 3, "troll_hide": 1}},
}


func _set_of(tier: String) -> Dictionary:
	return {
		ItemTable.SLOT_HELM: tier + "_helm", ItemTable.SLOT_BODY: tier + "_body", ItemTable.SLOT_LEGS: tier + "_legs",
	}


func test_a_full_armour_set_matches_the_single_armour_it_replaced() -> void:
	for tier in ItemTable.TIERS:
		var before: Dictionary = SINGLE_ARMOUR[tier]
		var set := _set_of(tier)
		assert_eq(ItemTable.worn_defence(set), before["defence"], "a full %s set takes off what %s armour did" % [tier, tier])
		var weight := 0
		var value := 0
		var inputs := {}
		for slot in set:
			var kind: String = set[slot]
			assert_eq(ItemTable.slot(kind), slot, "%s goes in the %s slot" % [kind, slot])
			assert_eq(ItemTable.tier(kind), tier)
			weight += ItemTable.weight(kind)
			value += ItemTable.value(kind)
			if RecipeTable.has(kind):
				var cost: Dictionary = RecipeTable.get_recipe(kind)["inputs"]
				for k in cost:
					inputs[k] = int(inputs.get(k, 0)) + int(cost[k])
		assert_eq(weight, before["weight"], "a full %s set weighs what the armour did" % tier)
		assert_eq(value, before["value"], "a full %s set is worth what the armour was" % tier)
		assert_eq(inputs, before["inputs"], "a full %s set costs what the armour did" % tier)


func test_full_sets_get_stronger_tier_by_tier_and_no_piece_gets_weaker() -> void:
	for i in range(1, ItemTable.TIERS.size()):
		var lo := _set_of(ItemTable.TIERS[i - 1])
		var hi := _set_of(ItemTable.TIERS[i])
		assert_true(ItemTable.worn_defence(hi) > ItemTable.worn_defence(lo), "a full %s set beats %s" % [ItemTable.TIERS[i], ItemTable.TIERS[i - 1]])
		for slot in ItemTable.ARMOUR_SLOTS:
			assert_true(ItemTable.defence(hi[slot]) >= ItemTable.defence(lo[slot]), "%s is no weaker than %s" % [hi[slot], lo[slot]])
			assert_true(ItemTable.value(hi[slot]) > ItemTable.value(lo[slot]), "%s is worth more than %s" % [hi[slot], lo[slot]])


func test_defence_is_the_sum_of_the_worn_pieces() -> void:
	var sim := SimScript.new()
	assert_eq(sim.combatant(Vocab.PLAYER)["defence"], 0, "nothing worn")
	var snap := sim.snapshot()
	snap["inventory"]["equipment"].merge({"helm": "steel_helm", "legs": "iron_legs"}, true)
	sim.restore(snap)
	assert_eq(sim.combatant(Vocab.PLAYER)["defence"], 2, "steel helm 1 and iron legs 1")
	snap["inventory"]["equipment"]["body"] = "steel_body"
	sim.restore(snap)
	assert_eq(sim.combatant(Vocab.PLAYER)["defence"], 4, "and a steel body's 2")


# --- Iron gear ---------------------------------------------------------------------------

## The eight iron gear recipes as the ticket gives them (#117): inputs and smithing level.
const IRON_GEAR := {
	"iron_axe": [{"iron_bar": 1, "logs": 2}, 3], "iron_pickaxe": [{"iron_bar": 1, "logs": 2}, 3],
	"iron_sword": [{"iron_bar": 2, "logs": 1}, 4], "iron_bow": [{"iron_bar": 2, "logs": 3}, 4],
	"iron_staff": [{"iron_bar": 2, "logs": 2, "ice_crystal": 1}, 4],
	"iron_helm": [{"iron_bar": 1}, 4], "iron_body": [{"iron_bar": 2}, 4], "iron_legs": [{"iron_bar": 1}, 4],
}


## A character at the workbench with `upgrades` built, at smithing `level`, carrying `recipe`'s inputs.
func _at_workbench_with_inputs(upgrades: Array, level: int, recipe: String) -> Sim:
	var sim := _with_stash([], upgrades)
	var snap := sim.snapshot()
	snap["skills"][SkillTable.SMITHING] = {"xp": SkillTable.xp_for_level(level), "level": level}
	sim.restore(snap)
	sim.command(Vocab.INTERACT, {"object_id": "workbench"})
	H.run_until_idle(sim, 60)
	var pack: Array = []
	var inputs: Dictionary = RecipeTable.get_recipe(recipe)["inputs"]
	for kind in inputs:
		pack.append({"item": kind, "count": inputs[kind]})
	H.set_pack(sim, pack)
	sim.drain_events()
	return sim


func test_every_iron_item_is_smithed_after_the_bloomery() -> void:
	for id in IRON_GEAR:
		var r := RecipeTable.get_recipe(id)
		assert_eq(r["inputs"], IRON_GEAR[id][0], "%s's inputs" % id)
		assert_eq(int(r["level"]), IRON_GEAR[id][1], "%s's smithing level" % id)
		assert_eq(r["output"], {"item": id, "count": 1})
		var sim := _at_workbench_with_inputs(["forge", "armoury"], IRON_GEAR[id][1], id)
		assert_eq(sim.check(Vocab.SMITH, {"recipe": id}), Vocab.REASON_UPGRADE_MISSING, "%s needs the Bloomery" % id)
		H.patch(sim, {"upgrades": ["forge", "armoury", "bloomery"]})
		assert_true(sim.command(Vocab.SMITH, {"recipe": id})["ok"], "%s is smithed after the Bloomery" % id)
		H.run(sim, 1)
		assert_eq(H.pack_count(sim, id), 1, "one %s made" % id)
		for kind in r["inputs"]:
			assert_eq(H.pack_count(sim, kind), 0, "%s took its %s" % [id, kind])


func test_the_blast_furnace_alone_smiths_steel_but_no_iron_gear() -> void:
	var built := ["forge", "armoury", "ring_two_gate", "blast_furnace"]
	for id in RecipeTable.ids():
		var tier: String = RecipeTable.get_recipe(id)["tier"]
		if tier == ItemTable.TIER_IRON:
			var sim := _at_workbench_with_inputs(built, 5, id)
			assert_eq(sim.check(Vocab.SMITH, {"recipe": id}), Vocab.REASON_UPGRADE_MISSING, "%s still needs the Bloomery" % id)
		elif tier == ItemTable.TIER_STEEL:
			var sim := _at_workbench_with_inputs(built, 5, id)
			assert_eq(sim.check(Vocab.SMITH, {"recipe": id}), "", "%s passes" % id)


func test_an_iron_weapon_at_smithing_3_is_too_low() -> void:
	var sim := _at_workbench_with_inputs(["forge", "armoury", "bloomery"], 3, "iron_sword")
	assert_eq(sim.check(Vocab.SMITH, {"recipe": "iron_sword"}), Vocab.REASON_LEVEL_TOO_LOW, "an iron sword needs smithing 4")


func test_iron_is_made_at_the_bloomery_and_still_drops() -> void:
	var made := {}
	for id in RecipeTable.ids():
		var r := RecipeTable.get_recipe(id)
		made[r["output"]["item"]] = r["upgrade"]
	var found := {}
	for kind in CombatTable.RARE_LOOT:
		found[kind] = true
	for kind in CombatTable.ENEMIES["bandit_captain"]["boss_loot"]:
		found[kind] = true
	for kind in ItemTable.ITEMS:
		if ItemTable.tier(kind) == ItemTable.TIER_IRON:
			assert_eq(made.get(kind, ""), "bloomery", "%s is smithed at the Bloomery" % kind)
			assert_true(found.has(kind), "%s drops in ring one" % kind)


func test_iron_recipes_mirror_bronze_and_sit_between_bronze_and_steel() -> void:
	for id in IRON_GEAR:
		var iron := RecipeTable.get_recipe(id)
		var bronze := RecipeTable.get_recipe(id.replace("iron_", "bronze_"))
		var steel := RecipeTable.get_recipe(id.replace("iron_", "steel_"))
		assert_eq(iron["upgrade"], "bloomery", "%s names the Bloomery" % id)
		assert_eq(iron["tier"], ItemTable.TIER_IRON)
		var shape := {}
		for kind in bronze["inputs"]:
			shape[kind.replace("bronze_bar", "iron_bar")] = bronze["inputs"][kind]
		assert_eq(iron["inputs"], shape, "%s takes the bronze shape with iron bars" % id)
		assert_true(int(iron["level"]) > int(bronze["level"]) and int(iron["level"]) < int(steel["level"]), "%s's level sits between bronze and steel" % id)
		assert_true(int(iron["xp"]) > int(bronze["xp"]) and int(iron["xp"]) < int(steel["xp"]), "%s's experience sits between bronze and steel" % id)


## Adds to `into` every raw item `kind` comes from: a smithed item's inputs, followed down.
func _raw_kinds(kind: String, into: Dictionary) -> void:
	for id in RecipeTable.ids():
		var r := RecipeTable.get_recipe(id)
		if r["output"]["item"] == kind:
			for input in r["inputs"]:
				_raw_kinds(input, into)
			return
	into[kind] = true


func test_the_bloomery_and_a_full_iron_kit_are_paid_for_from_ring_one() -> void:
	var w := WorldDefScript.outpost()
	var near_side := [WorldDef.REGION_INNER_RING, WorldDef.REGION_RING_ONE]
	var on_hand := {}
	for id in w.node_ids():
		if w.region_at(w.object_center(id)) in near_side:
			on_hand[WorldDef.NODE_KINDS[w.objects[id]["kind"]]["item"]] = true
	for id in w.enemies:
		var home: Array = w.enemies[id]["home"]
		if w.region_at(Vector2(home[0], home[1])) in near_side:
			for drop in CombatTable.enemy(w.enemies[id]["kind"])["loot"]:
				on_hand[drop["item"]] = true
	var needed := {}
	var upgrades := ["bloomery"]
	while not upgrades.is_empty():
		var u := UpgradeTable.get_upgrade(upgrades.pop_back())
		for kind in u["cost"]:
			_raw_kinds(kind, needed)
		upgrades.append_array(u["requires"])
	for id in IRON_GEAR:
		_raw_kinds(id, needed)
	for kind in needed:
		assert_true(on_hand.has(kind), "%s comes from ring one" % kind)
