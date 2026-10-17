## The frozen world's mood, and nothing else: a fixed dusk sun, the sky's blue-violet light
## in the shadows, the fog, the snow falling around the camera, the colour grade and the
## aurora, all read each frame from the ring look (scenes/ring_look.gd) at the character's
## position, so the world gets colder and darker the farther out the player walks. Driven by
## frame time, never by the simulation, and it changes no rule. There is no day-night cycle:
## it is always dusk.
extends Node

## The sun sits low in the south-west, so shadows run long to the north-east.
const SUN_ELEVATION_DEGREES := 17.0
const SUN_AZIMUTH := -PI * 0.25
## Snow falls from several emitters so its density can change without a visible restart:
## each layer stops emitting and its flakes fall out on their own.
const SNOW_LAYERS := 5
const SNOW_PER_LAYER := 110
const SNOW_COLOR := Color(1.0, 1.0, 1.0, 0.9)
## The fog begins this far past the character and closes in over the look's fog distance.
const FOG_START := 3.0
## The split tone and the contrast the grade applies at full strength.
const GRADE := 0.3
const CONTRAST := 1.05
const SATURATION := 0.9
const GRADE_SHADER := preload("res://scenes/shaders/colour_grade.gdshader")

var sun: DirectionalLight3D
var environment: Environment
var _camera_rig: Node3D
var _character: Node3D
var _world: WorldDef
var _snow: Array[CPUParticles3D] = []
var _flake_material: StandardMaterial3D
var _grade: ShaderMaterial
var _look := {}
var _override: Variant = null
var _wind := -1.0
var _tint := Color(-1, -1, -1)


## Wires the mood to the scene's sun and environment, hangs the snow on the camera rig and
## the grade over the view, and reads the character's position for the ring look.
func setup(sun_light: DirectionalLight3D, env: Environment, camera_rig: Node3D, character: Node3D, world: WorldDef) -> void:
	sun = sun_light
	environment = env
	_camera_rig = camera_rig
	_character = character
	_world = world
	sun.rotation = Vector3(-deg_to_rad(SUN_ELEVATION_DEGREES), SUN_AZIMUTH, 0.0)
	environment.fog_enabled = true
	environment.fog_mode = Environment.FOG_MODE_DEPTH
	environment.fog_sky_affect = 1.0
	environment.fog_depth_curve = 1.0
	_flake_material = _flake_material_new()
	for i in SNOW_LAYERS:
		var layer := _make_snow(i)
		camera_rig.add_child(layer)
		_snow.append(layer)
	var grade_layer := CanvasLayer.new()
	grade_layer.name = "Grade"
	grade_layer.layer = 0
	add_child(grade_layer)
	var grade := ColorRect.new()
	grade.name = "ColourGrade"
	grade.set_anchors_preset(Control.PRESET_FULL_RECT)
	grade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grade = ShaderMaterial.new()
	_grade.shader = GRADE_SHADER
	grade.material = _grade
	grade_layer.add_child(grade)
	_apply(RingLook.at(_world, _character_pos()))


## The look applied last frame.
func look() -> Dictionary:
	return _look


## Pins the look to `fixed` (a RingLook dictionary) instead of reading the character's
## position: for boards and screenshots. Null releases it.
func set_look_override(fixed: Variant) -> void:
	_override = fixed


func _process(_delta: float) -> void:
	if sun == null:
		return
	_apply(_override if _override is Dictionary else RingLook.at(_world, _character_pos()))


func _character_pos() -> Vector2:
	var p := _character.global_position
	return Vector2(p.x, p.z)


func _apply(look: Dictionary) -> void:
	_look = look
	environment.background_color = look["sky"]
	environment.ambient_light_color = look["ambient_color"]
	environment.ambient_light_energy = look["ambient_energy"]
	environment.fog_light_color = look["fog_color"]
	var near: float = _camera_rig.get("distance") if _camera_rig.get("distance") != null else 32.0
	environment.fog_depth_begin = near + FOG_START
	environment.fog_depth_end = near + FOG_START + float(look["fog_distance"])
	environment.fog_density = lerpf(0.6, 1.0, float(look["snow_density"]))
	sun.light_color = look["sun_color"]
	sun.light_energy = look["sun_energy"]
	var density: float = look["snow_density"]
	for i in SNOW_LAYERS:
		_snow[i].emitting = density > float(i) / SNOW_LAYERS
	var wind: float = look["wind"]
	if not is_equal_approx(wind, _wind):
		_wind = wind
		for layer in _snow:
			layer.direction = Vector3(0.15 + wind * 1.4, -1.0, 0.05 + wind * 0.3)
			layer.initial_velocity_min = 1.6 + wind * 2.4
			layer.initial_velocity_max = 2.4 + wind * 3.6
	var tint: Color = look["tint"]
	if not tint.is_equal_approx(_tint):
		_tint = tint
		_flake_material.albedo_color = Color(tint.r, tint.g, tint.b, SNOW_COLOR.a)
		WorldDressing.apply_tint(tint)
		Props.apply_tint(tint)
	_grade.set_shader_parameter("shadow_tint", look["ambient_color"])
	_grade.set_shader_parameter("light_tint", (look["sun_color"] as Color).lerp(Color.WHITE, 0.6))
	_grade.set_shader_parameter("grade", GRADE)
	_grade.set_shader_parameter("contrast", CONTRAST)
	_grade.set_shader_parameter("saturation", SATURATION)
	_grade.set_shader_parameter("aurora", look["aurora"])


func _make_snow(index: int) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "Snow%d" % index
	p.amount = SNOW_PER_LAYER
	p.lifetime = 7.0
	p.preprocess = 7.0
	p.randomness = 0.3
	p.local_coords = false
	p.position = Vector3(0, 14, 0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(26, 1, 26)
	p.direction = Vector3(0.15, -1, 0.05)
	p.spread = 12.0
	p.initial_velocity_min = 1.6
	p.initial_velocity_max = 2.4
	p.gravity = Vector3(0, -0.3, 0)
	var quad := QuadMesh.new()
	quad.size = Vector2(0.09, 0.09)
	quad.material = _flake_material
	p.mesh = quad
	return p


static func _flake_material_new() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.albedo_color = SNOW_COLOR
	return m
