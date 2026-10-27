## The kit builders (#160): each is a static builder that takes a look and a palette, names its
## root after its shape, draws at least two tones, sizes its left and right sides on their own
## where it has sides, shines only when its look's glow is above 0, never carries a light or
## motes (#250), and has a sample in CharacterGear.samples() for
## the warm-up. How the shapes read on screen is judged from tools/kit_shots.gd.
extends "res://tests/run.gd".TestCase

const GearLookScript := preload("res://scenes/gear_look.gd")
const CharacterGearScript := preload("res://scenes/character_gear.gd")

## The builders with a left and a right side, and the look numbers that size each.
const SIDED := {
	GearLookScript.SHAPE_STACKED_PLATES: ["size_left", "size_right"],
	GearLookScript.SHAPE_UNDER_ROBE: ["panel_left", "panel_right"],
	GearLookScript.SHAPE_CLOAK: ["length_left", "length_right"],
	GearLookScript.SHAPE_ANTLERS: ["length_left", "length_right"],
}


static func _build(own: Dictionary, colours := GearLookScript.KIT) -> Node3D:
	return CharacterGearScript.kit_builder(own["shape"]).call(GearLookScript.numbers(own), colours)


static func _materials(piece: Node) -> Array:
	var out: Array = []
	for node in piece.find_children("*", "MeshInstance3D", true, false):
		out.append((node as MeshInstance3D).mesh.surface_get_material(0) as StandardMaterial3D)
	return out


static func _tones(piece: Node) -> Array:
	var out: Array = []
	for m in _materials(piece):
		if not out.has(m.albedo_color):
			out.append(m.albedo_color)
	return out


static func _glowing(piece: Node) -> int:
	var n := 0
	for m in _materials(piece):
		if m.emission_enabled:
			n += 1
	return n


