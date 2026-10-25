## The gear-look table: every piece of gear has a look, every look is complete, the builders
## draw what the look says (the tier shape rules are data now), and gear with no look draws in
## magenta. How the looks read on screen is judged from tools/gear_shots.gd.
extends "res://tests/run.gd".TestCase

const GearLookScript := preload("res://scenes/gear_look.gd")
const CharacterGearScript := preload("res://scenes/character_gear.gd")

## The parts each equipment slot draws.
const SLOT_PARTS := {
	ItemTable.SLOT_HELM: [GearLookScript.PART_HEAD],
	ItemTable.SLOT_BODY: [GearLookScript.PART_BODY],
	ItemTable.SLOT_LEGS: [GearLookScript.PART_HIPS, GearLookScript.PART_SHIN],
	ItemTable.SLOT_WEAPON: [GearLookScript.PART_WEAPON],
	ItemTable.SLOT_TOOL: [GearLookScript.PART_TOOL],
}


func test_every_piece_of_gear_has_a_look_and_is_drawn_in_its_base() -> void:
	for item in ItemTable.ITEMS:
		if ItemTable.slot(item) == "":
			assert_false(GearLookScript.has(item), "%s is not gear, so has no look" % item)
			continue
		assert_true(GearLookScript.has(item), "%s has a look" % item)
		assert_eq(CharacterGearScript.colour_of(item), GearLookScript.palette(item)["base"], "%s is drawn in its look's base" % item)
	for item in GearLookScript.LOOKS:
		assert_true(ItemTable.has(item), "the look %s is for an item in the table" % item)


func test_every_look_is_complete() -> void:
	for item in GearLookScript.LOOKS:
		var look: Dictionary = GearLookScript.LOOKS[item]
		var colours: Dictionary = look["palette"]
		for field in GearLookScript.PALETTE_FIELDS:
			assert_true(colours.has(field), "%s's palette has %s" % [item, field])
		assert_eq(colours.size(), GearLookScript.PALETTE_FIELDS.size(), "%s's palette carries only the known fields" % item)
		var parts: Array = SLOT_PARTS[ItemTable.slot(item)]
		for part in look:
			if part == "palette":
				continue
			assert_true(parts.has(part), "%s draws %s, a part of its slot" % [item, part])
			var own: Dictionary = look[part]
			if own.is_empty():
				continue
			assert_true(GearLookScript.SHAPES.has(own["shape"]), "%s's %s is a known shape" % [item, part])
			var numbers: Dictionary = GearLookScript.SHAPES.get(own["shape"], {})
			for key in own:
				assert_true(key == "shape" or numbers.has(key), "%s's %s %s is one of its shape's numbers" % [item, part, key])
		for part in parts:
			assert_true(look.has(part), "%s says what it draws on %s" % [item, part])


func test_a_piece_lays_its_own_numbers_over_its_shape() -> void:
	var helm := GearLookScript.piece("iron_helm", GearLookScript.PART_HEAD)
	assert_eq(helm["shape"], GearLookScript.SHAPE_HELM)
	assert_true(helm["band"] and helm["nose_guard"], "the entry's switches win")
	assert_eq(helm["radius"], GearLookScript.SHAPES[GearLookScript.SHAPE_HELM]["radius"], "the shape fills in the rest")
	assert_eq(GearLookScript.piece("bronze_legs", GearLookScript.PART_SHIN), {}, "an empty piece draws nothing")


func _meshes(piece: Node3D) -> int:
	return piece.find_children("*", "MeshInstance3D", true, false).size()


func test_the_tier_shape_rules_come_from_the_looks() -> void:
	# A band on the helm from bronze and a nose guard from iron, pauldrons from bronze, a greave
	# from iron: the parts each tier's piece draws.
	var parts := {
		"wooden": [1, 1, false], "bronze": [2, 3, false], "iron": [3, 3, true], "steel": [3, 3, true],
	}
	for tier in parts:
		var helm := CharacterGearScript.head_piece(tier + "_helm")
		assert_eq(_meshes(helm), parts[tier][0], "the %s helm's parts" % tier)
		helm.free()
		var body := CharacterGearScript.body_piece(tier + "_body")
		assert_eq(_meshes(body), parts[tier][1], "the %s body's parts" % tier)
		body.free()
		var shin := CharacterGearScript.shin_piece(tier + "_legs")
		assert_eq(shin != null, parts[tier][2], "a greave on %s legs" % tier)
		if shin != null:
			shin.free()
	for item in ["bronze_helm", "iron_helm", "steel_helm"]:
		assert_true(GearLookScript.piece(item, GearLookScript.PART_HEAD)["band"], "%s's band is in its look" % item)
	for item in ["bronze_body", "iron_body", "steel_body"]:
		assert_true(GearLookScript.piece(item, GearLookScript.PART_BODY)["pauldrons"], "%s's pauldrons are in its look" % item)


func test_the_wooden_weapon_is_a_club_and_the_rod_a_rod() -> void:
	assert_eq(GearLookScript.piece("wooden_club", GearLookScript.PART_WEAPON)["shape"], GearLookScript.SHAPE_CLUB)
	for item in ["bronze_sword", "iron_sword", "steel_sword"]:
		assert_eq(GearLookScript.piece(item, GearLookScript.PART_WEAPON)["shape"], GearLookScript.SHAPE_SWORD, "%s is a sword" % item)
	assert_eq(GearLookScript.piece("fishing_rod", GearLookScript.PART_TOOL)["shape"], GearLookScript.SHAPE_ROD)


func test_gear_with_no_look_draws_in_magenta() -> void:
	var item := "no_such_gear"
	assert_false(GearLookScript.has(item))
	assert_eq(CharacterGearScript.colour_of(item), Color.MAGENTA, "a missing look's colour")
	for make in [CharacterGearScript.head_piece, CharacterGearScript.body_piece, CharacterGearScript.hips_piece]:
		var piece: Node3D = make.call(item)
		assert_true(_meshes(piece) > 0, "%s still draws its slot's plain shape" % piece.name)
		for node in piece.find_children("*", "MeshInstance3D", true, false):
			var m := (node as MeshInstance3D).mesh.surface_get_material(0) as StandardMaterial3D
			assert_eq(m.albedo_color, Color.MAGENTA, "%s is drawn in magenta" % piece.name)
		piece.free()
	assert_true(CharacterGearScript.shin_piece(item) == null, "a missing look leaves the shin bare")


func test_the_gear_node_keeps_no_colour_table_of_its_own() -> void:
	var script: Script = CharacterGearScript
	var consts := script.get_script_constant_map()
	for name in consts:
		assert_false(consts[name] is Color, "%s is a colour outside the look table" % name)
		assert_false(consts[name] is Dictionary, "%s is a table outside the look table" % name)
