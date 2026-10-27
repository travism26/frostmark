## The melee sets (#162): Hearthguard, Wolfmark and Ruinwarden are set items under the
## set-item rule with a look and an icon each; every worn piece draws its own layered shape
## and swaps with steel both ways; steel draws what it drew before; the three weapons are
## three builders; nothing in the sets carries a light, motes or emission (a mid to high set
## keeps plain materials, #250), the Ruinwarden rune and fuller drawn in its glow colour,
## unlit; the all-gear stash holds every piece; the builders know no set's numbers; the warm-up
## samples and the shot tool cover every piece. How the sets read on screen is judged from
## tools/gear_shots.gd.
extends "res://tests/run.gd".TestCase

const GearLookScript := preload("res://scenes/gear_look.gd")
const CharacterGearScript := preload("res://scenes/character_gear.gd")
const CharacterViewScript := preload("res://scenes/character_view.gd")

## Each set's pieces by slot, and the steel item each stands in for.
const SETS := {
	ItemTable.SET_HEARTHGUARD: {
		ItemTable.SLOT_HELM: "hearthguard_helm", ItemTable.SLOT_BODY: "hearthguard_body",
		ItemTable.SLOT_LEGS: "hearthguard_legs", ItemTable.SLOT_WEAPON: "hearthguard_broadsword",
	},
	ItemTable.SET_WOLFMARK: {
		ItemTable.SLOT_HELM: "wolfmark_helm", ItemTable.SLOT_BODY: "wolfmark_body",
		ItemTable.SLOT_LEGS: "wolfmark_legs", ItemTable.SLOT_WEAPON: "wolfmark_axe",
	},
	ItemTable.SET_RUINWARDEN: {
		ItemTable.SLOT_HELM: "ruinwarden_helm", ItemTable.SLOT_BODY: "ruinwarden_body",
		ItemTable.SLOT_LEGS: "ruinwarden_legs", ItemTable.SLOT_WEAPON: "ruinwarden_greatsword",
	},
}
const STEEL := {
	ItemTable.SLOT_HELM: "steel_helm", ItemTable.SLOT_BODY: "steel_body",
	ItemTable.SLOT_LEGS: "steel_legs", ItemTable.SLOT_WEAPON: "steel_sword",
}
## The weapon builder each set's weapon draws.
const WEAPON_SHAPES := {
	"hearthguard_broadsword": GearLookScript.SHAPE_BROADSWORD,
	"wolfmark_axe": GearLookScript.SHAPE_BEARDED_AXE,
	"ruinwarden_greatsword": GearLookScript.SHAPE_GREATSWORD,
}
## The set piece whose rune is drawn in its glow colour, unlit (#250); the fuller is too.
const RUNE := "ruinwarden_body"
## What the steel pieces drew before the sets (#159): their meshes' colours in build order.
const STEEL_DRAWN := {
	"steel_helm": [GearLookScript.STEEL["base"], GearLookScript.STEEL["trim"], GearLookScript.STEEL["trim"]],
	"steel_body": [GearLookScript.STEEL["base"], GearLookScript.STEEL["accent"], GearLookScript.STEEL["accent"]],
	"steel_legs": [GearLookScript.STEEL["dark"]],
	"steel_shin": [GearLookScript.STEEL["base"]],
}


static func _materials(piece: Node) -> Array:
	var out: Array = []
	for node in piece.find_children("*", "MeshInstance3D", true, false):
		out.append((node as MeshInstance3D).mesh.surface_get_material(0) as StandardMaterial3D)
	return out


static func _colours(piece: Node) -> Array:
	var out: Array = []
	for m in _materials(piece):
		out.append(m.albedo_color)
	return out


static func _glowing(piece: Node) -> int:
	var n := 0
	for m in _materials(piece):
		if m.emission_enabled:
			n += 1
	return n


## The pieces `item` draws, one per part of its slot (the shin's included), as fresh nodes.
static func _pieces(item: String) -> Array:
	match ItemTable.slot(item):
		ItemTable.SLOT_HELM:
			return [CharacterGearScript.head_piece(item)]
		ItemTable.SLOT_BODY:
			return [CharacterGearScript.body_piece(item)]
		ItemTable.SLOT_LEGS:
			var out := [CharacterGearScript.hips_piece(item)]
			var shin := CharacterGearScript.shin_piece(item)
			if shin != null:
				out.append(shin)
			return out
		ItemTable.SLOT_WEAPON:
			return [CharacterGearScript.weapon_piece(item)]
	return []


