## Presentation glue for Frostmark. Owns one Sim, ticks it on a fixed accumulator, turns
## ground clicks into `move_to` and marker clicks into `interact` (the gate into
## `cross_gate`), and plays the simulation's events back as motion, HUD and banners. The
## grey-box world is built from the Sim's WorldDef so the drawing and the walkability grid
## can never disagree. It starts on the title screen and writes the browser save whenever
## the simulation reports a save point.
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
	WorldDef.KIND_TREE: Color(0.42, 0.30, 0.20),
}
const COLOR_PINE := Color(0.18, 0.38, 0.30)
const TRUNK_HEIGHT := 1.2

## What a rejection reason means to the player.
const REASON_TEXT := {
	SimVocab.REASON_NO_TOOL: "You need an axe for that.",
	SimVocab.REASON_PACK_FULL: "Your pack is full.",
	SimVocab.REASON_STASH_FULL: "The stash is full.",
	SimVocab.REASON_DEPLETED: "That tree is felled. It will grow back.",
	SimVocab.REASON_NOT_IN_OUTPOST: "The stash is only reachable inside the outpost.",
	SimVocab.REASON_NOT_AT_WORKBENCH: "Stand at the workbench to craft.",
	SimVocab.REASON_MISSING_INPUTS: "You don't have the materials for that.",
	SimVocab.REASON_LEVEL_TOO_LOW: "Your skill level is too low.",
	SimVocab.REASON_NOT_EQUIPPABLE: "That can't be equipped.",
	SimVocab.REASON_BAD_CODE: "That is not a Frostmark save code. Check that you copied all of it.",
	SimVocab.REASON_BAD_CHECKSUM: "That save code has been changed or damaged (its checksum does not match).",
	SimVocab.REASON_UNSUPPORTED_VERSION: "That save code comes from a newer version of Frostmark.",
	SimVocab.REASON_BAD_SNAPSHOT: "That save code holds a character this version cannot load.",
}

const TitleScreen := preload("res://scenes/title_screen.gd")
const Hud := preload("res://scenes/hud.gd")

var sim: Sim
var _accumulator := 0.0
## Polyline the character walked during the last tick, replayed over the current one.
var _segment: Array[Vector2] = []
var _segment_length := 0.0
var _facing := Vector2(0, 1)
var _pending_click: Variant = null  # screen position awaiting a physics query
var _last_event := ""
var _faded: Array[MeshInstance3D] = []  # blocks made see-through because they hide the character
var _playing := false
var _crowns := {}  # tree object id -> its crown mesh, hidden while the tree is felled
var _title_screen: Control
var _hud: Control

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
	_hud = Hud.new()
	_hud.command_requested.connect(_on_hud_command)
	_hud.export_requested.connect(func() -> void: _hud.show_code(sim.export_code()))
	$HUD.add_child(_hud)
	_title_screen = TitleScreen.new()
	_title_screen.new_character.connect(_on_new_character)
	_title_screen.continue_requested.connect(_on_continue)
	_title_screen.import_requested.connect(_on_import)
	$HUD.add_child(_title_screen)
	_hud.visible = false
	_show_sim()


func _process(delta: float) -> void:
	if not _playing:
		return
	_accumulator += delta
	while _accumulator >= Sim.TICK_SECONDS:
		_accumulator -= Sim.TICK_SECONDS
		_segment = []
		sim.step()
		_apply_events(sim.drain_events())
	_animate(delta)


func _physics_process(_delta: float) -> void:
	_fade_occluders()
	if _pending_click == null or not _playing:
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
		var id: String = collider.get_meta("object_id")
		if sim.world.objects[id]["kind"] == WorldDef.KIND_GATE:
			sim.command(SimVocab.CROSS_GATE)
		else:
			sim.command(SimVocab.INTERACT, {"object_id": id})
	else:
		var p: Vector3 = hit["position"]
		sim.command(SimVocab.MOVE_TO, {"pos": [p.x, p.z]})
	_apply_events(sim.drain_events())


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_pending_click = event.position
		get_viewport().set_input_as_handled()


