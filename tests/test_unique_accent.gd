## A unique piece's accent (#251): a unique piece worn on the character shows an emissive accent
## in its rarity band's colour, blue for rare, purple for super rare and gold for ultra rare, read
## from the one table of band colours (RarityLook), with no light or particles. No real unique
## piece exists yet (#243), so stand-in items carry those bands and stand-in looks draw them.
## Checked through the screen seam: each piece is put on a CharacterView by CharacterGear from
## its equipment slot, alone and beside tiers and sets, since pieces are unlocked one at a time
## and mixed.
extends "res://tests/run.gd".TestCase

const GearLookScript := preload("res://scenes/gear_look.gd")
const CharacterGearScript := preload("res://scenes/character_gear.gd")
const CharacterViewScript := preload("res://scenes/character_view.gd")

## The node classes that would put a light or particles on the character.
const FX_CLASSES := ["Light3D", "GPUParticles3D", "CPUParticles3D"]

## A stand-in unique piece in each of three slots, one per band.
const STAND_IN_ITEMS := {
	"stand_in_rare_helm": {
		"label": "Stand-in rare helm", "stack": 1, "weight": 2, "value": 200, "slot": ItemTable.SLOT_HELM,
		"defence": 1, "rarity": ItemTable.RARITY_RARE,
	},
	"stand_in_super_rare_body": {
		"label": "Stand-in super rare body", "stack": 1, "weight": 4, "value": 400, "slot": ItemTable.SLOT_BODY,
		"defence": 1, "rarity": ItemTable.RARITY_SUPER_RARE,
	},
	"stand_in_ultra_rare_sword": {
		"label": "Stand-in ultra rare sword", "stack": 1, "weight": 3, "value": 800, "slot": ItemTable.SLOT_WEAPON,
		"style": "melee", "power": 10, "speed": 2, "reach": 1.5, "rarity": ItemTable.RARITY_ULTRA_RARE,
	},
	# The rare helm's look on an uncommon item, to show the band is what lights the accent.
	"stand_in_uncommon_helm": {
		"label": "Stand-in uncommon helm", "stack": 1, "weight": 2, "value": 50, "slot": ItemTable.SLOT_HELM,
		"defence": 1, "rarity": ItemTable.RARITY_UNCOMMON,
	},
}
## Their looks: steel with an accent part each (a row of studs on the helm, pauldrons on the
## body, a grip and pommel on the broadsword). None names a band colour.
const HELM_LOOK := {"palette": GearLookScript.STEEL, GearLookScript.PART_HEAD: {
	"shape": GearLookScript.SHAPE_HELM, "band": true,
	GearLookScript.LAYERS: [{"shape": GearLookScript.SHAPE_STUDS, "count": 7, "radius": 0.49, "arc": PI * 1.1, "y": 0.42, "stud": 0.04, "band_height": 0.025}],
}}
const STAND_IN_LOOKS := {
	"stand_in_rare_helm": HELM_LOOK,
	"stand_in_super_rare_body": {"palette": GearLookScript.STEEL, GearLookScript.PART_BODY: {"shape": GearLookScript.SHAPE_VEST, "pauldrons": true}},
	"stand_in_ultra_rare_sword": {"palette": GearLookScript.STEEL, GearLookScript.PART_WEAPON: {"shape": GearLookScript.SHAPE_BROADSWORD, "pommel_tone": "accent"}},
	"stand_in_uncommon_helm": HELM_LOOK,
}
const UNIQUE := ["stand_in_rare_helm", "stand_in_super_rare_body", "stand_in_ultra_rare_sword"]
## The bones each slot's piece hangs on.
const BONES := {
	ItemTable.SLOT_HELM: ["head"], ItemTable.SLOT_BODY: ["chest"], ItemTable.SLOT_WEAPON: ["handslot_r"],
	ItemTable.SLOT_LEGS: ["hips", "lowerleg_l", "lowerleg_r"],
}

var _root: Node3D
var _view: Node3D
var _gear: Node3D


