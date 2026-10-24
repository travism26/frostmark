## The frozen frontier's looks that are not props: the snowfield painted by ring and the
## trodden yard, the timber palisade and the ice cliffs, the ruins over ring two's footprints,
## the gateway, the markers at the ring edges, and the dressing of each ring (its scatter, its
## camps and dens, its landmarks) from RingDressing's table in the ring look's colours.
## Presentation only: GameRoot builds the world from the WorldDef and calls in here for each
## piece, and nothing built here carries a collision body (clicks fall through dressing to the
## ground) or changes where anything is.
class_name WorldDressing
extends RefCounted

const SNOWFIELD_SHADER := preload("res://scenes/shaders/snowfield.gdshader")
const CASTLE := "res://assets/models/kenney_castle/"

const COLOR_SNOW := Color(0.93, 0.95, 0.99)
const COLOR_SNOW_SHADE := Color(0.76, 0.83, 0.94)
const COLOR_EARTH := Color(0.56, 0.50, 0.43)
const COLOR_EARTH_SHADE := Color(0.42, 0.37, 0.31)
const COLOR_TRODDEN_SNOW := Color(0.84, 0.85, 0.88)
const COLOR_PATH_STONE := Color(0.47, 0.50, 0.56)
const COLOR_TIMBER := Color(0.46, 0.33, 0.21)
const COLOR_TIMBER_DARK := Color(0.33, 0.23, 0.15)
const COLOR_SNOW_CAP := Color(0.94, 0.96, 1.0)
const COLOR_ICE_DEEP := Color(0.30, 0.50, 0.76)
const COLOR_ICE := Color(0.52, 0.72, 0.92)
const COLOR_ICE_PALE := Color(0.78, 0.88, 0.97)
## The gateway's posts stand this tall; GameRoot hangs the gate label above it.
const GATEWAY_HEIGHT := 3.2

static var _noise_texture: ImageTexture
static var _sparkle_texture: ImageTexture
static var _ground_materials: Array[ShaderMaterial] = []


# --- Ground ------------------------------------------------------------------------------

## The open snowfield: blue-white mottling with a faint sparkle.
static func snowfield_material() -> ShaderMaterial:
	return _ground_material(COLOR_SNOW, COLOR_SNOW_SHADE, 0.18, 0.0)


## The outpost yard: packed earth and trodden snow, with drifts blown into the corners.
static func yard_material() -> ShaderMaterial:
	var m := _ground_material(COLOR_EARTH, COLOR_EARTH_SHADE, 0.0, 0.36)
	m.set_shader_parameter("drift_color", COLOR_TRODDEN_SNOW)
	m.set_shader_parameter("broad_metres", 9.0)
	m.set_shader_parameter("fine_metres", 2.2)
	return m


static func _ground_material(base: Color, shade: Color, sparkle: float, drift_cover: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SNOWFIELD_SHADER
	m.set_shader_parameter("noise_tex", _noise())
	m.set_shader_parameter("sparkle_tex", _sparkles())
	m.set_shader_parameter("base_color", base)
	m.set_shader_parameter("shade_color", shade)
	m.set_shader_parameter("sparkle_strength", sparkle)
	m.set_shader_parameter("drift_cover", drift_cover)
	_ground_materials.append(m)
	return m


## The ring look's palette tint over the yard (the atmosphere node calls this whenever the
## tint at the character changes). The open snowfield ignores it: it is painted by ring.
static func apply_tint(tint: Color) -> void:
	for m in _ground_materials:
		m.set_shader_parameter("tint", tint)


## Paints the open snowfield by ring: each ring's `snow_tone` from the ring-look table out to
## its edge (the reach of its region polygon), stepping to the next across a short band, so
## the snow itself says where one ring ends and the next begins.
static func paint_rings(material: ShaderMaterial, world: WorldDef) -> void:
	var names := RingLook.rings(world)
	var edges := Vector3.ZERO
	for i in mini(3, names.size()):
		var reach := 0.0
		for p in world.regions[i]["polygon"]:
			reach = maxf(reach, maxf(absf(p[0]), absf(p[1])))
		edges[i] = reach
	material.set_shader_parameter("ring_tones", true)
	material.set_shader_parameter("ring_edges", edges)
	var slots := ["tone_outpost", "tone_inner", "tone_one", "tone_two"]
	for i in slots.size():
		var ring: String = names[mini(i, names.size() - 1)]
		material.set_shader_parameter(slots[i], RingLook.entry(ring)["snow_tone"])


## One seamless tile of soft fractal noise, generated once (deterministic seed) so the
## export carries no texture file.
static func _noise() -> ImageTexture:
	if _noise_texture == null:
		var n := FastNoiseLite.new()
		n.seed = 11
		n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		n.frequency = 0.03
		n.fractal_octaves = 4
		n.fractal_gain = 0.55
		_noise_texture = _seamless(n, 128)
	return _noise_texture


## Cellular noise whose bright cell centres become sun-glints on the snow.
static func _sparkles() -> ImageTexture:
	if _sparkle_texture == null:
		var n := FastNoiseLite.new()
		n.seed = 23
		n.noise_type = FastNoiseLite.TYPE_CELLULAR
		n.frequency = 0.05
		n.fractal_type = FastNoiseLite.FRACTAL_NONE
		n.cellular_return_type = FastNoiseLite.RETURN_DISTANCE
		_sparkle_texture = _seamless(n, 128, true)
	return _sparkle_texture


static func _seamless(n: FastNoiseLite, size: int, invert := false) -> ImageTexture:
	var image := n.get_seamless_image(size, size, invert, false, 0.2, true)
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


# --- The yard's path ---------------------------------------------------------------------

## Flat stones trodden into the yard from the gate (`from`) to the fire (`to`), one draw call.
static func path_stones(from: Vector2, to: Vector2) -> MultiMeshInstance3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var slab := CylinderMesh.new()
	slab.top_radius = 0.34
	slab.bottom_radius = 0.38
	slab.height = 0.07
	slab.radial_segments = 7
	slab.rings = 1
	slab.material = Props.flat(COLOR_PATH_STONE)
	var transforms: Array[Transform3D] = []
	var steps := int(from.distance_to(to) / 0.85)
	var dir := (to - from).normalized()
	var side := Vector2(-dir.y, dir.x)
	for i in steps:
		var along := from.lerp(to, (i + 0.5) / float(steps))
		var p := along + side * (0.42 if i % 2 == 0 else -0.42) + side * rng.randf_range(-0.12, 0.12)
		var s := rng.randf_range(0.8, 1.15)
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, 1.0, s * rng.randf_range(0.8, 1.1)))
		transforms.append(Transform3D(basis, Vector3(p.x, 0.035, p.y)))
	return multimesh(slab, transforms)


# --- Walls and cliffs --------------------------------------------------------------------

## The look of a blocking solid: a palisade of sharpened logs for a wall, jagged ice for a
## cliff (its snow in the snow tone of the ring it stands in), a broken wall or pillar from the
## ruin kit (in the stone of the ring it stands in) for a ruin, or null to keep the plain box.
## The mesh is centred on the footprint with the ground at -height/2, matching GameRoot's block
## placement, and carries one StandardMaterial3D on its only surface so the occluder fade can
## still see through it.
static func solid_mesh(world: WorldDef, solid: Dictionary) -> ArrayMesh:
	var min_xz: Array = solid["min"]
	var max_xz: Array = solid["max"]
	var height: float = solid["height"]
	var size := Vector3(max_xz[0] - min_xz[0], height, max_xz[1] - min_xz[1])
	var centre := Vector2((min_xz[0] + max_xz[0]) * 0.5, (min_xz[1] + max_xz[1]) * 0.5)
	match solid["kind"]:
		WorldDef.KIND_WALL:
			return _palisade(size, centre)
		WorldDef.KIND_CLIFF:
			var tone: Color = RingLook.at(world, centre)["snow_tone"]
			return _ice_cliff(size, centre, COLOR_SNOW_CAP * tone)
		WorldDef.KIND_RUIN:
			var stone: Color = RingLook.at(world, centre)["stone"]
			if RingDressing.ruin_piece(solid) == "pillar":
				return RuinKit.pillar(size, centre, stone, -height * 0.5)
			return RuinKit.wall(size, centre, stone, -height * 0.5)
	return null


## Two staggered rows of sharpened logs with snow on their points, a thicker post every
## few logs, each leaning a touch so the wall reads as hand-built.
static func _palisade(size: Vector3, centre: Vector2) -> ArrayMesh:
	var along_x := size.x >= size.z
	var length := size.x if along_x else size.z
	var thick := size.z if along_x else size.x
	var rng := MeshKit.rng(centre)
	var st := MeshKit.begin()
	var base_y := -size.y * 0.5
	var spacing := 0.5
	var count := int(length / spacing)
	for row in 2:
		var v := thick * (-0.22 if row == 0 else 0.22)
		for i in count:
			var u := -length * 0.5 + (i + 0.5 + 0.5 * row) * spacing
			if u > length * 0.5 - 0.15:
				continue
			var post := row == 0 and i % 5 == 2
			var top := base_y + size.y + (0.35 if post else rng.randf_range(-0.18, 0.1))
			var lean := Vector2(rng.randf_range(-0.03, 0.03), rng.randf_range(-0.03, 0.03))
			var colour := COLOR_TIMBER * rng.randf_range(0.82, 1.08)
			colour.a = 1.0
			MeshKit.log_post(st, MeshKit.local(u, v, along_x), base_y - 0.1, top, 0.33 if post else 0.26, 0.3 if post else 0.24, lean, colour)
	return MeshKit.finish(st)


