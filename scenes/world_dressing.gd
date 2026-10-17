## The frozen frontier's looks that are not props: the snowfield and the trodden yard, the
## timber palisade and the ice cliffs, the gateway, and the scatter of rocks, drifts, bushes
## and pines that dress the rings. Presentation only: GameRoot builds the world from the
## WorldDef and calls in here for each piece, and nothing built here carries a collision body
## (clicks fall through dressing to the ground) or changes where anything is.
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
	return m


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
## cliff, or null to keep the plain box. The mesh is centred on the footprint with the ground
## at -height/2, matching GameRoot's block placement, and carries one StandardMaterial3D on
## its only surface so the occluder fade can still see through it.
static func solid_mesh(kind: String, min_xz: Array, max_xz: Array, height: float) -> ArrayMesh:
	var size := Vector3(max_xz[0] - min_xz[0], height, max_xz[1] - min_xz[1])
	var centre := Vector2((min_xz[0] + max_xz[0]) * 0.5, (min_xz[1] + max_xz[1]) * 0.5)
	match kind:
		WorldDef.KIND_WALL:
			return _palisade(size, centre)
		WorldDef.KIND_CLIFF:
			return _ice_cliff(size, centre)
	return null


## Two staggered rows of sharpened logs with snow on their points, a thicker post every
## few logs, each leaning a touch so the wall reads as hand-built.
static func _palisade(size: Vector3, centre: Vector2) -> ArrayMesh:
	var along_x := size.x >= size.z
	var length := size.x if along_x else size.z
	var thick := size.z if along_x else size.x
	var rng := _rng(centre)
	var st := _begin()
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
			_log(st, _local(u, v, along_x), base_y - 0.1, top, 0.33 if post else 0.26, 0.3 if post else 0.24, lean, colour)
	return _finish(st)


## A sharpened log: a six-sided trunk from `y0` to `top`, a short band blending into snow,
## and a snow-white point `tip` high, leaning by `lean` per metre of height.
static func _log(st: SurfaceTool, at: Vector3, y0: float, top: float, r: float, tip: float, lean: Vector2, colour: Color) -> void:
	var band := top - 0.1
	var ring0: Array[Vector3] = []
	var ring1: Array[Vector3] = []
	var ring2: Array[Vector3] = []
	for k in 6:
		var a := k * TAU / 6.0
		var off := Vector3(cos(a) * r, 0.0, sin(a) * r)
		ring0.append(at + off + Vector3(0, y0, 0))
		ring1.append(at + off + Vector3(lean.x * (band - y0), band, lean.y * (band - y0)))
		ring2.append(at + off * 0.82 + Vector3(lean.x * (top - y0), top, lean.y * (top - y0)))
	var apex := at + Vector3(lean.x * (top + tip - y0), top + tip, lean.y * (top + tip - y0))
	for k in 6:
		var n := (k + 1) % 6
		var out := Vector3(cos((k + 0.5) * TAU / 6.0), 0.0, sin((k + 0.5) * TAU / 6.0))
		_quad(st, ring0[k], ring0[n], ring1[n], ring1[k], colour, colour, out)
		_quad(st, ring1[k], ring1[n], ring2[n], ring2[k], colour, COLOR_SNOW_CAP, out)
		_tri(st, ring2[k], ring2[n], apex, COLOR_SNOW_CAP, out + Vector3.UP)