## The names of every node under `piece`, the root included.
static func _names(piece: Node) -> Array:
	var out := [String(piece.name)]
	for child in piece.find_children("*", "", true, false):
		out.append(String(child.name))
	return out


## The piece still live under `bone` (one swapped out is queued to go until the frame ends):
## the first child of a mount holder that is not queued for deletion.
static func _live_piece(bone: Node) -> Node:
	for holder in bone.get_children():
		if holder.is_queued_for_deletion() or holder.get_child_count() == 0:
			continue
		return holder.get_child(0)
	return null


func test_each_set_has_four_items_under_the_set_item_rule() -> void:
	for set_key in SETS:
		for slot in SETS[set_key]:
			var item: String = SETS[set_key][slot]
			assert_true(ItemTable.has(item), "%s is an item" % item)
			assert_eq(ItemTable.set_of(item), set_key, "%s is in the %s set" % [item, set_key])
			assert_eq(ItemTable.slot(item), slot, "%s goes in the %s slot" % [item, slot])
			assert_eq(ItemTable.tier(item), "", "%s has no tier" % item)
			var steel: String = STEEL[slot]
			for stat in ["value", "defence", "style", "power", "speed", "reach", "ammo"]:  # weight is its rung's (test_set_levels.gd)
				assert_eq(ItemTable.ITEMS[item].get(stat), ItemTable.ITEMS[steel].get(stat), "%s's %s is %s's" % [item, stat, steel])
			assert_true(ItemTable.label(item).begins_with(set_key.capitalize() + " "), "%s is labelled with its set: %s" % [item, ItemTable.label(item)])
			assert_true(GearLookScript.has(item), "%s has a look" % item)
			assert_true(IconTable.has(item), "%s has an icon" % item)
			assert_eq(IconTable.path(item), IconTable.path(steel), "%s uses its slot's glyph" % item)
			assert_eq(IconTable.tint(item), GearLookScript.palette(item)["base"], "%s's badge is its set's base colour" % item)
	for item in ItemTable.ITEMS:
		if ItemTable.set_of(item) != "":
			assert_true(ItemTable.SETS.has(ItemTable.set_of(item)), "%s is in a set the item table knows" % item)


func test_the_three_weapons_draw_three_different_builders() -> void:
	var seen := {}
	for item in WEAPON_SHAPES:
		var look := GearLookScript.piece(item, GearLookScript.PART_WEAPON)
		assert_eq(look["shape"], WEAPON_SHAPES[item], "%s's look names its builder" % item)
		var weapon := CharacterGearScript.weapon_piece(item)
		assert_true(weapon != null, "%s is built from a kit shape" % item)
		assert_eq(String(weapon.name), WEAPON_SHAPES[item], "%s's root is named after its builder" % item)
		assert_true(_materials(weapon).size() >= 4, "%s has a blade or head, a haft or grip and fittings" % item)
		seen[String(weapon.name)] = true
		weapon.free()
	assert_eq(seen.size(), 3, "three different builders")
	assert_true(CharacterGearScript.weapon_piece("steel_sword") == null, "a steel sword is still the model, not a kit weapon")