## A ridge of ice along the footprint: a bank of snow at its toe, a face towards the world
## that steps in and out in deep blue, a crest and a higher snow-covered ridge behind it that
## rise and fall, and shards of ice standing along the top and broken at the foot. The snow
## takes `snow`, the cap toned by the ring the cliff stands in, so it sits in that ring's light.
static func _ice_cliff(size: Vector3, centre: Vector2, snow: Color) -> ArrayMesh:
	var along_x := size.x >= size.z
	var length := size.x if along_x else size.z
	var thick := size.z if along_x else size.x
	# The face nearer the world's centre is the one the player sees.
	var towards_centre := centre.y if along_x else centre.x
	var n := -1.0 if towards_centre > 0.0 else 1.0  # +v is out of the box on the inner side
	var inner := -n * thick * 0.5
	var outer := n * thick * 0.5
	var rng := MeshKit.rng(centre)
	var st := MeshKit.begin()
	var base_y := -size.y * 0.5
	var top_y := base_y + size.y
	var steps := maxi(int(length / 1.6), 1)
	var stations: Array = []
	for i in steps + 1:
		var u := -length * 0.5 + length * i / float(steps)
		if i > 0 and i < steps:
			u += rng.randf_range(-0.35, 0.35)
		stations.append([
			MeshKit.local(u, inner + n * rng.randf_range(1.2, 1.7), along_x) + Vector3(0, base_y, 0),
			MeshKit.local(u, inner + n * rng.randf_range(0.1, 0.4), along_x) + Vector3(0, base_y + rng.randf_range(0.3, 0.55), 0),
			MeshKit.local(u, inner + n * rng.randf_range(0.0, 0.5), along_x) + Vector3(0, base_y + size.y * rng.randf_range(0.4, 0.6), 0),
			MeshKit.local(u, inner + n * rng.randf_range(-0.5, 0.1), along_x) + Vector3(0, top_y + rng.randf_range(0.1, 0.8), 0),
			MeshKit.local(u, inner - n * thick * rng.randf_range(0.35, 0.55), along_x) + Vector3(0, top_y + rng.randf_range(1.0, 2.2), 0),
			MeshKit.local(u, outer, along_x) + Vector3(0, top_y * 0.4 + base_y * 0.6, 0),
			MeshKit.local(u, outer, along_x) + Vector3(0, base_y, 0),
		])
	var colours := [snow, COLOR_ICE_DEEP, COLOR_ICE, COLOR_ICE, snow, snow, COLOR_ICE_PALE]
	var face_out := MeshKit.local(0.0, n, along_x)
	var hints := [face_out + Vector3.UP * 2.0, face_out, face_out, face_out + Vector3.UP, Vector3.UP, -face_out + Vector3.UP, -face_out]
	for i in steps:
		var a: Array = stations[i]
		var b: Array = stations[i + 1]
		for k in 6:
			MeshKit.quad(st, a[k], b[k], b[k + 1], a[k + 1], colours[k], colours[k + 1], hints[k])
	# End caps so the ridge is closed where two cliffs meet at a corner.
	for end in [stations[0], stations[steps]]:
		var cap_out := MeshKit.local(-1.0 if end == stations[0] else 1.0, 0.0, along_x)
		for k in range(1, 6):
			MeshKit.tri(st, end[1], end[k], end[k + 1], colours[k], cap_out)
	# Shards: pyramids of ice along the crest and a few broken ones at the foot.
	for i in int(length / 1.4):
		var u := rng.randf_range(-length * 0.5 + 0.5, length * 0.5 - 0.5)
		var on_top := rng.randf() < 0.7
		var v := inner - n * thick * rng.randf_range(0.15, 0.6) if on_top else inner + n * rng.randf_range(0.4, 1.0)
		var h := rng.randf_range(1.2, 2.6) if on_top else rng.randf_range(0.5, 1.1)
		var y := top_y + rng.randf_range(0.3, 1.0) if on_top else base_y
		MeshKit.shard(st, MeshKit.local(u, v, along_x) + Vector3(0, y, 0), rng.randf_range(0.4, 0.8), h, rng.randf() * TAU, COLOR_ICE if on_top else COLOR_ICE_DEEP)
	return MeshKit.finish(st)


# --- The outpost gateway ------------------------------------------------------------------

## The gap in the south wall as a gateway: two tall posts and a snow-topped lintel (one mesh,
## which fades like a wall when it hides the character), a plank threshold over the footprint
## and a banner on the lintel. Stands on the ground at its origin; GameRoot adds the click
## body and the label.
static func gateway(min_xz: Array, max_xz: Array) -> MeshInstance3D:
	var width: float = max_xz[0] - min_xz[0]
	var depth: float = max_xz[1] - min_xz[1]
	var st := MeshKit.begin()
	for side in [-1.0, 1.0]:
		MeshKit.log_post(st, Vector3(side * (width * 0.5 + 0.2), 0.0, 0.0), -0.1, GATEWAY_HEIGHT, 0.36, 0.42, Vector2.ZERO, COLOR_TIMBER_DARK)
	MeshKit.box(st, Vector3(0.0, GATEWAY_HEIGHT - 0.05, 0.0), Vector3(width + 1.2, 0.32, 0.42), COLOR_TIMBER_DARK, COLOR_SNOW_CAP)
	MeshKit.box(st, Vector3(0.0, GATEWAY_HEIGHT - 0.5, 0.0), Vector3(width + 0.4, 0.16, 0.24), COLOR_TIMBER, COLOR_TIMBER)
	var planks := 4
	for i in planks:
		var plank := COLOR_TIMBER * (0.85 + 0.08 * (i % 2))
		plank.a = 1.0
		MeshKit.box(st, Vector3(-width * 0.5 + (i + 0.5) * width / planks, 0.045, 0.0), Vector3(width / planks - 0.08, 0.09, depth * 0.9), plank, plank)
	var gate := MeshInstance3D.new()
	gate.mesh = MeshKit.finish(st)
	var trim := Node3D.new()
	trim.name = "Trim"
	gate.add_child(trim)
	var banner := Props.model(CASTLE + "flag.glb", 1.6, 0.9)
	banner.position = Vector3(width * 0.5 + 0.2, GATEWAY_HEIGHT + 0.16, 0.0)
	banner.rotation.y = PI * 0.5
	trim.add_child(banner)
	return gate


# --- Set dressing ------------------------------------------------------------------------

## Dressing is kept this far from any solid or object footprint, so it never crowds a thing
## the player clicks, and this far from where an enemy stands.
const DRESSING_MARGIN := 1.3
const DRESSING_HOME_MARGIN := 3.0
const PINE_MARGIN := 2.5
const PINE_HOME_MARGIN := 5.0
## The wind the drifts lie along, as a turn about the up axis.
const WIND_ANGLE := 0.55
## Dead wood and the pennants' cloth, before the ring tint.
const COLOR_DEAD_WOOD := Color(0.40, 0.34, 0.32)
const COLOR_PENNANT := Color(0.78, 0.30, 0.22)
## A mine's rock face rises this high, over the cliff it stands on.
const MINE_FACE_HEIGHT := 7.5

## One scatter pass over every ring, then the camps, the landmarks, the mines, the lakes and
## the yard: each ring's clutter comes from RingDressing.SCATTER at the ring look's density,
## in the ring look's colours, so a later ring, dungeon or region dresses itself by adding a
## table entry. One multimesh per model surface, nothing clickable, seeded so every session
## sees the same frontier.
static func dressing(world: WorldDef) -> Node3D:
	var root := Node3D.new()
	root.name = "Dressing"
	var placer := Placer.new(world, 41)
	for ring in RingDressing.rings():
		var node := Node3D.new()
		node.name = ring
		_scatter_ring(node, placer, ring, RingLook.entry(ring))
		root.add_child(node)
	root.add_child(_camps(world, placer))
	root.add_child(_landmarks(world))
	root.add_child(mines(world))
	root.add_child(_lakes_and_rims(world))
	root.add_child(yard_props())
	return root


