## Presentation glue for Frostmark. Owns one Sim, ticks it on a fixed accumulator, turns
## ground clicks into `move_to`, marker and loot clicks into `interact` (the gate into
## `cross_gate`) and enemy clicks into `attack`, and plays the simulation's events back as
## motion, telegraph cues, HUD, banners and the death screen. The
## grey-box world is built from the Sim's WorldDef so the drawing and the walkability grid
## can never disagree. It starts on the title screen and writes the browser save whenever
## the simulation reports a save point.
##
## Nothing here decides a rule: every position the character or an enemy is drawn at comes
## from the simulation, interpolated along the polyline it walked in the last tick.
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
const COLOR_BY_ENEMY := {"wolf": Color(0.42, 0.40, 0.40), "bandit_archer": Color(0.55, 0.24, 0.20)}
## Telegraph cues are coloured by the style of the blow coming, so the counter reads at a glance.
const COLOR_BY_STYLE := {
	CombatTable.STYLE_MELEE: Color(0.95, 0.35, 0.2),
	CombatTable.STYLE_RANGED: Color(0.2, 0.55, 1.0),
}
const COLOR_LOOT := Color(0.85, 0.68, 0.2)
const CUE_FONT := 72
const CUE_FONT_HEAVY := 120

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
	SimVocab.REASON_NO_AMMO: "You have no arrows. Swap to a melee weapon or bare hands.",
	SimVocab.REASON_IN_OUTPOST: "Nothing can be fought from inside the outpost.",
	SimVocab.REASON_TARGET_DEAD: "It is already dead.",
	SimVocab.REASON_NOT_FOOD: "You can't eat that.",
	SimVocab.REASON_ALREADY_EATING: "You are already eating.",
	SimVocab.REASON_BAD_CODE: "That is not a Frostmark save code. Check that you copied all of it.",
	SimVocab.REASON_BAD_CHECKSUM: "That save code has been changed or damaged (its checksum does not match).",
	SimVocab.REASON_UNSUPPORTED_VERSION: "That save code comes from a newer version of Frostmark.",
	SimVocab.REASON_BAD_SNAPSHOT: "That save code holds a character this version cannot load.",
}

const TitleScreen := preload("res://scenes/title_screen.gd")
const Hud := preload("res://scenes/hud.gd")
const DeathScreen := preload("res://scenes/death_screen.gd")

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
var _death_screen: Control
## Enemy id -> {root, body, label, cue, cue_at, segment, length}: its drawing, its telegraph
## cue (shown until the tick `cue_at` resolves) and the polyline it walked last tick.
var _enemies := {}
var _loot := {}  # loot id -> its pile's node
var _enemy_layer := Node3D.new()
var _loot_layer := Node3D.new()

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
	add_child(_enemy_layer)
	add_child(_loot_layer)
	_build_enemies(sim.world)
	_hud = Hud.new()
	_hud.command_requested.connect(_on_hud_command)
	_hud.export_requested.connect(func() -> void: _hud.show_code(sim.export_code()))
	$HUD.add_child(_hud)
	_title_screen = TitleScreen.new()
	_title_screen.new_character.connect(_on_new_character)
	_title_screen.continue_requested.connect(_on_continue)
	_title_screen.import_requested.connect(_on_import)
	$HUD.add_child(_title_screen)
	_death_screen = DeathScreen.new()
	_death_screen.dismissed.connect(_on_death_dismissed)
	$HUD.add_child(_death_screen)
	_death_screen.visible = false
	_hud.visible = false
	_show_sim()


func _process(delta: float) -> void:
	if not _playing:
		return
	_accumulator += delta
	while _accumulator >= Sim.TICK_SECONDS and _playing:
		_accumulator -= Sim.TICK_SECONDS
		_segment = []
		for id in _enemies:
			_enemies[id]["segment"] = []
		sim.step()
		_expire_cues()
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
	if collider.has_meta("enemy_id"):
		sim.command(SimVocab.ATTACK, {"enemy_id": collider.get_meta("enemy_id")})
	elif collider.has_meta("object_id"):
		var id: String = collider.get_meta("object_id")
		if sim.world.objects.has(id) and sim.world.objects[id]["kind"] == WorldDef.KIND_GATE:
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
	_death_screen.visible = false
	_hud.visible = true
	_playing = true
	_accumulator = 0.0
	_segment = []
	_last_event = ""
	_show_sim()
	_hud.banner("Cut wood in the inner ring and walk it home. Past the trees, wolves and a bandit archer wait;\nyour stash holds a bow, arrows and cooked fish.")


