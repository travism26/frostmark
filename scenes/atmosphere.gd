## The frozen world's mood, and nothing else: a day-night cycle in the light, snow falling
## around the camera, and the character's breath in the cold. Driven by frame time, never by
## the simulation, and it changes no rule (night is only darker).
extends Node

## One full day and night, in seconds of play.
const DAY_SECONDS := 480.0
const BREATH_SECONDS := 2.2

const SKY_DAY := Color(0.72, 0.80, 0.88)
const SKY_DUSK := Color(0.62, 0.52, 0.62)
const SKY_NIGHT := Color(0.13, 0.17, 0.28)
const SUN_DAY := Color(1.0, 0.97, 0.92)
const SUN_DUSK := Color(1.0, 0.7, 0.5)
const SUN_NIGHT := Color(0.55, 0.65, 1.0)
const AMBIENT_DAY := Color(0.85, 0.9, 1.0)
const AMBIENT_NIGHT := Color(0.4, 0.48, 0.7)

var sun: DirectionalLight3D
var environment: Environment
## The day starts mid-morning so a new session opens in daylight.
var _time := DAY_SECONDS * 0.1
var _breath_left := 0.0
var _outside := false
var _snow: CPUParticles3D
var _breath: CPUParticles3D


## Wires the cycle to the scene's sun and environment, hangs the snow on the camera rig and
## the breath on the character.
func setup(sun_light: DirectionalLight3D, env: Environment, camera_rig: Node3D, character: Node3D) -> void:
	sun = sun_light
	environment = env
	_snow = _make_snow()
	camera_rig.add_child(_snow)
	_breath = _make_breath()
	character.add_child(_breath)
	_apply()


## Whether the character is out in the cold (breath shows only there).
func set_outside(outside: bool) -> void:
	_outside = outside


func _process(delta: float) -> void:
	if sun == null:
		return
	_time = fmod(_time + delta, DAY_SECONDS)
	_apply()
	if _outside:
		_breath_left -= delta
		if _breath_left <= 0.0:
			_breath_left = BREATH_SECONDS
			_breath.restart()


## 0 at midnight, 0.5 at noon.
func day_fraction() -> float:
	return _time / DAY_SECONDS


func _apply() -> void:
	# Daylight is a smooth bump around noon; dusk colours sit where it rises and falls.
	var f := day_fraction()
	var daylight := clampf(0.5 - 0.5 * cos(f * TAU) + 0.15, 0.0, 1.0)
	var dusk := clampf(1.0 - absf(daylight - 0.45) * 4.0, 0.0, 1.0)
	var sky := SKY_NIGHT.lerp(SKY_DAY, daylight).lerp(SKY_DUSK, dusk * 0.5)
	environment.background_color = sky
	environment.ambient_light_color = AMBIENT_NIGHT.lerp(AMBIENT_DAY, daylight)
	environment.ambient_light_energy = lerpf(0.55, 0.5, daylight)
	sun.light_color = SUN_NIGHT.lerp(SUN_DAY, daylight).lerp(SUN_DUSK, dusk * 0.6)
	sun.light_energy = lerpf(0.35, 1.0, daylight)
	# The sun swings across the southern sky; at night the same light stands in for the moon.
	var elevation := lerpf(deg_to_rad(18.0), deg_to_rad(62.0), daylight)
	sun.rotation = Vector3(-elevation, f * TAU + PI * 0.25, 0.0)


func _make_snow() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "Snow"
	p.amount = 360
	p.lifetime = 7.0
	p.preprocess = 7.0
	p.local_coords = false
	p.position = Vector3(0, 14, 0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(26, 1, 26)
	p.direction = Vector3(0.15, -1, 0.05)
	p.spread = 12.0
	p.initial_velocity_min = 1.6
	p.initial_velocity_max = 2.4
	p.gravity = Vector3(0, -0.3, 0)
	p.mesh = _flake_mesh(0.09, Color(1, 1, 1, 0.9))
	return p


func _make_breath() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "Breath"
	p.amount = 10
	p.lifetime = 1.3
	p.one_shot = true
	p.explosiveness = 0.6
	p.emitting = false
	p.local_coords = false
	p.position = Vector3(0, 1.45, -0.35)
	p.direction = Vector3(0, 0.3, -1)
	p.spread = 25.0
	p.initial_velocity_min = 0.3
	p.initial_velocity_max = 0.6
	p.gravity = Vector3(0, 0.25, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.55))
	fade.set_color(1, Color(1, 1, 1, 0.0))
	p.color_ramp = fade
	p.mesh = _flake_mesh(0.16, Color.WHITE)
	return p


static func _flake_mesh(size: float, colour: Color) -> QuadMesh:
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.albedo_color = colour
	quad.material = m
	return quad
