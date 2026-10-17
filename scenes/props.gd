## Low-poly props for the world: CC0 Kenney models (credited in docs/assets/CREDITS.md) where
## one fits, flat-shaded primitives where none does, all dusted with snow by one shader.
##
## Presentation only. Every builder returns a Node3D standing on the ground at its origin;
## GameRoot places it where the WorldDef says the object is. Props that change with the state
## carry named children GameRoot toggles: a node's `Full` and `Spent` looks, a fire's `Flame`,
## the ring gate's `Bars`, a waystone's `Glow`.
class_name Props
extends RefCounted

const NATURE := "res://assets/models/kenney_nature/"
const SURVIVAL := "res://assets/models/kenney_survival/"
const SNOW_SHADER := preload("res://scenes/shaders/snow_cap.gdshader")

const COLOR_WOOD := Color(0.42, 0.30, 0.20)
const COLOR_DARK_WOOD := Color(0.30, 0.21, 0.14)
const COLOR_ICE := Color(0.72, 0.86, 0.95)
## Ice crystal and frost shard: the cold a staff casts with.
const COLOR_FROST := Color(0.55, 0.85, 1.0)
const COLOR_WATER := Color(0.10, 0.20, 0.30)
const COLOR_STONE := Color(0.50, 0.53, 0.58)
## Ore glints, by the rock kind they sit in.
const ORE_COLORS := {
	WorldDef.KIND_COPPER_ROCK: Color(0.85, 0.45, 0.20),
	WorldDef.KIND_TIN_ROCK: Color(0.78, 0.80, 0.84),
	WorldDef.KIND_IRON_ROCK: Color(0.45, 0.28, 0.22),
	WorldDef.KIND_ICE_CRYSTAL: COLOR_FROST,
	WorldDef.KIND_COAL_ROCK: Color(0.12, 0.12, 0.14),
	WorldDef.KIND_RICH_IRON_ROCK: Color(0.62, 0.30, 0.18),
}

static var _snow_materials := {}  # "colour|texture|snow_from" -> ShaderMaterial


## A model scaled uniformly to `height` metres, standing on the ground at the origin, with its
## materials snow-capped (snow from faces whose normal's y exceeds `snow_from`) and its colours
## multiplied by `tint`.
static func model(path: String, height: float, snow_from := 0.55, tint := Color.WHITE) -> Node3D:
	var holder := Node3D.new()
	var scene: PackedScene = load(path)
	var inner: Node3D = scene.instantiate()
	var box := _bounds(inner)
	var s := height / maxf(box.size.y, 0.001)
	inner.scale = Vector3.ONE * s
	inner.position = Vector3(-(box.position.x + box.size.x * 0.5) * s, -box.position.y * s, -(box.position.z + box.size.z * 0.5) * s)
	_snow(inner, snow_from, tint)
	holder.add_child(inner)
	return holder


## A pine for a tree node: the standing tree as `Full`, a snowy stump as `Spent`.
static func pine(kind: String) -> Node3D:
	var root := Node3D.new()
	var standing: Node3D
	if kind == WorldDef.KIND_FROST_PINE:
		standing = model(NATURE + "tree_pineTallA_detailed.glb", 4.8, 0.25)
	else:
		standing = model(NATURE + "tree_pineDefaultA.glb", 3.4)
	standing.name = "Full"
	root.add_child(standing)
	var stump := model(NATURE + "stump_round.glb", 0.45)
	stump.name = "Spent"
	stump.visible = false
	root.add_child(stump)
	return root


## A rock for a mining node, `size` metres across: the rock and its ore glints as `Full`, the
## rock alone as `Spent` (the ore has been dug out).
static func ore_rock(kind: String, size: float) -> Node3D:
	var root := Node3D.new()
	# Only the flattest tops hold snow, so the rock still reads against the snowfield.
	root.add_child(model(NATURE + "rock_largeB.glb", size * 0.5, 0.9, Color(0.55, 0.62, 0.78)))
	var ore := Node3D.new()
	ore.name = "Full"
	var colour: Color = ORE_COLORS.get(kind, Color.MAGENTA)
	var spots := [Vector3(-0.3, 0.85, 0.1), Vector3(0.25, 0.95, -0.25), Vector3(0.05, 0.8, 0.45), Vector3(0.45, 0.7, 0.3)]
	for i in spots.size():
		var glint := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.34, 0.34, 0.34) * (size / 2.0)
		mesh.material = flat(colour, 0.6)
		glint.mesh = mesh
		glint.position = spots[i] * (size / 2.0)
		glint.rotation = Vector3(0.6 * i, 0.9 * i, 0.4)
		ore.add_child(glint)
	root.add_child(ore)
	var spent := Node3D.new()
	spent.name = "Spent"
	spent.visible = false
	root.add_child(spent)
	return root


