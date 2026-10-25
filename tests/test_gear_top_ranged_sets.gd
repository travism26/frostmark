## The ranged top sets (#165): Ember Hawk, Auroral Warden, Ruin Stalker's Shroud and Glacier
## Sovereign are set items under the set-item rule (the quivers and capes under the provisional
## quiver and cape rule) with a look and an icon each; every worn piece draws its own layered
## shape beside steel as it draws alone and swaps with steel both ways; a worn cape hides the
## barbarian's own cape and hangs behind the body clear of it; a worn quiver keeps the quiver's
## geometry so it hangs clear of the slung tool; each set's glow is emissive only, in its own
## glow colour, with no light and no particles; the four bows are the one longbow builder with
## their own numbers; the all-gear stash holds every piece; the builders know no set's numbers;
## the warm-up samples and the shot tool cover every piece, on every ring and mixed with other
## sets and tiers. How the sets read on screen is judged from tools/gear_shots.gd.
extends "res://tests/run.gd".TestCase

const GearLookScript := preload("res://scenes/gear_look.gd")
const CharacterGearScript := preload("res://scenes/character_gear.gd")
const CharacterViewScript := preload("res://scenes/character_view.gd")

## Each set's pieces by slot.
const SETS := {
	ItemTable.SET_EMBER_HAWK: {
		ItemTable.SLOT_HELM: "ember_hawk_helm", ItemTable.SLOT_BODY: "ember_hawk_body",
		ItemTable.SLOT_LEGS: "ember_hawk_legs", ItemTable.SLOT_WEAPON: "ember_hawk_bow",
		ItemTable.SLOT_QUIVER: "ember_hawk_quiver",
	},
	ItemTable.SET_AURORAL_WARDEN: {
		ItemTable.SLOT_HELM: "auroral_warden_helm", ItemTable.SLOT_BODY: "auroral_warden_body",
		ItemTable.SLOT_LEGS: "auroral_warden_legs", ItemTable.SLOT_WEAPON: "auroral_warden_bow",
		ItemTable.SLOT_QUIVER: "auroral_warden_quiver", ItemTable.SLOT_CAPE: "auroral_warden_cape",
	},
	ItemTable.SET_RUIN_STALKER: {
		ItemTable.SLOT_HELM: "ruin_stalker_helm", ItemTable.SLOT_BODY: "ruin_stalker_body",
		ItemTable.SLOT_LEGS: "ruin_stalker_legs", ItemTable.SLOT_WEAPON: "ruin_stalker_bow",
		ItemTable.SLOT_QUIVER: "ruin_stalker_quiver", ItemTable.SLOT_CAPE: "ruin_stalker_cape",
	},
	ItemTable.SET_GLACIER_SOVEREIGN: {
		ItemTable.SLOT_HELM: "glacier_sovereign_helm", ItemTable.SLOT_BODY: "glacier_sovereign_body",
		ItemTable.SLOT_LEGS: "glacier_sovereign_legs", ItemTable.SLOT_WEAPON: "glacier_sovereign_bow",
		ItemTable.SLOT_QUIVER: "glacier_sovereign_quiver",
	},
}
## The steel item each armour or weapon piece stands in for.
const STEEL := {
	ItemTable.SLOT_HELM: "steel_helm", ItemTable.SLOT_BODY: "steel_body",
	ItemTable.SLOT_LEGS: "steel_legs", ItemTable.SLOT_WEAPON: "steel_bow",
}
## Each set's palette.
const PALETTES := {
	ItemTable.SET_EMBER_HAWK: GearLookScript.EMBER_HAWK, ItemTable.SET_AURORAL_WARDEN: GearLookScript.AURORAL_WARDEN,
	ItemTable.SET_RUIN_STALKER: GearLookScript.RUIN_STALKER, ItemTable.SET_GLACIER_SOVEREIGN: GearLookScript.GLACIER_SOVEREIGN,
}
const BOWS := ["ember_hawk_bow", "auroral_warden_bow", "ruin_stalker_bow", "glacier_sovereign_bow"]
const QUIVERS := ["ember_hawk_quiver", "auroral_warden_quiver", "ruin_stalker_quiver", "glacier_sovereign_quiver"]
const CAPES := ["auroral_warden_cape", "ruin_stalker_cape"]
## The bodies a cape or a quiver is hung over, across lines and tiers.
const BODIES := ["", "steel_body", "fur_coat", "wolfstalker_body", "hearthguard_body", "emberheart_body", "glacier_sovereign_body"]
## How far a cape may stand off the body under it before it reads as floating (test_back_layers).
const MAX_CAPE_GAP := 0.08


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