## Lays down every SCATTER entry for `ring`.
static func _scatter_ring(parent: Node3D, placer: Placer, ring: String, look: Dictionary) -> void:
	var tint: Color = look["tint"]
	var density: float = look["density"]
	for entry in RingDressing.SCATTER[ring]:
		var count := RingDressing.scaled_count(entry, density)
		var spacing: float = entry["spacing"]
		var scale: Array = entry.get("scale", [1.0, 1.0])
		var band: Array = entry.get("band", [0.0, INF])
		var what: String = entry["what"]
		match what:
			"drift":
				_drifts(parent, placer, ring, count, spacing, look)
			"rock":
				for name in ["rock_smallA", "rock_smallB", "rock_smallC"]:
					var spots := placer.spots(ring, count / 3, spacing, scale[0] * 0.5, scale[1] * 0.5, DRESSING_MARGIN, DRESSING_HOME_MARGIN, band)
					_scatter_model(parent, Props.NATURE + name + ".glb", 1.0, 0.6, Color(0.52, 0.58, 0.72) * tint, spots)
			"stone":
				for name in ["stone_smallA", "stone_smallB"]:
					var spots := placer.spots(ring, count / 2, spacing, scale[0] * 0.55, scale[1] * 0.55, DRESSING_MARGIN, DRESSING_HOME_MARGIN, band)
					_scatter_model(parent, Props.NATURE + name + ".glb", 1.0, 0.3, Color(0.84, 0.90, 0.98) * tint, spots)
			"bush":
				for name in ["plant_bush", "plant_bushSmall"]:
					var spots := placer.spots(ring, count / 2, spacing, scale[0] * 0.6, scale[1] * 0.6, DRESSING_MARGIN, DRESSING_HOME_MARGIN, band)
					_scatter_model(parent, Props.NATURE + name + ".glb", 1.0, 0.5, look["foliage"], spots)
			"log":
				_scatter_model(parent, Props.NATURE + "log.glb", 1.0, 0.5, tint, placer.spots(ring, count, spacing, scale[0] * 0.32, scale[1] * 0.32, DRESSING_MARGIN, DRESSING_HOME_MARGIN, band))
			"stump":
				_scatter_model(parent, Props.NATURE + "stump_old.glb", 1.0, 0.5, tint, placer.spots(ring, count, spacing, scale[0] * 0.4, scale[1] * 0.4, DRESSING_MARGIN, DRESSING_HOME_MARGIN, band))
			"pine_small":
				for name in ["tree_pineSmallA", "tree_pineSmallB"]:
					var spots := placer.spots(ring, count / 2, spacing, scale[0] * 2.4, scale[1] * 2.4, PINE_MARGIN, PINE_HOME_MARGIN, band)
					_scatter_model(parent, Props.NATURE + name + ".glb", 1.0, 0.4, tint, spots)
			"pine_tall":
				var tall := {"tree_pineRoundA": 3.3, "tree_pineDefaultB": 3.5, "tree_pineTallB_detailed": 4.6}
				for name in tall:
					var spots := placer.spots(ring, count / 3, spacing, scale[0] * tall[name], scale[1] * tall[name], PINE_MARGIN, PINE_HOME_MARGIN, band)
					_scatter_model(parent, Props.NATURE + name + ".glb", 1.0, 0.4, tint, spots)
			"dead_tree":
				for v in 3:
					var mesh := RuinKit.dead_tree(1.0, 300 + v, COLOR_DEAD_WOOD * tint)
					parent.add_child(multimesh(mesh, placer.spots(ring, count / 3, spacing, scale[0] * 3.6, scale[1] * 4.4, PINE_MARGIN, DRESSING_HOME_MARGIN, band)))
			"rubble":
				for v in 3:
					var mesh := RuinKit.rubble(400 + v, look["stone"])
					parent.add_child(multimesh(mesh, placer.spots(ring, count / 3, spacing, scale[0], scale[1], DRESSING_MARGIN, DRESSING_HOME_MARGIN, band)))
			"ice_shard":
				for v in 3:
					var mesh := RuinKit.ice_shard(1.0, 500 + v)
					parent.add_child(multimesh(mesh, placer.spots(ring, count / 3, spacing, scale[0] * 1.2, scale[1] * 2.0, DRESSING_MARGIN, DRESSING_HOME_MARGIN, band)))


## Snow drifts: low blobs lying along the prevailing wind, flatter in the safe ring and deep
## in the outer rings (the look's `drift`).
static func _drifts(parent: Node3D, placer: Placer, ring: String, count: int, spacing: float, look: Dictionary) -> void:
	var drift := SphereMesh.new()
	drift.radius = 1.0
	drift.height = 2.0
	drift.radial_segments = 9
	drift.rings = 4
	drift.material = Props.flat(Color(0.95, 0.97, 1.0) * look["snow_tone"])
	var depth: float = look["drift"]
	var transforms: Array[Transform3D] = []
	for p in placer.scatter(ring, count, spacing, 0.4, DRESSING_HOME_MARGIN):
		var length := placer.rng.randf_range(1.8, 3.4) * lerpf(0.8, 1.2, depth)
		var height := placer.rng.randf_range(0.08, 0.14) * lerpf(0.8, 2.4, depth)
		var basis := Basis(Vector3.UP, WIND_ANGLE + placer.rng.randf_range(-0.3, 0.3)).scaled(Vector3(length, height, placer.rng.randf_range(0.7, 1.3)))
		transforms.append(Transform3D(basis, Vector3(p.x, 0.0, p.y)))
	parent.add_child(multimesh(drift, transforms))


## A wolf den (a rock pile with bones at its mouth) by every wolf pack and a bandit camp (a
## tent, a cold fire ring, crates and a bit of fence) by every archer group, so the camps mark
## where the sim's enemies really live. Pieces stand 2 to 4 m from the pack's centre, never on
## a footprint; the enemies walk through them like any dressing.
static func _camps(world: WorldDef, placer: Placer) -> Node3D:
	var root := Node3D.new()
	root.name = "Camps"
	for camp in RingDressing.camps(world):
		var at: Vector2 = camp["at"]
		var look := RingLook.at(world, at)
		var away := at.normalized()  # away from the outpost
		var node := Node3D.new()
		node.name = camp["pack"]
		node.position = Vector3(at.x, 0.0, at.y)
		if camp["kind"] == "wolf_den":
			var pile := placer.clear_spot(at, away, 2.8, 1.2) - at
			for i in 3:
				var rock := Props.model(Props.NATURE + ["rock_smallA", "rock_smallB", "rock_largeB"][i] + ".glb", 1.1 + 0.3 * i, 0.7, Color(0.50, 0.54, 0.66) * look["tint"])
				rock.position = Vector3(pile.x, 0.0, pile.y) + Vector3(cos(i * 2.1) * 0.7, 0.0, sin(i * 2.1) * 0.7)
				rock.rotation.y = i * 1.3
				node.add_child(rock)
			var mouth := placer.clear_spot(at, -away, 1.8, 0.6) - at
			var bones := MeshInstance3D.new()
			bones.mesh = RuinKit.bones(int(at.x * 3.0 + at.y))
			bones.position = Vector3(mouth.x, 0.0, mouth.y)
			node.add_child(bones)
		else:
			var tents := 2 if int(camp["size"]) > 1 else 1
			for i in tents:
				var dir := away.rotated(0.9 * (i - 0.5 * (tents - 1)))
				var spot := placer.clear_spot(at, dir, 3.2, 1.4) - at
				var tent := Props.model(Props.NATURE + "tent_detailedClosed.glb", 1.9, 0.8, Color(0.72, 0.58, 0.46) * look["tint"])
				tent.position = Vector3(spot.x, 0.0, spot.y)
				tent.rotation.y = -dir.angle() + PI * 0.5
				node.add_child(tent)
			var fire_spot := placer.clear_spot(at, away.rotated(PI * 0.5), 2.2, 0.9) - at
			var fire := MeshInstance3D.new()
			fire.mesh = RuinKit.fire_ring(at)
			fire.position = Vector3(fire_spot.x, 0.0, fire_spot.y)
			node.add_child(fire)
			var crate_spot := placer.clear_spot(at, -away.rotated(0.6), 2.4, 0.6) - at
			var crate := Props.model(Props.SURVIVAL + "box.glb", 0.6, 0.6)
			crate.position = Vector3(crate_spot.x, 0.0, crate_spot.y)
			crate.rotation.y = at.x
			node.add_child(crate)
			var barrel := Props.model(Props.SURVIVAL + "barrel.glb", 0.8, 0.6)
			barrel.position = Vector3(crate_spot.x, 0.0, crate_spot.y) + Vector3(0.8, 0.0, 0.3)
			node.add_child(barrel)
			var fence_spot := placer.clear_spot(at, -away.rotated(-0.9), 3.6, 1.0) - at
			var fence := Props.model(Props.NATURE + "fence_simple.glb", 0.9, 0.5, look["tint"])
			fence.position = Vector3(fence_spot.x, 0.0, fence_spot.y)
			fence.rotation.y = -away.angle()
			node.add_child(fence)
		root.add_child(node)
	return root


## One landmark per compass direction per ring, from RingDressing.LANDMARKS, in the ring
## look's stone and wood.
static func _landmarks(world: WorldDef) -> Node3D:
	var root := Node3D.new()
	root.name = "Landmarks"
	for ring in RingDressing.LANDMARKS:
		for direction in RingDressing.DIRECTIONS:
			var mark: Dictionary = RingDressing.landmark(ring, direction)
			var at := Vector2(mark["at"][0], mark["at"][1])
			var look := RingLook.at(world, at)
			var node := landmark(mark["kind"], at, float(mark["size"]), look)
			node.name = "%s_%s" % [ring, direction]
			node.position = Vector3(at.x, 0.0, at.y)
			node.rotation.y = mark["turn"]
			root.add_child(node)
	return root


## Every mine's dressing, from RingDressing.MINES, with a pickaxe left in the first spoil heap.
static func mines(world: WorldDef) -> Node3D:
	var root := Node3D.new()
	root.name = "Mines"
	var heaps := 0
	for piece in RingDressing.mine_pieces():
		var node := Node3D.new()
		node.position = Vector3(piece["at"][0], 0.0, piece["at"][1])
		node.rotation.y = piece["turn"]
		_add_mesh(node, mine_mesh(world, piece))
		if piece["kind"] == "spoil_heap":
			if heaps == 0:
				var pick := Props.model(Props.SURVIVAL + "tool-pickaxe.glb", 0.9, 0.6)
				pick.position = Vector3(0.2, 0.3, 0.1)
				pick.rotation.z = 0.5
				node.add_child(pick)
			heaps += 1
		root.add_child(node)
	return root


## The mesh of one mine piece, standing at the origin before its turn, in the ring look's
## stone with veins of the mine's ores.
static func mine_mesh(world: WorldDef, piece: Dictionary) -> ArrayMesh:
	var at := Vector2(piece["at"][0], piece["at"][1])
	var half := Vector2(piece["half"][0], piece["half"][1])
	var stone: Color = RingLook.at(world, at)["stone"]
	var veins := []
	for kind in piece["ores"]:
		veins.append(Props.ORE_COLORS[kind])
	match piece["kind"]:
		"mine_face":
			return RuinKit.mine_face(half, MINE_FACE_HEIGHT, at, stone, veins)
		"ore_boulder":
			return RuinKit.ore_boulder(minf(half.x, half.y), at, stone, veins)
		"spoil_heap":
			return RuinKit.spoil_heap(half, at, stone, veins)
	assert(false, "no mine piece %s" % piece["kind"])
	return null


