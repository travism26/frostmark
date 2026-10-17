## Footprints in the trodden yard: a small pool of flat prints the character leaves inside the
## outpost, the oldest fading first and the next step reusing it, all drawn in one MultiMesh.
## Outside the yard the character leaves none. Presentation only: nothing reads them back.
extends MultiMeshInstance3D

## Prints in the pool; the oldest is reused for the next step.
const POOL := 24
## Metres walked between prints, and how far each print sits off the line of travel.
const STRIDE := 0.8
const SIDE := 0.13
const PRINT_SIZE := Vector2(0.16, 0.3)
## Just above the yard floor, which sits at 1 cm.
const LIFT := 0.035
## Metres from the outpost's centre that bound every print.
const YARD_REACH := 30.0
## The newest print: snow packed off the boots onto the yard's earth, lit by the dusk and
## the fire like the ground under it.
const COLOR_PRINT := Color(0.86, 0.88, 1.0, 0.55)
## Sides of the low-poly oval each print is.
const PRINT_SIDES := 8

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
	var m := StandardMaterial3D.new()
	m.roughness = 1.0
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _oval(m)
	mm.instance_count = POOL
	mm.visible_instance_count = 0
	multimesh = mm
	# Prints only ever lie in the yard: a fixed box round it saves recomputing the bounds.
	custom_aabb = AABB(Vector3(-YARD_REACH, -1.0, -YARD_REACH), Vector3(YARD_REACH * 2.0, 2.0, YARD_REACH * 2.0))


## Prints laid and still showing.
func count() -> int:
	return multimesh.visible_instance_count


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
	track(Vector2(p.x, p.z))


## Follows the character to `pos` on the ground, laying a print each stride inside the yard.
func track(pos: Vector2) -> void:
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


## A flat oval, PRINT_SIZE across, lying face up, its long axis along z.
static func _oval(material: Material) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	var r := PRINT_SIZE * 0.5
	for i in PRINT_SIDES:
		var a := TAU * i / PRINT_SIDES
		var b := TAU * (i + 1) / PRINT_SIDES
		st.add_vertex(Vector3.ZERO)
		st.add_vertex(Vector3(cos(b) * r.x, 0.0, sin(b) * r.y))
		st.add_vertex(Vector3(cos(a) * r.x, 0.0, sin(a) * r.y))
	st.set_material(material)
	return st.commit()


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