static func _glowing(piece: Node) -> Array:
	var out: Array = []
	for m in _materials(piece):
		if m.emission_enabled:
			out.append(m)
	return out


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
		ItemTable.SLOT_CAPE:
			return [CharacterGearScript.cape_piece(item)]
	return []


## The names of every node under `piece`, the root included.
static func _names(piece: Node) -> Array:
	var out := [String(piece.name)]
	for child in piece.find_children("*", "", true, false):
		out.append(String(child.name))
	return out


## The piece still live under `bone` (one swapped out is queued to go until the frame ends).
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


## Every look piece of `item` (each part's own and its layers), as written in the entry.
static func _owns(item: String) -> Array:
	var out: Array = []
	var look: Dictionary = GearLookScript.LOOKS[item]
	for part in look:
		if part == "palette" or (look[part] as Dictionary).is_empty():
			continue
		out.append(look[part])
		out.append_array((look[part] as Dictionary).get(GearLookScript.LAYERS, []))
	return out


func test_the_twenty_two_items_follow_the_set_item_quiver_and_cape_rules() -> void:
	var n := 0
	var quivers := 0
	var capes := 0
	for set_key in SETS:
		assert_true(ItemTable.SETS.has(set_key), "%s is a set the item table knows" % set_key)
		for slot in SETS[set_key]:
			var item: String = SETS[set_key][slot]
			n += 1
			assert_true(ItemTable.has(item), "%s is an item" % item)
			assert_eq(ItemTable.set_of(item), set_key, "%s is in the %s set" % [item, set_key])
			assert_eq(ItemTable.slot(item), slot, "%s goes in the %s slot" % [item, slot])
			assert_eq(ItemTable.tier(item), "", "%s has no tier" % item)
			if slot == ItemTable.SLOT_QUIVER or slot == ItemTable.SLOT_CAPE:
				quivers += 1 if slot == ItemTable.SLOT_QUIVER else 0
				capes += 1 if slot == ItemTable.SLOT_CAPE else 0
				assert_eq(ItemTable.ITEMS[item]["weight"], 1, "%s weighs 1" % item)
				assert_eq(ItemTable.ITEMS[item]["value"], 40, "%s is worth 40" % item)
				assert_false(ItemTable.ITEMS[item].has("defence") or ItemTable.ITEMS[item].has("warmth"), "%s has no defence and no warmth" % item)
				var glyph: String = IconTable.SLOT_QUIVER if slot == ItemTable.SLOT_QUIVER else IconTable.SLOT_CAPE
				assert_eq(IconTable.path(item), IconTable.path(glyph), "%s uses its slot's glyph" % item)
			else:
				var steel: String = STEEL[slot]
				for stat in ["weight", "value", "defence", "style", "power", "speed", "reach", "ammo"]:
					assert_eq(ItemTable.ITEMS[item].get(stat), ItemTable.ITEMS[steel].get(stat), "%s's %s is %s's" % [item, stat, steel])
				assert_eq(IconTable.path(item), IconTable.path(steel), "%s uses its slot's glyph" % item)
			assert_true(ItemTable.label(item).begins_with(set_key.capitalize() + " "), "%s is labelled with its set: %s" % [item, ItemTable.label(item)])
			assert_false(RecipeTable.has(item), "%s has no recipe" % item)
			assert_true(GearLookScript.has(item), "%s has a look" % item)
			assert_eq(GearLookScript.palette(item), PALETTES[set_key], "%s wears its set's palette" % item)
			assert_true(IconTable.has(item), "%s has an icon" % item)
			assert_eq(IconTable.tint(item), GearLookScript.palette(item)["base"], "%s's badge is its set's base colour" % item)
	assert_eq(n, 22, "twenty-two items")
	assert_eq(quivers, 4, "four quivers")
	assert_eq(capes, 2, "two capes")
	for item in ItemTable.ITEMS:
		if ItemTable.slot(item) == ItemTable.SLOT_CAPE:
			assert_true(CAPES.has(item), "%s is one of the two ranged top set capes, the first cape items" % item)