func _stand_in() -> void:
	ItemTable.add_stand_ins(STAND_IN_ITEMS)
	GearLookScript.add_stand_ins(STAND_IN_LOOKS)


func _clear() -> void:
	if _root != null:
		_root.free()
		_root = null
	ItemTable.clear_stand_ins()
	GearLookScript.clear_stand_ins()


## A fresh character wearing `equipment` (slot -> item).
func _wear(equipment: Dictionary) -> void:
	if _root != null:
		_root.free()
	_root = Node3D.new()
	_view = CharacterViewScript.new()
	_gear = CharacterGearScript.new()
	_root.add_child(_view)
	_root.add_child(_gear)
	_gear.show_equipment(equipment)


## The emissive materials drawn under `node`.
static func _emissive(node: Node) -> Array:
	var out: Array = []
	for found in node.find_children("*", "MeshInstance3D", true, false):
		var mi := found as MeshInstance3D
		if mi.is_queued_for_deletion() or mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var m: Material = mi.material_override
			if m == null:
				m = mi.get_surface_override_material(i)
			if m == null:
				m = mi.mesh.surface_get_material(i)
			if m is BaseMaterial3D and (m as BaseMaterial3D).emission_enabled:
				out.append(m)
	return out


## The emissive materials drawn on the bones `slot`'s piece hangs on.
func _emissive_on(slot: String) -> Array:
	var out: Array = []
	for bone in BONES[slot]:
		out.append_array(_emissive(_view.bone_slot(bone)))
	return out


static func _fx(node: Node) -> int:
	var count := 0
	for type in FX_CLASSES:
		count += node.find_children("*", type, true, false).size()
	return count


func test_a_unique_piece_shines_its_accent_in_its_band_colour() -> void:
	_stand_in()
	for item in UNIQUE:
		var band: Color = RarityLook.of_item(item)
		_wear({ItemTable.slot(item): item})
		var lit := _emissive(_root)
		assert_true(lit.size() > 0, "%s worn alone shows an emissive accent" % item)
		for m in lit:
			assert_eq((m as BaseMaterial3D).albedo_color, band, "%s's accent is drawn in its band's colour" % item)
			assert_eq((m as BaseMaterial3D).emission, band, "%s's accent shines in its band's colour" % item)
			assert_almost_eq((m as BaseMaterial3D).emission_energy_multiplier, GearLookScript.UNIQUE_ACCENT_GLOW, 0.0001, "%s's accent shines at the unique accent glow" % item)
		assert_eq(_fx(_root), 0, "%s adds no light or particles" % item)
	_clear()


func test_the_accents_are_blue_purple_and_gold_from_the_shared_band_colours() -> void:
	_stand_in()
	var bands := {
		"stand_in_rare_helm": ItemTable.RARITY_RARE,
		"stand_in_super_rare_body": ItemTable.RARITY_SUPER_RARE,
		"stand_in_ultra_rare_sword": ItemTable.RARITY_ULTRA_RARE,
	}
	for item in bands:
		var colours := GearLookScript.palette(item)
		assert_eq(colours["accent"], RarityLook.COLOURS[bands[item]], "%s's accent is RarityLook's colour for its band" % item)
		assert_eq(colours["accent_glow"], GearLookScript.UNIQUE_ACCENT_GLOW, "%s's accent glows" % item)
		assert_eq(colours.size(), GearLookScript.PALETTE_FIELDS.size(), "%s's palette carries only the known fields" % item)
	var rare: Color = GearLookScript.palette("stand_in_rare_helm")["accent"]
	var super_rare: Color = GearLookScript.palette("stand_in_super_rare_body")["accent"]
	var ultra_rare: Color = GearLookScript.palette("stand_in_ultra_rare_sword")["accent"]
	assert_true(rare.b > rare.r and rare.b > rare.g, "rare's accent is blue: %s" % rare)
	assert_true(super_rare.r > super_rare.g and super_rare.b > super_rare.g, "super rare's accent is purple: %s" % super_rare)
	assert_true(ultra_rare.r > ultra_rare.b and ultra_rare.g > ultra_rare.b, "ultra rare's accent is gold: %s" % ultra_rare)
	assert_eq(GearLookScript.STEEL["accent_glow"], 0.0, "the palette a stand-in names keeps its own accent plain")
	_clear()