## Builds one landmark of `kind`, `size` big, standing at the origin.
static func landmark(kind: String, at: Vector2, size: float, look: Dictionary) -> Node3D:
	var stone: Color = look["stone"]
	var wood: Color = COLOR_DEAD_WOOD * look["tint"]
	var node := Node3D.new()
	match kind:
		"fallen_pine":
			_add_mesh(node, RuinKit.fallen_pine(size, at, wood))
		"split_rock":
			_add_mesh(node, RuinKit.split_rock(size, at, stone))
		"cairn":
			_add_mesh(node, RuinKit.cairn(size, at, stone))
		"dead_giant":
			_add_mesh(node, RuinKit.dead_giant(size, at, wood))
		"frozen_waterfall":
			_add_mesh(node, RuinKit.frozen_waterfall(size, 3.6, at))
		"watch_post":
			_add_mesh(node, RuinKit.watch_post(size, at))
		"tower_base":
			_add_mesh(node, RuinKit.tower_base(size, 2.4, at, stone))
		"fallen_arch":
			_add_mesh(node, RuinKit.arch(size, 3.2, 1.0, at, stone))
		"ice_spire":
			_add_mesh(node, RuinKit.ice_spire(size, at))
		"stone_ring":
			var count := 7
			for i in count:
				var a := i * TAU / count + 0.3
				var stone_mesh := MeshInstance3D.new()
				stone_mesh.mesh = RuinKit.standing_stone(1.4 + 0.5 * (i % 3), at + Vector2(i, 0), stone, false, Vector2(cos(a), sin(a)) * 0.12)
				stone_mesh.position = Vector3(cos(a) * size, 0.0, sin(a) * size)
				stone_mesh.rotation.y = -a
				node.add_child(stone_mesh)
		"caravan_wreck":
			_add_mesh(node, RuinKit.wagon(at))
			# The load spilled out behind and beside the wagon, toward the road it came up.
			var crates := [[Vector2(-1.6, -0.6), 0.6, 0.3], [Vector2(-1.9, 0.6), 0.5, 1.4], [Vector2(-1.2, 2.1), 0.55, 0.8], [Vector2(1.3, 2.4), 0.5, 2.2]]
			for c in crates:
				var crate := Props.model(Props.SURVIVAL + "box.glb", c[1], 0.6)
				crate.position = Vector3(c[0].x, 0.0, c[0].y)
				crate.rotation.y = c[2]
				node.add_child(crate)
			var barrel := Props.model(Props.SURVIVAL + "barrel.glb", 0.8, 0.6)
			barrel.position = Vector3(1.6, 0.0, 1.4)
			barrel.rotation.z = PI * 0.5
			barrel.position.y = 0.4
			node.add_child(barrel)
			var fire := MeshInstance3D.new()
			fire.mesh = RuinKit.fire_ring(at + Vector2(1, 1))
			fire.position = Vector3(-2.6, 0.0, 3.2)
			node.add_child(fire)
		_:
			assert(false, "no landmark kind %s" % kind)
	return node


static func _add_mesh(parent: Node3D, mesh: Mesh) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	parent.add_child(mi)
	return mi


## The frozen lakes, as sheets of ice under their holes, and the frozen rim around the safe
## ring's fishing hole.
static func _lakes_and_rims(world: WorldDef) -> Node3D:
	var root := Node3D.new()
	root.name = "Ice"
	for ring in RingDressing.LAKES:
		for lake in RingDressing.LAKES[ring]:
			var at := Vector2(lake["at"][0], lake["at"][1])
			var st := MeshKit.begin()
			var rng := MeshKit.rng(at)
			MeshKit.disc(st, Vector3(0, 0.015, 0), lake["radius"], 18, Color(0.70, 0.82, 0.94), Color(0.60, 0.74, 0.90), rng)
			for i in 12:
				var a := rng.randf() * TAU
				var d := float(lake["radius"]) * rng.randf_range(0.3, 0.95)
				MeshKit.shard(st, Vector3(cos(a) * d, 0.2, sin(a) * d), rng.randf_range(0.15, 0.3), rng.randf_range(0.3, 0.8), rng.randf() * TAU, RuinKit.ICE)
			var mi := _add_mesh(root, MeshKit.finish(st))
			mi.position = Vector3(at.x, 0.0, at.y)
	for id in world.objects_of_kind(WorldDef.KIND_FISHING_HOLE):
		var centre := world.object_center(id)
		var size: float = world.objects[id]["max"][0] - world.objects[id]["min"][0]
		var st := MeshKit.begin()
		var rng := MeshKit.rng(centre)
		for k in 11:
			var a := k * TAU / 11.0
			var d := size * 0.95 + rng.randf_range(0.0, 0.3)
			MeshKit.block(st, Vector3(cos(a) * d, 0.04, sin(a) * d), Vector3(0.6, 0.08, 0.5), -a, rng.randf_range(-0.12, 0.12), RuinKit.ICE_PALE, RuinKit.ICE_PALE)
		var mi := _add_mesh(root, MeshKit.finish(st))
		mi.position = Vector3(centre.x, 0.0, centre.y)
	return root


## The markers at the ring edges: rough standing stones every few metres along the safe
## ring's edge where the ground is walkable, two pennant posts where the road crosses it, and
## two carved stones flanking the road just past the gate to ring two.
static func boundaries(world: WorldDef) -> Node3D:
	var root := Node3D.new()
	root.name = "Boundaries"
	var inner_look := RingLook.entry(WorldDef.REGION_INNER_RING)
	var variants: Array[Array] = [[], [], []]
	for r in world.regions:
		if r["name"] != WorldDef.REGION_INNER_RING:
			continue
		var polygon: Array = r["polygon"]
		var n := 0
		for i in polygon.size():
			var a := Vector2(polygon[i][0], polygon[i][1])
			var b := Vector2(polygon[(i + 1) % polygon.size()][0], polygon[(i + 1) % polygon.size()][1])
			var steps := int(a.distance_to(b) / RingDressing.BOUNDARY_SPACING)
			for k in steps:
				var p := a.lerp(b, float(k) / steps)
				if not world.is_walkable(p) or (absf(p.x) < 4.0 and p.y > 0.0):
					continue  # the road south keeps its posts instead
				n += 1
				var turn := Basis(Vector3.UP, float(n) * 2.399).scaled(Vector3.ONE * (0.9 + 0.2 * (n % 3)))
				(variants[n % 3] as Array).append(Transform3D(turn, Vector3(p.x, 0.0, p.y)))
	for v in 3:
		var transforms: Array[Transform3D] = []
		transforms.assign(variants[v])
		root.add_child(multimesh(RuinKit.standing_stone(1.8, Vector2(v * 7.0, 24.0), inner_look["stone"], false), transforms))
	for post in RingDressing.ROAD_POSTS:
		var st := MeshKit.begin()
		MeshKit.log_post(st, Vector3.ZERO, -0.2, 2.6, 0.12, 0.14, Vector2.ZERO, COLOR_TIMBER_DARK)
		# The pennant: a long triangle streaming along the wind from the top of the post.
		var top := Vector3(0, 2.45, 0)
		var wind := Vector3(cos(WIND_ANGLE), 0.0, sin(WIND_ANGLE))
		MeshKit.tri_shade(st, top, top - Vector3(0, 0.45, 0), top + wind * 1.1 - Vector3(0, 0.2, 0), COLOR_PENNANT, COLOR_PENNANT, COLOR_PENNANT.lightened(0.2), Vector3(wind.z, 0.0, -wind.x))
		MeshKit.tri_shade(st, top, top - Vector3(0, 0.45, 0), top + wind * 1.1 - Vector3(0, 0.2, 0), COLOR_PENNANT, COLOR_PENNANT, COLOR_PENNANT.lightened(0.2), Vector3(-wind.z, 0.0, wind.x))
		var mi := _add_mesh(root, MeshKit.finish(st))
		mi.position = Vector3(post[0], 0.0, post[1])
	var far_look := RingLook.entry(WorldDef.REGION_RING_TWO)
	for i in RingDressing.GATE_STONES.size():
		var at := Vector2(RingDressing.GATE_STONES[i][0], RingDressing.GATE_STONES[i][1])
		var mi := _add_mesh(root, RuinKit.standing_stone(2.7, at, far_look["stone"], true, Vector2(0.03 * (1 if i == 0 else -1), -0.02)))
		mi.position = Vector3(at.x, 0.0, at.y)
	return root