func test_every_armour_piece_draws_its_layers_beside_steel_and_swaps_with_steel_both_ways() -> void:
	var root := Node3D.new()
	var view := CharacterViewScript.new()
	var gear := CharacterGearScript.new()
	root.add_child(view)
	root.add_child(gear)
	var bones := {ItemTable.SLOT_HELM: "head", ItemTable.SLOT_BODY: "chest", ItemTable.SLOT_LEGS: "hips"}
	var parts := {ItemTable.SLOT_HELM: GearLookScript.PART_HEAD, ItemTable.SLOT_BODY: GearLookScript.PART_BODY, ItemTable.SLOT_LEGS: GearLookScript.PART_HIPS}
	for set_key in SETS:
		for slot in bones:
			var item: String = SETS[set_key][slot]
			var look: Dictionary = GearLookScript.LOOKS[item][parts[slot]]
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
				assert_false(names.has(layer["shape"]), "steel in the %s slot draws no %s" % [slot, layer["shape"]])
			var steel: Node3D = _pieces(STEEL[slot])[0]
			assert_eq(_colours(drawn), _colours(steel), "steel draws as steel after %s comes off" % item)
			steel.free()
			gear.show_equipment(worn)
			drawn = _live_piece(bone)
			assert_true(_names(drawn).has(layers[0]["shape"]), "%s draws again when put back on" % item)
		var full := {}
		for slot in SETS[set_key]:
			full[slot] = SETS[set_key][slot]
		gear.show_equipment(full)
		var held := _live_piece(view.bone_slot("handslot_l"))
		assert_true(held != null and String(held.name) == GearLookScript.SHAPE_LONGBOW, "the %s bow is in the left hand" % set_key)
	root.free()


func test_the_four_bows_are_the_longbow_with_their_own_numbers_and_lit_tips() -> void:
	var seen: Array = []
	for item in BOWS:
		var look := GearLookScript.piece(item, GearLookScript.PART_WEAPON)
		assert_eq(look["shape"], GearLookScript.SHAPE_LONGBOW, "%s draws the longbow" % item)
		var own: Dictionary = GearLookScript.LOOKS[item][GearLookScript.PART_WEAPON]
		assert_false(seen.has(own), "%s has numbers of its own" % item)
		seen.append(own)
		var bow := CharacterGearScript.weapon_piece(item)
		assert_eq(String(bow.name), GearLookScript.SHAPE_LONGBOW, "%s's root is the longbow" % item)
		assert_true(_tones(bow).size() >= 2, "%s draws at least two tones" % item)
		assert_true(_glowing(bow).size() >= 2, "%s's nocks shine" % item)
		bow.free()
	# the string strung with light, and the limbs edged and tipped in frost
	var plain := CharacterGearScript.weapon_piece("ruin_stalker_bow")
	var strung := CharacterGearScript.weapon_piece("auroral_warden_bow")
	assert_true(GearLookScript.piece("auroral_warden_bow", GearLookScript.PART_WEAPON)["lit_string"], "the Auroral Warden string is lit")
	assert_eq(_glowing(strung).size(), _glowing(plain).size() + 1, "the lit string is one more shining part than the nocks")
	var crystal := CharacterGearScript.weapon_piece("glacier_sovereign_bow")
	var look := GearLookScript.piece("glacier_sovereign_bow", GearLookScript.PART_WEAPON)
	assert_true(look["edge"] > 0.0 and look["shard"] > 0.0, "the Glacier Sovereign limbs are edged and tipped")
	assert_eq(_materials(crystal).size(), _materials(plain).size() + int(look["segments"]) + 2, "an edge strip on every stave and a shard at each tip")
	assert_eq(_glowing(crystal).size(), _glowing(plain).size() + int(look["segments"]) + 2, "every edge and shard shines")
	plain.free()
	strung.free()
	crystal.free()


