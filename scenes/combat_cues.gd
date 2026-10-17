## The telegraph on the ground: a ring under an enemy in the colour of the style it has
## declared for the next tick, and a brief swing arc toward the player when the blow lands.
## Driven only by the `enemy_telegraphed`, `enemy_stance`, `hit` and `missed` events the
## simulation already emits, on the tick they arrive; it keeps no state of its own beyond
## what is on screen. Rings sit on the snow with no depth test, so they read in a crowd.
class_name CombatCues
extends Node3D

const RING_RADIUS := 0.9
const RING_RADIUS_HEAVY := 1.15
const ARC_SECONDS := 0.38
const ARC_RADIUS := 1.3
const LIFT := 0.04  # above the snow, clear of z-fighting

static var _ring_texture: Texture2D
static var _arc_texture: Texture2D

var _rings := {}  # enemy id -> MeshInstance3D
var _arcs: Array[Dictionary] = []  # {mesh, left}


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