## The keeper's clutter inside the walls: barrels by the stash, crates by the workbench, log
## stacks and a bucket by the fire, a signpost inside the gate, a bedroll and a bit of fence
## by the tent, planks and firewood against the walls, and the outpost's banners hung on the
## north wall. Lived-in and warm, nothing dangerous.
static func yard_props() -> Node3D:
	var yard := Node3D.new()
	yard.name = "Yard"
	var items := [
		[Props.SURVIVAL + "barrel.glb", 0.9, Vector2(-8.2, -8.0), 0.3],
		[Props.SURVIVAL + "barrel.glb", 0.85, Vector2(-7.4, -8.5), 1.9],
		[Props.SURVIVAL + "box.glb", 0.7, Vector2(-2.6, -8.4), 0.2],
		[Props.SURVIVAL + "box.glb", 0.6, Vector2(-1.5, -8.5), 0.9],
		[Props.NATURE + "log_stackLarge.glb", 0.55, Vector2(-8.4, 1.5), PI * 0.5],
		[Props.NATURE + "log_stack.glb", 0.5, Vector2(-8.4, 4.6), PI * 0.5],
		[Props.NATURE + "log_stack.glb", 0.5, Vector2(-8.3, 2.8), PI * 0.5],
		[Props.NATURE + "log_stack.glb", 0.45, Vector2(2.6, -8.4), 0.0],
		[Props.SURVIVAL + "resource-planks.glb", 0.5, Vector2(8.3, -3.0), PI * 0.5],
		[Props.SURVIVAL + "resource-wood.glb", 0.45, Vector2(8.3, -1.4), PI * 0.5],
		[Props.SURVIVAL + "bucket.glb", 0.35, Vector2(1.9, 1.4), 0.0],
		[Props.SURVIVAL + "signpost.glb", 1.5, Vector2(-3.4, 8.0), PI * 0.1],
		[Props.SURVIVAL + "bedroll.glb", 0.22, Vector2(4.6, 8.0), PI * 0.4],
		[Props.SURVIVAL + "tree-log.glb", 0.3, Vector2(-8.5, 3.4), PI * 0.5],
		[Props.NATURE + "fence_simple.glb", 0.9, Vector2(5.2, 5.6), 0.0],
		[Props.NATURE + "fence_planks.glb", 0.9, Vector2(8.6, 4.6), PI * 0.5],
	]
	for item in items:
		var prop := Props.model(item[0], item[1], 0.6)
		prop.position = Vector3(item[2].x, 0.0, item[2].y)
		prop.rotation.y = item[3]
		yard.add_child(prop)
	for x in [-5.0, 5.0]:
		var banner := Props.model(CASTLE + "flag-banner-long.glb", 2.2, 0.9)
		banner.position = Vector3(x, 0.8, -8.6)
		banner.rotation.y = PI * 0.5
		yard.add_child(banner)
	var drift := SphereMesh.new()
	drift.radius = 1.0
	drift.height = 2.0
	drift.radial_segments = 9
	drift.rings = 4
	drift.material = Props.flat(Color(0.95, 0.97, 1.0))
	var corners: Array[Transform3D] = []
	for corner in [Vector2(-8.3, -8.3), Vector2(8.3, -8.3), Vector2(-8.3, 8.2)]:
		corners.append(Transform3D(Basis(Vector3.UP, corner.angle()).scaled(Vector3(1.6, 0.14, 1.1)), Vector3(corner.x, 0.0, corner.y)))
	yard.add_child(multimesh(drift, corners))
	return yard


# --- Upgrade pieces in the yard -----------------------------------------------------------

## Fresh-sawn plank for the yard pieces, paler than the palisade's weathered timber.
const COLOR_PLANK := Color(0.66, 0.49, 0.31)
## A shelf rack's boards, as fractions of its height: YardLook stands crates on their tops.
const YARD_RACK_BOARDS := [0.1, 0.48, 0.86]
## Wrought iron for the straps and hinges on the yard pieces, and the brass of a lock plate.
const COLOR_IRON := Color(0.22, 0.23, 0.26)
const COLOR_IRON_EDGE := Color(0.36, 0.37, 0.41)
const COLOR_BRASS := Color(0.66, 0.52, 0.26)
## Bright worked iron on the armoury's blades and the winch's bands and chain, and the armoury's
## grips, before the ring tint.
const COLOR_STEEL := Color(0.62, 0.65, 0.70)
const COLOR_IRON_DARK := Color(0.27, 0.28, 0.31)
const COLOR_LEATHER := Color(0.36, 0.22, 0.14)

## One piece from YardLook, standing where the piece says: kit models and hand-made meshes in
## the outpost's timber. Nothing clickable, so a click falls through to the yard floor.
static func yard_piece(piece: Dictionary) -> Node3D:
	var node := Node3D.new()
	node.name = piece["upgrade"]
	node.position = Vector3(piece["at"].x, 0.0, piece["at"].y)
	node.rotation.y = piece["turn"]
	for part in piece["parts"]:
		var built: Node3D
		if part.has("model"):
			built = Props.model(part["model"], part["height"], part.get("snow_from", 0.55))
		else:
			var mi := MeshInstance3D.new()
			mi.mesh = yard_mesh(part["mesh"], Vector3(part["size"][0], part["size"][1], part["size"][2]))
			built = mi
		built.position = Vector3(part["at"][0], part.get("y", 0.0), part["at"][1])
		built.rotation.y = part.get("turn", 0.0)
		node.add_child(built)
	return node


## A hand-made yard mesh YardLook names, `size` long (x), high (y) and deep (z).
static func yard_mesh(kind: String, size: Vector3) -> ArrayMesh:
	assert(kind in YardLook.MESHES, "no yard mesh %s" % kind)
	match kind:
		"hatch":
			return _hatch(size)
		"iron_chest":
			return _iron_chest(size)
		"weapon_rack":
			return _weapon_rack(size)
		"winch_frame":
			return _winch_frame(size)
		"forge_hearth":
			return _forge_hearth(size)
		"bloomery_shaft":
			return _bloomery_shaft(size)
		"furnace_stack":
			return _furnace_stack(size)
	return _shelf_rack(size)


## A shelf rack in the gateway's hand: four log uprights with snowy points, three boards in
## fresh-sawn plank (light enough to read in the wall's shadow) and a back rail, standing on
## the ground with its back to -z. The boards sit at YARD_RACK_BOARDS of its height.
static func _shelf_rack(size: Vector3) -> ArrayMesh:
	var st := MeshKit.begin()
	var r := 0.06
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			MeshKit.log_post(st, Vector3(x * (size.x * 0.5 - r), 0.0, z * (size.z * 0.5 - r)), -0.05, size.y - 0.1, r, 0.1, Vector2.ZERO, COLOR_TIMBER)
	for i in YARD_RACK_BOARDS.size():
		var plank := COLOR_PLANK * (0.94 + 0.06 * (i % 2))
		plank.a = 1.0
		MeshKit.box(st, Vector3(0.0, YARD_RACK_BOARDS[i] * size.y, 0.0), Vector3(size.x - 0.04, 0.06, size.z - 0.04), plank, plank)
	MeshKit.box(st, Vector3(0.0, size.y * 0.62, -size.z * 0.5 + 0.03), Vector3(size.x - 0.1, 0.08, 0.04), COLOR_TIMBER_DARK, COLOR_TIMBER_DARK)
	return MeshKit.finish(st)


## A cellar hatch lying in the yard floor: a dark timber frame, a door of fresh-sawn planks
## running along x, two iron hinge straps across them from the back (-z) and an iron ring at
## the front, all within `size.y` of the ground.
static func _hatch(size: Vector3) -> ArrayMesh:
	var st := MeshKit.begin()
	var rim := 0.12
	var h := size.y
	for z in [-1.0, 1.0]:
		MeshKit.box(st, Vector3(0.0, h * 0.4, z * (size.z - rim) * 0.5), Vector3(size.x, h * 0.8, rim), COLOR_TIMBER_DARK, COLOR_TIMBER_DARK)
	for x in [-1.0, 1.0]:
		MeshKit.box(st, Vector3(x * (size.x - rim) * 0.5, h * 0.4, 0.0), Vector3(rim, h * 0.8, size.z - rim * 2.0), COLOR_TIMBER_DARK, COLOR_TIMBER_DARK)
	var planks := 4
	var inner := size.z - rim * 2.0
	for i in planks:
		var plank := COLOR_PLANK * (0.9 + 0.1 * (i % 2))
		plank.a = 1.0
		var z := -inner * 0.5 + inner * (i + 0.5) / planks
		MeshKit.box(st, Vector3(0.0, h * 0.3, z), Vector3(size.x - rim * 2.0, h * 0.6, inner / planks - 0.02), plank, plank)
	for x in [-0.28, 0.28]:
		MeshKit.box(st, Vector3(x * size.x, h * 0.65, -size.z * 0.12), Vector3(0.07, h * 0.1, size.z * 0.66), COLOR_IRON, COLOR_IRON_EDGE)
	MeshKit.box(st, Vector3(0.0, h * 0.65, size.z * 0.5 - rim - 0.08), Vector3(0.16, h * 0.1, 0.05), COLOR_IRON, COLOR_IRON_EDGE)
	MeshKit.box(st, Vector3(0.0, h * 0.65, size.z * 0.5 - rim - 0.17), Vector3(0.05, h * 0.1, 0.13), COLOR_IRON, COLOR_IRON_EDGE)
	return MeshKit.finish(st)


## An iron-bound chest: a dark timber body, a lid of fresh-sawn plank with a little snow along
## its back, two iron straps over body and lid, iron caps on its ends, an iron rim at the seam and a brass lock
## plate on the front (+z).
static func _iron_chest(size: Vector3) -> ArrayMesh:
	var st := MeshKit.begin()
	var body := size.y * 0.62
	var lid := size.y - body
	MeshKit.box(st, Vector3(0.0, body * 0.5, 0.0), Vector3(size.x - 0.04, body, size.z - 0.04), COLOR_TIMBER, COLOR_TIMBER)
	MeshKit.box(st, Vector3(0.0, body + lid * 0.5, 0.0), Vector3(size.x, lid, size.z), COLOR_PLANK, COLOR_PLANK)
	MeshKit.box(st, Vector3(0.0, size.y + 0.01, -size.z * 0.36), Vector3(size.x - 0.06, 0.03, size.z * 0.24), MeshKit.SNOW, MeshKit.SNOW)
	for x in [-0.3, 0.3]:
		MeshKit.box(st, Vector3(x * size.x, size.y * 0.5 + 0.005, 0.0), Vector3(0.08, size.y + 0.03, size.z + 0.03), COLOR_IRON, COLOR_IRON_EDGE)
	MeshKit.box(st, Vector3(0.0, body, 0.0), Vector3(size.x + 0.03, 0.05, size.z + 0.03), COLOR_IRON, COLOR_IRON_EDGE)
	for x in [-1.0, 1.0]:
		MeshKit.box(st, Vector3(x * (size.x * 0.5 - 0.03), size.y * 0.5, 0.0), Vector3(0.08, size.y + 0.02, size.z + 0.02), COLOR_IRON, COLOR_IRON_EDGE)
	MeshKit.box(st, Vector3(0.0, body - 0.02, size.z * 0.5 + 0.025), Vector3(0.16, 0.2, 0.03), COLOR_BRASS, COLOR_BRASS)
	return MeshKit.finish(st)