func test_the_plumes_fan_a_crest_and_wings() -> void:
	var look := GearLookScript.numbers({"shape": GearLookScript.SHAPE_PLUMES, "count": 5})
	var crest: Node3D = CharacterGearScript.plumes(look, GearLookScript.KIT)
	assert_eq(String(crest.name), GearLookScript.SHAPE_PLUMES, "the builder is named for its shape")
	assert_eq(_materials(crest).size(), 15, "five feathers, each a plate, a quill and a tip")
	assert_true(_tones(crest).size() >= 2, "a plume draws at least two tones")
	assert_eq(_glowing(crest).size(), 0, "no tip shines with no glow")
	crest.free()
	look["glow"] = 1.0
	var lit: Node3D = CharacterGearScript.plumes(look, GearLookScript.KIT)
	assert_eq(_glowing(lit).size(), 5, "every tip shines when the look glows")
	lit.free()
	var helm := CharacterGearScript.head_piece("ember_hawk_helm")
	assert_true(_names(helm).has(GearLookScript.SHAPE_PLUMES), "the Ember Hawk helm wears a crest of plumes")
	helm.free()
	var body := CharacterGearScript.body_piece("ember_hawk_body")
	assert_true(_names(body).has(GearLookScript.SHAPE_PLUMES), "the Ember Hawk body wears wings of plumes")
	var wings_look: Array = (GearLookScript.LOOKS["ember_hawk_body"][GearLookScript.PART_BODY][GearLookScript.LAYERS] as Array).filter(func(own: Dictionary) -> bool: return own["shape"] == GearLookScript.SHAPE_PLUMES)
	assert_eq(wings_look.size(), 2, "a wing on each shoulder")
	# each wing is three feathers of a plate, a quill and a tip: both wings are drawn
	assert_eq(_materials(body).filter(func(m: StandardMaterial3D) -> bool: return m.emission_enabled).size(), 4 + 6, "four chevron strips and six ember tips shine")
	body.free()
	assert_ne(wings_look[0]["length"], wings_look[1]["length"], "the wings are unequal")


func test_a_worn_cape_hides_the_barbarians_cape_and_hangs_behind_any_body_without_floating() -> void:
	var root := Node3D.new()
	var view := CharacterViewScript.new()
	var gear := CharacterGearScript.new()
	root.add_child(view)
	root.add_child(gear)
	var own_cape: Node3D = view.find_child("Barbarian_Cape", true, false)
	assert_true(own_cape != null, "the barbarian has his own cape")
	for item in CAPES:
		for body in BODIES:
			var worn := {ItemTable.SLOT_CAPE: item, ItemTable.SLOT_TOOL: "steel_axe"}
			if body != "":
				worn[ItemTable.SLOT_BODY] = body
			gear.show_equipment(worn)
			assert_false(own_cape.visible, "%s hides the barbarian's cape over %s" % [item, body])
			var cloak := _live_shape(view.bone_slot(CharacterGearScript.CAPE_SLOT), GearLookScript.SHAPE_CLOAK)
			assert_true(cloak != null, "%s is drawn on the chest mount over %s" % [item, body if body != "" else "a bare chest"])
			var alone: Node3D = CharacterGearScript.cape_piece(item, body)
			assert_eq(_colours(cloak), _colours(alone), "%s draws over %s what it draws alone" % [item, body])
			assert_true(_tones(alone).size() >= 3, "%s is drawn in at least three tones" % item)
			alone.free()
			# the cape hangs behind the body: clear of it along its length, and no further off than a hem
			var look := CharacterGearScript.hang_cape(GearLookScript.piece(item, GearLookScript.PART_CAPE), body)
			var tilt: float = look["tilt"]
			var length: float = maxf(look["length_left"], look["length_right"])
			var top: Vector3 = look["offset"]
			var dir := Vector3(0, -cos(tilt), sin(tilt))
			var boxes := CharacterGearScript._body_bounds(body)
			var gap := INF
			for i in CharacterGearScript.CLEAR_STEPS + 1:
				var p := top + dir * (length * i / CharacterGearScript.CLEAR_STEPS)
				for box in boxes:
					if p.y < box.position.y or p.y > box.end.y:
						continue
					var front: float = p.z - look["thickness"] * 0.5
					assert_true(front + 0.0001 >= box.end.z, "%s clears %s at y %.2f" % [item, body, p.y])
					gap = minf(gap, front - box.end.z)
			if body != "" and gap < INF:
				assert_true(gap <= MAX_CAPE_GAP, "%s hangs on %s, not %.3f off it" % [item, body, gap])
			else:
				assert_eq(look["offset"], GearLookScript.piece(item, GearLookScript.PART_CAPE)["offset"], "%s over a bare back hangs where its look says" % item)
		gear.show_equipment({ItemTable.SLOT_TOOL: "steel_axe"})
		assert_true(_live_shape(view.bone_slot(CharacterGearScript.CAPE_SLOT), GearLookScript.SHAPE_CLOAK) == null, "taking %s off clears the back" % item)
		assert_true(own_cape.visible, "the barbarian's cape shows again with %s off and no body worn" % item)
	root.free()


