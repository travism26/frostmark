## The ranged sets (#164): Trapper's Leathers, Wolfstalker and Steelpoint Ranger are set items
## under the set-item rule (the quivers under the quiver rule) with a look and an icon each;
## every worn piece draws its own layered shape and swaps with steel both ways; the three bows
## are one longbow builder in the left hand with their own numbers while the steel bow is still
## the model; a worn quiver draws on the back clear of the slung tool at rest and at work;
## nothing in the sets glows or carries a light or motes; the all-gear stash holds every piece;
## the builders know no set's numbers; the warm-up samples and the shot tool cover every piece.
## How the sets read on screen is judged from tools/gear_shots.gd.
extends "res://tests/run.gd".TestCase

const GearLookScript := preload("res://scenes/gear_look.gd")
const CharacterGearScript := preload("res://scenes/character_gear.gd")
const CharacterViewScript := preload("res://scenes/character_view.gd")

## Each set's pieces by slot.
const SETS := {
	ItemTable.SET_TRAPPER: {
		ItemTable.SLOT_HELM: "trapper_helm", ItemTable.SLOT_BODY: "trapper_body",
		ItemTable.SLOT_LEGS: "trapper_legs", ItemTable.SLOT_WEAPON: "trapper_bow",
	},
	ItemTable.SET_WOLFSTALKER: {
		ItemTable.SLOT_HELM: "wolfstalker_helm", ItemTable.SLOT_BODY: "wolfstalker_body",
		ItemTable.SLOT_LEGS: "wolfstalker_legs", ItemTable.SLOT_WEAPON: "wolfstalker_bow",
		ItemTable.SLOT_QUIVER: "wolfstalker_quiver",
	},
	ItemTable.SET_STEELPOINT: {
		ItemTable.SLOT_HELM: "steelpoint_helm", ItemTable.SLOT_BODY: "steelpoint_body",
		ItemTable.SLOT_LEGS: "steelpoint_legs", ItemTable.SLOT_WEAPON: "steelpoint_bow",
		ItemTable.SLOT_QUIVER: "steelpoint_quiver",
	},
}
## The steel item each armour or weapon piece stands in for.
const STEEL := {
	ItemTable.SLOT_HELM: "steel_helm", ItemTable.SLOT_BODY: "steel_body",
	ItemTable.SLOT_LEGS: "steel_legs", ItemTable.SLOT_WEAPON: "steel_bow",
}
const BOWS := ["trapper_bow", "wolfstalker_bow", "steelpoint_bow"]
const QUIVERS := ["wolfstalker_quiver", "steelpoint_quiver"]
const PALETTES := [GearLookScript.TRAPPER, GearLookScript.WOLFSTALKER, GearLookScript.STEELPOINT]


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


static func _tones(piece: Node) -> Array:
	var out: Array = []
	for c in _colours(piece):
		if not out.has(c):
			out.append(c)
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
		ItemTable.SLOT_QUIVER:
			return [CharacterGearScript.quiver_piece(item)]
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


## The live piece named `shape` under `bone`, or null.
static func _live_shape(bone: Node, shape: String) -> Node:
	for holder in bone.get_children():
		if holder.is_queued_for_deletion():
			continue
		for child in holder.get_children():
			if String(child.name) == shape:
				return child
	return null


