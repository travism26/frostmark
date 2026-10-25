## The magic sets (#166): Shardweaver, Rimecaller and Glacier Warden are set items under the
## set-item rule (the cloaks under the cape rule) with a look and an icon each; every worn
## piece draws its own layered shape beside steel as it draws alone and swaps with steel both
## ways; the three staves are one mage staff builder with three head kinds, upright in the
## right hand, while the steel staff is still the model; a worn cloak hides the barbarian's cape
## and hangs behind the body; no piece carries a light or motes and every glow is emission in
## the set's glow colour on the parts the issue names; the all-gear stash holds every piece; the
## builders know no set's numbers; the warm-up samples and the shot tool cover every piece, on
## every ring. How the sets read on screen is judged from tools/gear_shots.gd.
extends "res://tests/run.gd".TestCase

const GearLookScript := preload("res://scenes/gear_look.gd")
const CharacterGearScript := preload("res://scenes/character_gear.gd")
const CharacterViewScript := preload("res://scenes/character_view.gd")

## Each set's pieces by slot.
const SETS := {
	ItemTable.SET_SHARDWEAVER: {
		ItemTable.SLOT_HELM: "shardweaver_helm", ItemTable.SLOT_BODY: "shardweaver_body",
		ItemTable.SLOT_LEGS: "shardweaver_legs", ItemTable.SLOT_WEAPON: "shardweaver_staff",
	},
	ItemTable.SET_RIMECALLER: {
		ItemTable.SLOT_HELM: "rimecaller_helm", ItemTable.SLOT_BODY: "rimecaller_body",
		ItemTable.SLOT_LEGS: "rimecaller_legs", ItemTable.SLOT_WEAPON: "rimecaller_staff",
		ItemTable.SLOT_CAPE: "rimecaller_cape",
	},
	ItemTable.SET_GLACIER_WARDEN: {
		ItemTable.SLOT_HELM: "glacier_warden_helm", ItemTable.SLOT_BODY: "glacier_warden_body",
		ItemTable.SLOT_LEGS: "glacier_warden_legs", ItemTable.SLOT_WEAPON: "glacier_warden_staff",
		ItemTable.SLOT_CAPE: "glacier_warden_cape",
	},
}
## The steel item each armour or weapon piece stands in for.
const STEEL := {
	ItemTable.SLOT_HELM: "steel_helm", ItemTable.SLOT_BODY: "steel_body",
	ItemTable.SLOT_LEGS: "steel_legs", ItemTable.SLOT_WEAPON: "steel_staff",
}
## The head each staff carries.
const STAVES := {
	"shardweaver_staff": GearLookScript.HEAD_LASHED,
	"rimecaller_staff": GearLookScript.HEAD_FORKED,
	"glacier_warden_staff": GearLookScript.HEAD_RING,
}
const CAPES := ["rimecaller_cape", "glacier_warden_cape"]
## The pieces that glow, as the issue lists them: Shardweaver's staff shard; Rimecaller's brow
## prism and floating staff shard; Glacier Warden's crest, glyph band and chest glyph, and
## staff prisms. Every other piece has no emission at all.
const GLOWING := ["shardweaver_staff", "rimecaller_helm", "rimecaller_staff", "glacier_warden_helm", "glacier_warden_body", "glacier_warden_staff"]
const PALETTES := {
	ItemTable.SET_SHARDWEAVER: GearLookScript.SHARDWEAVER, ItemTable.SET_RIMECALLER: GearLookScript.RIMECALLER,
	ItemTable.SET_GLACIER_WARDEN: GearLookScript.GLACIER_WARDEN,
}
## The bodies a cloak is hung over: none, steel, fur, and one of each line's sets.
const BODIES := ["", "steel_body", "fur_coat", "shardweaver_body", "glacier_warden_body", "hoarfrost_body", "steelpoint_body"]


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


## The live piece under `bone` whose root is named `shape`, or null.
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


