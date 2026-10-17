## A campfire's fire: a solid flame cone, tongues of flame and wisps above it, embers that rise and wink out,
## a thread of smoke leaning with the wind, a glowing core on the logs and a warm light that
## flickers. CPU particles on additive billboards (Kenney particle textures, CC0), under
## sixty per fire. Presentation only: GameRoot names it `Flame` and leaves it to burn.
class_name FireFx
extends Node3D

const PARTICLES := "res://assets/particles/kenney_particle_pack/"
const FLAME_TONGUE := preload(PARTICLES + "flame_05.png")
const FLAME_WISP := preload(PARTICLES + "flame_01.png")
const EMBER := preload(PARTICLES + "star_05.png")
const SMOKE := preload(PARTICLES + "smoke_01.png")
const GLOW := preload(PARTICLES + "circle_05.png")

const COLOR_LIGHT := Color(1.0, 0.62, 0.32)
const WIND := Vector3(0.25, 1.0, 0.08)

var _light: OmniLight3D
var _core: MeshInstance3D
var _tongue: Node3D  # the solid flame the camera always sees, under the particles
var _glow: MeshInstance3D
var _size := 1.0
var _light_energy := 1.6
var _phase := 0.0
var _time := 0.0


## A fire `size` metres across, with a light unless `light` is false.
static func create(size: float, light := true) -> FireFx:
	var fire := FireFx.new()
	fire.name = "Flame"
	fire._size = size
	fire._phase = fmod(size * 7.31, TAU)
	fire._build(light)
	return fire


func _build(light: bool) -> void:
	var s := _size
	# The glowing heart of the fire on the logs, and a soft halo over them.
	_core = MeshInstance3D.new()
	var core := SphereMesh.new()
	core.radius = s * 0.16
	core.height = s * 0.22
	core.radial_segments = 8
	core.rings = 4
	var core_m := StandardMaterial3D.new()
	core_m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	core_m.albedo_color = Color(1.0, 0.72, 0.3)
	core_m.emission_enabled = true
	core_m.emission = Color(1.0, 0.5, 0.15)
	core_m.emission_energy_multiplier = 2.0
	core.material = core_m
	_core.mesh = core
	_core.position.y = s * 0.14
	add_child(_core)
	# A solid two-layer flame cone, so the fire reads from the top-down camera even where
	# the additive particles wash out against bright snow.
	_tongue = Node3D.new()
	add_child(_tongue)
	for layer in [[s * 0.30, s * 0.85, Color(1.0, 0.5, 0.12), 1.4], [s * 0.16, s * 0.55, Color(1.0, 0.85, 0.35), 2.2]]:
		var cone := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.0
		mesh.bottom_radius = layer[0]
		mesh.height = layer[1]
		mesh.radial_segments = 7
		var cone_m := StandardMaterial3D.new()
		cone_m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		cone_m.albedo_color = layer[2]
		cone_m.emission_enabled = true
		cone_m.emission = layer[2]
		cone_m.emission_energy_multiplier = layer[3]
		mesh.material = cone_m
		cone.mesh = mesh
		cone.position.y = layer[1] * 0.5 + 0.05
		_tongue.add_child(cone)
	_glow = MeshInstance3D.new()
	var glow := QuadMesh.new()
	glow.size = Vector2(s * 1.1, s * 1.1)
	glow.material = _billboard(GLOW, Color(1.0, 0.45, 0.12, 0.5), true)
	_glow.mesh = glow
	_glow.position.y = s * 0.3
	add_child(_glow)

	# Tongues of flame: short-lived, shrinking as they rise, white-hot to orange to ember-red.
	var tongues := _emitter(20, 0.75, s * 0.2, s * 0.62, FLAME_TONGUE, true)
	tongues.position.y = s * 0.12
	tongues.direction = Vector3(0.05, 1, 0)
	tongues.spread = 12.0
	tongues.initial_velocity_min = s * 0.7
	tongues.initial_velocity_max = s * 1.3
	tongues.scale_amount_min = 0.7
	tongues.scale_amount_max = 1.2
	tongues.scale_amount_curve = _curve([[0.0, 0.55], [0.25, 1.0], [1.0, 0.15]])
	tongues.color_ramp = _ramp([[0.0, Color(1.0, 0.95, 0.7, 1.0)], [0.35, Color(1.0, 0.6, 0.15, 0.95)], [0.75, Color(0.9, 0.2, 0.02, 0.6)], [1.0, Color(0.4, 0.05, 0.0, 0.0)]])
	add_child(tongues)
	# Wisps: bigger, fainter, drifting with the wind and spinning a little.
	var wisps := _emitter(10, 1.0, s * 0.22, s * 0.8, FLAME_WISP, true)
	wisps.position.y = s * 0.35
	wisps.direction = WIND
	wisps.spread = 18.0
	wisps.initial_velocity_min = s * 0.5
	wisps.initial_velocity_max = s * 0.9
	wisps.angle_min = -40.0
	wisps.angle_max = 40.0
	wisps.scale_amount_curve = _curve([[0.0, 0.5], [0.4, 1.0], [1.0, 0.3]])
	wisps.color_ramp = _ramp([[0.0, Color(1.0, 0.7, 0.25, 0.0)], [0.3, Color(1.0, 0.5, 0.12, 0.6)], [1.0, Color(0.6, 0.1, 0.0, 0.0)]])
	add_child(wisps)
	# Embers: tiny bright sparks that climb, slow and go out.
	var embers := _emitter(14, 1.7, s * 0.22, s * 0.09, EMBER, true)
	embers.position.y = s * 0.3
	embers.direction = WIND
	embers.spread = 30.0
	embers.initial_velocity_min = s * 0.9
	embers.initial_velocity_max = s * 2.0
	embers.gravity = Vector3(0, -0.35, 0)
	embers.damping_min = 0.3
	embers.damping_max = 0.8
	embers.scale_amount_min = 0.5
	embers.scale_amount_max = 1.2
	embers.scale_amount_curve = _curve([[0.0, 1.0], [0.7, 0.8], [1.0, 0.0]])
	embers.color_ramp = _ramp([[0.0, Color(1.0, 0.9, 0.5, 1.0)], [0.5, Color(1.0, 0.5, 0.1, 1.0)], [1.0, Color(0.8, 0.2, 0.0, 0.0)]])
	add_child(embers)
	# Smoke: a faint grey thread that widens and leans with the wind.
	var smoke := _emitter(10, 2.8, s * 0.15, s * 0.5, SMOKE, false)
	smoke.position.y = s * 0.7
	smoke.direction = WIND
	smoke.spread = 8.0
	smoke.initial_velocity_min = s * 0.45
	smoke.initial_velocity_max = s * 0.7
	smoke.angle_min = -90.0
	smoke.angle_max = 90.0
	smoke.angular_velocity_min = -15.0
	smoke.angular_velocity_max = 15.0
	smoke.scale_amount_curve = _curve([[0.0, 0.4], [1.0, 2.2]])
	smoke.color_ramp = _ramp([[0.0, Color(0.5, 0.5, 0.55, 0.0)], [0.2, Color(0.55, 0.56, 0.6, 0.22)], [1.0, Color(0.7, 0.72, 0.78, 0.0)]])
	add_child(smoke)

	if light:
		_light = OmniLight3D.new()
		_light.light_color = COLOR_LIGHT
		_light_energy = 1.2 + s * 0.3
		_light.light_energy = _light_energy
		_light.omni_range = 5.0 + s * 1.5
		_light.omni_attenuation = 1.4
		_light.position.y = s * 0.6
		add_child(_light)


