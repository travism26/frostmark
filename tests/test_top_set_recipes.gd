## The top sets' workbench recipes (#184): every piece of the twelve top sets (#163, #165, #167)
## costs 2 or 3 of its style's ring-three rare material on top of the steel recipe of its slot
## and style, at smithing level 60, once the Ring-three gate hoist is built.
extends "res://tests/run.gd".TestCase

const H := preload("res://tests/sim_helpers.gd")
const SimScript := preload("res://sim/sim.gd")
const Vocab := preload("res://sim/vocab.gd")

const MELEE := ["emberheart", "hoarfrost", "auroral", "trollbone"]
const RANGED := ["ember_hawk", "auroral_warden", "ruin_stalker", "glacier_sovereign"]
const MAGIC := ["hoarfrost_sovereign", "hearthfire_magus", "aurora_shaman", "ruinwarden_mage"]
## Every other set item: it gains no recipe here.
const OTHER := ["hearthguard", "wolfmark", "ruinwarden", "trapper", "wolfstalker", "steelpoint", "shardweaver", "rimecaller", "glacier_warden"]
const HOIST := ["stash_shelves", "forge", "armoury", "bloomery", "ring_two_gate", "blast_furnace"]


func _material_of(kind: String) -> String:
	var set_key := ItemTable.set_of(kind)
	return "rime_steel" if MELEE.has(set_key) else "frost_sinew" if RANGED.has(set_key) else "aurora_glass" if MAGIC.has(set_key) else ""


func _top_pieces() -> Array[String]:
	var pieces: Array[String] = []
	for kind in ItemTable.ITEMS:
		if _material_of(kind) != "":
			pieces.append(kind)
	return pieces


func test_every_top_set_piece_has_a_recipe_with_its_styles_material() -> void:
	var pieces := _top_pieces()
	assert_eq(pieces.size(), 58, "4 melee sets of 4, 4 ranged sets of 5 or 6, 4 magic sets of 5")
	for kind in pieces:
		assert_true(RecipeTable.has(kind), "%s has a recipe" % kind)
		var recipe := RecipeTable.get_recipe(kind)
		assert_eq(recipe["output"], {"item": kind, "count": 1}, kind)
		var count := 3 if ItemTable.slot(kind) in [ItemTable.SLOT_BODY, ItemTable.SLOT_WEAPON] else 2
		assert_eq(recipe["inputs"].get(_material_of(kind)), count, "%s costs %d %s" % [kind, count, _material_of(kind)])
		assert_eq(recipe["skill"], SkillTable.SMITHING, kind)
		assert_eq(recipe["level"], 60, "%s needs smithing 60" % kind)
		assert_eq(recipe["upgrade"], "ring_three_gate", kind)
		assert_eq(recipe["tier"], "", "%s has no tier, so the smithing cap never refuses it" % kind)
		assert_true(int(recipe["xp"]) > 0, "%s grants experience" % kind)
		assert_true(UpgradeTable.get_upgrade("ring_three_gate")["effects"]["recipes"].has(kind), "the hoist unlocks %s" % kind)


func test_the_rest_of_each_recipe_is_the_steel_recipe_of_its_slot_and_style() -> void:
	var steel := {
		ItemTable.SLOT_HELM: {"steel_bar": 1}, ItemTable.SLOT_LEGS: {"steel_bar": 1},
		ItemTable.SLOT_BODY: {"steel_bar": 1, "troll_hide": 1},
		ItemTable.SLOT_QUIVER: {"steel_bar": 2}, ItemTable.SLOT_CAPE: {"steel_bar": 2},
	}
	var weapon := {"melee": "steel_sword", "ranged": "steel_bow", "magic": "steel_staff"}
	for kind in _top_pieces():
		var slot := ItemTable.slot(kind)
		var expected: Dictionary = RecipeTable.get_recipe(weapon[ItemTable.ITEMS[kind]["style"]])["inputs"].duplicate() if slot == ItemTable.SLOT_WEAPON else steel[slot].duplicate()
		expected[_material_of(kind)] = 3 if slot in [ItemTable.SLOT_BODY, ItemTable.SLOT_WEAPON] else 2
		assert_eq(RecipeTable.get_recipe(kind)["inputs"], expected, kind)


func test_a_full_set_costs_ten_twelve_or_fourteen_of_the_material() -> void:
	for key in MELEE + RANGED + MAGIC:
		var total := 0
		for kind in _top_pieces():
			if ItemTable.set_of(kind) == key:
				total += int(RecipeTable.get_recipe(kind)["inputs"][_material_of(kind)])
		var expected := 10
		if RANGED.has(key) or MAGIC.has(key):
			expected = 14 if ItemTable.ITEMS.has(key + "_cape") and ItemTable.ITEMS.has(key + "_quiver") else 12
		assert_eq(total, expected, "%s costs %d" % [key, expected])