# --- Title screen and saves -----------------------------------------------------------

func _on_new_character() -> void:
	sim = Sim.new()
	_start()
	_save()


func _on_continue() -> void:
	var fresh := Sim.new()
	var result := fresh.command(SimVocab.IMPORT_SAVE, {"code": SaveStore.read()})
	if not result["ok"]:
		_title_screen.show_error("Your browser save could not be loaded. %s" % _reason_text(result["reason"]))
		return
	fresh.drain_events()
	sim = fresh
	_start()


func _on_import(code: String) -> void:
	var fresh := Sim.new()
	var result := fresh.command(SimVocab.IMPORT_SAVE, {"code": code})
	if not result["ok"]:
		_title_screen.show_error(_reason_text(result["reason"]))
		return
	sim = fresh
	_start()
	_apply_events(sim.drain_events())  # the import's `saved` makes it the browser save
	_last_event = "Save code imported."
	_refresh_status()


func _start() -> void:
	_title_screen.visible = false
	_hud.visible = true
	_playing = true
	_accumulator = 0.0
	_segment = []
	_last_event = ""
	_show_sim()
	_hud.banner("Leave through the gate, cut wood, and walk it home.")


## Redraws everything that depends on the state after a new, continued or imported sim.
func _show_sim() -> void:
	_hud.sim = sim
	_hud.close_panels()
	_facing = sim.player_facing()
	_place_character(sim.player_pos(), _facing, 0.0)
	_camera_rig.global_position = _character.global_position
	for id in _crowns:
		(_crowns[id] as Node3D).visible = int(sim.state["nodes"][id]["left"]) > 0
	_hud.refresh()
	_refresh_status()


func _save() -> void:
	if SaveStore.write(sim.export_code()):
		_hud.flash_saved()
	else:
		_last_event = "Could not write the browser save."


func _on_hud_command(kind: String, args: Dictionary) -> void:
	sim.command(kind, args)
	_apply_events(sim.drain_events())


static func _reason_text(reason: String) -> String:
	return REASON_TEXT.get(reason, reason.replace("_", " ").capitalize() + ".")


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
			SimVocab.EV_PATH_SET:
				_hud.close_panels()
			SimVocab.EV_ARRIVED:
				if e["object_id"] == "":
					_last_event = "Arrived."
			SimVocab.EV_INTERACTED:
				match e["action"]:
					SimVocab.ACTION_STASH:
						_hud.open_panel(_hud.PANEL_STASH)
						_last_event = "The stash."
					SimVocab.ACTION_CRAFT:
						_hud.open_panel(_hud.PANEL_CRAFT)
						_last_event = "The workbench."
					SimVocab.ACTION_WARM:
						_last_event = "Warming up by the fire."
					SimVocab.ACTION_GATHER:
						_last_event = "Chopping..."
			SimVocab.EV_REGION_CHANGED:
				_last_event = "Entered the %s." % str(e["to"]).replace("_", " ")
				if e["from"] == WorldDef.REGION_OUTPOST:
					_last_event += " The cold sets in."
			SimVocab.EV_GATHERED:
				_last_event = "+%d %s  (+%d %s xp)" % [e["count"], ItemTable.label(e["item"]), e["xp"], e["skill"]]
			SimVocab.EV_ACTIVITY_STOPPED:
				if e["reason"] != SimVocab.REASON_MOVED:
					_last_event = _reason_text(e["reason"])
			SimVocab.EV_NODE_DEPLETED:
				(_crowns[e["object_id"]] as Node3D).visible = false
			SimVocab.EV_NODE_RESPAWNED:
				(_crowns[e["object_id"]] as Node3D).visible = true
			SimVocab.EV_LEVELLED:
				_hud.banner("%s level %d!" % [str(e["skill"]).capitalize(), e["level"]])
			SimVocab.EV_BANKED:
				_hud.banner(_banked_text(e))
			SimVocab.EV_CRAFTED:
				_last_event = "Crafted: %s." % ItemTable.label(e["item"])
				_hud.banner("Crafted a %s." % ItemTable.label(e["item"]).to_lower())
			SimVocab.EV_EQUIPPED:
				if e["item"] == "":
					_last_event = "Unequipped the %s." % ItemTable.label(e["previous"]).to_lower()
				else:
					_last_event = "Equipped the %s." % ItemTable.label(e["item"]).to_lower()
			SimVocab.EV_DEPOSITED:
				_last_event = "Deposited %d %s." % [e["count"], ItemTable.label(e["item"])]
			SimVocab.EV_WITHDREW:
				_last_event = "Withdrew %d %s." % [e["count"], ItemTable.label(e["item"])]
			SimVocab.EV_DROPPED:
				_last_event = "Dropped %d %s in the snow." % [e["count"], ItemTable.label(e["item"])]
			SimVocab.EV_TOOK_DAMAGE:
				_last_event = "You are freezing. Get back to the fire."
			SimVocab.EV_DIED:
				_hud.banner("You died and woke by the fire.")
			SimVocab.EV_SAVED:
				_save()
			SimVocab.EV_COMMAND_REJECTED:
				var reason: String = e["reason"]
				if REASON_TEXT.has(reason):
					_last_event = REASON_TEXT[reason]
				else:
					_last_event = "Can't do that (%s)." % reason.replace("_", " ")
	_hud.refresh()
	_refresh_status()


