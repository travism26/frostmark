## The telegraph on the ground: a ring under an enemy in the colour of the style it has
## declared for the next tick, and a brief swing arc toward the player when the blow lands.
## An area blow's ground mark is drawn red from its telegraph until it lands, brighter on the
## landing tick, and cleared after. An add a boss has called shows where it will enter, a pale
## ring on the snow at its entry point, until it comes in or leaves. Driven only by the
## `enemy_telegraphed`, `enemy_stance`, `ground_marked`, `add_called`, `hit` and `missed` events
## the simulation already emits, on the tick they arrive; it keeps no state of its own beyond
## what is on screen. Rings and marks sit on the
## snow with no depth test, so they read in a crowd.
class_name CombatCues
extends Node3D

const RING_RADIUS := 0.9
const RING_RADIUS_HEAVY := 1.15
const ARC_SECONDS := 0.38
const ARC_RADIUS := 1.3
const LIFT := 0.04  # above the snow, clear of z-fighting
const MARK_COLOUR := Color(0.93, 0.13, 0.09)
const MARK_TOLD_ALPHA := 0.45
const MARK_LANDING_ALPHA := 0.95
const CALL_COLOUR := Color(0.78, 0.88, 1.0, 0.9)
const CALL_RADIUS := 1.2

static var _ring_texture: Texture2D
static var _arc_texture: Texture2D
static var _front_texture: Texture2D
static var _disc_texture: Texture2D

var _rings := {}  # enemy id -> MeshInstance3D
var _arcs: Array[Dictionary] = []  # {mesh, left}
var _marks := {}  # enemy id -> {mesh, at}
var _calls := {}  # add id -> MeshInstance3D


## Lays the ring under `anchor` (the enemy's root) in `colour`, bigger for a heavy blow.
func ring(enemy_id: String, anchor: Node3D, colour: Color, heavy: bool) -> void:
	var mesh: MeshInstance3D = _rings.get(enemy_id)
	if mesh == null:
		mesh = _flat_quad(_ring_tex())
		add_child(mesh)
		_rings[enemy_id] = mesh
	var r := RING_RADIUS_HEAVY if heavy else RING_RADIUS
	mesh.scale = Vector3(r * 2.0, 1.0, r * 2.0)
	(mesh.material_override as StandardMaterial3D).albedo_color = Color(colour, 0.9)
	mesh.global_position = anchor.global_position + Vector3(0, LIFT, 0)
	mesh.visible = true


## Takes the ring away (the blow has landed or the enemy has lost interest).
func clear_ring(enemy_id: String) -> void:
	if _rings.has(enemy_id):
		(_rings[enemy_id] as MeshInstance3D).visible = false


## A swing arc at the enemy's feet, opening toward `toward`, that fades over ARC_SECONDS.
func arc(anchor: Node3D, toward: Vector3, colour: Color) -> void:
	var mesh := _flat_quad(_arc_tex())
	mesh.scale = Vector3(ARC_RADIUS * 2.0, 1.0, ARC_RADIUS * 2.0)
	(mesh.material_override as StandardMaterial3D).albedo_color = Color(colour, 1.0)
	add_child(mesh)
	mesh.global_position = anchor.global_position + Vector3(0, LIFT * 2.0, 0)
	var dir := Vector3(toward.x - anchor.global_position.x, 0.0, toward.z - anchor.global_position.z)
	if dir.length_squared() > 0.001:
		mesh.rotation.y = atan2(dir.x, dir.z)
	_arcs.append({"mesh": mesh, "left": ARC_SECONDS})


func _process(delta: float) -> void:
	var i := _arcs.size() - 1
	while i >= 0:
		var a: Dictionary = _arcs[i]
		a["left"] = float(a["left"]) - delta
		var mesh: MeshInstance3D = a["mesh"]
		var t := clampf(float(a["left"]) / ARC_SECONDS, 0.0, 1.0)
		var mat := mesh.material_override as StandardMaterial3D
		mat.albedo_color.a = t
		var grow := 1.0 + (1.0 - t) * 0.25
		mesh.scale = Vector3(ARC_RADIUS * 2.0 * grow, 1.0, ARC_RADIUS * 2.0 * grow)
		if t <= 0.0:
			mesh.queue_free()
			_arcs.remove_at(i)
		i -= 1


## Lays an area blow's ground mark from its `ground_marked` event, red on the snow at height
## `ground_y`, where the blow will land. This node sits at the world origin, so the mark's
## world-space geometry is its own.
func mark(e: Dictionary, ground_y := 0.0) -> void:
	clear_mark(e["enemy_id"])
	var m: Dictionary = e["mark"]
	var front: bool = m["shape"] == CombatTable.MARK_FRONT
	var mesh := _flat_quad(_front_tex() if front else _disc_tex())
	var r := float(m["radius"])
	mesh.scale = Vector3(r * 2.0, 1.0, r * 2.0)
	(mesh.material_override as StandardMaterial3D).albedo_color = Color(MARK_COLOUR, MARK_TOLD_ALPHA)
	mesh.position = Vector3(float(m["centre"][0]), ground_y + LIFT, float(m["centre"][1]))
	if front:
		mesh.rotation.y = atan2(float(m["facing"][0]), float(m["facing"][1]))
	add_child(mesh)
	_marks[e["enemy_id"]] = {"mesh": mesh, "at": int(e["at"])}


## The area blow has landed on its mark: the mark flares for the rest of the landing tick.
func land_mark(enemy_id: String) -> void:
	if _marks.has(enemy_id):
		var mesh: MeshInstance3D = _marks[enemy_id]["mesh"]
		(mesh.material_override as StandardMaterial3D).albedo_color = Color(MARK_COLOUR.lightened(0.25), MARK_LANDING_ALPHA)