func test_each_set_has_its_items_under_the_set_item_and_cape_rules() -> void:
	var count := 0
	for set_key in SETS:
		assert_true(ItemTable.SETS.has(set_key), "%s is a set the item table knows" % set_key)
		for slot in SETS[set_key]:
			var item: String = SETS[set_key][slot]
			count += 1
			assert_true(ItemTable.has(item), "%s is an item" % item)
			assert_eq(ItemTable.set_of(item), set_key, "%s is in the %s set" % [item, set_key])
			assert_eq(ItemTable.slot(item), slot, "%s goes in the %s slot" % [item, slot])
			assert_eq(ItemTable.tier(item), "", "%s has no tier" % item)
			assert_true(ItemTable.label(item).begins_with(set_key.capitalize() + " "), "%s is labelled with its set: %s" % [item, ItemTable.label(item)])
			assert_true(GearLookScript.has(item), "%s has a look" % item)
			assert_eq(GearLookScript.palette(item), PALETTES[set_key], "%s wears its set's palette" % item)
			assert_eq(GearLookScript.palette(item)["glow_energy"], 0.0, "%s has no staff glow" % item)
			assert_true(IconTable.has(item), "%s has an icon" % item)
			assert_eq(IconTable.tint(item), GearLookScript.palette(item)["base"], "%s's badge is its set's base colour" % item)
			if slot == ItemTable.SLOT_CAPE:
				assert_eq(ItemTable.ITEMS[item]["weight"], 1, "%s weighs 1 under the cape rule" % item)
				assert_eq(ItemTable.ITEMS[item]["value"], 40, "%s is worth 40 under the cape rule" % item)
				assert_false(ItemTable.ITEMS[item].has("defence"), "%s has no defence" % item)
				assert_false(ItemTable.ITEMS[item].has("warmth"), "%s has no warmth" % item)
				assert_eq(IconTable.path(item), IconTable.path(IconTable.SLOT_CAPE), "%s uses the cape slot's glyph" % item)
				continue
			var steel: String = STEEL[slot]
			for stat in ["weight", "value", "defence", "style", "power", "speed", "reach", "ammo"]:
				assert_eq(ItemTable.ITEMS[item].get(stat), ItemTable.ITEMS[steel].get(stat), "%s's %s is %s's" % [item, stat, steel])
			assert_eq(IconTable.path(item), IconTable.path(steel), "%s uses its slot's glyph" % item)
	assert_eq(count, 14, "fourteen magic set items")
	assert_eq(SETS[ItemTable.SET_SHARDWEAVER].size(), 4, "Shardweaver has no cloak")


func test_the_three_staves_are_one_builder_with_three_heads_upright_in_the_right_hand() -> void:
	var root := Node3D.new()
	var view := CharacterViewScript.new()
	var gear := CharacterGearScript.new()
	root.add_child(view)
	root.add_child(gear)
	var heads := {}
	var own_numbers: Array = []
	for item in STAVES:
		var look := GearLookScript.piece(item, GearLookScript.PART_WEAPON)
		assert_eq(look["shape"], GearLookScript.SHAPE_MAGE_STAFF, "%s draws the mage staff" % item)
		assert_eq(look["head"], STAVES[item], "%s carries the %s head" % [item, STAVES[item]])
		assert_true(GearLookScript.STAFF_HEADS.has(look["head"]), "%s's head is a kind the staff knows" % item)
		var own: Dictionary = GearLookScript.LOOKS[item][GearLookScript.PART_WEAPON]
		assert_false(own_numbers.has(own), "%s has numbers of its own" % item)
		own_numbers.append(own)
		var staff := CharacterGearScript.weapon_piece(item)
		assert_true(staff != null, "%s is built from a kit shape" % item)
		assert_eq(String(staff.name), GearLookScript.SHAPE_MAGE_STAFF, "%s's root is the mage staff" % item)
		assert_true(_names(staff).has(STAVES[item]), "%s's head holder is named %s" % [item, STAVES[item]])
		for other in GearLookScript.STAFF_HEADS:
			if other != STAVES[item]:
				assert_false(_names(staff).has(other), "%s carries no %s head" % [item, other])
		heads[STAVES[item]] = true
		assert_true(_materials(staff).size() >= 5, "%s has a shaft, a grip, a prism and its head's parts" % item)
		assert_true(_tones(staff).size() >= 3, "%s draws at least three tones" % item)
		assert_true(_glowing(staff).size() >= 1, "%s's prism shines" % item)
		var top := INF
		var bottom := -INF
		for mesh in staff.find_children("*", "MeshInstance3D", true, false):
			var box := (mesh as MeshInstance3D).mesh.get_aabb()
			var y: float = (mesh as Node3D).position.y + (mesh.get_parent() as Node3D).position.y
			top = minf(top, y + box.position.y)
			bottom = maxf(bottom, y + box.end.y)
		assert_true(bottom - top > 1.0, "%s stands taller than it is wide: upright in the hand" % item)
		staff.free()
		gear.show_equipment({ItemTable.SLOT_WEAPON: item})
		var held := _live_piece(view.bone_slot("handslot_r"))
		assert_true(held != null and String(held.name) == GearLookScript.SHAPE_MAGE_STAFF, "%s is held in the right hand like a staff" % item)
		assert_true(_live_piece(view.bone_slot("handslot_l")) == null, "%s leaves the left hand empty" % item)
	assert_eq(heads.size(), 3, "three different heads")
	assert_true(CharacterGearScript.weapon_piece("steel_staff") == null, "the steel staff is still the model, not a kit weapon")
	assert_eq(GearLookScript.piece("steel_staff", GearLookScript.PART_WEAPON), GearLookScript.numbers({"shape": GearLookScript.SHAPE_STAFF}), "the steel staff's look is unchanged")
	gear.show_equipment({ItemTable.SLOT_WEAPON: "steel_staff"})
	var model := _live_piece(view.bone_slot("handslot_r"))
	assert_true(model != null and String(model.name) != GearLookScript.SHAPE_MAGE_STAFF, "the steel staff is drawn in the right hand from its model")
	root.free()


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
			assert_eq(names[0], look["shape"], "%s draws its own shape on the %s" % [item, bones[slot]])
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
		assert_true(_live_piece(view.bone_slot("handslot_r")) != null, "the %s staff is in the right hand" % set_key)
	root.free()


