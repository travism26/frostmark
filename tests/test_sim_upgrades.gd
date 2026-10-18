## The outpost tech tree: build pays from the stash, prerequisites and locks are enforced,
## and each built upgrade applies its effect. Also the gear tiers it unlocks.
extends "res://tests/run.gd".TestCase

const H := preload("res://tests/sim_helpers.gd")
const SimScript := preload("res://sim/sim.gd")
const Vocab := preload("res://sim/vocab.gd")


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


func test_can_build_now_does_not_depend_on_where_the_player_stands() -> void:
	var sim := _with_stash([{"item": "logs", "count": 8}])
	H.place(sim, H.OUTSIDE)
	var s: Dictionary = sim.upgrade_status()["stash_shelves"]
	assert_eq(s["status"], Vocab.UPGRADE_CAN_BUILD)
	assert_eq(s["reason"], Vocab.REASON_NOT_IN_OUTPOST, "but Build is refused out there")


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
		{"item": "iron_ore", "have": 0, "need": 8}, {"item": "wolf_pelt", "have": 0, "need": 3},
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
	sim = _with_stash([{"item": "logs", "count": 10}])
	H.set_pack(sim, [{"item": "logs", "count": 10}])
	H.place(sim, H.OUTSIDE)
	assert_eq(sim.command(Vocab.BUILD, {"upgrade": "stash_shelves"})["reason"], Vocab.REASON_NOT_IN_OUTPOST)
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
const SINGLE_ARMOUR := {
	"wooden": {"defence": 1, "weight": 4, "value": 16, "inputs": {"logs": 8}},
	"bronze": {"defence": 2, "weight": 5, "value": 50, "inputs": {"bronze_bar": 4}},
	"iron": {"defence": 3, "weight": 6, "value": 90, "inputs": {}},
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


func test_iron_is_only_found() -> void:
	var made := {}
	for id in RecipeTable.ids():
		var r := RecipeTable.get_recipe(id)
		if ItemTable.tier_rank(r["tier"]) <= ItemTable.tier_rank(Sim.SMITHING_TIER_CAP):
			made[r["output"]["item"]] = true
	var found := {}
	for kind in CombatTable.RARE_LOOT:
		found[kind] = true
	for kind in CombatTable.ENEMIES["bandit_captain"]["boss_loot"]:
		found[kind] = true
	for kind in ItemTable.ITEMS:
		if ItemTable.tier(kind) == ItemTable.TIER_IRON:
			assert_false(made.has(kind), "%s cannot be smithed" % kind)
			assert_true(found.has(kind), "%s drops in ring one" % kind)