## A weapon rack in the gateway's hand, its back to -z: two log uprights, a snowy top rail
## and a notched foot rail in fresh plank, swords (hilts up, iron blades catching the light)
## and spears leaning back into it, and a round shield in the banners' red hung at the middle,
## tipped up so its face reads from above.
static func _weapon_rack(size: Vector3) -> ArrayMesh:
	var st := MeshKit.begin()
	var r := 0.07
	var back := -size.z * 0.5 + r
	for x in [-1.0, 1.0]:
		MeshKit.log_post(st, Vector3(x * (size.x * 0.5 - r), 0.0, back), -0.05, size.y - 0.1, r, 0.12, Vector2.ZERO, COLOR_TIMBER)
	MeshKit.box(st, Vector3(0.0, size.y * 0.78, back + 0.04), Vector3(size.x - 0.04, 0.09, 0.1), COLOR_PLANK, MeshKit.SNOW)
	MeshKit.box(st, Vector3(0.0, 0.12, size.z * 0.5 - 0.1), Vector3(size.x - 0.04, 0.1, 0.16), COLOR_PLANK, COLOR_PLANK)
	MeshKit.box(st, Vector3(0.0, 0.04, 0.0), Vector3(size.x - 0.2, 0.06, size.z - 0.08), COLOR_TIMBER_DARK, COLOR_TIMBER_DARK)
	# Each weapon stands on the foot rail and leans back onto the top rail.
	var rest := Vector3(0.0, size.y * 0.78, back + 0.12)
	var foot_z := size.z * 0.5 - 0.12
	var lean := atan2(foot_z - rest.z, rest.y)
	var slots := [-0.8, -0.5, -0.2, 0.55, 0.85]
	for i in slots.size():
		var x: float = slots[i] * (size.x * 0.5 - 0.15)
		if i % 2 == 0:
			_rack_sword(st, Vector3(x, 0.17, foot_z), lean)
		else:
			_rack_spear(st, Vector3(x, 0.17, foot_z), lean, size.y + 0.15)
	_rack_shield(st, Vector3(size.x * 0.08, size.y * 0.55, back + 0.24), 0.4)
	return MeshKit.finish(st)


## A point `up` metres along a weapon standing at `foot` and leaning back (to -z) by `lean`.
static func _along(foot: Vector3, lean: float, up: float) -> Vector3:
	return foot + Vector3(0.0, cos(lean) * up, -sin(lean) * up)


## A sword point-down in a rack: an iron blade, a dark crossguard, a leather grip and pommel.
static func _rack_sword(st: SurfaceTool, foot: Vector3, lean: float) -> void:
	var tilt := -lean
	MeshKit.block(st, _along(foot, lean, 0.4), Vector3(0.12, 0.8, 0.04), 0.0, tilt, COLOR_STEEL, COLOR_STEEL)
	MeshKit.block(st, _along(foot, lean, 0.82), Vector3(0.32, 0.07, 0.08), 0.0, tilt, COLOR_IRON_DARK, COLOR_IRON_DARK)
	MeshKit.block(st, _along(foot, lean, 0.94), Vector3(0.06, 0.2, 0.06), 0.0, tilt, COLOR_LEATHER, COLOR_LEATHER)
	MeshKit.block(st, _along(foot, lean, 1.06), Vector3(0.1, 0.08, 0.1), 0.0, tilt, COLOR_IRON_DARK, COLOR_IRON_DARK)


## A spear butt-down in a rack: a timber shaft `length` long and an iron head.
static func _rack_spear(st: SurfaceTool, foot: Vector3, lean: float, length: float) -> void:
	var tilt := -lean
	MeshKit.block(st, _along(foot, lean, length * 0.45), Vector3(0.06, length * 0.9, 0.06), 0.0, tilt, COLOR_TIMBER_DARK, COLOR_TIMBER_DARK)
	MeshKit.block(st, _along(foot, lean, length * 0.95), Vector3(0.14, length * 0.14, 0.05), PI * 0.25, tilt, COLOR_STEEL, COLOR_STEEL)


## A round shield `r` across hung at `at`, facing +z and tipped back to face the sky a little:
## a red face, a dark iron rim and a boss.
static func _rack_shield(st: SurfaceTool, at: Vector3, r: float) -> void:
	var sides := 10
	var face := Basis(Vector3.RIGHT, -0.7)
	var normal := face * Vector3.BACK
	for k in sides:
		var a0 := k * TAU / sides
		var a1 := (k + 1) * TAU / sides
		var p0 := at + face * Vector3(cos(a0) * r, sin(a0) * r, 0.0)
		var p1 := at + face * Vector3(cos(a1) * r, sin(a1) * r, 0.0)
		var i0 := at + face * Vector3(cos(a0) * r * 0.82, sin(a0) * r * 0.82, 0.02)
		var i1 := at + face * Vector3(cos(a1) * r * 0.82, sin(a1) * r * 0.82, 0.02)
		MeshKit.quad(st, p0, p1, i1, i0, COLOR_IRON_DARK, COLOR_IRON_DARK, normal)
		MeshKit.tri(st, i0, i1, at + normal * 0.03, COLOR_PENNANT, normal)
	MeshKit.block(st, at + normal * 0.05, Vector3(0.12, 0.12, 0.06), 0.0, -0.7, COLOR_STEEL, COLOR_STEEL)


## A winch frame in the gateway's hand: two A-frame trestles of log legs on sill timbers, an
## axle beam across their tops, a timber drum with iron bands and its chain wound on, a crank
## at one end, and the chain run out along the ground (+z) to an anchor stone with an iron ring.
static func _winch_frame(size: Vector3) -> ArrayMesh:
	var st := MeshKit.begin()
	var r := 0.07
	var half := size * 0.5
	var top := size.y - 0.15
	var drum_y := size.y * 0.62
	var foot_z := half.z - 0.25
	for side in [-1.0, 1.0]:
		var x: float = side * (half.x - 0.2)
		MeshKit.box(st, Vector3(x, 0.05, -0.1), Vector3(0.16, 0.1, size.z - 0.25), COLOR_TIMBER_DARK, COLOR_TIMBER_DARK)
		for z in [-foot_z - 0.1, foot_z - 0.1]:
			MeshKit.log_post(st, Vector3(x, 0.0, z), 0.0, top, r, 0.1, Vector2(0.0, (-0.1 - z) / top), COLOR_TIMBER)
		MeshKit.box(st, Vector3(x, drum_y, -0.1), Vector3(0.14, 0.12, 0.3), COLOR_TIMBER_DARK, MeshKit.SNOW)
	MeshKit.box(st, Vector3(0.0, top + 0.02, -0.1), Vector3(size.x - 0.2, 0.12, 0.14), COLOR_PLANK, MeshKit.SNOW)
	# The drum, its iron bands and the chain wound round it.
	var drum_x := half.x - 0.32
	_cylinder_x(st, Vector3(0.0, drum_y, -0.1), drum_x, 0.2, 8, COLOR_PLANK)
	for x in [-drum_x + 0.05, drum_x - 0.05]:
		_cylinder_x(st, Vector3(x, drum_y, -0.1), 0.04, 0.215, 8, COLOR_IRON_DARK)
	_cylinder_x(st, Vector3(0.0, drum_y, -0.1), 0.32, 0.23, 8, COLOR_STEEL)
	# The crank outside the east trestle, and the axle through both.
	_cylinder_x(st, Vector3(0.0, drum_y, -0.1), half.x - 0.05, 0.04, 6, COLOR_IRON_DARK)
	MeshKit.box(st, Vector3(half.x - 0.07, drum_y + 0.14, -0.1), Vector3(0.05, 0.32, 0.06), COLOR_IRON_DARK, COLOR_IRON_DARK)
	_cylinder_x(st, Vector3(half.x + 0.0, drum_y + 0.28, -0.1), 0.07, 0.03, 6, COLOR_LEATHER)
	# The chain: links off the drum's foot, down and out along the ground to the anchor.
	var from := Vector3(0.0, drum_y - 0.22, 0.05)
	var to := Vector3(0.0, 0.08, half.z - 0.2)
	var links := 9
	for i in links:
		var t := (i + 0.5) / links
		var p := from.lerp(to, t)
		p.y = lerpf(from.y, to.y, sqrt(t))
		MeshKit.block(st, p, Vector3(0.05, 0.03, 0.12) if i % 2 == 0 else Vector3(0.015, 0.06, 0.12), 0.0, 0.0, COLOR_STEEL, COLOR_STEEL)
	MeshKit.prism(st, Vector3(0.0, 0.0, half.z - 0.12), 6, 0.16, 0.12, 0.0, 0.16, 0.3, COLOR_PATH_STONE, COLOR_PATH_STONE, MeshKit.SNOW)
	MeshKit.box(st, Vector3(0.0, 0.2, half.z - 0.12), Vector3(0.12, 0.1, 0.03), COLOR_IRON_DARK, COLOR_IRON_DARK)
	return MeshKit.finish(st)