static func _banked_text(e: Dictionary) -> String:
	var parts: PackedStringArray = []
	for item in e["items"]:
		parts.append("%d %s" % [item["count"], ItemTable.label(item["item"])])
	var text := "Home safe. Banked %s." % ", ".join(parts) if not parts.is_empty() else "Home safe."
	if not (e["overflow"] as Array).is_empty():
		var left: PackedStringArray = []
		for item in e["overflow"]:
			left.append("%d %s" % [item["count"], ItemTable.label(item["item"])])
		text += "\nStash full: %s stayed in your pack." % ", ".join(left)
	return text


func _refresh_status() -> void:
	var region: String = str(sim.state["player"]["region"]).replace("_", " ")
	_status.text = "%s\n%s" % [region.capitalize(), _last_event]


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
	var meshes: Array[MeshInstance3D] = [block]
	for child in block.get_children():
		if child is MeshInstance3D:
			meshes.append(child)  # a tree's crown fades with its trunk
	for m in meshes:
		var material := m.mesh.material as StandardMaterial3D
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
		if o["kind"] == WorldDef.KIND_TREE:
			_add_tree(str(id), o, colour)
			continue
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


## A pine: a thin trunk under a cone crown, with a click volume over the whole footprint.
## The crown is hidden while the tree is felled, leaving the stump.
func _add_tree(id: String, o: Dictionary, trunk_colour: Color) -> void:
	var trunk := MeshInstance3D.new()
	trunk.name = id
	var box := BoxMesh.new()
	box.size = Vector3(0.45, TRUNK_HEIGHT, 0.45)
	box.material = _flat_material(trunk_colour)
	trunk.mesh = box
	var centre := Vector2((o["min"][0] + o["max"][0]) * 0.5, (o["min"][1] + o["max"][1]) * 0.5)
	trunk.position = Vector3(centre.x, TRUNK_HEIGHT * 0.5, centre.y)
	_world.add_child(trunk)
	var body := _add_box_body(trunk, _box_size(o["min"], o["max"], o["height"]), Vector3(0, (o["height"] - TRUNK_HEIGHT) * 0.5, 0))
	body.set_meta("object_id", id)
	var crown := MeshInstance3D.new()
	crown.name = "Crown"
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 1.1
	cone.height = o["height"] - TRUNK_HEIGHT + 1.0
	cone.radial_segments = 7
	cone.material = _flat_material(COLOR_PINE)
	crown.mesh = cone
	crown.position = Vector3(0, TRUNK_HEIGHT * 0.5 + cone.height * 0.5 - 0.4, 0)
	trunk.add_child(crown)
	_crowns[id] = crown


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