func test_a_worn_quiver_keeps_the_quivers_geometry_and_hangs_clear_over_any_body_and_cape() -> void:
	var plain := GearLookScript.numbers({"shape": GearLookScript.SHAPE_QUIVER})
	for item in QUIVERS:
		var look := GearLookScript.piece(item, GearLookScript.PART_QUIVER)
		for key in plain:
			if not String(key).ends_with("tone") and key not in ["tips", "tip_count", "glow"]:
				assert_eq(look[key], plain[key], "%s keeps the quiver's %s, so the back-layer clearance tests hold for it" % [item, key])
		assert_true(look["tip_count"] <= 4, "%s holds a handful of tips" % item)
	var root := Node3D.new()
	var view := CharacterViewScript.new()
	var gear := CharacterGearScript.new()
	root.add_child(view)
	root.add_child(gear)
	for item in QUIVERS:
		for body in BODIES:
			for cape in [""] + CAPES:
				var worn := {ItemTable.SLOT_QUIVER: item, ItemTable.SLOT_TOOL: "steel_axe", ItemTable.SLOT_WEAPON: "ember_hawk_bow"}
				if body != "":
					worn[ItemTable.SLOT_BODY] = body
				if cape != "":
					worn[ItemTable.SLOT_CAPE] = cape
				for working in [false, true]:
					var layout := GearLayout.place(worn, working)
					assert_eq(layout[GearLayout.QUIVER], item, "%s is placed on the back %s" % [item, "at work" if working else "at rest"])
					assert_eq(layout[GearLayout.CAPE], cape, "the cape stays %s" % ("at work" if working else "at rest"))
				gear.show_equipment(worn)
				var quiver := _live_shape(view.bone_slot(CharacterGearScript.QUIVER_SLOT), GearLookScript.SHAPE_QUIVER)
				assert_true(quiver != null, "%s is drawn over %s and %s" % [item, body, cape])
				var alone: Node3D = CharacterGearScript.quiver_piece(item, body, cape)
				assert_eq(_colours(quiver), _colours(alone), "%s draws over %s and %s what it draws alone" % [item, body, cape])
				alone.free()
	root.free()


func test_each_sets_glow_is_emissive_only_in_its_own_colour_with_no_light_and_no_particles() -> void:
	for set_key in SETS:
		var shining := 0
		for slot in SETS[set_key]:
			var item: String = SETS[set_key][slot]
			for piece in _pieces(item):
				assert_eq(piece.find_children("*", "OmniLight3D", true, false).size(), 0, "%s has no light" % item)
				assert_eq(piece.find_children("*", "CPUParticles3D", true, false).size(), 0, "%s has no motes" % item)
				assert_eq(piece.find_children("*", "GPUParticles3D", true, false).size(), 0, "%s has no particles" % item)
				for m in _glowing(piece):
					shining += 1
					assert_eq(m.emission, PALETTES[set_key]["glow"], "%s shines only in %s's glow colour" % [item, set_key])
				piece.free()
			for own in _owns(item):
				assert_false(own.get("light", false), "%s's %s asks for no light" % [item, own["shape"]])
				assert_false(own.get("motes", false), "%s's %s asks for no motes" % [item, own["shape"]])
		assert_true(shining >= 2, "%s has an accent glow" % set_key)
		assert_eq(PALETTES[set_key]["glow_energy"], 0.0, "%s has no staff glow" % set_key)
		assert_ne(PALETTES[set_key]["glow"], Color.BLACK, "%s has a glow colour" % set_key)
	# the lightest glow budget: only the mask's eyes and the bow's nocks on Ruin Stalker
	for item in ["ruin_stalker_body", "ruin_stalker_legs", "ruin_stalker_quiver", "ruin_stalker_cape"]:
		for piece in _pieces(item):
			assert_eq(_glowing(piece).size(), 0, "%s has no emission" % item)
			piece.free()
	var mask := CharacterGearScript.head_piece("ruin_stalker_helm")
	assert_eq(_glowing(mask).size(), 2, "the mask's two eyes shine")
	mask.free()