## A horizontal prism `sides` around and `r` wide along x, `half_len` either side of `at`,
## closed at both ends: a drum, a band, an axle.
static func _cylinder_x(st: SurfaceTool, at: Vector3, half_len: float, r: float, sides: int, colour: Color) -> void:
	for k in sides:
		var a0 := (k + 0.5) * TAU / sides
		var a1 := (k + 1.5) * TAU / sides
		var o0 := Vector3(0.0, sin(a0) * r, cos(a0) * r)
		var o1 := Vector3(0.0, sin(a1) * r, cos(a1) * r)
		var out := (o0 + o1).normalized()
		var lit := colour if out.y < 0.5 else colour.lightened(0.08)
		MeshKit.quad(st, at + o0 - Vector3(half_len, 0, 0), at + o1 - Vector3(half_len, 0, 0), at + o1 + Vector3(half_len, 0, 0), at + o0 + Vector3(half_len, 0, 0), lit, lit, out)
		for end in [-1.0, 1.0]:
			var c := at + Vector3(end * half_len, 0, 0)
			MeshKit.tri(st, c + o0, c + o1, c, colour, Vector3(end, 0, 0))


## The smithy's field stone and its soot (its hoops are COLOR_IRON, its bellows COLOR_LEATHER).
const COLOR_SMITHY_STONE := Color(0.53, 0.50, 0.48)
const COLOR_SOOT := Color(0.17, 0.15, 0.15)
## Live coals: the forge and furnace glow with this emissive colour, the way the waystone
## runes do, and light nothing around them.
const COLOR_EMBER := Color(0.95, 0.34, 0.07)
## The bloomery's daubed clay, and the ore heaped beside it.
const COLOR_CLAY := Color(0.56, 0.38, 0.27)
const COLOR_IRON_ORE := Color(0.36, 0.31, 0.32)
const EMBER_GLOW := 1.2

## A forge hearth in the gateway's hand: a coursed stone hearth with a bed of glowing coals
## in a sooty rim, an ash-pit mouth glowing at its front (+z), a stone hood and flue at its
## back (-z) and timber bellows along its west end. No snow: it is warm.
static func _forge_hearth(size: Vector3) -> ArrayMesh:
	var st := MeshKit.begin()
	var glow := MeshKit.begin()
	var bellows := 0.3
	var body := Vector3(size.x - bellows, size.y, size.z)
	var cx := bellows * 0.5
	_courses(st, Vector3(cx, 0.0, 0.0), body, body, 3, COLOR_SMITHY_STONE, COLOR_SOOT)
	# The rim round the coal bed, and the coals sunk a little inside it.
	var rim := 0.13
	var top := size.y
	for side in [-1.0, 1.0]:
		MeshKit.box(st, Vector3(cx, top + 0.05, side * (body.z * 0.5 - rim * 0.5)), Vector3(body.x, 0.1, rim), COLOR_SOOT, COLOR_SOOT)
		MeshKit.box(st, Vector3(cx + side * (body.x * 0.5 - rim * 0.5), top + 0.05, 0.0), Vector3(rim, 0.1, body.z - 2.0 * rim), COLOR_SOOT, COLOR_SOOT)
	# Lumps of coal, most of them alight, heaped in the bed in front of the hood.
	var bed := Vector2(body.x - 2.0 * rim - 0.06, body.z * 0.42)
	var lumps := Vector2i(4, 3)
	for i in lumps.x:
		for k in lumps.y:
			var u := (i + 0.5) / lumps.x - 0.5
			var v := (k + 0.5) / lumps.y - 0.5
			var lump := Vector3(bed.x / lumps.x - 0.02, 0.05 + 0.03 * ((i + k) % 2), bed.y / lumps.y - 0.02)
			var at := Vector3(cx + u * bed.x, top + 0.02, 0.08 + v * bed.y)
			if (i * 2 + k) % 5 == 1:
				MeshKit.box(st, at, lump, COLOR_SOOT, COLOR_SOOT)
			else:
				MeshKit.box(glow, at, lump, COLOR_EMBER, COLOR_EMBER)
	# The hood over the back of the bed, and its flue.
	var back := -body.z * 0.5 + 0.17
	MeshKit.box(st, Vector3(cx, top + 0.3, back), Vector3(body.x * 0.62, 0.4, 0.32), COLOR_SMITHY_STONE * 0.9, COLOR_SOOT)
	MeshKit.prism(st, Vector3(cx, 0.0, back), 6, 0.15, 0.13, top + 0.5, top + 1.05, 0.3, COLOR_SMITHY_STONE * 0.86, COLOR_SOOT, COLOR_SOOT)
	# The bellows: two boards with leather between, the nozzle into the hearth's side.
	var bx := -size.x * 0.5 + bellows * 0.5
	MeshKit.block(st, Vector3(bx, size.y * 0.55, 0.0), Vector3(0.26, 0.14, size.z * 0.66), 0.0, 0.12, COLOR_LEATHER, COLOR_LEATHER)
	MeshKit.block(st, Vector3(bx, size.y * 0.55 + 0.09, 0.02), Vector3(0.28, 0.04, size.z * 0.7), 0.0, 0.18, COLOR_TIMBER, COLOR_PLANK)
	MeshKit.block(st, Vector3(bx, size.y * 0.55 - 0.09, 0.0), Vector3(0.28, 0.04, size.z * 0.7), 0.0, 0.06, COLOR_TIMBER_DARK, COLOR_TIMBER_DARK)
	MeshKit.box(st, Vector3(bx + 0.14, size.y * 0.55, -size.z * 0.32), Vector3(0.12, 0.06, 0.06), COLOR_IRON, COLOR_IRON)
	MeshKit.log_post(st, Vector3(bx, 0.0, size.z * 0.25), 0.0, size.y * 0.5, 0.04, 0.02, Vector2.ZERO, COLOR_TIMBER_DARK, COLOR_TIMBER_DARK)
	MeshKit.log_post(st, Vector3(bx, 0.0, -size.z * 0.25), 0.0, size.y * 0.5, 0.04, 0.02, Vector2.ZERO, COLOR_TIMBER_DARK, COLOR_TIMBER_DARK)
	return _with_glow(st, glow)


## A bloomery `size` high: a round clay shaft tapering to a sooty, glowing mouth on a stone
## footing, a glowing tap arch at its front (+z) where the bloom is drawn, a clay pipe for the
## bellows at its west side and a heap of iron ore at its east foot. Snow only on the footing.
static func _bloomery_shaft(size: Vector3) -> ArrayMesh:
	var st := MeshKit.begin()
	var glow := MeshKit.begin()
	var r := minf(size.x, size.z) * 0.5
	var footing := 0.22
	_courses(st, Vector3.ZERO, Vector3(size.x, footing, size.z), Vector3(size.x, footing, size.z), 1, COLOR_SMITHY_STONE, MeshKit.SNOW)
	MeshKit.prism(st, Vector3.ZERO, 8, r * 0.82, r * 0.5, footing, size.y - 0.08, PI / 8.0, COLOR_CLAY, COLOR_CLAY * 0.82, COLOR_SOOT)
	MeshKit.prism(st, Vector3.ZERO, 8, r * 0.52, r * 0.46, size.y - 0.08, size.y, PI / 8.0, COLOR_SOOT, COLOR_SOOT, COLOR_SOOT)
	MeshKit.box(glow, Vector3(0.0, size.y + 0.005, 0.0), Vector3(r * 0.6, 0.02, r * 0.6), COLOR_EMBER, COLOR_EMBER)
	# The tap arch at the foot, glowing, with a clay lintel over it.
	var front := r * 0.8
	MeshKit.box(glow, Vector3(0.0, footing + 0.16, front + 0.005), Vector3(0.26, 0.26, 0.02), COLOR_EMBER, COLOR_EMBER)
	MeshKit.box(st, Vector3(0.0, footing + 0.34, front - 0.01), Vector3(0.4, 0.08, 0.1), COLOR_CLAY * 0.7, COLOR_CLAY * 0.7)
	# The tuyere: a clay pipe into the west side, low, where the bellows blow.
	MeshKit.block(st, Vector3(-r * 0.9, footing + 0.3, 0.0), Vector3(0.36, 0.1, 0.1), 0.0, 0.0, COLOR_CLAY * 0.75, COLOR_CLAY * 0.75)
	# Ore heaped at the east foot, ready to be charged.
	var lumps := [Vector3(r + 0.08, 0.0, 0.12), Vector3(r + 0.2, 0.0, -0.06), Vector3(r + 0.06, 0.0, -0.18), Vector3(r + 0.14, 0.08, 0.02)]
	for i in lumps.size():
		MeshKit.box(st, lumps[i] + Vector3(0.0, 0.06, 0.0), Vector3(0.14, 0.12, 0.13), COLOR_IRON_ORE, COLOR_IRON_ORE * 1.1)
	return _with_glow(st, glow)


