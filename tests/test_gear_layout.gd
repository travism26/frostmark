## The gear layout: only equipped items are drawn, the item in use in the hand and at most one
## more on the back; the tool comes to the hand at work and the weapon is put away. And the
## barbarian glb's own axes, shield and mug are all on the list CharacterView hides, so none of
## them shows beside the equipped gear. The meshes themselves are judged from screenshots.
extends "res://tests/run.gd".TestCase

const GearLayoutScript := preload("res://scenes/gear_layout.gd")
const CharacterViewScript := preload("res://scenes/character_view.gd")
const CharacterGearScript := preload("res://scenes/character_gear.gd")

## The barbarian's own body: every other mesh in the glb is a prop to hide.
const BODY_PARTS := [
	"Barbarian_ArmLeft", "Barbarian_ArmRight", "Barbarian_Body", "Barbarian_Head",
	"Barbarian_LegLeft", "Barbarian_LegRight", "Barbarian_Cape",
]


func _gear(weapon: String, tool: String, body := "", helm := "", legs := "") -> Dictionary:
	return {
		ItemTable.SLOT_WEAPON: weapon, ItemTable.SLOT_TOOL: tool,
		ItemTable.SLOT_HELM: helm, ItemTable.SLOT_BODY: body, ItemTable.SLOT_LEGS: legs,
	}


func test_nothing_equipped_draws_nothing() -> void:
	for working in [false, true]:
		var layout := GearLayoutScript.place(_gear("", ""), working)
		for place in GearLayoutScript.PLACES:
			assert_eq(layout[place], "", "%s empty (working %s)" % [place, working])


func test_at_rest_the_weapon_is_in_the_hand_and_the_tool_on_the_back() -> void:
	var layout := GearLayoutScript.place(_gear("steel_bow", "steel_pickaxe", "iron_body"), false)
	assert_eq(layout[GearLayoutScript.HAND], "steel_bow")
	assert_eq(layout[GearLayoutScript.BACK], "steel_pickaxe")
	assert_eq(layout[GearLayoutScript.BODY], "iron_body")


func test_at_work_the_tool_is_in_the_hand_and_the_weapon_put_away() -> void:
	var layout := GearLayoutScript.place(_gear("steel_sword", "steel_axe", "iron_body"), true)
	assert_eq(layout[GearLayoutScript.HAND], "steel_axe")
	assert_eq(layout[GearLayoutScript.BACK], "", "nothing on the back while the tool is out")
	assert_eq(layout[GearLayoutScript.BODY], "iron_body", "the body piece stays on at work")


func test_each_armour_piece_has_its_own_place_and_shows_only_when_worn() -> void:
	var full := GearLayoutScript.place(_gear("", "", "wooden_body", "wooden_helm", "wooden_legs"), false)
	assert_eq(full[GearLayoutScript.HEAD], "wooden_helm")
	assert_eq(full[GearLayoutScript.BODY], "wooden_body")
	assert_eq(full[GearLayoutScript.LEGS], "wooden_legs")
	var helm_only := GearLayoutScript.place(_gear("", "", "", "iron_helm"), false)
	assert_eq(helm_only[GearLayoutScript.HEAD], "iron_helm")
	assert_eq(helm_only[GearLayoutScript.BODY], "", "no body drawn when none is worn, whatever the helm's tier")
	assert_eq(helm_only[GearLayoutScript.LEGS], "")
	var legs_only := GearLayoutScript.place(_gear("", "", "", "", "steel_legs"), true)
	assert_eq(legs_only[GearLayoutScript.HEAD], "", "no helm drawn when none is worn")
	assert_eq(legs_only[GearLayoutScript.LEGS], "steel_legs", "the legs stay on at work")


func test_fur_pieces_are_worn_like_armour_and_drawn_in_fur() -> void:
	var full := GearLayoutScript.place(_gear("", "", "fur_coat", "fur_hood", "fur_legs"), false)
	assert_eq(full[GearLayoutScript.HEAD], "fur_hood")
	assert_eq(full[GearLayoutScript.BODY], "fur_coat")
	assert_eq(full[GearLayoutScript.LEGS], "fur_legs")
	for kind in ["fur_hood", "fur_coat", "fur_legs"]:
		assert_eq(CharacterGearScript.colour_of(kind), CharacterGearScript.FUR_COLOR, "%s is drawn in fur" % kind)
		assert_ne(CharacterGearScript.colour_of(kind), Color.MAGENTA, "%s is not the missing-colour magenta" % kind)
	assert_eq(CharacterGearScript.colour_of("steel_body"), CharacterGearScript.TIER_COLORS[ItemTable.TIER_STEEL], "metal keeps its tier colour")