func test_every_set_piece_draws_its_layers_and_swaps_with_steel_both_ways() -> void:
	var root := Node3D.new()
	var view := CharacterViewScript.new()
	var gear := CharacterGearScript.new()
	root.add_child(view)
	root.add_child(gear)
	var bones := {ItemTable.SLOT_HELM: "head", ItemTable.SLOT_BODY: "chest", ItemTable.SLOT_LEGS: "hips"}
	for set_key in SETS:
		for slot in bones:
			var item: String = SETS[set_key][slot]
			var part: String = GearLookScript.PART_HEAD if slot == ItemTable.SLOT_HELM else (GearLookScript.PART_BODY if slot == ItemTable.SLOT_BODY else GearLookScript.PART_HIPS)
			var look: Dictionary = GearLookScript.LOOKS[item][part]
			var layers: Array = look.get(GearLookScript.LAYERS, [])
			assert_true(layers.size() >= 1, "%s layers something on its shape" % item)
			var bone := view.bone_slot(bones[slot])
			var worn := STEEL.duplicate()
			worn[slot] = item
			gear.show_equipment(worn)
			var drawn := _live_piece(bone)
			var names := _names(drawn)
			for layer in layers:
				assert_true(names.has(layer["shape"]), "%s draws its %s on the %s" % [item, layer["shape"], bones[slot]])
			var alone: Node3D = _pieces(item)[0]
			assert_eq(_colours(drawn), _colours(alone), "%s draws beside steel what it draws alone" % item)
			alone.free()
			gear.show_equipment(STEEL.duplicate())
			drawn = _live_piece(bone)
			names = _names(drawn)
			for layer in layers:
				assert_false(names.has(layer["shape"]), "steel %s has no %s" % [slot, layer["shape"]])
			var steel: Node3D = _pieces(STEEL[slot])[0]
			assert_eq(_colours(drawn), _colours(steel), "steel %s is redrawn as steel" % slot)
			steel.free()
			gear.show_equipment(worn)
			names = _names(_live_piece(bone))
			for layer in layers:
				assert_true(names.has(layer["shape"]), "%s is redrawn with its %s" % [item, layer["shape"]])
	root.free()


func test_steel_draws_exactly_what_it_drew_before() -> void:
	for item in ["steel_helm", "steel_body", "steel_legs"]:
		var pieces := _pieces(item)
		assert_eq(_colours(pieces[0]), STEEL_DRAWN[item], "%s's meshes and colours" % item)
		for piece in pieces:
			assert_eq(_glowing(piece), 0, "%s has no emission" % item)
			assert_eq(piece.find_children("*", "OmniLight3D", true, false).size(), 0, "%s has no light" % item)
			assert_false(_names(piece).any(func(n: String) -> bool: return GearLookScript.KIT_SHAPES.has(n)), "%s draws no kit shape" % item)
			piece.free()
	var shin := CharacterGearScript.shin_piece("steel_legs")
	assert_eq(_colours(shin), STEEL_DRAWN["steel_shin"], "the steel greave")
	shin.free()
	assert_eq(GearLookScript.STEEL, {
		"base": Color(0.42, 0.50, 0.62), "dark": Color(0.378, 0.45, 0.558),
		"trim": Color(0.336, 0.40, 0.496), "accent": Color(0.478, 0.55, 0.658),
		"glow": Color(0.55, 0.85, 1.0), "glow_energy": 0.0, "trim_glow": 0.0,
	}, "the steel palette is unchanged but for its plain staff crystal (#250)")


func test_no_set_piece_has_a_light_motes_or_emission_and_the_rune_is_unlit() -> void:
	for set_key in SETS:
		for slot in SETS[set_key]:
			var item: String = SETS[set_key][slot]
			for piece in _pieces(item):
				assert_eq(piece.find_children("*", "OmniLight3D", true, false).size(), 0, "%s has no light" % item)
				assert_eq(piece.find_children("*", "CPUParticles3D", true, false).size(), 0, "%s has no motes" % item)
				assert_eq(piece.find_children("*", "GPUParticles3D", true, false).size(), 0, "%s has no particles" % item)
				assert_eq(_glowing(piece), 0, "%s has no emission" % item)
				if item == RUNE:
					assert_true(_colours(piece).has(GearLookScript.RUINWARDEN["glow"]), "%s draws its rune in Ruinwarden's glow colour" % item)
				piece.free()
	var rune: Dictionary = GearLookScript.LOOKS["ruinwarden_body"][GearLookScript.PART_BODY][GearLookScript.LAYERS].filter(func(l: Dictionary) -> bool: return l["shape"] == GearLookScript.SHAPE_CRYSTAL)[0]
	assert_false(rune.get("light", false) or rune.get("motes", false), "the rune asks for no light and no motes")
	assert_eq(float(GearLookScript.numbers(rune)["glow"]), 0.0, "the rune is unlit")
	assert_eq(GearLookScript.RUINWARDEN["trim_glow"], 0.0, "Ruinwarden's trims stay plain")