## Redraws everything that depends on the state after a new, continued or imported sim.
func _show_sim() -> void:
	_hud.sim = sim
	_hud.close_panels()
	_facing = sim.player_facing()
	_place_character(sim.player_pos(), _facing, 0.0)
	_camera_rig.global_position = _character.global_position
	for id in _crowns:
		(_crowns[id] as Node3D).visible = int(sim.state["nodes"][id]["left"]) > 0
	for id in _enemies:
		_sync_enemy(id)
	for id in _loot:
		(_loot[id] as Node).queue_free()
	_loot.clear()
	for id in sim.state["loot"]:
		_add_loot(id)
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


func _on_death_dismissed() -> void:
	_death_screen.visible = false
	_playing = true
	_accumulator = 0.0


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
				_segment_length = _polyline_length(_segment)
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
				if e["reason"] not in [SimVocab.REASON_MOVED, SimVocab.REASON_TARGET_DEAD, SimVocab.REASON_DIED]:
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
				if e["cause"] == "cold":
					_last_event = "You are freezing. Get back to the fire."
			SimVocab.EV_ATE:
				_last_event = "You eat the %s." % ItemTable.label(e["item"]).to_lower()
			SimVocab.EV_DIED:
				_playing = false
				_death_screen.show_death(e)
			SimVocab.EV_ENEMY_NOTICED:
				if e["cause"] != CombatTable.NOTICE_PACK:
					_last_event = "%s has noticed you!" % _enemy_name(e["enemy_id"]).capitalize()
			SimVocab.EV_ENEMY_MOVED:
				var walked: Array = []
				for p in e["path"]:
					walked.append(Vector2(p[0], p[1]))
				_enemies[e["enemy_id"]]["segment"] = walked
				_enemies[e["enemy_id"]]["length"] = _polyline_length(walked)
			SimVocab.EV_ENEMY_TELEGRAPHED:
				_show_cue(e)
			SimVocab.EV_HIT:
				_last_event = _hit_text(e)
				if e["target"] != SimVocab.PLAYER:
					_sync_enemy(e["target"])
			SimVocab.EV_MISSED:
				_last_event = "%s's %s misses. You stepped clear." % [
					_enemy_name(e["attacker"]).capitalize(), CombatTable.action_label(e["action"]).to_lower(),
				]
			SimVocab.EV_ENEMY_DIED:
				_sync_enemy(e["enemy_id"])
				_last_event = "%s falls." % _enemy_name(e["enemy_id"]).capitalize()
			SimVocab.EV_ENEMY_DISENGAGED, SimVocab.EV_ENEMY_RESPAWNED:
				_sync_enemy(e["enemy_id"])
			SimVocab.EV_LOOT_DROPPED:
				_add_loot(e["loot_id"])
			SimVocab.EV_PICKED_UP:
				_last_event = "Picked up %d %s." % [e["count"], ItemTable.label(e["item"])]
				_remove_loot(e["loot_id"])
				if sim.state["loot"].has(e["loot_id"]):
					_add_loot(e["loot_id"])  # some was left: redraw the smaller pile
			SimVocab.EV_LOOT_GONE:
				_remove_loot(e["loot_id"])
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