func test_bare_handed_with_a_tool() -> void:
	var resting := GearLayoutScript.place(_gear("", "steel_axe"), false)
	assert_eq(resting[GearLayoutScript.HAND], "", "hands empty at rest")
	assert_eq(resting[GearLayoutScript.BACK], "steel_axe")
	var working := GearLayoutScript.place(_gear("", "fishing_rod"), true)
	assert_eq(working[GearLayoutScript.HAND], "fishing_rod")
	assert_eq(working[GearLayoutScript.BACK], "")


func test_working_without_a_tool_keeps_the_weapon_in_hand() -> void:
	var layout := GearLayoutScript.place(_gear("steel_staff", ""), true)
	assert_eq(layout[GearLayoutScript.HAND], "steel_staff")
	assert_eq(layout[GearLayoutScript.BACK], "")


func test_every_item_drawn_is_one_equipped() -> void:
	for weapon in ["", "wooden_club", "steel_sword", "iron_bow", "bronze_staff"]:
		for tool in ["", "wooden_axe", "steel_pickaxe", "fishing_rod"]:
			for working in [false, true]:
				var gear := _gear(weapon, tool, "steel_body", "steel_helm", "steel_legs")
				var layout := GearLayoutScript.place(gear, working)
				var drawn: Array = []
				for place in GearLayoutScript.PLACES:
					if layout[place] != "":
						drawn.append(layout[place])
				for item in drawn:
					assert_true(gear.values().has(item), "%s is equipped" % item)
					assert_eq(drawn.count(item), 1, "%s drawn once" % item)


func test_the_barbarians_own_props_are_all_hidden() -> void:
	var model: Node = (load(CharacterViewScript.MODEL) as PackedScene).instantiate()
	var props: Array = []
	for node in model.find_children("*", "MeshInstance3D", true, false):
		if not BODY_PARTS.has(String(node.name)):
			props.append(String(node.name))
	model.free()
	for name in ["1H_Axe", "1H_Axe_Offhand", "2H_Axe", "Barbarian_Round_Shield", "Mug"]:
		assert_true(props.has(name), "the glb still carries %s" % name)
	for name in props:
		assert_true(CharacterViewScript.BUILT_IN_GEAR.has(name), "%s is hidden" % name)


## The live children of `node`: those not already queued to go with the gear they drew.
static func _live(node: Node, out: Array = []) -> Array:
	for child in node.get_children():
		if child.is_queued_for_deletion():
			continue
		out.append(String(child.name))
		_live(child, out)
	return out


func test_fur_pieces_draw_their_own_shapes_in_fur_and_metal_keeps_its_own() -> void:
	var shapes := {
		"fur_hood": [CharacterGearScript.head_piece, CharacterGearScript.SHAPE_FUR_HOOD, CharacterGearScript.SHAPE_HELM],
		"fur_coat": [CharacterGearScript.body_piece, CharacterGearScript.SHAPE_FUR_COAT, CharacterGearScript.SHAPE_VEST],
		"fur_legs": [CharacterGearScript.hips_piece, CharacterGearScript.SHAPE_FUR_LEGGINGS, CharacterGearScript.SHAPE_KILT],
	}
	for kind in shapes:
		var make: Callable = shapes[kind][0]
		var fur: Node3D = make.call(kind)
		assert_eq(fur.name, shapes[kind][1], "%s draws its own fur shape" % kind)
		var in_fur := 0
		for node in fur.find_children("*", "MeshInstance3D", true, false):
			var m := (node as MeshInstance3D).mesh.surface_get_material(0) as StandardMaterial3D
			assert_true(m != null, "%s has a flat material" % kind)
			if m != null and m.albedo_color == CharacterGearScript.FUR_COLOR:
				in_fur += 1
		assert_true(in_fur > 0, "%s has a part in the fur colour" % kind)
		fur.free()
		for metal in ["wooden", "bronze", "iron", "steel"]:
			var item := "%s_%s" % [metal, ItemTable.slot(kind)]
			var piece: Node3D = make.call(item)
			assert_eq(piece.name, shapes[kind][2], "%s keeps the metal shape" % item)
			piece.free()
	var band := CharacterGearScript.shin_piece("fur_legs")
	assert_eq(band.name, CharacterGearScript.SHAPE_FUR_BAND, "fur leggings put a band at the shin")
	band.free()
	var greave := CharacterGearScript.shin_piece("iron_legs")
	assert_eq(greave.name, CharacterGearScript.SHAPE_GREAVE, "iron legs put a greave at the shin")
	greave.free()
	assert_true(CharacterGearScript.shin_piece("bronze_legs") == null, "bronze legs leave the shin bare")


