## The melee top sets (#163): Emberheart, Hoarfrost, Auroral and Trollbone are set items under
## the set-item rule with a look and an icon each; every worn piece draws its own layered shape
## beside steel as it draws alone and swaps with steel both ways; the four weapons are four
## builders; the glow line holds (at most one light per set, and only on Emberheart's hammer;
## every emitter a sparse CPUParticles3D; Trollbone with no glow at all); the all-gear stash
## holds every piece; the builders know no set's numbers; the warm-up samples and the shot tool
## cover every piece, on every ring. How the sets read on screen is judged from
## tools/gear_shots.gd.
extends "res://tests/run.gd".TestCase

const GearLookScript := preload("res://scenes/gear_look.gd")
const CharacterGearScript := preload("res://scenes/character_gear.gd")
const CharacterViewScript := preload("res://scenes/character_view.gd")

## Each set's pieces by slot, and the steel item each stands in for.
const SETS := {
	ItemTable.SET_EMBERHEART: {
		ItemTable.SLOT_HELM: "emberheart_helm", ItemTable.SLOT_BODY: "emberheart_body",
		ItemTable.SLOT_LEGS: "emberheart_legs", ItemTable.SLOT_WEAPON: "emberheart_hammer",
	},
	ItemTable.SET_HOARFROST: {
		ItemTable.SLOT_HELM: "hoarfrost_helm", ItemTable.SLOT_BODY: "hoarfrost_body",
		ItemTable.SLOT_LEGS: "hoarfrost_legs", ItemTable.SLOT_WEAPON: "hoarfrost_greatsword",
	},
	ItemTable.SET_AURORAL: {
		ItemTable.SLOT_HELM: "auroral_helm", ItemTable.SLOT_BODY: "auroral_body",
		ItemTable.SLOT_LEGS: "auroral_legs", ItemTable.SLOT_WEAPON: "auroral_glaive",
	},
	ItemTable.SET_TROLLBONE: {
		ItemTable.SLOT_HELM: "trollbone_helm", ItemTable.SLOT_BODY: "trollbone_body",
		ItemTable.SLOT_LEGS: "trollbone_legs", ItemTable.SLOT_WEAPON: "trollbone_cleaver",
	},
}
const STEEL := {
	ItemTable.SLOT_HELM: "steel_helm", ItemTable.SLOT_BODY: "steel_body",
	ItemTable.SLOT_LEGS: "steel_legs", ItemTable.SLOT_WEAPON: "steel_sword",
}
## Each set's palette.
const PALETTES := {
	ItemTable.SET_EMBERHEART: GearLookScript.EMBERHEART, ItemTable.SET_HOARFROST: GearLookScript.HOARFROST,
	ItemTable.SET_AURORAL: GearLookScript.AURORAL, ItemTable.SET_TROLLBONE: GearLookScript.TROLLBONE,
}
## The weapon builder each set's weapon draws.
const WEAPON_SHAPES := {
	"emberheart_hammer": GearLookScript.SHAPE_FORGE_HAMMER,
	"hoarfrost_greatsword": GearLookScript.SHAPE_GREATSWORD,
	"auroral_glaive": GearLookScript.SHAPE_GLAIVE,
	"trollbone_cleaver": GearLookScript.SHAPE_CLEAVER,
}
## The one piece across the four sets that carries a light.
const LIT := "emberheart_hammer"
## The set with no glow, light or particles at all.
const DARK := ItemTable.SET_TROLLBONE
## The most motes an emitter on these sets may keep alive at once.
const MOTES_MAX := 16


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