func test_the_fourteen_items_follow_the_set_item_and_quiver_rules() -> void:
	var n := 0
	for set_key in SETS:
		for slot in SETS[set_key]:
			var item: String = SETS[set_key][slot]
			n += 1
			assert_true(ItemTable.has(item), "%s is an item" % item)
			assert_eq(ItemTable.set_of(item), set_key, "%s is in the %s set" % [item, set_key])
			assert_eq(ItemTable.slot(item), slot, "%s goes in the %s slot" % [item, slot])
			assert_eq(ItemTable.tier(item), "", "%s has no tier" % item)
			if slot == ItemTable.SLOT_QUIVER:
				assert_eq(ItemTable.ITEMS[item]["weight"], 1, "%s weighs 1" % item)
				assert_eq(ItemTable.ITEMS[item]["value"], 40, "%s is worth 40" % item)
				assert_false(ItemTable.ITEMS[item].has("defence") or ItemTable.ITEMS[item].has("warmth"), "%s has no defence and no warmth" % item)
				assert_eq(IconTable.path(item), IconTable.path(IconTable.SLOT_QUIVER), "%s uses the quiver slot's glyph" % item)
			else:
				var steel: String = STEEL[slot]
				for stat in ["value", "defence", "style", "power", "speed", "reach", "ammo"]:  # weight is its rung's (test_set_levels.gd)
					assert_eq(ItemTable.ITEMS[item].get(stat), ItemTable.ITEMS[steel].get(stat), "%s's %s is %s's" % [item, stat, steel])
				assert_eq(IconTable.path(item), IconTable.path(steel), "%s uses its slot's glyph" % item)
			assert_true(ItemTable.label(item).begins_with(set_key.capitalize() + " "), "%s is labelled with its set: %s" % [item, ItemTable.label(item)])
			assert_true(GearLookScript.has(item), "%s has a look" % item)
			assert_true(IconTable.has(item), "%s has an icon" % item)
			assert_eq(IconTable.tint(item), GearLookScript.palette(item)["base"], "%s's badge is its set's base colour" % item)
	assert_eq(n, 14, "fourteen items")
	for item in ItemTable.ITEMS:
		if ItemTable.slot(item) == ItemTable.SLOT_QUIVER:
			assert_true(ItemTable.set_of(item) != "", "%s is a set quiver: every quiver item belongs to a ranged set" % item)


func test_the_three_bows_are_one_builder_with_their_own_numbers_in_the_left_hand() -> void:
	var seen: Array = []
	var root := Node3D.new()
	var view := CharacterViewScript.new()
	var gear := CharacterGearScript.new()
	root.add_child(view)
	root.add_child(gear)
	for item in BOWS:
		var look := GearLookScript.piece(item, GearLookScript.PART_WEAPON)
		assert_eq(look["shape"], GearLookScript.SHAPE_LONGBOW, "%s draws the longbow" % item)
		var own: Dictionary = GearLookScript.LOOKS[item][GearLookScript.PART_WEAPON]
		assert_false(seen.has(own), "%s has numbers of its own" % item)
		seen.append(own)
		var bow := CharacterGearScript.weapon_piece(item)
		assert_true(bow != null, "%s is built from a kit shape" % item)
		assert_eq(String(bow.name), GearLookScript.SHAPE_LONGBOW, "%s's root is the longbow" % item)
		assert_true(_tones(bow).size() >= 2, "%s draws at least two tones" % item)
		assert_eq(_glowing(bow), 0, "%s has no emission" % item)
		bow.free()
		gear.show_equipment({ItemTable.SLOT_WEAPON: item})
		var held := _live_piece(view.bone_slot("handslot_l"))
		assert_true(held != null and String(held.name) == GearLookScript.SHAPE_LONGBOW, "%s is held in the left hand like a bow" % item)
		assert_true(_live_piece(view.bone_slot("handslot_r")) == null, "%s leaves the right hand empty" % item)
	assert_true(CharacterGearScript.weapon_piece("steel_bow") == null, "the steel bow is still the model, not a kit weapon")
	assert_eq(GearLookScript.piece("steel_bow", GearLookScript.PART_WEAPON), {"shape": GearLookScript.SHAPE_BOW, "length": 1.1}, "the steel bow's look is unchanged")
	gear.show_equipment({ItemTable.SLOT_WEAPON: "steel_bow"})
	var model := _live_piece(view.bone_slot("handslot_l"))
	assert_true(model != null and String(model.name) != GearLookScript.SHAPE_LONGBOW, "the steel bow is drawn in the left hand from its model")
	var capped := CharacterGearScript.weapon_piece("steelpoint_bow")
	var plain := CharacterGearScript.weapon_piece("trapper_bow")
	assert_eq(_materials(capped).size(), _materials(plain).size() + 2, "the capped bow has a limb cap at each tip the plain one has not")
	capped.free()
	plain.free()
	root.free()