func test_swapping_fur_and_metal_in_a_slot_redraws_it_both_ways() -> void:
	var root := Node3D.new()
	var view := CharacterViewScript.new()
	var gear := CharacterGearScript.new()
	root.add_child(view)
	root.add_child(gear)
	var head := view.bone_slot("head")
	var hips := view.bone_slot("hips")
	var shin := view.bone_slot("lowerleg_l")
	assert_true(head != null and hips != null and shin != null, "the barbarian has head, hips and shin slots")
	gear.show_equipment({ItemTable.SLOT_HELM: "fur_hood", ItemTable.SLOT_LEGS: "fur_legs"})
	assert_true(_live(head).has(CharacterGearScript.SHAPE_FUR_HOOD), "the fur hood is on the head")
	assert_true(_live(hips).has(CharacterGearScript.SHAPE_FUR_LEGGINGS), "the fur leggings are on the hips")
	assert_true(_live(shin).has(CharacterGearScript.SHAPE_FUR_BAND), "a fur band is on the shin")
	gear.show_equipment({ItemTable.SLOT_HELM: "iron_helm", ItemTable.SLOT_LEGS: "iron_legs"})
	assert_true(_live(head).has(CharacterGearScript.SHAPE_HELM), "the iron helm replaces the hood")
	assert_false(_live(head).has(CharacterGearScript.SHAPE_FUR_HOOD), "the hood is gone from the head")
	assert_true(_live(hips).has(CharacterGearScript.SHAPE_KILT), "the kilt replaces the leggings")
	assert_false(_live(hips).has(CharacterGearScript.SHAPE_FUR_LEGGINGS), "the leggings are gone from the hips")
	assert_true(_live(shin).has(CharacterGearScript.SHAPE_GREAVE), "a greave replaces the band")
	assert_false(_live(shin).has(CharacterGearScript.SHAPE_FUR_BAND), "the band is gone from the shin")
	gear.show_equipment({ItemTable.SLOT_HELM: "fur_hood", ItemTable.SLOT_LEGS: "wooden_legs"})
	assert_true(_live(head).has(CharacterGearScript.SHAPE_FUR_HOOD), "the hood comes back")
	assert_false(_live(head).has(CharacterGearScript.SHAPE_HELM), "the helm is gone again")
	assert_true(_live(hips).has(CharacterGearScript.SHAPE_KILT), "wooden legs are a kilt")
	assert_false(_live(shin).has(CharacterGearScript.SHAPE_GREAVE) or _live(shin).has(CharacterGearScript.SHAPE_FUR_BAND), "wooden legs leave the shin bare")
	root.free()


func test_every_armour_look_is_there_to_warm_up() -> void:
	var all := CharacterGearScript.samples()
	var names: Array = []
	for child in all.get_children():
		names.append(String(child.name))
	for shape in [CharacterGearScript.SHAPE_FUR_HOOD, CharacterGearScript.SHAPE_FUR_COAT, CharacterGearScript.SHAPE_FUR_LEGGINGS, CharacterGearScript.SHAPE_FUR_BAND, CharacterGearScript.SHAPE_HELM, CharacterGearScript.SHAPE_VEST, CharacterGearScript.SHAPE_KILT, CharacterGearScript.SHAPE_GREAVE]:
		assert_true(names.has(shape), "a %s is sampled" % shape)
	var armour := 0
	for item in ItemTable.ITEMS:
		if ItemTable.ARMOUR_SLOTS.has(ItemTable.slot(item)):
			armour += 1
	assert_true(all.get_child_count() >= armour, "at least one sample per armour piece (%d)" % armour)
	for node in all.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		assert_true(mi.mesh != null and mi.mesh.surface_get_material(0) != null, "%s has a look to warm up" % node.get_parent().name)
	all.free()
