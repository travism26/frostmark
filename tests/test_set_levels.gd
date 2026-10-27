## Sets on the ladder (#247): every set has a level (mid, mid-high, high or top) and a rung (mid
## beside bronze, mid-high beside iron, high beside steel, top above steel), read from the item
## table; every set piece weighs its rung's tier piece in its slot, and a quiver or cape 1; the
## mid to high sets have no recipe while the top-set recipes stand; and the worn weight the sim
## answers follows the rung.
extends "res://tests/run.gd".TestCase

const H := preload("res://tests/sim_helpers.gd")
const SimScript := preload("res://sim/sim.gd")
const Vocab := preload("res://sim/vocab.gd")

const STYLES := ["melee", "ranged", "magic"]


## The tier piece of `tier` that `kind` stands beside: the same slot, and for a weapon the same
## style; "" when the tier has none (a quiver or a cape).
func _tier_piece(kind: String, tier: String) -> String:
	for other in ItemTable.ITEMS:
		if ItemTable.tier(other) != tier or ItemTable.slot(other) != ItemTable.slot(kind):
			continue
		if ItemTable.ITEMS[other].get("style", "") == ItemTable.ITEMS[kind].get("style", ""):
			return other
	return ""


## The tier whose pieces a set's pieces weigh: its rung's, and steel's for a top set.
func _weight_tier(set_key: String) -> String:
	return ItemTable.TIERS[mini(ItemTable.set_rung(set_key), ItemTable.TIERS.size() - 1)]


func _set_pieces() -> Array[String]:
	var out: Array[String] = []
	for kind in ItemTable.ITEMS:
		if ItemTable.set_of(kind) != "":
			out.append(kind)
	return out


func test_every_one_of_the_21_sets_has_a_level() -> void:
	assert_eq(ItemTable.SETS.size(), 21, "21 sets")
	for set_key in ItemTable.SETS:
		assert_true(ItemTable.SET_LEVELS.has(ItemTable.set_level(set_key)), "%s has a level: %s" % [set_key, ItemTable.set_level(set_key)])
	for kind in _set_pieces():
		assert_true(ItemTable.SETS.has(ItemTable.set_of(kind)), "%s's set is on the ladder" % kind)


func test_each_style_has_one_mid_one_mid_high_one_high_and_four_top_sets() -> void:
	var count := {}
	for set_key in ItemTable.SETS:
		var key := "%s/%s" % [ItemTable.set_style(set_key), ItemTable.set_level(set_key)]
		count[key] = int(count.get(key, 0)) + 1
	for style in STYLES:
		assert_eq(count.get("%s/mid" % style, 0), 1, "one mid %s set" % style)
		assert_eq(count.get("%s/mid-high" % style, 0), 1, "one mid-high %s set" % style)
		assert_eq(count.get("%s/high" % style, 0), 1, "one high %s set" % style)
		assert_eq(count.get("%s/top" % style, 0), 4, "four top %s sets" % style)


func test_a_sets_style_is_the_style_of_its_weapon() -> void:
	for kind in _set_pieces():
		if ItemTable.slot(kind) == ItemTable.SLOT_WEAPON:
			assert_eq(ItemTable.set_style(ItemTable.set_of(kind)), ItemTable.ITEMS[kind]["style"], "%s's set fights by its style" % kind)


func test_the_item_table_answers_each_sets_level_and_rung() -> void:
	var expected := {
		"hearthguard": ["mid", "bronze"], "trapper": ["mid", "bronze"], "shardweaver": ["mid", "bronze"],
		"wolfmark": ["mid-high", "iron"], "wolfstalker": ["mid-high", "iron"], "rimecaller": ["mid-high", "iron"],
		"ruinwarden": ["high", "steel"], "steelpoint": ["high", "steel"], "glacier_warden": ["high", "steel"],
	}
	for set_key in expected:
		assert_eq(ItemTable.set_level(set_key), expected[set_key][0], "%s's level" % set_key)
		assert_eq(ItemTable.set_rung(set_key), ItemTable.tier_rank(expected[set_key][1]), "%s sits beside %s" % [set_key, expected[set_key][1]])
	for set_key in ItemTable.SETS:
		if expected.has(set_key):
			continue
		assert_eq(ItemTable.set_level(set_key), "top", "%s is a top set" % set_key)
		assert_true(ItemTable.set_rung(set_key) > ItemTable.tier_rank(ItemTable.TIER_STEEL), "%s sits above steel" % set_key)
	assert_eq(ItemTable.set_level(""), "", "no set, no level")
	assert_eq(ItemTable.set_rung(""), -1, "no set, no rung")
	assert_eq(ItemTable.set_level("steel"), "", "a tier is not a set")


func test_a_set_keeps_no_gear_tier() -> void:
	for kind in _set_pieces():
		assert_eq(ItemTable.tier(kind), "", "%s has a set level, not a gear tier" % kind)