func test_a_worn_cloak_hides_the_barbarian_cape_and_hangs_behind_any_body() -> void:
	var root := Node3D.new()
	var view := CharacterViewScript.new()
	var gear := CharacterGearScript.new()
	root.add_child(view)
	root.add_child(gear)
	var own_cape: Node3D = view.find_child("Barbarian_Cape", true, false)
	assert_true(own_cape != null, "the barbarian has his own cape")
	for item in CAPES:
		var look := GearLookScript.piece(item, GearLookScript.PART_CAPE)
		assert_eq(look["shape"], GearLookScript.SHAPE_CLOAK, "%s is a cloak" % item)
		assert_true(look["length_left"] != look["length_right"], "%s's halves are two lengths" % item)
		for body in BODIES:
			var worn := {ItemTable.SLOT_CAPE: item, ItemTable.SLOT_TOOL: "steel_axe"}
			if body != "":
				worn[ItemTable.SLOT_BODY] = body
			gear.show_equipment(worn)
			assert_false(own_cape.visible, "%s hides the barbarian's cape over %s" % [item, body if body != "" else "a bare chest"])
			var cloak := _live_shape(view.bone_slot(CharacterGearScript.CAPE_SLOT), GearLookScript.SHAPE_CLOAK)
			assert_true(cloak != null, "%s is drawn on the chest mount over %s" % [item, body if body != "" else "a bare chest"])
			var alone: Node3D = CharacterGearScript.cape_piece(item, body)
			assert_eq(_colours(cloak), _colours(alone), "%s draws over %s what it draws alone" % [item, body])
			assert_true(_tones(alone).size() >= 2, "%s has a cloth and a hem tone" % item)
			alone.free()
			var hung := CharacterGearScript.hang_cape(look, body)
			assert_true((hung["offset"] as Vector3).z >= (look["offset"] as Vector3).z, "%s hangs behind %s" % [item, body])
			if body != "":
				# the hang rule: at every step down its run, the cloak's back face stands behind
				# each body box its width and height reach (a pauldron beside the hem is no clip)
				var piece: Node3D = CharacterGearScript.body_piece(body)
				var under := CharacterGearScript.mesh_bounds(piece)
				piece.free()
				var top := hung["offset"] as Vector3
				var down := Vector3(0, -cos(look["tilt"]), sin(look["tilt"]))
				var half_width: float = look["width"] * 0.5
				var length: float = maxf(look["length_left"], look["length_right"])
				var clear := true
				for i in 17:
					var p := top + down * (length * i / 16.0)
					for box in under:
						if p.y < box.position.y or p.y > box.end.y:
							continue
						if p.x + half_width < box.position.x or p.x - half_width > box.end.x:
							continue
						clear = clear and p.z - look["thickness"] * 0.5 >= box.end.z - 0.001
				assert_true(clear, "%s hangs clear of %s down its run" % [item, body])
		gear.show_equipment({ItemTable.SLOT_TOOL: "steel_axe"})
		assert_true(_live_shape(view.bone_slot(CharacterGearScript.CAPE_SLOT), GearLookScript.SHAPE_CLOAK) == null, "taking %s off clears the back" % item)
		assert_true(own_cape.visible, "the barbarian's cape shows again with nothing worn")
	assert_true(GearLookScript.piece("glacier_warden_cape", GearLookScript.PART_CAPE)["length_left"] > GearLookScript.piece("rimecaller_cape", GearLookScript.PART_CAPE)["length_left"], "the Glacier Warden cloak is the longer")
	root.free()


