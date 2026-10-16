## Presentation glue for Frostmark. Owns one Sim, ticks it on a fixed accumulator, turns
## ground clicks into `move_to` and marker clicks into `interact`, and plays the simulation's
## events back as motion and HUD text. The grey-box world is built from the Sim's WorldDef
## so the drawing and the walkability grid can never disagree.
##
## Nothing here decides a rule: every position the character is drawn at comes from the
## simulation, interpolated along the polyline it walked in the last tick.
extends Node3D

const CHARACTER_TURN_SPEED := 12.0  # radians per second, for the facing marker
const RAY_LENGTH := 500.0

const COLOR_GROUND := Color(0.86, 0.90, 0.96)
const COLOR_OUTPOST_FLOOR := Color(0.60, 0.56, 0.50)
const COLOR_WALL := Color(0.55, 0.56, 0.58)
const OCCLUDER_ALPHA := 0.25
const COLOR_BY_KIND := {
	WorldDef.KIND_GATE: Color(0.45, 0.32, 0.20),
	WorldDef.KIND_FIRE: Color(0.95, 0.45, 0.15),
	WorldDef.KIND_STASH: Color(0.50, 0.35, 0.22),
	WorldDef.KIND_WORKBENCH: Color(0.30, 0.42, 0.60),
}

var sim: Sim
var _accumulator := 0.0
## Polyline the character walked during the last tick, replayed over the current one.
var _segment: Array[Vector2] = []
var _segment_length := 0.0
var _facing := Vector2(0, 1)
var _pending_click: Variant = null  # screen position awaiting a physics query
var _last_event := ""
var _faded: Array[MeshInstance3D] = []  # blocks made see-through because they hide the character

@onready var _world: Node3D = $World
@onready var _character: Node3D = $Character
@onready var _camera_rig: Node3D = $CameraRig
@onready var _camera: Camera3D = $CameraRig/Camera3D
@onready var _title: Label = $HUD/Title
@onready var _status: Label = $HUD/Status


func _ready() -> void:
	sim = Sim.new()
	_title.text = "Frostmark v%s" % ProjectSettings.get_setting("application/config/version")
	_build_world(sim.world)
	_facing = sim.player_facing()
	_place_character(sim.player_pos(), _facing, 0.0)
	_camera_rig.global_position = _character.global_position
	_refresh_status()


func _process(delta: float) -> void:
	_accumulator += delta
	while _accumulator >= Sim.TICK_SECONDS:
		_accumulator -= Sim.TICK_SECONDS
		_segment = []
		sim.step()
		_apply_events(sim.drain_events())
	_animate(delta)


func _physics_process(_delta: float) -> void:
	_fade_occluders()
	if _pending_click == null:
		return
	var screen: Vector2 = _pending_click
	_pending_click = null
	var from := _camera.project_ray_origin(screen)
	var to := from + _camera.project_ray_normal(screen) * RAY_LENGTH
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to))
	if hit.is_empty():
		return
	var collider: Object = hit["collider"]
	if collider.has_meta("object_id"):
		sim.command(SimVocab.INTERACT, {"object_id": collider.get_meta("object_id")})
	else:
		var p: Vector3 = hit["position"]
		sim.command(SimVocab.MOVE_TO, {"pos": [p.x, p.z]})
	_apply_events(sim.drain_events())


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_pending_click = event.position
		get_viewport().set_input_as_handled()


# --- Events to motion and text --------------------------------------------------------

func _apply_events(events: Array[Dictionary]) -> void:
	for e in events:
		match e["kind"]:
			SimVocab.EV_MOVED:
				_segment = []
				for p in e["path"]:
					_segment.append(Vector2(p[0], p[1]))
				_segment_length = 0.0
				for i in range(1, _segment.size()):
					_segment_length += _segment[i - 1].distance_to(_segment[i])
			SimVocab.EV_ARRIVED:
				if e["object_id"] == "":
					_last_event = "Arrived."
			SimVocab.EV_INTERACTED:
				var label: String = sim.world.objects[e["object_id"]]["label"]
				_last_event = "%s: nothing to do here yet." % label
			SimVocab.EV_REGION_CHANGED:
				_last_event = "Entered the %s." % str(e["to"]).replace("_", " ")
			SimVocab.EV_COMMAND_REJECTED:
				_last_event = "Can't go there (%s)." % str(e["reason"]).replace("_", " ")
	_refresh_status()


func _refresh_status() -> void:
	var region: String = str(sim.state["player"]["region"]).replace("_", " ")
	_status.text = "tick %d  |  %s\n%s" % [sim.state["tick"], region, _last_event]


## Where the character is drawn this frame: along last tick's polyline, by elapsed fraction.
func _animate(delta: float) -> void:
	var pos := sim.player_pos()
	if _segment.size() >= 2 and _segment_length > 0.0:
		var t := clampf(_accumulator / Sim.TICK_SECONDS, 0.0, 1.0)
		var remaining := t * _segment_length
		pos = _segment[_segment.size() - 1]
		for i in range(1, _segment.size()):
			var a := _segment[i - 1]
			var b := _segment[i]
			var d := a.distance_to(b)
			if remaining <= d:
				pos = a.lerp(b, remaining / d if d > 0.0 else 1.0)
				if d > 0.0:
					_facing = (b - a).normalized()
				break
			remaining -= d
	else:
		_facing = sim.player_facing()
	_place_character(pos, _facing, delta)
	_camera_rig.global_position = _character.global_position