## A blast furnace stack `size` high: a tapering coursed-stone body to a little over half
## its height bound with iron hoops, a glowing tap under a lintel at its front (+z), a
## snowy shoulder, and a round chimney whose sooty mouth glows from the coals inside.
static func _furnace_stack(size: Vector3) -> ArrayMesh:
	var st := MeshKit.begin()
	var glow := MeshKit.begin()
	var body_top := size.y * 0.55
	var foot := Vector3(size.x, body_top, size.z)
	var head := Vector3(size.x * 0.8, body_top, size.z * 0.8)
	_courses(st, Vector3.ZERO, foot, head, 6, COLOR_SMITHY_STONE, COLOR_SMITHY_STONE)
	for y in [body_top * 0.3, body_top * 0.72]:
		var w := lerpf(1.0, 0.8, y / body_top)
		MeshKit.box(st, Vector3(0.0, y, 0.0), Vector3(size.x * w + 0.05, 0.08, size.z * w + 0.05), COLOR_IRON, COLOR_IRON)
	# The tap at the foot, glowing under its lintel, and a short run of slag before it.
	var front := size.z * 0.5
	MeshKit.box(glow, Vector3(0.0, 0.27, front + 0.005), Vector3(0.38, 0.32, 0.02), COLOR_EMBER, COLOR_EMBER)
	MeshKit.box(st, Vector3(0.0, 0.5, front + 0.03), Vector3(0.62, 0.12, 0.08), COLOR_SOOT, COLOR_SOOT)
	MeshKit.box(glow, Vector3(0.0, 0.015, front + 0.12), Vector3(0.14, 0.03, 0.24), COLOR_EMBER, COLOR_EMBER)
	# The shoulder narrows the body to the chimney; the chimney's mouth glows.
	var r_head := head.x * 0.5 * sqrt(2.0)
	MeshKit.prism(st, Vector3.ZERO, 4, r_head, 0.42, body_top, body_top + 0.35, PI * 0.25, COLOR_SMITHY_STONE, MeshKit.SNOW, MeshKit.SNOW)
	MeshKit.prism(st, Vector3.ZERO, 8, 0.34, 0.29, body_top + 0.3, size.y - 0.14, 0.0, COLOR_SMITHY_STONE * 0.92, COLOR_SOOT, COLOR_SOOT)
	MeshKit.box(st, Vector3(0.0, size.y - 0.07, 0.0), Vector3(0.7, 0.14, 0.7), COLOR_SOOT, COLOR_SOOT)
	MeshKit.box(glow, Vector3(0.0, size.y + 0.005, 0.0), Vector3(0.4, 0.02, 0.4), COLOR_EMBER, COLOR_EMBER)
	return _with_glow(st, glow)


## Courses of cut stone `count` high from the ground to `foot.y`, centred at `at`, narrowing
## from `foot` at the bottom to `head` at the top: blocks about a ruin-kit block long with
## joints staggered course to course, each a shade apart; the top course is capped in `top`.
static func _courses(st: SurfaceTool, at: Vector3, foot: Vector3, head: Vector3, count: int, stone: Color, top: Color) -> void:
	var course := foot.y / count
	for row in count:
		var w := foot.lerp(head, (row + 0.5) / count)
		var blocks := maxi(roundi(w.x / (RuinKit.BLOCK * 0.5)), 1)
		var span := w.x / blocks
		var stagger := 0.5 * span if row % 2 == 1 else 0.0
		for i in range(0, blocks + (1 if row % 2 == 1 else 0)):
			var u0 := maxf(-w.x * 0.5 + i * span - stagger, -w.x * 0.5)
			var u1 := minf(-w.x * 0.5 + (i + 1) * span - stagger, w.x * 0.5)
			var shade := stone * (0.86 + 0.06 * ((row + i) % 3))
			shade.a = 1.0
			MeshKit.box(st, at + Vector3((u0 + u1) * 0.5, (row + 0.5) * course, 0.0), Vector3(u1 - u0 - 0.025, course - 0.025, w.z), shade, top if row == count - 1 else shade)


## The mesh of `st`, plus `glow` as a second surface in the emissive ember material.
static func _with_glow(st: SurfaceTool, glow: SurfaceTool) -> ArrayMesh:
	var mesh := MeshKit.finish(st)
	glow.generate_normals()
	glow.commit(mesh)
	mesh.surface_set_material(1, Props.flat(COLOR_EMBER, EMBER_GLOW))
	return mesh


## Draws one Kenney model, scaled to `height` and snow-capped like a prop, once per transform:
## one multimesh per mesh, carrying the prop's materials.
static func _scatter_model(parent: Node3D, path: String, height: float, snow_from: float, tint: Color, transforms: Array[Transform3D]) -> void:
	if transforms.is_empty():
		return
	var holder := Props.model(path, height, snow_from, tint)
	var inner := holder.get_child(0) as Node3D
	for node in holder.find_children("*", "MeshInstance3D", true, false):
		var source := node as MeshInstance3D
		var mesh := source.mesh.duplicate() as Mesh
		for surface in mesh.get_surface_count():
			mesh.surface_set_material(surface, source.get_surface_override_material(surface))
		var local := Transform3D(inner.basis, inner.position) * Props._relative_transform(inner, source)
		var placed: Array[Transform3D] = []
		for t in transforms:
			placed.append(t * local)
		parent.add_child(multimesh(mesh, placed))
	holder.free()


## Picks dressing spots on walkable ground in a ring: clear of every footprint and enemy
## home, off the stretch the camera looks over at the ring-two gate, off the gate approach,
## and at least `spacing` from each other (a coarse grid keeps that cheap).
class Placer:
	var rng := RandomNumberGenerator.new()
	var _world: WorldDef
	var _rects: Array = []  # [min: Vector2, max: Vector2] per solid and object footprint
	var _homes: Array[Vector2] = []
	var _bounds := {}  # ring -> [lo: Vector2, hi: Vector2]
	var _taken := {}  # Vector2i cell -> Array[Vector2] of spots in it
	const CELL := 3.0

	func _init(world: WorldDef, seed_value: int) -> void:
		_world = world
		rng.seed = seed_value
		for s in world.solids:
			_rects.append([Vector2(s["min"][0], s["min"][1]), Vector2(s["max"][0], s["max"][1])])
		for id in world.objects:
			var o: Dictionary = world.objects[id]
			_rects.append([Vector2(o["min"][0], o["min"][1]), Vector2(o["max"][0], o["max"][1])])
		for id in world.enemies:
			_homes.append(Vector2(world.enemies[id]["home"][0], world.enemies[id]["home"][1]))
		# The gate approach, inside and out, stays clear so the way home always reads.
		_rects.append([Vector2(-3.5, -1.0), Vector2(3.5, 15.0)])
		for r in world.regions:
			var lo := Vector2(INF, INF)
			var hi := Vector2(-INF, -INF)
			for p in r["polygon"]:
				lo = lo.min(Vector2(p[0], p[1]))
				hi = hi.max(Vector2(p[0], p[1]))
			_bounds[r["name"]] = [lo, hi]
		# Landmarks keep their ground too.
		for ring in RingDressing.LANDMARKS:
			for direction in RingDressing.LANDMARKS[ring]:
				var mark: Dictionary = RingDressing.LANDMARKS[ring][direction]
				var at := Vector2(mark["at"][0], mark["at"][1])
				var half := float(mark["size"]) * 0.6
				_rects.append([at - Vector2.ONE * half, at + Vector2.ONE * half])
		# And so do the mines' pieces.
		for piece in RingDressing.mine_pieces():
			_rects.append(RingDressing.piece_ground(piece))

	## `count` spots in `ring` with a random turn and a scale between `scale_min` and
	## `scale_max`, within `band` (reach from the world's centre) if given.
	func spots(ring: String, count: int, spacing: float, scale_min: float, scale_max: float, margin := DRESSING_MARGIN, home_margin := DRESSING_HOME_MARGIN, band: Array = [0.0, INF]) -> Array[Transform3D]:
		var out: Array[Transform3D] = []
		for p in scatter(ring, count, spacing, margin, home_margin, band):
			var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(scale_min, scale_max))
			out.append(Transform3D(basis, Vector3(p.x, 0.0, p.y)))
		return out

	func scatter(ring: String, count: int, spacing: float, margin: float, home_margin: float, band: Array = [0.0, INF]) -> Array[Vector2]:
		var out: Array[Vector2] = []
		var lo: Vector2 = _bounds[ring][0]
		var hi: Vector2 = _bounds[ring][1]
		var tries := 0
		while out.size() < count and tries < count * 80:
			tries += 1
			var p := Vector2(rng.randf_range(lo.x, hi.x), rng.randf_range(lo.y, hi.y))
			var reach := maxf(absf(p.x), absf(p.y))
			if reach < float(band[0]) or reach >= float(band[1]):
				continue
			if absf(p.x) < 24.0 and p.y > 50.0 and p.y < 64.0:
				continue  # the camera looks over this stretch at the captain's gate
			if _world.region_at(p) != ring or not _world.is_walkable(p):
				continue
			if not _clear(p, margin, home_margin) or not _spaced(p, spacing):
				continue
			out.append(p)
			var cell := Vector2i(int(floor(p.x / CELL)), int(floor(p.y / CELL)))
			if not _taken.has(cell):
				_taken[cell] = []
			(_taken[cell] as Array).append(p)
		return out

	## A walkable spot about `distance` from `around` towards `direction`, clear of every
	## footprint by `margin`, turning the direction by eighths until one is found (the camp
	## pieces around a pack's home).
	func clear_spot(around: Vector2, direction: Vector2, distance: float, margin: float) -> Vector2:
		for k in 8:
			var dir := direction.rotated(k * TAU / 8.0 * (1 if k % 2 == 0 else -1))
			var p := around + dir * distance
			if _world.is_walkable(p) and _clear(p, margin, 0.0):
				return p
		return around + direction * distance

	func _clear(p: Vector2, margin: float, home_margin: float) -> bool:
		for r in _rects:
			if p.x > r[0].x - margin and p.x < r[1].x + margin and p.y > r[0].y - margin and p.y < r[1].y + margin:
				return false
		for h in _homes:
			if p.distance_to(h) < home_margin:
				return false
		return true

	func _spaced(p: Vector2, spacing: float) -> bool:
		var cell := Vector2i(int(floor(p.x / CELL)), int(floor(p.y / CELL)))
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				for q in _taken.get(cell + Vector2i(dx, dy), []):
					if p.distance_to(q) < spacing:
						return false
		return true


# --- Shared helpers ----------------------------------------------------------------------

## One MultiMeshInstance3D drawing `mesh` once per transform. Dressing never casts a click
## body, so it needs no node of its own per instance.
static func multimesh(mesh: Mesh, transforms: Array[Transform3D]) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	return mmi