## The bounds of every mesh under `node`, in `node`'s frame.
static func _bounds(node: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for mesh in node.find_children("*", "MeshInstance3D", true, false):
		var t := Transform3D.IDENTITY
		var n: Node = mesh
		while n != node:
			t = (n as Node3D).transform * t
			n = n.get_parent()
		var b := t * (mesh as MeshInstance3D).mesh.get_aabb()
		out = b if first else out.merge(b)
		first = false
	return out


func test_every_kit_shape_has_a_builder_named_after_it_that_draws_two_tones() -> void:
	for shape in GearLookScript.KIT_SHAPES:
		assert_true(GearLookScript.SHAPES.has(shape), "%s has its numbers in the shape table" % shape)
		var build := CharacterGearScript.kit_builder(shape)
		assert_true(build.is_valid(), "%s has a builder" % shape)
		var piece: Node3D = build.call(GearLookScript.numbers({"shape": shape}), GearLookScript.KIT)
		assert_eq(String(piece.name), shape, "the builder's root is named after its shape")
		assert_true(_tones(piece).size() >= 2, "%s draws at least two tones (%s)" % [shape, _tones(piece)])
		piece.free()
	assert_false(CharacterGearScript.kit_builder(GearLookScript.SHAPE_HELM).is_valid(), "a helm is not a kit shape")


func test_every_cloak_outline_and_collar_kind_draws_two_tones() -> void:
	for outline in GearLookScript.OUTLINES:
		var piece := _build({"shape": GearLookScript.SHAPE_CLOAK, "outline": outline})
		assert_true(_tones(piece).size() >= 2, "a %s cloak draws at least two tones" % outline)
		assert_true(_materials(piece).size() >= 2, "a %s cloak has parts" % outline)
		piece.free()
	for kind in GearLookScript.COLLARS:
		var piece := _build({"shape": GearLookScript.SHAPE_COLLAR, "kind": kind})
		assert_true(_tones(piece).size() >= 2, "a %s collar draws at least two tones" % kind)
		piece.free()
	for jagged in [false, true]:
		var piece := _build({"shape": GearLookScript.SHAPE_FIN, "jagged": jagged})
		assert_true(_tones(piece).size() >= 2, "a fin (jagged %s) draws at least two tones" % jagged)
		piece.free()
	for tips in GearLookScript.QUIVER_TIPS:
		var piece := _build({"shape": GearLookScript.SHAPE_QUIVER, "tips": tips})
		assert_true(_tones(piece).size() >= 2, "a quiver with %s draws at least two tones" % tips)
		piece.free()
	for round in [false, true]:
		var piece := _build({"shape": GearLookScript.SHAPE_EDGE_TRIM, "round": round})
		assert_true(_tones(piece).size() >= 2, "edge trim (round %s) draws at least two tones" % round)
		piece.free()


func test_a_look_with_unequal_sides_draws_unequal_sides() -> void:
	for shape in SIDED:
		var left_key: String = SIDED[shape][0]
		var right_key: String = SIDED[shape][1]
		var numbers: Dictionary = GearLookScript.SHAPES[shape]
		var even := _build({"shape": shape, left_key: numbers[left_key], right_key: numbers[left_key]})
		var left: Node3D = even.find_child(CharacterGearScript.SIDE_LEFT, true, false)
		var right: Node3D = even.find_child(CharacterGearScript.SIDE_RIGHT, true, false)
		assert_true(left != null and right != null, "%s has a Left and a Right side" % shape)
		assert_true(_bounds(left).size.is_equal_approx(_bounds(right).size), "%s's sides match when the look's do (%s, %s)" % [shape, _bounds(left).size, _bounds(right).size])
		even.free()
		var own := {"shape": shape, left_key: numbers[left_key] * 1.5, right_key: numbers[right_key] * 0.75}
		var uneven := _build(own)
		left = uneven.find_child(CharacterGearScript.SIDE_LEFT, true, false)
		right = uneven.find_child(CharacterGearScript.SIDE_RIGHT, true, false)
		assert_true(_bounds(left).size.y > _bounds(right).size.y, "%s's left is the longer side when its look says so" % shape)
		uneven.free()
	var plates := _build({"shape": GearLookScript.SHAPE_STACKED_PLATES, "plates_left": 3, "plates_right": 2})
	var left_plates: int = plates.find_child(CharacterGearScript.SIDE_LEFT, true, false).find_children("*", "MeshInstance3D", true, false).size()
	var right_plates: int = plates.find_child(CharacterGearScript.SIDE_RIGHT, true, false).find_children("*", "MeshInstance3D", true, false).size()
	assert_eq(left_plates - right_plates, 1, "one more plate on the left when the look stacks three there")
	plates.free()


func test_glow_above_zero_turns_emission_on_and_zero_leaves_it_off() -> void:
	for shape in GearLookScript.KIT_SHAPES:
		var dark := _build({"shape": shape, "glow": 0.0})
		assert_eq(_glowing(dark), 0, "%s with no glow has no emission" % shape)
		dark.free()
		var lit := _build({"shape": shape, "glow": 1.2})
		assert_true(_glowing(lit) > 0, "%s with glow has emission on" % shape)
		for m in _materials(lit):
			if m.emission_enabled:
				assert_eq(m.emission, GearLookScript.KIT["glow"], "%s shines in the palette's glow colour" % shape)
				assert_almost_eq(m.emission_energy_multiplier, 1.2, 0.0001, "%s shines as bright as its look says" % shape)
		lit.free()


func test_no_kit_shape_carries_a_light_or_motes() -> void:
	# Glow is emission only (#250): nothing on the character lights the snow or drifts motes.
	for own in GearLookScript.KIT_SAMPLES:
		var piece := _build(own)
		assert_eq(piece.find_children("*", "Light3D", true, false).size(), 0, "%s's sample carries no light" % own["shape"])
		assert_eq(piece.find_children("*", "CPUParticles3D", true, false).size(), 0, "%s's sample carries no motes" % own["shape"])
		assert_eq(piece.find_children("*", "GPUParticles3D", true, false).size(), 0, "%s's sample carries no particles" % own["shape"])
		piece.free()
	for shape in GearLookScript.SHAPES:
		for key in ["light", "motes"]:
			assert_false((GearLookScript.SHAPES[shape] as Dictionary).has(key), "a %s has no %s number" % [shape, key])


func test_the_samples_hold_one_of_each_kit_shape_and_no_light_or_motes() -> void:
	var shapes: Array = []
	for own in GearLookScript.KIT_SAMPLES:
		shapes.append(own["shape"])
		for key in own:
			assert_true(key == "shape" or GearLookScript.SHAPES[own["shape"]].has(key), "the %s sample's %s is one of its numbers" % [own["shape"], key])
	for shape in GearLookScript.KIT_SHAPES:
		assert_eq(shapes.count(shape), 1, "one %s sample" % shape)
	var all := CharacterGearScript.samples()
	var names: Array = []
	for child in all.get_children():
		names.append(String(child.name))
	for shape in GearLookScript.KIT_SHAPES:
		assert_true(names.has(shape), "a %s is sampled for the warm-up" % shape)
	assert_eq(all.find_children("*", "Light3D", true, false).size(), 0, "the samples carry no light")
	assert_eq(all.find_children("*", "CPUParticles3D", true, false).size(), 0, "the samples carry no motes")
	assert_eq(all.find_children("*", "GPUParticles3D", true, false).size(), 0, "the samples carry no particles")
	var left: Node3D = all.find_child(GearLookScript.SHAPE_CLOAK, false, false).find_child(CharacterGearScript.SIDE_LEFT, true, false)
	var right: Node3D = all.find_child(GearLookScript.SHAPE_CLOAK, false, false).find_child(CharacterGearScript.SIDE_RIGHT, true, false)
	assert_ne(_bounds(left).size.y, _bounds(right).size.y, "the cloak sample has unequal sides")
	all.free()


func test_the_kit_changes_no_tier_or_fur_look() -> void:
	for item in GearLookScript.LOOKS:
		if ItemTable.set_of(item) != "":
			continue  # the sets are built from the kit
		var look: Dictionary = GearLookScript.LOOKS[item]
		for part in look:
			if part == "palette" or (look[part] as Dictionary).is_empty():
				continue
			assert_false(GearLookScript.KIT_SHAPES.has(look[part]["shape"]), "%s's %s is not a kit shape" % [item, part])
			assert_false((look[part] as Dictionary).has(GearLookScript.LAYERS), "%s's %s layers nothing on" % [item, part])
			for key in look[part]:
				assert_false(String(key).ends_with("tone"), "%s's %s keeps its shape's tones" % [item, part])
	for shape in GearLookScript.KIT_SHAPES:
		var numbers: Dictionary = GearLookScript.SHAPES[shape]
		assert_true(numbers.has("glow"), "%s has a glow number" % shape)
		for key in numbers:
			var name := String(key)
			assert_true(name == name.to_lower() and name.replace("_", "a").is_valid_identifier(), "%s's %s is a plain snake_case number" % [shape, name])