func test_the_all_gear_stash_holds_every_piece() -> void:
	var stash := FieldKit.gear_stash()
	for set_key in SETS:
		for slot in SETS[set_key]:
			var item: String = SETS[set_key][slot]
			assert_eq(stash.filter(func(s: Dictionary) -> bool: return s["item"] == item).size(), 1, "one %s in the all-gear stash" % item)
	var sim := Sim.new()
	assert_true(sim.command(SimVocab.IMPORT_SAVE, {"code": FieldKit.gear_code()})["ok"], "the all-gear code imports")
	for item in WEAPON_SHAPES:
		assert_eq(Inventory.count_of(sim.state["stash"]["slots"], item), 1, "the imported stash holds %s" % item)


func test_the_builders_know_no_set_and_every_number_is_in_the_look() -> void:
	var source := FileAccess.get_file_as_string("res://scenes/character_gear.gd").to_lower()
	for set_key in SETS:
		assert_false(source.contains(set_key), "character_gear.gd never names %s" % set_key)
	for set_key in SETS:
		for slot in SETS[set_key]:
			var item: String = SETS[set_key][slot]
			var look: Dictionary = GearLookScript.LOOKS[item]
			var colours: Dictionary = look["palette"]
			assert_true(colours == GearLookScript.HEARTHGUARD or colours == GearLookScript.WOLFMARK or colours == GearLookScript.RUINWARDEN, "%s wears its set's palette" % item)
			assert_eq(colours["glow_energy"], 0.0, "%s has no staff glow" % item)
			# every tone a layer sets is a palette field or a colour of the entry's own
			for part in look:
				if part == "palette" or (look[part] as Dictionary).is_empty():
					continue
				for own in [look[part]] + (look[part] as Dictionary).get(GearLookScript.LAYERS, []):
					for key in own:
						if String(key).ends_with("tone"):
							assert_true(own[key] is Color or GearLookScript.PALETTE_FIELDS.has(own[key]), "%s's %s %s is a field or a Color" % [item, part, key])


func test_the_samples_and_the_shot_tool_cover_every_piece() -> void:
	var all := CharacterGearScript.samples()
	var names: Array = []
	for child in all.get_children():
		names.append(String(child.name))
	for item in WEAPON_SHAPES:
		assert_true(names.has(WEAPON_SHAPES[item]), "the warm-up samples a %s" % WEAPON_SHAPES[item])
	var armour := 0
	var weapons := 0
	var kit_weapons := 0
	var back := 0
	for item in ItemTable.ITEMS:
		if ItemTable.ARMOUR_SLOTS.has(ItemTable.slot(item)):
			armour += _pieces(item).size()
		elif ItemTable.slot(item) == ItemTable.SLOT_QUIVER or ItemTable.slot(item) == ItemTable.SLOT_CAPE:
			back += 1
		elif CharacterGearScript.weapon_piece(item) != null:
			weapons += 1
		if ItemTable.slot(item) == ItemTable.SLOT_WEAPON and GearLookScript.WEAPON_SHAPES.has(GearLookScript.piece(item, GearLookScript.PART_WEAPON)["shape"]):
			kit_weapons += 1
	assert_true(weapons >= WEAPON_SHAPES.size(), "the three melee set weapons are kit weapons")
	assert_eq(weapons, kit_weapons, "every weapon whose look is a kit shape is built by weapon_piece")
	assert_eq(all.get_child_count(), GearLookScript.KIT_SAMPLES.size() + armour + back + weapons, "one sample per kit shape, armour piece, quiver or cape, and kit weapon")
	assert_eq(all.find_children("*", "Light3D", true, false).size(), 0, "the samples carry no light")
	all.free()
	var scenes: Array = (load("res://tools/gear_shots.gd") as Script).get_script_constant_map()["SCENES"]
	for set_key in SETS:
		var full := scenes.filter(func(scene: Dictionary) -> bool:
			for slot in SETS[set_key]:
				if scene.get(slot, "") != SETS[set_key][slot]:
					return false
			return true)
		assert_eq(full.size(), 1, "one gear_shots scene wears the full %s set" % set_key)