func test_each_set_has_four_items_under_the_set_item_rule() -> void:
	for set_key in SETS:
		assert_true(ItemTable.SETS.has(set_key), "%s is a set the item table knows" % set_key)
		for slot in SETS[set_key]:
			var item: String = SETS[set_key][slot]
			assert_true(ItemTable.has(item), "%s is an item" % item)
			assert_eq(ItemTable.set_of(item), set_key, "%s is in the %s set" % [item, set_key])
			assert_eq(ItemTable.slot(item), slot, "%s goes in the %s slot" % [item, slot])
			assert_eq(ItemTable.tier(item), "", "%s has no tier" % item)
			var steel: String = STEEL[slot]
			for stat in ["weight", "value", "defence", "style", "power", "speed", "reach", "ammo"]:
				assert_eq(ItemTable.ITEMS[item].get(stat), ItemTable.ITEMS[steel].get(stat), "%s's %s is %s's" % [item, stat, steel])
			assert_true(ItemTable.label(item).begins_with(set_key.capitalize() + " "), "%s is labelled with its set: %s" % [item, ItemTable.label(item)])
			assert_true(GearLookScript.has(item), "%s has a look" % item)
			assert_eq(GearLookScript.palette(item), PALETTES[set_key], "%s wears its set's palette" % item)
			assert_eq(GearLookScript.palette(item)["glow_energy"], 0.0, "%s has no staff glow" % item)
			assert_true(IconTable.has(item), "%s has an icon" % item)
			assert_eq(IconTable.path(item), IconTable.path(steel), "%s uses its slot's glyph" % item)
			assert_eq(IconTable.tint(item), GearLookScript.palette(item)["base"], "%s's badge is its set's base colour" % item)


func test_the_four_weapons_draw_four_different_builders() -> void:
	var seen := {}
	for item in WEAPON_SHAPES:
		var look := GearLookScript.piece(item, GearLookScript.PART_WEAPON)
		assert_eq(look["shape"], WEAPON_SHAPES[item], "%s's look names its builder" % item)
		assert_true(GearLookScript.WEAPON_SHAPES.has(look["shape"]), "%s is a kit weapon" % item)
		var weapon := CharacterGearScript.weapon_piece(item)
		assert_true(weapon != null, "%s is built from a kit shape" % item)
		assert_eq(String(weapon.name), WEAPON_SHAPES[item], "%s's root is named after its builder" % item)
		assert_true(_materials(weapon).size() >= 5, "%s has a blade or head, a haft or grip and fittings" % item)
		seen[String(weapon.name)] = true
		weapon.free()
	assert_eq(seen.size(), 4, "four different builders")


func test_every_set_piece_draws_its_layers_beside_steel_and_swaps_with_steel_both_ways() -> void:
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
		assert_true(_live_piece(view.bone_slot("handslot_r")) != null, "the %s weapon is in the right hand" % set_key)
	root.free()


func test_at_most_one_light_per_set_and_only_on_the_hammer_and_trollbone_is_dark() -> void:
	for set_key in SETS:
		var lights := 0
		for slot in SETS[set_key]:
			var item: String = SETS[set_key][slot]
			for piece in _pieces(item):
				var own: Array = piece.find_children("*", "OmniLight3D", true, false)
				lights += own.size()
				assert_eq(own.size(), 1 if item == LIT else 0, "%s carries %s" % [item, "the one light" if item == LIT else "no light"])
				for light in own:
					assert_eq((light as OmniLight3D).light_color, PALETTES[set_key]["glow"], "the light is %s's glow colour" % set_key)
					assert_eq(String(light.name), CharacterGearScript.GLOW_LIGHT, "the light is named for a test to find")
				for m in _glowing(piece):
					assert_eq(m.emission, PALETTES[set_key]["glow"], "%s shines only in %s's glow colour" % [item, set_key])
				if set_key == DARK:
					assert_eq(_glowing(piece).size(), 0, "%s has no emission" % item)
					assert_eq(piece.find_children("*", "CPUParticles3D", true, false).size(), 0, "%s has no motes" % item)
				piece.free()
		assert_true(lights <= 1, "%s carries at most one light" % set_key)
	assert_eq(PALETTES[DARK]["glow"], Color.BLACK, "%s has no glow colour" % DARK)
	var hammer := CharacterGearScript.weapon_piece(LIT)
	var light := hammer.find_children("*", "OmniLight3D", true, false)[0] as OmniLight3D
	var look := GearLookScript.piece(LIT, GearLookScript.PART_WEAPON)
	assert_true(look["light"], "the hammer's look asks for its light")
	assert_almost_eq(light.light_energy, float(look["light_energy"]), 0.0001, "the light is as bright as the look says")
	assert_almost_eq(light.omni_range, float(look["light_range"]), 0.0001, "the light reaches as far as the look says")
	assert_true(_glowing(hammer).size() >= 1, "the hammer's cracks shine")
	hammer.free()
	for item in GearLookScript.LOOKS:
		if not SETS.has(ItemTable.set_of(item)):
			continue
		for own in _owns(item):
			if own.get("light", false):
				assert_eq(item, LIT, "only %s asks for a light, not %s" % [LIT, item])
			if own.get("light", false) or own.get("motes", false):
				assert_true(GearLookScript.GLOW_FX_SHAPES.has(own["shape"]), "%s's %s is a shape that can carry a light or motes" % [item, own["shape"]])