## Where the character and the enemies are drawn this frame: along last tick's polyline, by
## elapsed fraction.
func _animate(delta: float) -> void:
	var t := clampf(_accumulator / Sim.TICK_SECONDS, 0.0, 1.0)
	var pos := sim.player_pos()
	if _segment.size() >= 2 and _segment_length > 0.0:
		var at := _along(_segment, _segment_length, t)
		pos = at[0]
		if at[1] != Vector2.ZERO:
			_facing = at[1]
	else:
		_facing = sim.player_facing()
	_place_character(pos, _facing, delta)
	_camera_rig.global_position = _character.global_position
	for id in _enemies:
		var drawn: Dictionary = _enemies[id]
		var e: Dictionary = sim.state["enemies"][id]
		var where := Vector2(e["pos"][0], e["pos"][1])
		var segment: Array = drawn["segment"]
		if segment.size() >= 2 and drawn["length"] > 0.0:
			where = _along(segment, drawn["length"], t)[0]
		var root: Node3D = drawn["root"]
		root.position = Vector3(where.x, 0.0, where.y)
		root.rotation.y = atan2(-float(e["facing"][0]), -float(e["facing"][1]))


## The point a fraction `t` of the way along a polyline of `length`, and the direction of
## the leg it lies on (zero when the legs have no length).
static func _along(segment: Array, length: float, t: float) -> Array:
	var remaining := t * length
	for i in range(1, segment.size()):
		var a: Vector2 = segment[i - 1]
		var b: Vector2 = segment[i]
		var d := a.distance_to(b)
		if remaining <= d:
			return [a.lerp(b, remaining / d if d > 0.0 else 1.0), (b - a).normalized() if d > 0.0 else Vector2.ZERO]
		remaining -= d
	return [segment[segment.size() - 1], Vector2.ZERO]


static func _polyline_length(points: Array) -> float:
	var length := 0.0
	for i in range(1, points.size()):
		length += (points[i - 1] as Vector2).distance_to(points[i])
	return length


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
		var label := _label3d(o["label"], 64)
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


# --- Enemies and loot -----------------------------------------------------------------

## One grey-box figure per placed enemy: a low box for a wolf, an upright capsule with a bow
## stave for an archer, a click volume that becomes `attack`, a name-and-health label and a
## telegraph cue above it.
func _build_enemies(world: WorldDef) -> void:
	for id in world.enemies:
		var kind: String = world.enemies[id]["kind"]
		var colour: Color = COLOR_BY_ENEMY.get(kind, Color.MAGENTA)
		var root := Node3D.new()
		root.name = id
		_enemy_layer.add_child(root)
		if kind == "wolf":
			_add_part(root, _box_mesh(Vector3(0.5, 0.55, 1.1), colour), Vector3(0, 0.45, 0))
			_add_part(root, _box_mesh(Vector3(0.3, 0.3, 0.35), colour.darkened(0.3)), Vector3(0, 0.65, -0.65))
		else:
			var body := CapsuleMesh.new()
			body.radius = 0.32
			body.height = 1.5
			body.material = _flat_material(colour)
			_add_part(root, body, Vector3(0, 0.75, 0))
			_add_part(root, _box_mesh(Vector3(0.06, 1.1, 0.06), COLOR_BY_KIND[WorldDef.KIND_TREE]), Vector3(0.38, 0.9, -0.2))
		var click := _add_box_body(root, Vector3(1.1, 1.8, 1.3), Vector3(0, 0.9, 0))
		click.set_meta("enemy_id", id)
		var label := _label3d("", 48)
		label.position = Vector3(0, 2.0, 0)
		root.add_child(label)
		var cue := _label3d("", CUE_FONT)
		cue.position = Vector3(0, 2.7, 0)
		cue.visible = false
		root.add_child(cue)
		_enemies[id] = {
			"root": root, "body": click, "label": label, "cue": cue, "cue_at": 0,
			"segment": [], "length": 0.0,
		}


## Redraws one enemy from the state: hidden and unclickable while dead, its health label,
## and no cue unless one is still due.
func _sync_enemy(id: String) -> void:
	var drawn: Dictionary = _enemies[id]
	var e: Dictionary = sim.state["enemies"][id]
	var alive: bool = e["mode"] != Sim.MODE_DEAD
	var root: Node3D = drawn["root"]
	root.visible = alive
	(drawn["body"] as StaticBody3D).collision_layer = 1 if alive else 0
	root.position = Vector3(float(e["pos"][0]), 0.0, float(e["pos"][1]))
	var c := sim.combatant(id)
	(drawn["label"] as Label3D).text = "%s  %d / %d" % [CombatTable.enemy(e["kind"])["label"], c["health"], c["health_max"]]
	var next: Dictionary = e["next"]
	if not alive or e["mode"] != Sim.MODE_ENGAGED or not CombatTable.is_attack(str(next.get("action", ""))):
		(drawn["cue"] as Label3D).visible = false


