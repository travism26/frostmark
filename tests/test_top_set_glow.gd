## Top sets glow (#250): every top-set piece worn on the character shines in its trims, while
## the tiers and the mid to high sets keep plain materials, and nothing on the character
## carries a light or particles. Checked through the screen seam: each piece is put on a
## CharacterView by CharacterGear from its equipment slot, alone and beside other sets and
## tiers, since pieces are unlocked one at a time and mixed.
extends "res://tests/run.gd".TestCase

const GearLookScript := preload("res://scenes/gear_look.gd")
const CharacterGearScript := preload("res://scenes/character_gear.gd")
const CharacterViewScript := preload("res://scenes/character_view.gd")

## The node classes that would put a light or particles on the character.
const FX_CLASSES := ["Light3D", "GPUParticles3D", "CPUParticles3D"]

var _root: Node3D
var _view: Node3D
var _gear: Node3D


## A fresh character with nothing worn.
func _dress() -> void:
	if _root != null:
		_root.free()
	_root = Node3D.new()
	_view = CharacterViewScript.new()
	_gear = CharacterGearScript.new()
	_root.add_child(_view)
	_root.add_child(_gear)


## A fresh character wearing `equipment` (slot -> item).
func _wear(equipment: Dictionary) -> void:
	_dress()
	_gear.show_equipment(equipment)


## Every material drawn under `node`, by surface.
static func _materials(node: Node) -> Array:
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
			if m != null:
				out.append(m)
	return out


## The emissive materials drawn under `node`.
static func _emissive(node: Node) -> Array:
	return _materials(node).filter(func(m: Material) -> bool: return m is BaseMaterial3D and (m as BaseMaterial3D).emission_enabled)


## How many lights and particle emitters are under `node`.
static func _fx(node: Node) -> int:
	var count := 0
	for type in FX_CLASSES:
		count += node.find_children("*", type, true, false).size()
	return count


## The gear items whose set or tier passes `keep`, in the table's order.
static func _items(keep: Callable) -> Array:
	var out: Array = []
	for item in ItemTable.ITEMS:
		if ItemTable.slot(item) != "" and keep.call(item):
			out.append(item)
	return out


## Whether `item` is a piece of a top set (GLOSSARY.md: *top set*), by its set's level in the
## item table.
static func _top(item: String) -> bool:
	return ItemTable.set_level(ItemTable.set_of(item)) == ItemTable.LEVEL_TOP


## Whether `item` is a piece of a mid, mid-high or high set.
static func _mid_to_high(item: String) -> bool:
	var level := ItemTable.set_level(ItemTable.set_of(item))
	return level != "" and level != ItemTable.LEVEL_TOP


func test_every_set_is_a_top_set_or_a_mid_to_high_set() -> void:
	var top := ItemTable.SETS.filter(func(set_key: String) -> bool: return ItemTable.set_level(set_key) == ItemTable.LEVEL_TOP)
	var rest := ItemTable.SETS.filter(func(set_key: String) -> bool: return [ItemTable.LEVEL_MID, ItemTable.LEVEL_MID_HIGH, ItemTable.LEVEL_HIGH].has(ItemTable.set_level(set_key)))
	assert_eq(top.size(), 12, "12 top sets")
	assert_eq(rest.size(), 9, "9 mid to high sets")
	assert_eq(top.size() + rest.size(), ItemTable.SETS.size(), "every set has a level")


func test_the_bare_character_has_no_emission() -> void:
	_dress()
	assert_eq(_emissive(_root).size(), 0, "nothing glows before gear goes on")
	assert_eq(_fx(_root), 0, "no light or particles before gear goes on")
	_root.free()
	_root = null