func test_every_emitter_is_a_sparse_cpu_particles_node() -> void:
	var emitters := 0
	for set_key in SETS:
		for slot in SETS[set_key]:
			var item: String = SETS[set_key][slot]
			for piece in _pieces(item):
				assert_eq(piece.find_children("*", "GPUParticles3D", true, false).size(), 0, "%s has no GPU particles" % item)
				for motes in piece.find_children("*", "CPUParticles3D", true, false):
					emitters += 1
					var p := motes as CPUParticles3D
					assert_true(p.amount <= MOTES_MAX, "%s keeps a handful of motes alive at once (%d)" % [item, p.amount])
					assert_true(p.mesh != null and (p.mesh.surface_get_material(0) as StandardMaterial3D).emission_enabled, "%s's motes glow" % item)
					assert_eq((p.mesh.surface_get_material(0) as StandardMaterial3D).emission, PALETTES[set_key]["glow"], "%s's motes are its glow colour" % item)
				piece.free()
	assert_eq(emitters, 3, "one emitter each on Emberheart, Hoarfrost and Auroral")
	for set_key in [ItemTable.SET_EMBERHEART, ItemTable.SET_HOARFROST, ItemTable.SET_AURORAL]:
		var own := 0
		for slot in SETS[set_key]:
			for piece in _pieces(SETS[set_key][slot]):
				own += piece.find_children("*", "CPUParticles3D", true, false).size()
				piece.free()
		assert_eq(own, 1, "%s has one emitter" % set_key)


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
			for own in _owns(item):
				var numbers: Dictionary = GearLookScript.SHAPES[own["shape"]]
				for key in own:
					assert_true(key == "shape" or key == GearLookScript.LAYERS or numbers.has(key), "%s's %s %s is one of its shape's numbers" % [item, own["shape"], key])
					if String(key).ends_with("tone"):
						assert_true(own[key] is Color or GearLookScript.PALETTE_FIELDS.has(own[key]), "%s's %s %s is a field or a Color" % [item, own["shape"], key])


func test_the_samples_and_the_shot_tool_cover_every_piece_on_every_ring() -> void:
	var all := CharacterGearScript.samples()
	var names: Array = []
	for child in all.get_children():
		names.append(String(child.name))
	for item in WEAPON_SHAPES:
		assert_true(names.has(WEAPON_SHAPES[item]), "the warm-up samples a %s" % WEAPON_SHAPES[item])
	var lit := 0
	for light in all.find_children("*", "OmniLight3D", true, false):
		if (light as OmniLight3D).light_color == GearLookScript.EMBERHEART["glow"]:
			lit += 1
	assert_eq(lit, 1, "the warm-up compiles the hammer's light")
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
		for slot in [ItemTable.SLOT_HELM, ItemTable.SLOT_BODY, ItemTable.SLOT_LEGS]:
			var mixed := scenes.filter(func(scene: Dictionary) -> bool:
				if scene.get(slot, "") != SETS[set_key][slot]:
					return false
				for other in [ItemTable.SLOT_HELM, ItemTable.SLOT_BODY, ItemTable.SLOT_LEGS]:
					if other != slot and ItemTable.set_of(scene.get(other, "")) == set_key:
						return false
				return true)
			assert_true(mixed.size() >= 1, "a gear_shots scene wears %s with no other %s piece" % [SETS[set_key][slot], set_key])
