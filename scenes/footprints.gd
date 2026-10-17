## Footprints in the trodden yard: a small pool of flat prints the character leaves inside the
## outpost, the oldest fading first and the next step reusing it, all drawn in one MultiMesh.
## Outside the yard the character leaves none. Presentation only: nothing reads them back.
extends MultiMeshInstance3D

## Prints in the pool; the oldest is reused for the next step.
const POOL := 24
## Metres walked between prints, and how far each print sits off the line of travel.
const STRIDE := 0.7
const SIDE := 0.12
const PRINT_SIZE := Vector2(0.14, 0.27)
## Just above the yard floor, which sits at 1 cm.
const LIFT := 0.035
## The print's shade at its darkest (the newest print).
const COLOR_PRINT := Color(0.20, 0.17, 0.30, 0.42)
const PRINT_TEXTURE := preload("res://assets/particles/kenney_particle_pack/circle_05.png")

var _character: Node3D
var _world: WorldDef
var _last := Vector2(INF, INF)
var _next := 0
var _laid := 0
var _left := false


## Follows `character` and lays prints wherever `world` says it is inside the outpost.
func setup(character: Node3D, world: WorldDef) -> void:
	name = "Footprints"
	_character = character
	_world = world
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var plane := PlaneMesh.new()
	plane.size = PRINT_SIZE
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = PRINT_TEXTURE
	plane.material = m
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = plane
	mm.instance_count = POOL
	mm.visible_instance_count = 0
	multimesh = mm


## Clears every print, for a new or imported game.
func clear() -> void:
	_laid = 0
	_next = 0
	_last = Vector2(INF, INF)
	multimesh.visible_instance_count = 0


func _process(_delta: float) -> void:
	if _character == null:
		return
	var p := _character.global_position
	var pos := Vector2(p.x, p.z)
	if _last.x == INF:
		_last = pos
		return
	var step := pos - _last
	if step.length() < STRIDE:
		return
	_last = pos
	if step.length() > STRIDE * 4.0 or _world.region_at(pos) != WorldDef.REGION_OUTPOST:
		return  # a jump (travel, a new game) or out in the rings: no print
	_lay(pos, step.normalized())


func _lay(pos: Vector2, heading: Vector2) -> void:
	_left = not _left
	var forward := Vector3(heading.x, 0.0, heading.y)
	var right := forward.cross(Vector3.UP)
	var at := Vector3(pos.x, LIFT, pos.y) + right * (-SIDE if _left else SIDE)
	multimesh.set_instance_transform(_next, Transform3D(Basis.looking_at(forward, Vector3.UP), at))
	_next = (_next + 1) % POOL
	_laid = mini(_laid + 1, POOL)
	multimesh.visible_instance_count = _laid
	# The newest print darkest, each older one fainter.
	for age in _laid:
		var i := posmod(_next - 1 - age, POOL)
		var c := COLOR_PRINT
		c.a *= 1.0 - float(age) / POOL
		multimesh.set_instance_color(i, c)