## A hole in the ice, `size` metres across: open water as `Full`, frozen over as `Spent`.
static func ice_hole(size: float, deep: bool) -> Node3D:
	var root := Node3D.new()
	var ice := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = size * 0.75
	disc.bottom_radius = size * 0.8
	disc.height = 0.08
	disc.radial_segments = 9
	disc.material = flat(COLOR_ICE.darkened(0.1) if deep else COLOR_ICE)
	ice.mesh = disc
	ice.position.y = 0.04
	root.add_child(ice)
	var water := MeshInstance3D.new()
	water.name = "Full"
	var hole := CylinderMesh.new()
	hole.top_radius = size * 0.32
	hole.bottom_radius = size * 0.32
	hole.height = 0.1
	hole.radial_segments = 7
	hole.material = flat(COLOR_WATER)
	water.mesh = hole
	water.position.y = 0.06
	root.add_child(water)
	var frozen := MeshInstance3D.new()
	frozen.name = "Spent"
	var lid := CylinderMesh.new()
	lid.top_radius = size * 0.32
	lid.bottom_radius = size * 0.32
	lid.height = 0.1
	lid.radial_segments = 7
	lid.material = flat(Color(0.88, 0.94, 1.0))
	frozen.mesh = lid
	frozen.position.y = 0.065
	frozen.visible = false
	root.add_child(frozen)
	# A rod stand at the edge, so the hole reads as a fishing spot from afar.
	var post := MeshInstance3D.new()
	var stick := CylinderMesh.new()
	stick.top_radius = 0.03
	stick.bottom_radius = 0.04
	stick.height = 1.4
	stick.material = flat(COLOR_WOOD)
	post.mesh = stick
	post.position = Vector3(size * 0.6, 0.6, 0)
	post.rotation.z = 0.5
	root.add_child(post)
	return root


## A campfire `size` metres across: logs under a fire (`Flame`, see scenes/fire_fx.gd) that
## burns, flickers and lights its surroundings on its own.
static func campfire(size: float, light := true) -> Node3D:
	var root := model(NATURE + "campfire_logs.glb", size * 0.25)
	root.add_child(FireFx.create(size, light))
	return root


static func chest(height: float) -> Node3D:
	return model(SURVIVAL + "chest.glb", height)


static func anvil(height: float) -> Node3D:
	return model(SURVIVAL + "workbench-anvil.glb", height)


## The gate to ring two: two timber posts, a lintel and the barred leaves (`Bars`), `width`
## metres across and `height` tall.
static func ring_gate(width: float, height: float) -> Node3D:
	var root := Node3D.new()
	for side in [-1, 1]:
		var post := MeshInstance3D.new()
		post.mesh = box(Vector3(0.6, height + 0.6, 0.8), COLOR_DARK_WOOD)
		post.position = Vector3(side * (width * 0.5 + 0.1), (height + 0.6) * 0.5, 0)
		root.add_child(post)
	var lintel := MeshInstance3D.new()
	lintel.mesh = box(Vector3(width + 1.4, 0.5, 0.9), COLOR_DARK_WOOD)
	lintel.position = Vector3(0, height + 0.5, 0)
	root.add_child(lintel)
	var bars := Node3D.new()
	bars.name = "Bars"
	root.add_child(bars)
	var planks := 5
	for i in planks:
		var plank := MeshInstance3D.new()
		plank.mesh = box(Vector3(width / planks - 0.08, height, 0.25), COLOR_WOOD)
		plank.position = Vector3(-width * 0.5 + (i + 0.5) * width / planks, height * 0.5, 0)
		bars.add_child(plank)
	for y in [0.3, 0.7]:
		var brace := MeshInstance3D.new()
		brace.mesh = box(Vector3(width, 0.25, 0.35), COLOR_DARK_WOOD)
		brace.position = Vector3(0, height * y, 0)
		bars.add_child(brace)
	return root