## Shows the blow an enemy has telegraphed for the next tick over its head, coloured by its
## style and bigger for a heavy one, until that tick resolves.
func _show_cue(e: Dictionary) -> void:
	var drawn: Dictionary = _enemies[e["enemy_id"]]
	var cue: Label3D = drawn["cue"]
	var heavy: bool = e["heavy"]
	cue.text = "%s%s" % [CombatTable.action_label(e["action"]).to_upper(), "!" if heavy else ""]
	cue.font_size = CUE_FONT_HEAVY if heavy else CUE_FONT
	cue.modulate = COLOR_BY_STYLE.get(e["style"], Color.WHITE)
	cue.visible = true
	drawn["cue_at"] = int(e["at"])


func _expire_cues() -> void:
	var tick := int(sim.state["tick"])
	for id in _enemies:
		if int(_enemies[id]["cue_at"]) <= tick:
			(_enemies[id]["cue"] as Label3D).visible = false


## "the wolf" for an enemy id, "you" for the player.
func _enemy_name(id: String) -> String:
	if id == SimVocab.PLAYER:
		return "you"
	return "the %s" % str(CombatTable.enemy(sim.state["enemies"][id]["kind"])["label"]).to_lower()


func _hit_text(e: Dictionary) -> String:
	var edge := ""
	if float(e["multiplier"]) > 1.0:
		edge = " Your style has the edge." if e["attacker"] == SimVocab.PLAYER else " Its style has the edge: counter it."
	elif float(e["multiplier"]) < 1.0:
		edge = " Their style has the edge on it." if e["attacker"] == SimVocab.PLAYER else " Your style blunts it."
	if e["attacker"] == SimVocab.PLAYER:
		return "You hit %s for %d.%s" % [_enemy_name(e["target"]), e["amount"], edge]
	return "%s hits you for %d.%s" % [_enemy_name(e["attacker"]).capitalize(), e["amount"], edge]


## A loot pile: a small crate with its contents written over it and a click volume that
## becomes `interact` (walk over and pick it up).
func _add_loot(id: String) -> void:
	var pile: Dictionary = sim.state["loot"][id]
	var root := Node3D.new()
	root.position = Vector3(float(pile["pos"][0]), 0.0, float(pile["pos"][1]))
	_loot_layer.add_child(root)
	_add_part(root, _box_mesh(Vector3(0.35, 0.25, 0.35), COLOR_LOOT), Vector3(0, 0.125, 0))
	var click := _add_box_body(root, Vector3(0.8, 0.6, 0.8), Vector3(0, 0.3, 0))
	click.set_meta("object_id", id)
	var count := int(pile["count"])
	var label := _label3d(ItemTable.label(pile["item"]) + (" x%d" % count if count > 1 else ""), 40)
	label.position = Vector3(0, 0.8, 0)
	root.add_child(label)
	_loot[id] = root


func _remove_loot(id: String) -> void:
	if _loot.has(id):
		(_loot[id] as Node).queue_free()
		_loot.erase(id)


func _add_part(parent: Node3D, mesh: Mesh, offset: Vector3) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.position = offset
	parent.add_child(part)
	return part


static func _box_mesh(size: Vector3, colour: Color) -> BoxMesh:
	var box := BoxMesh.new()
	box.size = size
	box.material = _flat_material(colour)
	return box


static func _label3d(text: String, size: int) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = size
	label.pixel_size = 0.01
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.modulate = Color(0.1, 0.14, 0.2)
	label.outline_modulate = Color(1, 1, 1, 0.9)
	label.outline_size = 12
	return label


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