## A ridge of ice along the footprint: a bank of snow at its toe, a face towards the world
## that steps in and out in deep blue, a crest and a higher snow-covered ridge behind it that
## rise and fall, and shards of ice standing along the top and broken at the foot.
static func _ice_cliff(size: Vector3, centre: Vector2) -> ArrayMesh:
	var along_x := size.x >= size.z
	var length := size.x if along_x else size.z
	var thick := size.z if along_x else size.x
	# The face nearer the world's centre is the one the player sees.
	var towards_centre := centre.y if along_x else centre.x
	var n := -1.0 if towards_centre > 0.0 else 1.0  # +v is out of the box on the inner side
	var inner := -n * thick * 0.5
	var outer := n * thick * 0.5
	var rng := _rng(centre)
	var st := _begin()
	var base_y := -size.y * 0.5
	var top_y := base_y + size.y
	var steps := maxi(int(length / 1.6), 1)
	var stations: Array = []
	for i in steps + 1:
		var u := -length * 0.5 + length * i / float(steps)
		if i > 0 and i < steps:
			u += rng.randf_range(-0.35, 0.35)
		stations.append([
			_local(u, inner + n * rng.randf_range(1.2, 1.7), along_x) + Vector3(0, base_y, 0),
			_local(u, inner + n * rng.randf_range(0.1, 0.4), along_x) + Vector3(0, base_y + rng.randf_range(0.3, 0.55), 0),
			_local(u, inner + n * rng.randf_range(0.0, 0.5), along_x) + Vector3(0, base_y + size.y * rng.randf_range(0.4, 0.6), 0),
			_local(u, inner + n * rng.randf_range(-0.5, 0.1), along_x) + Vector3(0, top_y + rng.randf_range(0.1, 0.8), 0),
			_local(u, inner - n * thick * rng.randf_range(0.35, 0.55), along_x) + Vector3(0, top_y + rng.randf_range(1.0, 2.2), 0),
			_local(u, outer, along_x) + Vector3(0, top_y * 0.4 + base_y * 0.6, 0),
			_local(u, outer, along_x) + Vector3(0, base_y, 0),
		])
	var colours := [COLOR_SNOW_CAP, COLOR_ICE_DEEP, COLOR_ICE, COLOR_ICE, COLOR_SNOW_CAP, COLOR_SNOW_CAP, COLOR_ICE_PALE]
	var face_out := _local(0.0, n, along_x)
	var hints := [face_out + Vector3.UP * 2.0, face_out, face_out, face_out + Vector3.UP, Vector3.UP, -face_out + Vector3.UP, -face_out]
	for i in steps:
		var a: Array = stations[i]
		var b: Array = stations[i + 1]
		for k in 6:
			_quad(st, a[k], b[k], b[k + 1], a[k + 1], colours[k], colours[k + 1], hints[k])
	# End caps so the ridge is closed where two cliffs meet at a corner.
	for end in [stations[0], stations[steps]]:
		var cap_out := _local(-1.0 if end == stations[0] else 1.0, 0.0, along_x)
		for k in range(1, 6):
			_tri(st, end[1], end[k], end[k + 1], colours[k], cap_out)
	# Shards: pyramids of ice along the crest and a few broken ones at the foot.
	for i in int(length / 1.4):
		var u := rng.randf_range(-length * 0.5 + 0.5, length * 0.5 - 0.5)
		var on_top := rng.randf() < 0.7
		var v := inner - n * thick * rng.randf_range(0.15, 0.6) if on_top else inner + n * rng.randf_range(0.4, 1.0)
		var h := rng.randf_range(1.2, 2.6) if on_top else rng.randf_range(0.5, 1.1)
		var y := top_y + rng.randf_range(0.3, 1.0) if on_top else base_y
		_shard(st, _local(u, v, along_x) + Vector3(0, y, 0), rng.randf_range(0.4, 0.8), h, rng.randf() * TAU, COLOR_ICE if on_top else COLOR_ICE_DEEP)
	return _finish(st)


## A four-sided spike of ice, pale towards its point.
static func _shard(st: SurfaceTool, at: Vector3, r: float, h: float, turn: float, colour: Color) -> void:
	var apex := at + Vector3(0, h, 0)
	var ring: Array[Vector3] = []
	for k in 4:
		var a := turn + k * TAU / 4.0
		ring.append(at + Vector3(cos(a) * r, -0.3, sin(a) * r))
	for k in 4:
		var m := (k + 1) % 4
		var out := (ring[k] + ring[m]) * 0.5 - at
		_tri_shade(st, ring[k], ring[m], apex, colour, colour, COLOR_ICE_PALE, out + Vector3.UP * 0.5)


# --- The outpost gateway ------------------------------------------------------------------