func test_no_piece_has_a_light_or_motes_and_every_glow_is_emission_in_the_set_colour() -> void:
	for set_key in SETS:
		for slot in SETS[set_key]:
			var item: String = SETS[set_key][slot]
			var glowing := 0
			for piece in _pieces(item):
				assert_eq(piece.find_children("*", "OmniLight3D", true, false).size(), 0, "%s has no light" % item)
				assert_eq(piece.find_children("*", "CPUParticles3D", true, false).size(), 0, "%s has no motes" % item)
				assert_eq(piece.find_children("*", "GPUParticles3D", true, false).size(), 0, "%s has no particles" % item)
				for m in _glowing(piece):
					glowing += 1
					assert_eq(m.emission, PALETTES[set_key]["glow"], "%s shines only in %s's glow colour" % [item, set_key])
				piece.free()
			if GLOWING.has(item):
				assert_true(glowing >= 1, "%s shines" % item)
			else:
				assert_eq(glowing, 0, "%s has no emission" % item)
			for own in _owns(item):
				assert_false(own.get("light", false), "%s's %s asks for no light" % [item, own["shape"]])
				assert_false(own.get("motes", false), "%s's %s asks for no motes" % [item, own["shape"]])
	for set_key in PALETTES:
		assert_true(PALETTES[set_key]["glow"] != Color.BLACK, "%s has a glow colour" % set_key)
	var glow := {}
	for item in STAVES:
		glow[item] = GearLookScript.piece(item, GearLookScript.PART_WEAPON)["glow"]
	assert_true(glow["shardweaver_staff"] < glow["rimecaller_staff"] and glow["rimecaller_staff"] < glow["glacier_warden_staff"], "each rung's staff shines brighter than the one below")


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
	for item in ["wooden_staff", "bronze_staff", "iron_staff", "steel_staff"]:
		assert_eq(GearLookScript.piece(item, GearLookScript.PART_WEAPON)["shape"], GearLookScript.SHAPE_STAFF, "%s is still the staff model" % item)
		assert_true(CharacterGearScript.weapon_piece(item) == null, "%s is not a kit weapon" % item)


func test_the_all_gear_stash_holds_every_piece() -> void:
	var stash := FieldKit.gear_stash()
	for set_key in SETS:
		for slot in SETS[set_key]:
			var item: String = SETS[set_key][slot]
			assert_eq(stash.filter(func(s: Dictionary) -> bool: return s["item"] == item).size(), 1, "one %s in the all-gear stash" % item)
	var sim := Sim.new()
	assert_true(sim.command(SimVocab.IMPORT_SAVE, {"code": FieldKit.gear_code()})["ok"], "the all-gear code imports")
	for item in STAVES.keys() + CAPES:
		assert_eq(Inventory.count_of(sim.state["stash"]["slots"], item), 1, "the imported stash holds %s" % item)
	assert_eq(sim.state["stash"]["slots"].size(), 136, "the all-gear stash fills 136 slots (docs/testing.md)")


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


func test_the_samples_and_the_shot_tool_cover_every_piece_on_every_ring() -> void:
	var all := CharacterGearScript.samples()
	# a second sibling of one name loses it, so each piece is found by the colours it draws
	var drawn: Array = []
	var names: Array = []
	for child in all.get_children():
		drawn.append(_colours(child))
		names.append(String(child.name))
	for item in STAVES:
		var staff: Node3D = CharacterGearScript.weapon_piece(item)
		assert_true(drawn.has(_colours(staff)), "the warm-up samples %s" % item)
		staff.free()
	for item in CAPES:
		var cloak: Node3D = CharacterGearScript.cape_piece(item)
		assert_true(drawn.has(_colours(cloak)), "the warm-up samples %s" % item)
		cloak.free()
	assert_true(names.has(GearLookScript.SHAPE_MAGE_STAFF), "the warm-up samples the kit's own mage staff")
	assert_true(names.has(GearLookScript.SHAPE_POUCH), "the warm-up samples a pouch")
	assert_true(names.has(GearLookScript.SHAPE_CLOAK), "the warm-up samples the kit's own cloak")
	all.free()
	var script := load("res://tools/gear_shots.gd") as Script
	var consts := script.get_script_constant_map()
	var scenes: Array = consts["SCENES"]
	var spots := {"the outpost": consts["SPOT"], "ring one": consts["SPOT_RING_ONE"], "ring two": consts["SPOT_RING_TWO"]}
	var armour := [ItemTable.SLOT_HELM, ItemTable.SLOT_BODY, ItemTable.SLOT_LEGS]
	for set_key in SETS:
		var full := scenes.filter(func(scene: Dictionary) -> bool:
			if scene.has("gather"):  # the working scenes wear what they like
				return false
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
				for other in armour + [ItemTable.SLOT_CAPE]:
					if other != slot and ItemTable.set_of(scene.get(other, "")) == set_key:
						return false
				return true)
			assert_true(mixed.size() >= 1, "a gear_shots scene wears %s with no other %s piece" % [SETS[set_key][slot], set_key])
