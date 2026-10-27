## Ring three's rare materials (#179): rime steel, frost sinew and aurora glass are materials
## like a troll hide, which stack, weigh, and go in and out of the stash, and which only the top
## sets' recipes spend (#184); so far the Frostbound knight, the Snowveil archer and the Aurora
## seer drop one each, and the Frost tyrant one of every one.
extends "res://tests/run.gd".TestCase

const H := preload("res://tests/sim_helpers.gd")
const SimScript := preload("res://sim/sim.gd")
const Vocab := preload("res://sim/vocab.gd")

const RARES: Array[String] = ["rime_steel", "frost_sinew", "aurora_glass"]
## The enemy kinds that drop each one so far.
const DROPPED_BY := {
	"rime_steel": ["frostbound_knight", "frost_tyrant"], "frost_sinew": ["snowveil_archer", "frost_tyrant"],
	"aurora_glass": ["aurora_seer", "frost_tyrant"],
}


func test_each_is_a_material_with_no_slot_or_tier_weighing_1_worth_25_in_stacks_of_10() -> void:
	for kind in RARES:
		assert_true(ItemTable.has(kind), "%s is an item" % kind)
		assert_eq(ItemTable.slot(kind), "", "%s has no slot" % kind)
		assert_eq(ItemTable.tier(kind), "", "%s has no tier" % kind)
		assert_eq(ItemTable.weight(kind), 1, kind)
		assert_eq(ItemTable.value(kind), 25, kind)
		assert_eq(ItemTable.stack_size(kind), 10, kind)
		assert_false(ItemTable.is_kit(kind), "%s is haul" % kind)
	assert_eq(ItemTable.label("rime_steel"), "Rime steel")
	assert_eq(ItemTable.label("frost_sinew"), "Frost sinew")
	assert_eq(ItemTable.label("aurora_glass"), "Aurora glass")
	assert_true(ItemTable.value("rime_steel") > ItemTable.value("troll_hide"), "just above a troll hide")


func test_each_has_its_own_icon() -> void:
	var paths := {}
	for kind in RARES:
		assert_true(IconTable.has(kind), "%s has an icon" % kind)
		paths[IconTable.path(kind)] = true
	assert_eq(paths.size(), RARES.size(), "three different glyphs")
	assert_false(paths.has(IconTable.path("steel_bar")), "rime steel is not a steel bar")


func test_each_tooltip_shows_weight_and_value_then_what_it_crafts_into() -> void:
	for kind in RARES:
		var lines := UiTooltip.item_lines(kind)
		assert_eq(lines.size(), 2, "%s: %s" % [kind, lines])
		assert_true(lines[1].begins_with("Crafts into "), lines[1])
		assert_true(lines[0].contains("1 Kg") and lines[0].contains("25"), lines[0])
		assert_false(lines[0].contains("Tier"), lines[0])


func test_they_stack_weigh_and_go_in_and_out_of_the_stash() -> void:
	var sim := SimScript.new()
	H.patch(sim, {"stash": {"capacity": Sim.STASH_START_SLOTS, "slots": []}})
	var before := sim.carry_weight()
	H.set_pack(sim, [{"item": "rime_steel", "count": 10}, {"item": "frost_sinew", "count": 3},
		{"item": "aurora_glass", "count": 2}])
	assert_eq(sim.carry_weight(), before + 15, "a kilogram a piece")
	assert_true(sim.command(Vocab.DEPOSIT_HAUL)["ok"])
	H.run(sim, 1)
	for kind in RARES:
		assert_eq(H.pack_count(sim, kind), 0, "%s is haul and deposits" % kind)
	assert_eq(H.stash_count(sim, "rime_steel"), 10)
	assert_eq(H.stash_count(sim, "frost_sinew"), 3)
	assert_eq(sim.carry_weight(), before)
	assert_true(sim.command(Vocab.WITHDRAW, {"index": 0})["ok"])
	H.run(sim, 1)
	assert_eq(H.pack_count(sim, "rime_steel"), 10, "a full stack comes back out")


func test_only_top_set_recipes_spend_them_and_only_the_listed_enemies_drop_them() -> void:
	for kind in RARES:
		assert_false(var_to_str(CombatTable.RARITY_BANDS).contains('"%s"' % kind), "%s is in no rarity band" % kind)
		for id in RecipeTable.ids():
			if RecipeTable.get_recipe(id)["inputs"].has(kind):
				assert_eq(ItemTable.set_of(id) != "", true, "%s: only a set item's recipe spends %s" % [id, kind])
		for enemy in CombatTable.ENEMIES:
			var drops := var_to_str(CombatTable.ENEMIES[enemy]["loot"]).contains('"%s"' % kind)
			assert_eq(drops, DROPPED_BY.get(kind, []).has(enemy), "%s drops %s only if listed" % [enemy, kind])


func test_the_all_gear_stash_leaves_them_out() -> void:
	var stash := FieldKit.gear_stash()
	for entry in stash:
		assert_false(RARES.has(entry["item"]), "%s has no slot" % entry["item"])