## The gap in the south wall as a gateway: two tall posts and a snow-topped lintel (one mesh,
## which fades like a wall when it hides the character), a plank threshold over the footprint
## and a banner on the lintel. Stands on the ground at its origin; GameRoot adds the click
## body and the label.
static func gateway(min_xz: Array, max_xz: Array) -> MeshInstance3D:
	var width: float = max_xz[0] - min_xz[0]
	var depth: float = max_xz[1] - min_xz[1]
	var st := _begin()
	for side in [-1.0, 1.0]:
		_log(st, Vector3(side * (width * 0.5 + 0.2), 0.0, 0.0), -0.1, GATEWAY_HEIGHT, 0.36, 0.42, Vector2.ZERO, COLOR_TIMBER_DARK)
	_box(st, Vector3(0.0, GATEWAY_HEIGHT - 0.05, 0.0), Vector3(width + 1.2, 0.32, 0.42), COLOR_TIMBER_DARK, COLOR_SNOW_CAP)
	_box(st, Vector3(0.0, GATEWAY_HEIGHT - 0.5, 0.0), Vector3(width + 0.4, 0.16, 0.24), COLOR_TIMBER, COLOR_TIMBER)
	var planks := 4
	for i in planks:
		var plank := COLOR_TIMBER * (0.85 + 0.08 * (i % 2))
		plank.a = 1.0
		_box(st, Vector3(-width * 0.5 + (i + 0.5) * width / planks, 0.045, 0.0), Vector3(width / planks - 0.08, 0.09, depth * 0.9), plank, plank)
	var gate := MeshInstance3D.new()
	gate.mesh = _finish(st)
	var trim := Node3D.new()
	trim.name = "Trim"
	gate.add_child(trim)
	var banner := Props.model(CASTLE + "flag.glb", 1.6, 0.9)
	banner.position = Vector3(width * 0.5 + 0.2, GATEWAY_HEIGHT + 0.16, 0.0)
	banner.rotation.y = PI * 0.5
	trim.add_child(banner)
	return gate


## An axis-aligned box of `size` centred at `at`, its sides in `colour` and its top in `top`.
static func _box(st: SurfaceTool, at: Vector3, size: Vector3, colour: Color, top: Color) -> void:
	var h := size * 0.5
	var c: Array[Vector3] = []
	for i in 8:
		c.append(at + Vector3(-h.x if i & 1 == 0 else h.x, -h.y if i & 2 == 0 else h.y, -h.z if i & 4 == 0 else h.z))
	# Bottom corners 0 1 4 5, top corners 2 3 6 7 (bit 1 = +x, bit 2 = +y, bit 4 = +z).
	_quad(st, c[0], c[1], c[3], c[2], colour, colour, Vector3.BACK * -1.0)
	_quad(st, c[4], c[5], c[7], c[6], colour, colour, Vector3.BACK)
	_quad(st, c[0], c[4], c[6], c[2], colour, colour, Vector3.LEFT)
	_quad(st, c[1], c[5], c[7], c[3], colour, colour, Vector3.RIGHT)
	_quad(st, c[2], c[3], c[7], c[6], top, top, Vector3.UP)
	_quad(st, c[0], c[1], c[5], c[4], colour, colour, Vector3.DOWN)


# --- Mesh helpers ------------------------------------------------------------------------

static func _rng(centre: Vector2) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(centre.x * 31.0 + centre.y * 7.0) + 1000
	return rng


## Maps a point along (`u`) and across (`v`) a solid to the footprint's own axes.
static func _local(u: float, v: float, along_x: bool) -> Vector3:
	return Vector3(u, 0.0, v) if along_x else Vector3(v, 0.0, u)


static func _begin() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st


## Flat normals from the unshared vertices, and one fresh material so this mesh can fade on
## its own when it hides the character.
static func _finish(st: SurfaceTool) -> ArrayMesh:
	st.generate_normals()
	var mesh := st.commit()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	m.vertex_color_use_as_albedo = true
	m.roughness = 1.0
	mesh.surface_set_material(0, m)
	return mesh


## A quad `a b c d` whose bottom edge is `a b` in `low` and top edge `c d` in `high`, wound so
## its normal leans towards `outward`.
static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, low: Color, high: Color, outward: Vector3) -> void:
	_tri_shade(st, a, b, c, low, low, high, outward)
	_tri_shade(st, a, c, d, low, high, high, outward)


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, colour: Color, outward: Vector3) -> void:
	_tri_shade(st, a, b, c, colour, colour, colour, outward)


## One triangle, flipped if needed so Godot's clockwise front face points along `outward`.
static func _tri_shade(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color, outward: Vector3) -> void:
	if (b - a).cross(c - a).dot(outward) > 0.0:
		var t := b
		b = c
		c = t
		var tc := cb
		cb = cc
		cc = tc
	st.set_color(ca)
	st.add_vertex(a)
	st.set_color(cb)
	st.add_vertex(b)
	st.set_color(cc)
	st.add_vertex(c)


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