## The fire breathes: the light and the core pulse a little out of step with every other fire.
func _process(delta: float) -> void:
	_time += delta
	var t := _time * 9.0 + _phase
	var flicker := 0.84 + 0.1 * sin(t) + 0.06 * sin(t * 2.7 + 1.3)
	if _light != null:
		_light.light_energy = _light_energy * flicker
	_core.scale = Vector3(1.0, 0.9 + 0.3 * flicker, 1.0)
	_tongue.scale = Vector3(1.0 + 0.08 * sin(t * 1.9), 0.8 + 0.35 * flicker, 1.0 + 0.08 * cos(t * 1.3))
	_tongue.rotation.y = _time * 0.8
	_glow.scale = Vector3.ONE * (0.9 + 0.25 * flicker)


static func _emitter(amount: int, lifetime: float, radius: float, size: float, texture: Texture2D, additive: bool) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = lifetime
	p.preprocess = lifetime
	p.randomness = 0.6
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = radius
	p.gravity = Vector3.ZERO
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	quad.material = _billboard(texture, Color.WHITE, additive)
	p.mesh = quad
	return p


static func _billboard(texture: Texture2D, colour: Color, additive: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	m.vertex_color_use_as_albedo = true
	m.albedo_color = colour
	m.albedo_texture = texture
	m.disable_receive_shadows = true
	return m


static func _curve(points: Array) -> Curve:
	var c := Curve.new()
	for p in points:
		c.add_point(Vector2(p[0], p[1]))
	return c


static func _ramp(stops: Array) -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array()
	g.colors = PackedColorArray()
	for s in stops:
		g.add_point(s[0], s[1])
	return g