func _place_character(pos: Vector2, facing: Vector2, delta: float) -> void:
	_character.global_position = Vector3(pos.x, 0.0, pos.y)
	var target_yaw := atan2(-facing.x, -facing.y)  # the marker sits on local -Z
	if delta <= 0.0:
		_character.rotation.y = target_yaw
	else:
		_character.rotation.y = lerp_angle(_character.rotation.y, target_yaw, clampf(CHARACTER_TURN_SPEED * delta, 0.0, 1.0))


## Blocks between the camera and the character go see-through so a wall never hides the player.
func _fade_occluders() -> void:
	var space := get_world_3d().direct_space_state
	var from := _camera.global_position
	var to := _character.global_position + Vector3(0, 1.0, 0)
	var query := PhysicsRayQueryParameters3D.create(from, to)
	var hits: Array[MeshInstance3D] = []
	for i in 4:
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			break
		var block := (hit["collider"] as Node).get_parent() as MeshInstance3D
		if block != null and block.get_parent() == _world and block.name != "Ground":
			hits.append(block)
		query.exclude.append(hit["rid"])
	for block in _faded:
		if not hits.has(block):
			_set_block_alpha(block, 1.0)
	for block in hits:
		if not _faded.has(block):
			_set_block_alpha(block, OCCLUDER_ALPHA)
	_faded = hits


static func _set_block_alpha(block: MeshInstance3D, alpha: float) -> void:
	var material := block.mesh.material as StandardMaterial3D
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if alpha < 1.0 else BaseMaterial3D.TRANSPARENCY_DISABLED
	material.albedo_color.a = alpha


# --- Grey-box world from the WorldDef -------------------------------------------------

func _build_world(world: WorldDef) -> void:
	var width := world.cols * world.cell_size
	var depth := world.rows * world.cell_size
	var centre := Vector3(world.origin[0] + width * 0.5, 0.0, world.origin[1] + depth * 0.5)

	var ground := MeshInstance3D.new()
	ground.name = "Ground"
	var plane := PlaneMesh.new()
	plane.size = Vector2(width, depth)
	plane.material = _flat_material(COLOR_GROUND)
	ground.mesh = plane
	ground.position = centre
	_world.add_child(ground)
	_add_box_body(ground, Vector3(width, 0.2, depth), Vector3(0, -0.1, 0))

	for r in world.regions:
		if r["name"] == WorldDef.REGION_OUTPOST:
			_add_floor(r["polygon"], COLOR_OUTPOST_FLOOR)

	for s in world.solids:
		var box := _add_block(str(s["id"]), s["min"], s["max"], s["height"], COLOR_WALL)
		_add_box_body(box, _box_size(s["min"], s["max"], s["height"]), Vector3.ZERO)

	for id in world.objects:
		var o: Dictionary = world.objects[id]
		var colour: Color = COLOR_BY_KIND.get(o["kind"], Color.MAGENTA)
		var box := _add_block(str(id), o["min"], o["max"], o["height"], colour)
		# A click volume at least 1 m tall so flat markers such as the gate are clickable.
		var click_size := _box_size(o["min"], o["max"], maxf(o["height"], 1.0))
		var body := _add_box_body(box, click_size, Vector3(0, (click_size.y - o["height"]) * 0.5, 0))
		body.set_meta("object_id", id)
		var label := Label3D.new()
		label.text = o["label"]
		label.font_size = 64
		label.pixel_size = 0.01
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.modulate = Color(0.1, 0.14, 0.2)
		label.outline_modulate = Color(1, 1, 1, 0.9)
		label.outline_size = 12
		label.position = Vector3(0, o["height"] * 0.5 + 1.0, 0)
		box.add_child(label)


func _add_floor(polygon: Array, colour: Color) -> void:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in polygon:
		lo = lo.min(Vector2(p[0], p[1]))
		hi = hi.max(Vector2(p[0], p[1]))
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.name = "OutpostFloor"
	var plane := PlaneMesh.new()
	plane.size = hi - lo
	plane.material = _flat_material(colour)
	floor_mesh.mesh = plane
	floor_mesh.position = Vector3((lo.x + hi.x) * 0.5, 0.01, (lo.y + hi.y) * 0.5)
	_world.add_child(floor_mesh)


func _add_block(id: String, min_xz: Array, max_xz: Array, height: float, colour: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = id
	var box := BoxMesh.new()
	box.size = _box_size(min_xz, max_xz, height)
	box.material = _flat_material(colour)
	mesh.mesh = box
	mesh.position = Vector3((min_xz[0] + max_xz[0]) * 0.5, height * 0.5, (min_xz[1] + max_xz[1]) * 0.5)
	_world.add_child(mesh)
	return mesh


func _add_box_body(parent: Node3D, size: Vector3, offset: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = offset
	body.add_child(shape)
	parent.add_child(body)
	return body


static func _box_size(min_xz: Array, max_xz: Array, height: float) -> Vector3:
	return Vector3(max_xz[0] - min_xz[0], height, max_xz[1] - min_xz[1])


static func _flat_material(colour: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	m.albedo_color = colour
	m.roughness = 1.0
	return m
