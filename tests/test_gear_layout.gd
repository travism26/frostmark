## The gear layout: only equipped items are drawn, the item in use in the hand and at most one
## more on the back; the tool comes to the hand at work and the weapon is put away. And the
## barbarian glb's own axes, shield and mug are all on the list CharacterView hides, so none of
## them shows beside the equipped gear. The meshes themselves are judged from screenshots.
extends "res://tests/run.gd".TestCase

const GearLayoutScript := preload("res://scenes/gear_layout.gd")
const CharacterViewScript := preload("res://scenes/character_view.gd")

## The barbarian's own body: every other mesh in the glb is a prop to hide.
const BODY_PARTS := [
	"Barbarian_ArmLeft", "Barbarian_ArmRight", "Barbarian_Body", "Barbarian_Head",
	"Barbarian_LegLeft", "Barbarian_LegRight", "Barbarian_Cape",
]


func _gear(weapon: String, tool: String, armour := "") -> Dictionary:
	return {ItemTable.SLOT_WEAPON: weapon, ItemTable.SLOT_TOOL: tool, ItemTable.SLOT_ARMOUR: armour}


func test_nothing_equipped_draws_nothing() -> void:
	for working in [false, true]:
		var layout := GearLayoutScript.place(_gear("", ""), working)
		for place in GearLayoutScript.PLACES:
			assert_eq(layout[place], "", "%s empty (working %s)" % [place, working])


func test_at_rest_the_weapon_is_in_the_hand_and_the_tool_on_the_back() -> void:
	var layout := GearLayoutScript.place(_gear("steel_bow", "steel_pickaxe", "iron_armour"), false)
	assert_eq(layout[GearLayoutScript.HAND], "steel_bow")
	assert_eq(layout[GearLayoutScript.BACK], "steel_pickaxe")
	assert_eq(layout[GearLayoutScript.BODY], "iron_armour")


func test_at_work_the_tool_is_in_the_hand_and_the_weapon_put_away() -> void:
	var layout := GearLayoutScript.place(_gear("steel_sword", "steel_axe", "iron_armour"), true)
	assert_eq(layout[GearLayoutScript.HAND], "steel_axe")
	assert_eq(layout[GearLayoutScript.BACK], "", "nothing on the back while the tool is out")
	assert_eq(layout[GearLayoutScript.BODY], "iron_armour", "armour stays on at work")


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
				var gear := _gear(weapon, tool, "steel_armour")
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