func test_every_set_piece_weighs_its_rungs_tier_piece_in_its_slot() -> void:
	var n := 0
	for kind in _set_pieces():
		var slot := ItemTable.slot(kind)
		if slot == ItemTable.SLOT_QUIVER or slot == ItemTable.SLOT_CAPE:
			assert_eq(ItemTable.weight(kind), 1, "%s weighs 1: no tier has a %s" % [kind, slot])
			continue
		var tier := _weight_tier(ItemTable.set_of(kind))
		var beside := _tier_piece(kind, tier)
		assert_true(beside != "", "%s has a %s piece beside it" % [kind, tier])
		assert_eq(ItemTable.weight(kind), ItemTable.weight(beside), "%s weighs what %s weighs" % [kind, beside])
		n += 1
	assert_true(n >= 84, "every helm, body, legs and weapon of 21 sets is checked: %d" % n)


func test_mid_and_mid_high_pieces_get_lighter_and_high_and_top_keep_steels_weight() -> void:
	assert_eq(ItemTable.weight("hearthguard_helm"), ItemTable.weight("bronze_helm"))
	assert_eq(ItemTable.weight("hearthguard_legs"), ItemTable.weight("bronze_legs"))
	assert_eq(ItemTable.weight("hearthguard_broadsword"), ItemTable.weight("bronze_sword"))
	assert_true(ItemTable.weight("hearthguard_broadsword") < ItemTable.weight("steel_sword"), "a mid sword is lighter than steel's")
	assert_eq(ItemTable.weight("wolfmark_axe"), ItemTable.weight("iron_sword"), "a set weapon weighs its rung's weapon of its style, not a tool")
	assert_eq(ItemTable.weight("wolfstalker_helm"), ItemTable.weight("iron_helm"))
	assert_eq(ItemTable.weight("ruinwarden_helm"), ItemTable.weight("steel_helm"))
	assert_eq(ItemTable.weight("emberheart_helm"), ItemTable.weight("steel_helm"))
	assert_eq(ItemTable.weight("wolfstalker_quiver"), 1)
	assert_eq(ItemTable.weight("ruinwarden_mage_cape"), 1)


func test_every_other_stat_stays_the_steel_placeholder() -> void:
	for kind in _set_pieces():
		var slot := ItemTable.slot(kind)
		if slot == ItemTable.SLOT_QUIVER or slot == ItemTable.SLOT_CAPE:
			continue
		var steel := _tier_piece(kind, ItemTable.TIER_STEEL)
		for stat in ["value", "defence", "style", "power", "speed", "reach", "ammo"]:
			assert_eq(ItemTable.ITEMS[kind].get(stat), ItemTable.ITEMS[steel].get(stat), "%s's %s is %s's" % [kind, stat, steel])


func test_no_mid_to_high_set_piece_has_a_recipe_and_every_top_set_piece_keeps_one() -> void:
	var top_recipes := 0
	for kind in _set_pieces():
		var top := ItemTable.set_level(ItemTable.set_of(kind)) == ItemTable.LEVEL_TOP
		assert_eq(RecipeTable.has(kind), top, "%s has a recipe only as a top-set piece" % kind)
		if top:
			top_recipes += 1
	assert_eq(top_recipes, 58, "the 58 top-set recipes (#184) stand")


func test_the_worn_weight_follows_the_rung() -> void:
	var mid := ["hearthguard_helm", "hearthguard_body", "hearthguard_legs", "hearthguard_broadsword"]
	var bronze := ["bronze_helm", "bronze_body", "bronze_legs", "bronze_sword"]
	var high := ["ruinwarden_helm", "ruinwarden_body", "ruinwarden_legs", "ruinwarden_greatsword"]
	var steel := ["steel_helm", "steel_body", "steel_legs", "steel_sword"]
	assert_eq(_worn_weight(mid), _worn_weight(bronze), "a worn mid set weighs a worn bronze set")
	assert_eq(_worn_weight(high), _worn_weight(steel), "a worn high set weighs a worn steel set")
	assert_true(_worn_weight(mid) < _worn_weight(high), "a mid set is lighter than a high one")


## The carry weight of a new character that equipped `pieces` from an otherwise empty pack.
func _worn_weight(pieces: Array) -> int:
	var sim := SimScript.new()
	var entries: Array = []
	for kind in pieces:
		entries.append({"item": kind, "count": 1})
	H.set_pack(sim, entries)
	var snap := sim.snapshot()
	for slot in ItemTable.EQUIPMENT_SLOTS:
		snap["inventory"]["equipment"][slot] = ""
	sim.restore(snap)
	for i in pieces.size():
		assert_true(sim.command(Vocab.EQUIP, {"index": i})["ok"], "equip %s" % pieces[i])
		H.run(sim, 1)
	for kind in pieces:
		assert_eq(sim.state["inventory"]["equipment"][ItemTable.slot(kind)], kind, "%s is worn" % kind)
	return sim.carry_weight()