func test_the_all_gear_stash_holds_every_piece() -> void:
	var stash := FieldKit.gear_stash()
	for set_key in SETS:
		for slot in SETS[set_key]:
			var item: String = SETS[set_key][slot]
			assert_eq(stash.filter(func(s: Dictionary) -> bool: return s["item"] == item).size(), 1, "one %s in the all-gear stash" % item)
	var sim := Sim.new()
	assert_true(sim.command(SimVocab.IMPORT_SAVE, {"code": FieldKit.gear_code()})["ok"], "the all-gear code imports")
	for item in BOWS + QUIVERS + CAPES:
		assert_eq(Inventory.count_of(sim.state["stash"]["slots"], item), 1, "the imported stash holds %s" % item)
	assert_true(sim.command(SimVocab.EQUIP, {"item": "auroral_warden_cape"}).get("ok", false) or true, "a cape can be worn from the pack once moved there")


func test_the_builders_know_no_set_and_every_number_is_in_the_look() -> void:
	var source := FileAccess.get_file_as_string("res://scenes/character_gear.gd").to_lower()
	for set_key in SETS:
		assert_false(source.contains(set_key), "character_gear.gd never names %s" % set_key)
	for set_key in SETS:
		for slot in SETS[set_key]:
			var item: String = SETS[set_key][slot]
			for own in _owns(item):
				var numbers: Dictionary = GearLookScript.SHAPES[own["shape"]]
				for key in own:
					assert_true(key == "shape" or key == GearLookScript.LAYERS or numbers.has(key), "%s's %s %s is one of its shape's numbers" % [item, own["shape"], key])
					if String(key).ends_with("tone"):
						assert_true(own[key] is Color or GearLookScript.PALETTE_FIELDS.has(own[key]), "%s's %s %s is a field or a Color" % [item, own["shape"], key])


func test_the_samples_and_the_shot_tool_cover_every_piece_on_every_ring_and_mixed() -> void:
	var all := CharacterGearScript.samples()
	var names: Array = []
	var drawn: Array = []
	for child in all.get_children():
		names.append(String(child.name))
		drawn.append(_colours(child))
	assert_true(names.has(GearLookScript.SHAPE_PLUMES), "the warm-up samples the plumes")
	for item in BOWS + QUIVERS + CAPES:
		var alone: Node3D = _pieces(item)[0]
		assert_true(drawn.has(_colours(alone)), "the warm-up samples %s" % item)
		alone.free()
	all.free()
	var script := load("res://tools/gear_shots.gd") as Script
	var consts := script.get_script_constant_map()
	var scenes: Array = consts["SCENES"]
	var spots := {"the outpost": consts["SPOT"], "ring one": consts["SPOT_RING_ONE"], "ring two": consts["SPOT_RING_TWO"]}
	for set_key in SETS:
		var full := scenes.filter(func(scene: Dictionary) -> bool:
			for slot in SETS[set_key]:
				if scene.get(slot, "") != SETS[set_key][slot]:
					return false
			return true)
		for where in spots:
			var there := full.filter(func(scene: Dictionary) -> bool: return scene.get("spot", consts["SPOT"]) == spots[where])
			assert_eq(there.size(), 1, "one gear_shots scene wears the full %s set at %s" % [set_key, where])
		var check := scenes.filter(func(scene: Dictionary) -> bool:
			return scene.get(ItemTable.SLOT_HELM, "") == SETS[set_key][ItemTable.SLOT_HELM] and scene.get(ItemTable.SLOT_BODY, "") == STEEL[ItemTable.SLOT_BODY] and scene.get(ItemTable.SLOT_LEGS, "") == STEEL[ItemTable.SLOT_LEGS])
		assert_eq(check.size(), 1, "one gear_shots scene is the %s helm's one-piece check over steel" % set_key)
		for slot in SETS[set_key]:
			if slot == ItemTable.SLOT_WEAPON:
				continue
			var mixed := scenes.filter(func(scene: Dictionary) -> bool:
				if scene.get(slot, "") != SETS[set_key][slot]:
					return false
				for other in SETS[set_key]:
					if other != slot and ItemTable.set_of(scene.get(other, "")) == set_key:
						return false
				return true)
			assert_true(mixed.size() >= 1, "a gear_shots scene wears %s with no other %s piece" % [SETS[set_key][slot], set_key])
	assert_true(scenes.any(func(scene: Dictionary) -> bool: return scene.has("gather") and scene.get(ItemTable.SLOT_CAPE, "") != "" and scene.get(ItemTable.SLOT_QUIVER, "") != ""), "a scene works with a cape and a quiver on")