func test_no_other_set_item_gains_a_recipe() -> void:
	for kind in ItemTable.ITEMS:
		if OTHER.has(ItemTable.set_of(kind)):
			assert_false(RecipeTable.has(kind), "%s has no recipe" % kind)


func test_the_tooltips_name_the_pieces_each_material_crafts() -> void:
	for pair in [["rime_steel", MELEE], ["frost_sinew", RANGED], ["aurora_glass", MAGIC]]:
		var line := ""
		for l in UiTooltip.item_lines(pair[0]):
			if l.begins_with("Crafts into "):
				line = l
		assert_true(line != "", "%s has a crafts-into line" % pair[0])
		for kind in _top_pieces():
			var listed := line.contains(ItemTable.label(kind).to_lower())
			assert_eq(listed, pair[1].has(ItemTable.set_of(kind)), "%s in %s's line" % [kind, pair[0]])


func _at_workbench(upgrades: Array, level: int, pack: Array) -> Sim:
	var sim := SimScript.new()
	var snap := sim.snapshot()
	snap["skills"][SkillTable.SMITHING] = {"xp": SkillTable.xp_for_level(level), "level": level}
	snap["upgrades"] = upgrades
	sim.restore(snap)
	sim.command(Vocab.INTERACT, {"object_id": "workbench"})
	H.run_until_idle(sim, 60)
	H.set_pack(sim, pack)
	sim.drain_events()
	return sim


func _inputs_of(kind: String) -> Array:
	var pack: Array = []
	var inputs: Dictionary = RecipeTable.get_recipe(kind)["inputs"]
	for item in inputs:
		pack.append({"item": item, "count": inputs[item]})
	return pack


func test_each_is_refused_before_the_hoist_and_crafts_after_it() -> void:
	for kind in _top_pieces():
		var before := _at_workbench(HOIST, 60, _inputs_of(kind))
		assert_eq(before.check(Vocab.SMITH, {"recipe": kind}), Vocab.REASON_UPGRADE_MISSING, "%s needs the hoist" % kind)
		var after := _at_workbench(HOIST + ["ring_three_gate"], 60, _inputs_of(kind))
		assert_eq(after.check(Vocab.SMITH, {"recipe": kind}), "", "%s crafts after it" % kind)
		assert_true(after.command(Vocab.SMITH, {"recipe": kind})["ok"], kind)
		H.run_until_idle(after, 60)
		assert_eq(H.pack_count(after, kind), 1, "%s lands in the pack" % kind)
		assert_eq(H.pack_count(after, _material_of(kind)), 0, "%s spends the material" % kind)


func test_smithing_level_60_is_needed_and_the_experience_is_granted() -> void:
	var low := _at_workbench(HOIST + ["ring_three_gate"], 59, _inputs_of("emberheart_hammer"))
	assert_eq(low.check(Vocab.SMITH, {"recipe": "emberheart_hammer"}), Vocab.REASON_LEVEL_TOO_LOW)
	var sim := _at_workbench(HOIST + ["ring_three_gate"], 60, _inputs_of("emberheart_hammer"))
	var xp_before := int(sim.snapshot()["skills"][SkillTable.SMITHING]["xp"])
	assert_true(sim.command(Vocab.SMITH, {"recipe": "emberheart_hammer"})["ok"])
	H.run_until_idle(sim, 60)
	assert_eq(int(sim.snapshot()["skills"][SkillTable.SMITHING]["xp"]) - xp_before, int(RecipeTable.get_recipe("emberheart_hammer")["xp"]))


func test_the_material_comes_from_the_stash_first_then_the_pack() -> void:
	var sim := _at_workbench(HOIST + ["ring_three_gate"], 60, [{"item": "steel_bar", "count": 1}, {"item": "rime_steel", "count": 1}])
	H.patch(sim, {"stash": {"capacity": Sim.STASH_START_SLOTS, "slots": [{"item": "rime_steel", "count": 1}]}})
	assert_eq(sim.check(Vocab.SMITH, {"recipe": "emberheart_helm"}), "", "one in the stash and one in the pack make the 2")
	assert_true(sim.command(Vocab.SMITH, {"recipe": "emberheart_helm"})["ok"])
	H.run_until_idle(sim, 60)
	assert_eq(H.stash_count(sim, "rime_steel"), 0, "the stash went first")
	assert_eq(H.pack_count(sim, "rime_steel"), 0)