func test_every_armour_piece_draws_its_layers_and_swaps_with_steel_both_ways() -> void:
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
			assert_true(_tones(alone).size() >= 3, "%s has a base, a darker and a lighter tone" % item)
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


func test_a_worn_quiver_hangs_on_the_back_clear_of_the_tool_at_rest_and_at_work() -> void:
	var plain := GearLookScript.numbers({"shape": GearLookScript.SHAPE_QUIVER})
	for item in QUIVERS:
		var look := GearLookScript.piece(item, GearLookScript.PART_QUIVER)
		for key in plain:
			if not String(key).ends_with("tone"):
				assert_eq(look[key], plain[key], "%s keeps the quiver's %s, so the back-layer clearance tests hold for it" % [item, key])
		var tones := {}
		for key in look:
			if String(key).ends_with("tone"):
				tones[look[key]] = true
		assert_true(tones.size() >= 3, "%s is drawn in at least three tones" % item)
	var root := Node3D.new()
	var view := CharacterViewScript.new()
	var gear := CharacterGearScript.new()
	root.add_child(view)
	root.add_child(gear)
	for item in QUIVERS:
		for body in ["", "steel_body", "fur_coat", "wolfstalker_body", "hearthguard_body"]:
			var worn := {ItemTable.SLOT_QUIVER: item, ItemTable.SLOT_TOOL: "steel_axe", ItemTable.SLOT_WEAPON: "trapper_bow"}
			if body != "":
				worn[ItemTable.SLOT_BODY] = body
			for working in [false, true]:
				var layout := GearLayout.place(worn, working)
				assert_eq(layout[GearLayout.QUIVER], item, "%s is placed on the back %s" % [item, "at work" if working else "at rest"])
				assert_eq(layout[GearLayout.BACK], "" if working else "steel_axe", "the tool is %s" % ("in the hand" if working else "slung"))
			gear.show_equipment(worn)
			var quiver := _live_shape(view.bone_slot(CharacterGearScript.QUIVER_SLOT), GearLookScript.SHAPE_QUIVER)
			assert_true(quiver != null, "%s is drawn on the chest mount over %s" % [item, body if body != "" else "a bare chest"])
			var alone: Node3D = CharacterGearScript.quiver_piece(item, body)
			assert_eq(_colours(quiver), _colours(alone), "%s draws over %s what it draws alone" % [item, body])
			alone.free()
		gear.show_equipment({ItemTable.SLOT_TOOL: "steel_axe"})
		assert_true(_live_shape(view.bone_slot(CharacterGearScript.QUIVER_SLOT), GearLookScript.SHAPE_QUIVER) == null, "taking %s off clears the back" % item)
	root.free()


func test_steel_draws_exactly_what_it_drew_before() -> void:
	for item in ["steel_helm", "steel_body", "steel_legs"]:
		for piece in _pieces(item):
			assert_false(_names(piece).any(func(n: String) -> bool: return GearLookScript.KIT_SHAPES.has(n)), "%s draws no kit shape" % item)
			piece.free()
	assert_eq(GearLookScript.STEEL, {
		"base": Color(0.42, 0.50, 0.62), "dark": Color(0.378, 0.45, 0.558),
		"trim": Color(0.336, 0.40, 0.496), "accent": Color(0.478, 0.55, 0.658),
		"glow": Color(0.55, 0.85, 1.0), "glow_energy": 1.5,
	}, "the steel palette is unchanged")
	for item in ["wooden_bow", "bronze_bow", "iron_bow", "steel_bow"]:
		assert_eq(GearLookScript.piece(item, GearLookScript.PART_WEAPON)["shape"], GearLookScript.SHAPE_BOW, "%s is still the bow model" % item)