## Clears every mark whose blow landed before `tick`.
func expire_marks(tick: int) -> void:
	for id in _marks.keys():
		if int(_marks[id]["at"]) < tick:
			clear_mark(id)


## Takes an enemy's mark away (it has landed, or the enemy fell or gave up the fight).
func clear_mark(enemy_id: String) -> void:
	if _marks.has(enemy_id):
		(_marks[enemy_id]["mesh"] as MeshInstance3D).queue_free()
		_marks.erase(enemy_id)


## The colour an enemy's ground mark is drawn in, or transparent black when it has none.
func mark_colour(enemy_id: String) -> Color:
	if not _marks.has(enemy_id):
		return Color(0, 0, 0, 0)
	return ((_marks[enemy_id]["mesh"] as MeshInstance3D).material_override as StandardMaterial3D).albedo_color


## Shows where an add will enter from its `add_called` event: a pale ring on the snow at its
## entry point, at height `ground_y`.
func call_in(e: Dictionary, ground_y := 0.0) -> void:
	clear_call(e["enemy_id"])
	var mesh := _flat_quad(_ring_tex())
	mesh.scale = Vector3(CALL_RADIUS * 2.0, 1.0, CALL_RADIUS * 2.0)
	(mesh.material_override as StandardMaterial3D).albedo_color = CALL_COLOUR
	mesh.position = Vector3(float(e["pos"][0]), ground_y + LIFT, float(e["pos"][1]))
	add_child(mesh)
	_calls[e["enemy_id"]] = mesh


## The add has come in, or left before it did.
func clear_call(enemy_id: String) -> void:
	if _calls.has(enemy_id):
		(_calls[enemy_id] as MeshInstance3D).queue_free()
		_calls.erase(enemy_id)


## Where an add's entry is shown, or null when none is.
func call_point(enemy_id: String) -> Variant:
	return (_calls[enemy_id] as MeshInstance3D).position if _calls.has(enemy_id) else null


## Keeps a ring on its enemy as the enemy is drawn along its path.
func follow(enemy_id: String, anchor: Node3D) -> void:
	if _rings.has(enemy_id) and (_rings[enemy_id] as MeshInstance3D).visible:
		(_rings[enemy_id] as MeshInstance3D).global_position = anchor.global_position + Vector3(0, LIFT, 0)


static func _flat_quad(tex: Texture2D) -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = Vector2(1, 1)
	quad.orientation = PlaneMesh.FACE_Y
	var mesh := MeshInstance3D.new()
	mesh.mesh = quad
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = tex
	mat.no_depth_test = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.render_priority = 2
	mesh.material_override = mat
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mesh


## A soft-edged ring, drawn once.
static func _ring_tex() -> Texture2D:
	if _ring_texture == null:
		_ring_texture = ImageTexture.create_from_image(_draw(func(r: float, _angle: float) -> float:
			var edge := 1.0 - clampf((r - 0.86) / 0.1, 0.0, 1.0)
			var inner := clampf((r - 0.66) / 0.08, 0.0, 1.0)
			return edge * inner * (0.75 + 0.25 * inner)))
	return _ring_texture


## A quarter sweep in front of the enemy (toward +z), brightest at its leading edge.
static func _arc_tex() -> Texture2D:
	if _arc_texture == null:
		_arc_texture = ImageTexture.create_from_image(_draw(func(r: float, angle: float) -> float:
			var edge := 1.0 - clampf((r - 0.9) / 0.08, 0.0, 1.0)
			var inner := clampf((r - 0.45) / 0.3, 0.0, 1.0)
			var sweep := 1.0 - clampf((absf(angle) - 0.55) / 0.25, 0.0, 1.0)
			return edge * inner * sweep))
	return _arc_texture


## A front mark: a sector of CombatTable.FRONT_ARC degrees ahead of the enemy, its rim brighter
## than its fill. The quad lays the image's bottom edge toward +z, where `_draw`'s angle is
## PI, so the sector is measured from there.
static func _front_tex() -> Texture2D:
	if _front_texture == null:
		var half := deg_to_rad(CombatTable.FRONT_ARC / 2.0)
		_front_texture = ImageTexture.create_from_image(_draw(func(r: float, angle: float) -> float:
			var off := PI - absf(angle)
			var edge := 1.0 - clampf((r - 0.94) / 0.06, 0.0, 1.0)
			var side := 1.0 - clampf((off - half + 0.05) / 0.05, 0.0, 1.0)
			var rim := 1.0 if r > 0.86 or off > half - 0.12 else 0.6
			return edge * side * rim))
	return _front_texture


## A ring mark: a filled disc, its rim brighter than its fill.
static func _disc_tex() -> Texture2D:
	if _disc_texture == null:
		_disc_texture = ImageTexture.create_from_image(_draw(func(r: float, _angle: float) -> float:
			var edge := 1.0 - clampf((r - 0.94) / 0.06, 0.0, 1.0)
			return edge * (1.0 if r > 0.86 else 0.6)))
	return _disc_texture


## A 64 px alpha mask from a function of polar coordinates (radius 0..1, angle from +z).
static func _draw(shape: Callable) -> Image:
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var u := (x + 0.5) / n * 2.0 - 1.0
			var v := (y + 0.5) / n * 2.0 - 1.0
			var r := Vector2(u, v).length()
			var a: float = shape.call(r, atan2(u, -v))
			img.set_pixel(x, y, Color(1, 1, 1, clampf(a, 0.0, 1.0)))
	return img