func test_the_same_look_on_an_uncommon_item_stays_plain() -> void:
	_stand_in()
	_wear({ItemTable.SLOT_HELM: "stand_in_uncommon_helm"})
	assert_eq(_emissive(_root).size(), 0, "an uncommon item's accent does not glow")
	assert_eq(GearLookScript.palette("stand_in_uncommon_helm")["accent"], GearLookScript.STEEL["accent"], "an uncommon item keeps its palette's accent")
	_clear()


func test_no_real_piece_of_gear_has_an_accent_glow_of_its_own() -> void:
	for item in GearLookScript.LOOKS:
		var colours: Dictionary = GearLookScript.LOOKS[item]["palette"]
		assert_eq(colours["accent_glow"], 0.0, "%s's palette keeps its accent plain; only a band lights it" % item)


func test_a_unique_piece_shines_beside_any_set_or_tier_and_the_rest_keep_their_own_look() -> void:
	_stand_in()
	# A tier, a mid set and a top set in every other slot, so the accent never depends on what
	# else is worn and never spills onto it.
	var neighbours := {
		"steel": {ItemTable.SLOT_HELM: "steel_helm", ItemTable.SLOT_BODY: "steel_body", ItemTable.SLOT_LEGS: "steel_legs", ItemTable.SLOT_WEAPON: "steel_sword"},
		"hearthguard": {ItemTable.SLOT_HELM: "hearthguard_helm", ItemTable.SLOT_BODY: "hearthguard_body", ItemTable.SLOT_LEGS: "hearthguard_legs", ItemTable.SLOT_WEAPON: "hearthguard_broadsword"},
		"emberheart": {ItemTable.SLOT_HELM: "emberheart_helm", ItemTable.SLOT_BODY: "emberheart_body", ItemTable.SLOT_LEGS: "emberheart_legs", ItemTable.SLOT_WEAPON: "emberheart_hammer"},
	}
	var bands: Array = RarityLook.COLOURS.values()
	for item in UNIQUE:
		var slot := ItemTable.slot(item)
		var band: Color = RarityLook.of_item(item)
		for other in neighbours:
			var worn: Dictionary = (neighbours[other] as Dictionary).duplicate()
			worn[slot] = item
			_wear(worn)
			var lit := _emissive_on(slot)
			assert_true(lit.size() > 0, "%s shines beside %s" % [item, other])
			for m in lit:
				assert_eq((m as BaseMaterial3D).emission, band, "%s beside %s shines in its band's colour" % [item, other])
			for other_slot in BONES:
				if other_slot == slot:
					continue
				var beside: String = worn[other_slot]
				var glowing := _emissive_on(other_slot)
				if other == "emberheart":
					assert_true(glowing.size() > 0, "%s beside %s keeps its top-set glow" % [beside, item])
				else:
					assert_eq(glowing.size(), 0, "%s beside %s stays plain" % [beside, item])
				for m in glowing:
					assert_false(bands.has((m as BaseMaterial3D).emission), "%s beside %s shines in its own colours, not a band's" % [beside, item])
			assert_eq(_fx(_root), 0, "%s beside %s adds no light or particles" % [item, other])
	# All three unique pieces worn together, each in its own band's colour.
	var all := {}
	for item in UNIQUE:
		all[ItemTable.slot(item)] = item
	_wear(all)
	for item in UNIQUE:
		for m in _emissive_on(ItemTable.slot(item)):
			assert_eq((m as BaseMaterial3D).emission, RarityLook.of_item(item), "%s worn with the other unique pieces shines in its own band's colour" % item)
	_clear()