func test_no_ranged_set_piece_has_emission_a_light_or_motes() -> void:
	for set_key in SETS:
		for slot in SETS[set_key]:
			var item: String = SETS[set_key][slot]
			for piece in _pieces(item):
				assert_eq(_glowing(piece), 0, "%s has no emission" % item)
				assert_eq(piece.find_children("*", "OmniLight3D", true, false).size(), 0, "%s has no light" % item)
				assert_eq(piece.find_children("*", "CPUParticles3D", true, false).size(), 0, "%s has no motes" % item)
				assert_eq(piece.find_children("*", "GPUParticles3D", true, false).size(), 0, "%s has no particles" % item)
				piece.free()
			var look: Dictionary = GearLookScript.LOOKS[item]
			for part in look:
				if part == "palette" or (look[part] as Dictionary).is_empty():
					continue
				for own in [look[part]] + (look[part] as Dictionary).get(GearLookScript.LAYERS, []):
					assert_eq(float(own.get("glow", 0.0)), 0.0, "%s's %s asks for no glow" % [item, own["shape"]])
	for colours in PALETTES:
		assert_eq(colours["glow_energy"], 0.0, "no ranged set has a staff glow")
		assert_eq(colours["glow"], Color.BLACK, "no ranged set has a glow colour")


func test_the_all_gear_stash_holds_every_piece() -> void:
	var stash := FieldKit.gear_stash()
	for set_key in SETS:
		for slot in SETS[set_key]:
			var item: String = SETS[set_key][slot]
			assert_eq(stash.filter(func(s: Dictionary) -> bool: return s["item"] == item).size(), 1, "one %s in the all-gear stash" % item)
	var sim := Sim.new()
	assert_true(sim.command(SimVocab.IMPORT_SAVE, {"code": FieldKit.gear_code()})["ok"], "the all-gear code imports")
	for item in BOWS + QUIVERS:
		assert_eq(Inventory.count_of(sim.state["stash"]["slots"], item), 1, "the imported stash holds %s" % item)


func test_the_builders_know_no_set_and_every_number_is_in_the_look() -> void:
	var source := FileAccess.get_file_as_string("res://scenes/character_gear.gd").to_lower()
	for set_key in SETS:
		assert_false(source.contains(set_key), "character_gear.gd never names %s" % set_key)
	for set_key in SETS:
		for slot in SETS[set_key]:
			var item: String = SETS[set_key][slot]
			var look: Dictionary = GearLookScript.LOOKS[item]
			assert_true(PALETTES.has(look["palette"]), "%s wears a ranged set's palette" % item)
			for part in look:
				if part == "palette" or (look[part] as Dictionary).is_empty():
					continue
				for own in [look[part]] + (look[part] as Dictionary).get(GearLookScript.LAYERS, []):
					for key in own:
						if String(key).ends_with("tone"):
							assert_true(own[key] is Color or GearLookScript.PALETTE_FIELDS.has(own[key]), "%s's %s %s is a field or a Color" % [item, part, key])


func test_the_samples_and_the_shot_tool_cover_every_piece() -> void:
	var all := CharacterGearScript.samples()
	# a second sibling of one name loses it, so each piece is found by the colours it draws
	var drawn: Array = []
	for child in all.get_children():
		drawn.append(_colours(child))
	for item in BOWS + QUIVERS:
		var alone: Node3D = _pieces(item)[0]
		assert_true(drawn.has(_colours(alone)), "the warm-up samples %s" % item)
		alone.free()
	all.free()
	var scenes: Array = (load("res://tools/gear_shots.gd") as Script).get_script_constant_map()["SCENES"]
	for set_key in SETS:
		var full := scenes.filter(func(scene: Dictionary) -> bool:
			for slot in SETS[set_key]:
				if scene.get(slot, "") != SETS[set_key][slot]:
					return false
			return true)
		assert_eq(full.size(), 1, "one gear_shots scene wears the full %s set" % set_key)
	for item in QUIVERS:
		assert_true(scenes.any(func(scene: Dictionary) -> bool: return scene.get(ItemTable.SLOT_QUIVER, "") == item and scene.has("gather")) or scenes.any(func(scene: Dictionary) -> bool: return scene.get(ItemTable.SLOT_QUIVER, "") == item), "a scene wears %s" % item)
	assert_true(scenes.any(func(scene: Dictionary) -> bool: return scene.has("gather") and scene.get(ItemTable.SLOT_QUIVER, "") != ""), "a scene works with a quiver on")