func test_every_top_set_piece_shines_in_its_trims() -> void:
	var pieces := _items(_top)
	assert_eq(pieces.size(), 58, "4 melee sets of 4, 4 ranged sets of 5 or 6, 4 magic sets of 5")
	for item in pieces:
		var colours := GearLookScript.palette(item)
		assert_true(float(colours["trim_glow"]) > 0.0, "%s's look marks its trims emissive" % item)
		_wear({ItemTable.slot(item): item})
		var trims := _emissive(_root).filter(func(m: BaseMaterial3D) -> bool: return m.albedo_color == colours["trim"])
		assert_true(trims.size() > 0, "%s worn alone draws emissive trims" % item)
		for m in trims:
			assert_eq((m as BaseMaterial3D).emission, colours["trim"], "%s's trims shine in the trim colour" % item)
			assert_almost_eq((m as BaseMaterial3D).emission_energy_multiplier, colours["trim_glow"], 0.0001, "%s's trims shine at its look's trim glow" % item)
	_root.free()
	_root = null


func test_no_tier_or_mid_to_high_set_piece_has_emission() -> void:
	var plain := _items(func(item: String) -> bool: return ItemTable.tier(item) != "" or _mid_to_high(item))
	assert_eq(plain.size(), 33 + 40, "every tier piece and every mid to high set piece")
	for item in plain:
		var colours := GearLookScript.palette(item)
		assert_eq(colours["trim_glow"], 0.0, "%s's look keeps its trims plain" % item)
		assert_eq(colours["glow_energy"], 0.0, "%s's look draws no lit staff crystal" % item)
		_wear({ItemTable.slot(item): item})
		assert_eq(_emissive(_root).size(), 0, "%s worn alone has no emission" % item)
	_root.free()
	_root = null


func test_nothing_on_the_character_has_a_light_or_particles() -> void:
	for item in _items(func(_item: String) -> bool: return true):
		_wear({ItemTable.slot(item): item})
		assert_eq(_fx(_root), 0, "%s worn adds no light or particles" % item)
	# A whole top set at once, for each top set.
	for set_key in ItemTable.SETS.filter(func(set_key: String) -> bool: return ItemTable.set_level(set_key) == ItemTable.LEVEL_TOP):
		var worn := {}
		for item in _items(func(item: String) -> bool: return ItemTable.set_of(item) == set_key):
			worn[ItemTable.slot(item)] = item
		_wear(worn)
		assert_eq(_fx(_root), 0, "the whole %s set adds no light or particles" % set_key)
		assert_true(_emissive(_root).size() > 0, "the whole %s set glows" % set_key)
	_root.free()
	_root = null
	var warm_up := CharacterGearScript.samples()
	assert_eq(_fx(warm_up), 0, "the shader warm-up's gear carries no light or particles")
	warm_up.free()


func test_a_top_set_piece_shines_beside_any_set_or_tier_and_the_rest_stay_plain() -> void:
	# The armour slots, each with the bones its piece hangs on (legs on the hips and both shins).
	var bones := {
		ItemTable.SLOT_HELM: ["head"], ItemTable.SLOT_BODY: ["chest"],
		ItemTable.SLOT_LEGS: ["hips", "lowerleg_l", "lowerleg_r"],
	}
	# The neighbours each top-set piece is worn beside: a tier, a mid set, a high set, and
	# another top set, so its glow never depends on what else is worn.
	var neighbours := ["steel", "hearthguard", "ruinwarden_mage", "trollbone"]
	for item in _items(_top):
		var slot := ItemTable.slot(item)
		if not bones.has(slot):
			continue
		for other in neighbours:
			var worn := {}
			for other_slot in bones:
				if other_slot == slot:
					continue
				var beside := "%s_%s" % [other, other_slot]
				if ItemTable.has(beside) and beside != item:
					worn[other_slot] = beside
			worn[slot] = item
			_wear(worn)
			for drawn_slot in bones:
				var drawn: String = worn.get(drawn_slot, "")
				if drawn == "":
					continue
				var glowing := 0
				for bone in bones[drawn_slot]:
					glowing += _emissive(_view.bone_slot(bone)).size()
				assert_eq(glowing > 0, _top(drawn), "%s %s beside %s" % [drawn, "glows" if _top(drawn) else "stays plain", worn])
	_root.free()
	_root = null
