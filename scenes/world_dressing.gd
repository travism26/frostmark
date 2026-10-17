## The frozen frontier's looks that are not props: the snowfield and the trodden yard, the
## timber palisade and the ice cliffs, the gateway, and the scatter of rocks, drifts, bushes
## and pines that dress the rings. Presentation only: GameRoot builds the world from the
## WorldDef and calls in here for each piece, and nothing built here carries a collision body
## (clicks fall through dressing to the ground) or changes where anything is.
class_name WorldDressing
extends RefCounted

const SNOWFIELD_SHADER := preload("res://scenes/shaders/snowfield.gdshader")

const COLOR_SNOW := Color(0.93, 0.95, 0.99)
const COLOR_SNOW_SHADE := Color(0.76, 0.83, 0.94)
const COLOR_EARTH := Color(0.56, 0.50, 0.43)
const COLOR_EARTH_SHADE := Color(0.42, 0.37, 0.31)
const COLOR_TRODDEN_SNOW := Color(0.84, 0.85, 0.88)
const COLOR_PATH_STONE := Color(0.47, 0.50, 0.56)

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