## A waystone: a standing stone `height` tall on a low plinth, `width` across, with frost runes
## (`Glow`) that light once the outpost has woken it.
static func waystone(width: float, height: float) -> Node3D:
	var root := Node3D.new()
	var plinth := MeshInstance3D.new()
	plinth.mesh = box(Vector3(width * 1.3, 0.25, width * 1.3), COLOR_STONE)
	plinth.position.y = 0.125
	root.add_child(plinth)
	var stone := MeshInstance3D.new()
	stone.mesh = box(Vector3(width * 0.7, height, width * 0.5), COLOR_STONE)
	stone.position.y = 0.25 + height * 0.5
	root.add_child(stone)
	var glow := Node3D.new()
	glow.name = "Glow"
	root.add_child(glow)
	for side in [-1, 1]:
		var rune := MeshInstance3D.new()
		rune.mesh = BoxMesh.new()
		(rune.mesh as BoxMesh).size = Vector3(width * 0.25, height * 0.45, 0.04)
		(rune.mesh as BoxMesh).material = flat(COLOR_FROST, 1.5)
		rune.position = Vector3(0, 0.25 + height * 0.55, side * (width * 0.25 + 0.02))
		glow.add_child(rune)
	return root


## A boulder filling a `size` footprint (x, height, z).
static func outcrop(size: Vector3) -> Node3D:
	return fitted(NATURE + "stone_tallB.glb", Vector3(size.x * 1.15, size.y, size.z * 1.15), 0.45)


## A model stretched to fill `size` (x, height, z), standing on the ground at the origin.
static func fitted(path: String, size: Vector3, snow_from := 0.55) -> Node3D:
	var holder := Node3D.new()
	var scene: PackedScene = load(path)
	var inner: Node3D = scene.instantiate()
	var box := _bounds(inner)
	var s := Vector3(size.x / maxf(box.size.x, 0.001), size.y / maxf(box.size.y, 0.001), size.z / maxf(box.size.z, 0.001))
	inner.scale = s
	inner.position = Vector3(-(box.position.x + box.size.x * 0.5) * s.x, -box.position.y * s.y, -(box.position.z + box.size.z * 0.5) * s.z)
	_snow(inner, snow_from)
	holder.add_child(inner)
	return holder


## A flat-shaded material of `colour`, optionally glowing a little.
static func flat(colour: Color, glow := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	m.albedo_color = colour
	m.roughness = 1.0
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = colour
		m.emission_energy_multiplier = glow
	return m


static func box(size: Vector3, colour: Color) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = flat(colour)
	return mesh


static func _bounds(root: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var b := _relative_transform(root, mi) * mi.mesh.get_aabb()
		out = b if first else out.merge(b)
		first = false
	return out


static func _relative_transform(root: Node3D, node: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var n: Node = node
	while n != null and n != root:
		t = (n as Node3D).transform * t
		n = n.get_parent()
	return t


## Swaps every surface of every mesh under `root` for a snow-capped copy of its material.
static func _snow(root: Node3D, snow_from: float, tint := Color.WHITE) -> void:
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(i) as StandardMaterial3D
			var colour := (src.albedo_color if src != null else Color.WHITE) * tint
			var tex: Texture2D = src.albedo_texture if src != null else null
			var key := "%s|%s|%.2f" % [colour.to_html(), tex.resource_path if tex != null else "", snow_from]
			if not _snow_materials.has(key):
				var m := ShaderMaterial.new()
				m.shader = SNOW_SHADER
				m.set_shader_parameter("albedo", colour)
				m.set_shader_parameter("use_texture", tex != null)
				if tex != null:
					m.set_shader_parameter("albedo_texture", tex)
				m.set_shader_parameter("snow_from", snow_from)
				_snow_materials[key] = m
			mi.set_surface_override_material(i, _snow_materials[key])
