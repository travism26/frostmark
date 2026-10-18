## Presentation glue for Frostmark. Owns one Sim, ticks it on a fixed accumulator, turns
## ground clicks into `move_to`, marker, field-fire and loot clicks into `interact` (the
## outpost gate into `cross_gate`) and enemy clicks into `attack`, and plays the simulation's
## events back as motion, telegraph rings and swing arcs on the ground, sound, HUD, banners
## and the death screen. The
## world is built from the Sim's WorldDef (props from scenes/props.gd) so the
## drawing and the walkability grid can never disagree. It starts on the title screen and
## writes the browser save whenever the simulation reports a save point, nudging the player
## to keep their save code after a long stretch of play or when the browser stops keeping saves.
##
## Nothing here decides a rule: every position the character or an enemy is drawn at comes
## from the simulation, interpolated along the polyline it walked in the last tick.
extends Node3D

const CHARACTER_TURN_SPEED := 12.0  # radians per second, for the facing marker
const RAY_LENGTH := 500.0

const COLOR_GROUND := Color(0.84, 0.88, 0.95)
const COLOR_OUTPOST_FLOOR := Color(0.60, 0.56, 0.50)
const OCCLUDER_ALPHA := 0.25
const COLOR_BY_SOLID := {
	WorldDef.KIND_WALL: Color(0.47, 0.36, 0.25),
	WorldDef.KIND_CLIFF: Color(0.62, 0.68, 0.76),
	WorldDef.KIND_RUIN: Color(0.52, 0.53, 0.56),
}
const COLOR_GATE := Color(0.45, 0.32, 0.20)
const COLOR_BY_ENEMY := {
	"wolf": Color(0.42, 0.40, 0.40), "bandit_archer": Color(0.55, 0.24, 0.20),
	"bandit_captain": Color(0.30, 0.10, 0.12), "frost_witch": Color(0.40, 0.48, 0.66),
	"ice_troll": Color(0.58, 0.70, 0.78), "ruin_stalker": Color(0.24, 0.26, 0.30),
}
## Telegraph cues take the style's colour from the icon table, so the ring on the ground, the
## name over the enemy and the style badge in the panel always agree.
const COLOR_BY_STYLE := IconTable.STYLE_COLOURS
## World labels show only under the mouse; the hover ray is cast when the mouse has moved.
const HOVER_RAY_LENGTH := 500.0
const COLOR_LOOT := Color(0.85, 0.68, 0.2)
const CUE_FONT := 72
const CUE_FONT_HEAVY := 120
const LOOT_FONT := 40
## Frames the warm-up stage is drawn behind the title screen before it is freed.
const WARMUP_FRAMES := 6
## Every character a label can show, rasterised into the font atlas behind the title.
const WARMUP_GLYPHS := "ABCDEFGHIJKLMNOPQRSTUVWXYZ abcdefghijklmnopqrstuvwxyz 0123456789 !?.,:;'()/+-x"
## The sun's shadows reach this many orbit distances from the camera: just past the far edge
## of the view at the camera's pitch and lens, and no farther.
const SHADOW_REACH := 1.6
## Fires nearest the character carry a dynamic light; the rest keep their pool and flames.
## GL Compatibility lights every mesh for each light in range, so the count stays small.
const MAX_FIRE_LIGHTS := 4
## How far the character walks before the fires are sorted by distance again.
const LIGHT_RESORT_METRES := 0.5

## What a rejection reason means to the player.
const REASON_TEXT := {
	SimVocab.REASON_NO_TOOL: "You need the right tool: an axe for trees, a pickaxe for rocks, a rod for fishing.",
	SimVocab.REASON_TOOL_TOO_WEAK: "A wooden pickaxe won't bite iron. Smith a bronze one.",
	SimVocab.REASON_PACK_FULL: "Your pack is full.",
	SimVocab.REASON_STASH_FULL: "The stash is full.",
	SimVocab.REASON_DEPLETED: "That's spent for now. It will come back.",
	SimVocab.REASON_NOT_IN_OUTPOST: "The stash is only reachable inside the outpost.",
	SimVocab.REASON_NOT_AT_WORKBENCH: "Stand at the workbench to craft.",
	SimVocab.REASON_MISSING_INPUTS: "You don't have the materials for that.",
	SimVocab.REASON_LEVEL_TOO_LOW: "Your skill level is too low.",
	SimVocab.REASON_NOT_EQUIPPABLE: "That can't be equipped.",
	SimVocab.REASON_NO_AMMO: "You're out of ammunition: a bow needs arrows, a staff frost shards. Swap weapons or use bare hands.",
	SimVocab.REASON_IN_OUTPOST: "Nothing can be fought from inside the outpost.",
	SimVocab.REASON_TARGET_DEAD: "It is already dead.",
	SimVocab.REASON_NOT_FOOD: "You can't eat that.",
	SimVocab.REASON_ALREADY_EATING: "You are already eating.",
	SimVocab.REASON_NOT_AT_FIRE: "Stand by a fire to cook. Light one with three logs, or use the outpost's.",
	SimVocab.REASON_NOT_COOKABLE: "That can't be cooked.",
	SimVocab.REASON_NOTHING_LEFT: "Nothing left to cook.",
	SimVocab.REASON_TIER_CAPPED: "Smithing stops at bronze until the blast furnace is built. Iron is found, not made.",
	SimVocab.REASON_UNREACHABLE: "You can't get there from here. Ring two is only reached through its gate.",
	SimVocab.REASON_UPGRADE_MISSING: "Build the upgrade that unlocks it first.",
	SimVocab.REASON_ALREADY_BUILT: "Already built.",
	SimVocab.REASON_UPGRADE_LOCKED: "That isn't open yet.",
	SimVocab.REASON_NOT_ATTUNED: "Walk up to the waystone first to attune it.",
	SimVocab.REASON_NOT_AT_WAYSTONE: "Stand by the waystone to travel.",
	SimVocab.REASON_INTERRUPTED: "The blow breaks your travel. Win the fight, or get clear, and try again.",
	SimVocab.REASON_BAD_CODE: "That is not a Frostmark save code. Check that you copied all of it.",
	SimVocab.REASON_BAD_CHECKSUM: "That save code has been changed or damaged (its checksum does not match).",
	SimVocab.REASON_UNSUPPORTED_VERSION: "That save code comes from a newer version of Frostmark.",
	SimVocab.REASON_BAD_SNAPSHOT: "That save code holds a character this version cannot load.",
}

const TitleScreen := preload("res://scenes/title_screen.gd")
const Hud := preload("res://scenes/hud.gd")
const GuidePanel := preload("res://scenes/guide_panel.gd")
const HelpPanel := preload("res://scenes/help_panel.gd")
const DeathScreen := preload("res://scenes/death_screen.gd")
const SaveNotice := preload("res://scenes/save_notice.gd")
const CharacterGear := preload("res://scenes/character_gear.gd")
const Atmosphere := preload("res://scenes/atmosphere.gd")
const AudioDirector := preload("res://scenes/audio_director.gd")
const CombatCues := preload("res://scenes/combat_cues.gd")
const Projectiles := preload("res://scenes/projectiles.gd")
const WaystonePanel := preload("res://scenes/waystone_panel.gd")

var sim: Sim
var _accumulator := 0.0
## Polyline the character walked during the last tick, replayed over the current one.
var _segment: Array[Vector2] = []
var _segment_length := 0.0
var _facing := Vector2(0, 1)
var _pending_click: Variant = null  # screen position awaiting a physics query
var _last_event := ""
var _faded: Array[MeshInstance3D] = []  # blocks made see-through because they hide the character
## Fadeable mesh -> its see-through twin material, made with the block so a fade swaps a
## material the GPU has already compiled instead of changing one's shader mid-walk.
var _fade_twins := {}
var _warmup: Node3D  # samples of every look, drawn behind the title screen, then freed
var _warmup_until := 0
var _page_code := ""  # the character the page link asks for, loaded once the warm-up is drawn
var _playing := false
var _node_looks := {}  # node object id -> its prop, whose Full/Spent children show its state
var _ring_gates := {}  # ring gate object id -> {bars, label}
var _waystones := {}  # waystone object id -> {glow, label}
var _fires := {}  # field fire id -> its prop
var _placed_fires: Array = []  # the props of the fires placed in the world: the outpost's, the brazier
var _light_anchor := Vector3(INF, INF, INF)  # where the character stood when the fire lights were last sorted
var _light_count := -1  # how many fires there were then
var _title_screen: Control
var _guide_panel: Control
var _waystone_panel: Control
var _help_panel: Control
var _hud: Control
var _death_screen: Control
var _save_notice: Control
var _save_watch := SaveWatch.new()
var _gear: Node3D
var _character_view: CharacterView
var _atmosphere: Node
var _audio: Node
var _cues: CombatCues
var _projectiles: Projectiles  # arrows and frost shards in flight
var _ui_settings: UiSettings
var _hover_point: Variant = null  # mouse position whose world label to show, or null
var _hovered_label: Label3D
var _clock := 0.0  # seconds of play, for flicker
## Enemy id -> {root, body, label, cue, cue_at, segment, length}: its drawing, its telegraph
## cue (shown until the tick `cue_at` resolves) and the polyline it walked last tick.
var _enemies := {}
var _loot := {}  # loot id -> its pile's node
var _enemy_layer := Node3D.new()
var _loot_layer := Node3D.new()
var _fire_layer := Node3D.new()
var _yard_layer := Node3D.new()  # the pieces the built upgrades put in the yard
var _yard_built: Array = []  # the built upgrades the yard layer was last drawn for
var _yard_pieces := {}  # built upgrade id -> {node, piece}: its piece in the yard layer
var _build_beat := BuildBeat.new()  # the camera ease, rise and puff when an upgrade is built

@onready var _world: Node3D = $World
@onready var _character: Node3D = $Character
@onready var _camera_rig: Node3D = $CameraRig
@onready var _camera: Camera3D = $CameraRig/Camera3D
@onready var _status: Label = $HUD/Status
@onready var _sun: DirectionalLight3D = $Sun


func _ready() -> void:
	sim = Sim.new()
	_build_world(sim.world)
	add_child(_enemy_layer)
	add_child(_loot_layer)
	add_child(_fire_layer)
	add_child(_yard_layer)
	add_child(_build_beat)
	_build_enemies(sim.world)
	_gear = CharacterGear.new()
	_character_view = CharacterView.new()
	_character.add_child(_character_view)
	_character.add_child(_gear)
	UiTheme.style_hud_label($HUD/Status, "status")
	_cues = CombatCues.new()
	add_child(_cues)
	_projectiles = Projectiles.new()
	add_child(_projectiles)
	_atmosphere = Atmosphere.new()
	add_child(_atmosphere)
	_atmosphere.setup($Sun, $WorldEnvironment.environment, _camera_rig, _character, sim.world)
	_hud = Hud.new()
	_hud.command_requested.connect(_on_hud_command)
	_hud.export_requested.connect(_on_show_code)
	$HUD.add_child(_hud)
	_save_notice = SaveNotice.new()
	_save_notice.copy_requested.connect(_on_copy_code)
	_save_notice.show_requested.connect(_on_show_code)
	_save_notice.dismissed.connect(_save_watch.code_seen)
	$HUD.add_child(_save_notice)
	_hud.help_requested.connect(func() -> void: _help_panel.open(true, sim.hints_on()))
	_guide_panel = GuidePanel.new()
	_guide_panel.dismissed.connect(_on_hints_set.bind(false))
	_hud.add_child(_guide_panel)
	_waystone_panel = WaystonePanel.new()
	_waystone_panel.travel_requested.connect(func(id: String) -> void: _on_hud_command(SimVocab.TRAVEL, {"object_id": id}))
	_hud.add_child(_waystone_panel)
	_audio = AudioDirector.new()
	add_child(_audio)
	var sound_layer := Node3D.new()
	add_child(sound_layer)
	_audio.setup(_camera, sound_layer)
	_hud.sound_changed.connect(_audio.change_settings)
	_hud.ui_changed.connect(_on_ui_settings)
	_ui_settings = UiSettings.load_from()
	_ui_settings.apply(get_window())
	_build_beat.moves_camera = not _ui_settings.reduced_motion
	_projectiles.reduced_motion = _ui_settings.reduced_motion
	_hud.set_settings(_audio.settings, _ui_settings)
	_title_screen = TitleScreen.new()
	_title_screen.help_requested.connect(func() -> void: _help_panel.open(false))
	_title_screen.new_character.connect(_on_new_character)
	_title_screen.continue_requested.connect(_on_continue)
	_title_screen.import_requested.connect(_on_import)
	$HUD.add_child(_title_screen)
	if not SaveStore.persistent():
		_title_screen.show_error("This browser is not keeping saves (storage blocked, as in some private browsing). You can play, but copy your save code to keep your character.")
	_death_screen = DeathScreen.new()
	_death_screen.dismissed.connect(_on_death_dismissed)
	$HUD.add_child(_death_screen)
	_death_screen.visible = false
	_help_panel = HelpPanel.new()
	_help_panel.hints_toggled.connect(_on_hints_set)
	$HUD.add_child(_help_panel)
	_hud.visible = false
	_show_sim()
	_build_warmup()
	_page_code = FieldKit.page_code(sim.world)


func _process(delta: float) -> void:
	_clock += delta
	_flicker()
	_end_warmup(false)
	if _warmup == null and _page_code != "":
		# Loading at once would free the warm-up before it was drawn, leaving every look to
		# compile on first sight in play: each arrow, puff and fire the first time it shows.
		var code := _page_code
		_page_code = ""
		_on_import(code)
	var shadow_reach: float = _camera_rig.distance * SHADOW_REACH
	if _sun.directional_shadow_max_distance != shadow_reach:
		_sun.directional_shadow_max_distance = shadow_reach
	if not _playing or _help_panel.visible:
		return
	_accumulator += delta
	while _accumulator >= Sim.TICK_SECONDS and _playing:
		_accumulator -= Sim.TICK_SECONDS
		_segment = []
		for id in _enemies:
			_enemies[id]["segment"] = []
		sim.step()
		if _save_watch.advance():
			if _save_watch.storage_ok:
				_save_notice.show_reminder()
			else:
				_save_notice.show_unstored()
		_expire_cues()
		_apply_events(sim.drain_events())
		# Some enemy changes carry no event (healing on reaching home), so redraw them all.
		for id in _enemies:
			_sync_enemy(id)
	_animate(delta)


func _physics_process(_delta: float) -> void:
	_fade_occluders()
	if _hover_point != null and _playing:
		_hover_label(_hover_point)
		_hover_point = null
	if _pending_click == null or not _playing or _help_panel.visible:
		return
	var screen: Vector2 = _pending_click
	_pending_click = null
	var from := _camera.project_ray_origin(screen)
	var to := from + _camera.project_ray_normal(screen) * RAY_LENGTH
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to))
	# A click sends the character somewhere, so it ends the build beat; the ray above was cast
	# from where the beat had the camera, which is the view the player clicked on.
	_build_beat.cancel()
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
	elif event is InputEventMouseMotion:
		_hover_point = event.position


## Shows the label of whatever world thing is under the mouse and hides the last one, so the
## screen carries no labels until the player asks. Enemies in a fight keep theirs regardless.
func _hover_label(screen: Vector2) -> void:
	var from := _camera.project_ray_origin(screen)
	var to := from + _camera.project_ray_normal(screen) * HOVER_RAY_LENGTH
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to))
	var label: Label3D = null
	if not hit.is_empty() and (hit["collider"] as Object).has_meta("hover_label"):
		label = hit["collider"].get_meta("hover_label")
	if label == _hovered_label:
		return
	if _hovered_label != null and is_instance_valid(_hovered_label) and not _hovered_label.get_meta("pinned", false):
		_hovered_label.visible = false
	_hovered_label = label
	if label != null:
		label.visible = true


## The HUD's Settings tab changed the interface: apply it now and keep it for next time.
func _on_ui_settings(settings: UiSettings) -> void:
	_ui_settings = settings
	settings.apply(get_window())
	_atmosphere.set_reduced_motion(settings.reduced_motion)
	_audio.settings.reduced_motion = settings.reduced_motion  # the director's copy, saved with the sound
	_build_beat.moves_camera = not settings.reduced_motion
	_projectiles.reduced_motion = settings.reduced_motion
	sim.command(SimVocab.SET_AUTO_RETALIATE, {"on": settings.auto_retaliate})
	settings.save_to()


# --- Title screen and saves -----------------------------------------------------------

func _on_new_character() -> void:
	sim = Sim.new(sim.world)  # the world is static data: reuse it and its path grid
	sim.command(SimVocab.NEW_CHARACTER, {"previous": SaveStore.read()})  # hints are for the first character
	_start()
	_save()


func _on_continue() -> void:
	var fresh := Sim.new(sim.world)
	var result := fresh.command(SimVocab.IMPORT_SAVE, {"code": SaveStore.read()})
	if not result["ok"]:
		_title_screen.show_error("Your browser save could not be loaded. %s" % _reason_text(result["reason"]))
		return
	fresh.drain_events()
	sim = fresh
	_start()


func _on_import(code: String) -> void:
	var fresh := Sim.new(sim.world)
	var result := fresh.command(SimVocab.IMPORT_SAVE, {"code": FieldKit.expand(code, sim.world)})
	if not result["ok"]:
		_title_screen.show_error(_reason_text(result["reason"]))
		return
	sim = fresh
	_start()
	_apply_events(sim.drain_events())  # the import's `saved` makes it the browser save
	_last_event = "Save code imported."
	_refresh_status()


func _start() -> void:
	_end_warmup(true)
	_title_screen.visible = false
	_death_screen.visible = false
	_hud.visible = true
	_save_notice.visible = false
	_playing = true
	_accumulator = 0.0
	_segment = []
	_last_event = ""
	_show_sim()
	_hud.banner("Cut wood and walk it home through the gate. The workbench makes a pickaxe and a rod from logs. The bandit captain guards the gate to ring two, far to the south.")


## Redraws everything that depends on the state after a new, continued or imported sim.
func _show_sim() -> void:
	sim.command(SimVocab.SET_AUTO_RETALIATE, {"on": _ui_settings.auto_retaliate})  # a browser preference, not in the save
	_hud.sim = sim
	_hud.close_panels()
	_facing = sim.player_facing()
	_place_character(sim.player_pos(), _facing, 0.0)
	_build_beat.cancel()  # a loaded yard stands as it is, with no beat
	_projectiles.clear()
	_camera_rig.global_position = _character.global_position
	for id in _node_looks:
		_set_node_look(id, int(sim.state["nodes"][id]["left"]) > 0)
	_sync_ring_gates()
	_sync_waystones()
	_sync_yard()
	for id in _fires:
		(_fires[id] as Node).queue_free()
	_fires.clear()
	for id in sim.state["fires"]:
		_add_field_fire(id)
	_gear.show_equipment(sim.state["inventory"]["equipment"])
	_character_view.set_sim(sim)
	_audio.sim = sim
	_atmosphere.sim = sim
	_atmosphere.clear_footprints()
	_audio.set_region(sim.state["player"]["region"])
	_audio.sync_fires(_world.get_node("fire").position, sim.state["fires"])
	for id in _enemies:
		_sync_enemy(id)
	for id in _loot:
		(_loot[id] as Node).queue_free()
	_loot.clear()
	for id in sim.state["loot"]:
		_add_loot(id)
	_hud.refresh()
	_guide_panel.show_sim(sim)
	_waystone_panel.show_sim(sim)
	_refresh_status()


func _save() -> void:
	var ok := SaveStore.write(sim.export_code())
	if ok:
		_hud.flash_saved()
	else:
		_last_event = "Not saved in this browser. Your save code still holds your character."
		_refresh_status()
	if _save_watch.stored(ok):
		_save_notice.show_unstored()


func _on_show_code() -> void:
	_save_watch.code_seen()
	_save_notice.visible = false
	_hud.show_code(sim.export_code())


func _on_copy_code() -> void:
	Clipboard.copy(sim.export_code(), func(ok: bool) -> void:
		if ok:
			_save_watch.code_seen()
			_save_notice.set_note("Copied. Paste it somewhere safe.")
		else:
			_save_notice.set_note("Your browser would not copy it. Use Show code and copy it by hand."))


func _on_hud_command(kind: String, args: Dictionary) -> void:
	sim.command(kind, args)
	_apply_events(sim.drain_events())


## Hides the guide (its own button, or the help switch) or brings it back, and saves the choice.
func _on_hints_set(on: bool) -> void:
	sim.command(SimVocab.SET_HINTS, {"on": on})
	_apply_events(sim.drain_events())
	_guide_panel.show_sim(sim)
	_save()


func _on_death_dismissed() -> void:
	_death_screen.visible = false
	_playing = true
	_accumulator = 0.0


static func _reason_text(reason: String) -> String:
	return REASON_TEXT.get(reason, reason.replace("_", " ").capitalize() + ".")


# --- Events to motion and text --------------------------------------------------------

func _apply_events(events: Array[Dictionary]) -> void:
	_audio.handle(events)
	for e in events:
		match e["kind"]:
			SimVocab.EV_MOVED:
				_segment = []
				for p in e["path"]:
					_segment.append(Vector2(p[0], p[1]))
				_segment_length = _polyline_length(_segment)
			SimVocab.EV_PATH_SET:
				_hud.close_panels()
				_build_beat.cancel()  # moving, by any command, ends the build beat
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
						if _has_raw_food():
							_last_event += " Click raw fish in your pack to cook it."
					SimVocab.ACTION_GATHER:
						_last_event = _gather_verb(e["object_id"])
					SimVocab.ACTION_RING_GATE:
						if sim.ring_gate_open(e["object_id"]):
							_last_event = "You pass through the gate."
						else:
							_last_event = _ring_gate_text(e["object_id"])
					SimVocab.ACTION_WAYSTONE:
						if sim.waystone_awake(e["object_id"]):
							_last_event = "The waystone hums. It can take you home."
						else:
							_last_event = "The waystone sleeps. Build Waystones at the outpost to wake it."
			SimVocab.EV_REGION_CHANGED:
				_last_event = "Entered the %s." % str(e["to"]).replace("_", " ")
				if e["from"] == WorldDef.REGION_OUTPOST:
					_last_event += " The cold sets in."
				elif e["to"] == WorldDef.REGION_RING_ONE:
					_last_event += " Wolves and bandits hunt here."
				elif e["to"] == WorldDef.REGION_RING_TWO:
					_last_event += " Trolls and stalkers keep the ruins."
			SimVocab.EV_GATHERED:
				_last_event = "+%d %s  (+%d %s xp)" % [e["count"], ItemTable.label(e["item"]), e["xp"], e["skill"]]
			SimVocab.EV_ACTIVITY_STOPPED:
				if e["reason"] not in [SimVocab.REASON_MOVED, SimVocab.REASON_TARGET_DEAD, SimVocab.REASON_DIED]:
					_last_event = _reason_text(e["reason"])
			SimVocab.EV_NODE_DEPLETED:
				_set_node_look(e["object_id"], false)
			SimVocab.EV_NODE_RESPAWNED:
				_set_node_look(e["object_id"], true)
			SimVocab.EV_COOKED:
				if e["burnt"]:
					_last_event = "The %s burns to a crisp." % ItemTable.label(e["item"]).to_lower()
				else:
					_last_event = "+1 %s  (+%d cooking xp)" % [ItemTable.label(e["output"]), e["xp"]]
			SimVocab.EV_FIRE_LIT:
				_add_field_fire(e["fire_id"])
				_last_event = "You build a fire. It will burn for a minute."
			SimVocab.EV_FIRE_OUT:
				_remove_field_fire(e["fire_id"])
			SimVocab.EV_BUILT:
				var label: String = UpgradeTable.get_upgrade(e["upgrade"])["label"]
				_hud.banner("Built: %s." % label)
				_hud.flash_upgrade(e["upgrade"])
				_last_event = "Built the %s." % label.to_lower()
				_sync_waystones()
				_sync_yard()
				if _yard_pieces.has(e["upgrade"]):
					_build_beat.start(_yard_pieces[e["upgrade"]]["node"], _yard_pieces[e["upgrade"]]["piece"])
			SimVocab.EV_RING_GATE_OPENED:
				_sync_ring_gates()
				_hud.banner("The gate to ring two is open.")
			SimVocab.EV_WAYSTONE_ATTUNED:
				_sync_waystones()
				_hud.banner("You lay a hand on the waystone. It will remember you.")
			SimVocab.EV_TRAVEL_STARTED:
				_last_event = "Travelling home. Hold still: a blow will break it."
			SimVocab.EV_TRAVELLED:
				_segment = []
				_place_character(sim.player_pos(), sim.player_facing(), 0.0)
				_camera_rig.global_position = _character.global_position
				_hud.banner("The waystone sets you down outside the outpost gate. Walk through it to bank your pack.")
			SimVocab.EV_RING_TWO_REACHED:
				_hud.banner("Ring two. The snow lies over broken walls older than the outpost, and the tracks in it are not wolves'. An old brazier still burns past the gate.")
			SimVocab.EV_ENEMY_STANCE:
				_show_cue(e)
			SimVocab.EV_LEVELLED:
				_hud.banner("%s level %d!" % [str(e["skill"]).capitalize(), e["level"]])
			SimVocab.EV_BANKED:
				_hud.banner(_banked_text(e))
			SimVocab.EV_CRAFTED:
				_last_event = "Crafted: %s." % ItemTable.label(e["item"])
				_hud.banner("Crafted a %s." % ItemTable.label(e["item"]).to_lower())
			SimVocab.EV_EQUIPPED:
				_gear.show_equipment(sim.state["inventory"]["equipment"])
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
					_last_event = "%s has noticed you!" % _sentence(_enemy_name(e["enemy_id"]))
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
				if e["attacker"] != SimVocab.PLAYER:
					_swing(e["attacker"])
					_projectiles.resolve(e["attacker"], true)
					_flinch(e["target"])
				elif _enemies.has(e["target"]):
					# The player's arrow or shard flies now and the enemy recoils when it lands.
					_projectiles.loose(_character, _enemies[e["target"]]["root"], e["style"], 0.0, -1.0, "", true, _flinch.bind(e["target"]))
				else:
					_flinch(e["target"])
			SimVocab.EV_MISSED:
				_last_event = "%s's %s misses. You stepped clear." % [
					_sentence(_enemy_name(e["attacker"])), CombatTable.action_label(e["action"]).to_lower(),
				]
				if e["attacker"] != SimVocab.PLAYER:
					_swing(e["attacker"])
					_projectiles.resolve(e["attacker"], false)
			SimVocab.EV_ENEMY_DIED:
				_last_event = "%s falls." % _sentence(_enemy_name(e["enemy_id"]))
				if e["enemy_kind"] == "bandit_captain" and not sim.ring_gate_open("ring_two_gate"):
					_hud.banner("The bandit captain falls. Build the ring-two gate winch at the outpost to open his gate.")
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
			SimVocab.EV_HINT:
				_guide_panel.show_hint(e["hint"])
			SimVocab.EV_TIP:
				_guide_panel.show_tip(e["tip"])
			SimVocab.EV_COMMAND_REJECTED:
				var reason: String = e["reason"]
				if reason == SimVocab.REASON_IN_OUTPOST and e["command"] == SimVocab.LIGHT_FIRE:
					_last_event = "The outpost has its own fire."
				elif reason == SimVocab.REASON_NO_TOOL and sim.is_node(str(e["args"].get("object_id", ""))):
					var tool: String = WorldDef.NODE_KINDS[sim.world.objects[e["args"]["object_id"]]["kind"]]["tool"]
					_last_event = "You need a %s for that. The workbench makes one from logs." % ("fishing rod" if tool == "rod" else tool)
				elif reason == SimVocab.REASON_LEVEL_TOO_LOW and sim.is_node(str(e["args"].get("object_id", ""))):
					var def: Dictionary = WorldDef.NODE_KINDS[sim.world.objects[e["args"]["object_id"]]["kind"]]
					_last_event = "You need %s level %d for that." % [str(def["skill"]).capitalize(), def["level"]]
				elif REASON_TEXT.has(reason):
					_last_event = REASON_TEXT[reason]
				else:
					_last_event = "Can't do that (%s)." % reason.replace("_", " ")
	_hud.refresh()
	_waystone_panel.show_sim(sim)
	_refresh_status()


## The banner for a `banked` event: what went in, what stayed for a full stash, and the
## upgrades this bank made affordable.
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
	# Only when this bank made something buildable, so it does not nag on every trip.
	var newly: Array = e.get("newly_affordable", [])
	if not newly.is_empty():
		var names: PackedStringArray = []
		for id in newly:
			names.append(UpgradeTable.get_upgrade(id)["label"])
		text += "\nYou can now build: %s." % ", ".join(names)
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
	_camera_rig.global_position = _build_beat.camera_point(_character.global_position)
	_audio.follow(_character.global_position)
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


func _set_block_alpha(block: MeshInstance3D, alpha: float) -> void:
	block.material_override = _fade_twins.get(block) if alpha < 1.0 else null


## A see-through copy of a mesh's material, kept for the session so it is compiled once.
func _add_fade_twin(mesh: MeshInstance3D) -> void:
	# Primitive and array meshes alike keep their material on surface 0; skip any without one.
	if mesh.mesh == null or mesh.mesh.get_surface_count() == 0:
		return
	var material := mesh.mesh.surface_get_material(0) as StandardMaterial3D
	if material == null:
		return
	var twin := material.duplicate() as StandardMaterial3D
	twin.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	twin.albedo_color.a = OCCLUDER_ALPHA
	_fade_twins[mesh] = twin


# --- Shader warm-up -------------------------------------------------------------------

## The browser compiles a shader the first time something draws with it, freezing the game
## for 50 to 275 ms (seconds in Firefox). So behind the title screen a tiny sample of every
## look the world can show is drawn in front of the camera for a few frames: each material
## once plain and once instanced, beside and away from a fire's light (both change the
## compiled shader), plus the see-through fade twins and every label size with every glyph
## it can print. The yard pieces of every upgrade are sampled too, built or not, so none
## freezes the game when it first appears, and so is the build beat's puff, with the
## particles of every fire, and a fight's shots and puffs. A look only stays compiled while
## a material of its kind lives, so the shots made during play share materials held for the
## session (Projectiles). The HUD is drawn under the title too, so its text is
## rasterised before the first click.
func _build_warmup() -> void:
	var looks := {}  # shader key -> [a mesh, a material with that key]
	var every_piece := Node3D.new()
	for piece in YardLook.pieces(UpgradeTable.ids()):
		every_piece.add_child(WorldDressing.yard_piece(piece))
		every_piece.add_child(BuildBeat.puff(piece))
	every_piece.add_child(Projectiles.samples())
	for root: Node in [_world, _enemy_layer, _character, every_piece]:
		for node in root.find_children("*", "GeometryInstance3D", true, false):
			var mesh: Mesh = null
			if node is MeshInstance3D:
				mesh = (node as MeshInstance3D).mesh
			elif node is MultiMeshInstance3D:
				mesh = (node as MultiMeshInstance3D).multimesh.mesh
			elif node is CPUParticles3D:
				mesh = (node as CPUParticles3D).mesh
			if mesh == null:
				continue
			for i in mesh.get_surface_count():
				var material: Material = (node as GeometryInstance3D).material_override
				if material == null and node is MeshInstance3D:
					material = (node as MeshInstance3D).get_active_material(i)
				elif material == null:
					material = mesh.surface_get_material(i)
				_add_look(looks, mesh, material)
	every_piece.free()
	for m: MeshInstance3D in _fade_twins:
		_add_look(looks, m.mesh, _fade_twins[m])
	var sizes := {CUE_FONT: true, CUE_FONT_HEAVY: true, LOOT_FONT: true}
	for root: Node in [_world, _enemy_layer]:
		for label in root.find_children("*", "Label3D", true, false):
			sizes[(label as Label3D).font_size] = true

	_warmup = Node3D.new()
	_warmup.name = "Warmup"
	_warmup.position = Vector3(0, 0, -2.0)
	_camera.add_child(_warmup)
	for lit in [false, true]:
		var cluster := Node3D.new()
		cluster.position = Vector3(0.4 if lit else -0.4, 0, 0)
		_warmup.add_child(cluster)
		if lit:
			var glow := OmniLight3D.new()
			glow.omni_range = 0.3
			cluster.add_child(glow)
		var n := 0
		for key in looks:
			for instanced in [false, true]:
				var sample := _warmup_sample(looks[key][0], looks[key][1], instanced)
				sample.position = Vector3((n % 8) * 0.03 - 0.1, (n / 8) * 0.03 - 0.1, 0)
				cluster.add_child(sample)
				n += 1
	var row := 0
	for size in sizes:
		var label := _label3d(WARMUP_GLYPHS, size)
		label.pixel_size = 0.00002
		label.position = Vector3(0, -0.2 - row * 0.01, 0)
		_warmup.add_child(label)
		row += 1
	_hud.visible = true
	_hud.banner(WARMUP_GLYPHS)
	_warmup_until = Engine.get_frames_drawn() + WARMUP_FRAMES


static func _add_look(looks: Dictionary, mesh: Mesh, material: Material) -> void:
	var key := _shader_key(material)
	if not looks.has(key):
		looks[key] = [mesh, material]


## What decides a material's compiled shader: a ShaderMaterial's shader, or a built-in
## material's class, switches, modes and which textures it has. Colours and other numbers
## are uniforms and share one shader.
static func _shader_key(material: Material) -> String:
	if material == null:
		return "default"
	if material is ShaderMaterial:
		return "shader %d" % (material as ShaderMaterial).shader.get_instance_id()
	var parts := PackedStringArray([material.get_class()])
	for p in material.get_property_list():
		if p["usage"] & PROPERTY_USAGE_STORAGE == 0:
			continue
		match p["type"]:
			TYPE_BOOL, TYPE_INT:
				parts.append("%s=%s" % [p["name"], material.get(p["name"])])
			TYPE_OBJECT:
				parts.append("%s=%s" % [p["name"], material.get(p["name"]) != null])
	return " ".join(parts)


## A tiny copy of `mesh` drawn with `material`, alone or as a one-instance multimesh.
static func _warmup_sample(mesh: Mesh, material: Material, instanced: bool) -> GeometryInstance3D:
	var sample: GeometryInstance3D
	if instanced:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = 1
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		sample = mmi
	else:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		sample = mi
	sample.material_override = material
	var extent := maxf(mesh.get_aabb().get_longest_axis_size(), 0.001)
	sample.scale = Vector3.ONE * (0.02 / extent)
	return sample


## Frees the warm-up stage once it has been drawn for WARMUP_FRAMES frames, or at once.
func _end_warmup(now: bool) -> void:
	if _warmup != null and (now or Engine.get_frames_drawn() >= _warmup_until):
		_warmup.queue_free()
		_warmup = null
		_hud.visible = _playing


# --- The world from the WorldDef -----------------------------------------------------

func _build_world(world: WorldDef) -> void:
	var width := world.cols * world.cell_size
	var depth := world.rows * world.cell_size
	var centre := Vector3(world.origin[0] + width * 0.5, 0.0, world.origin[1] + depth * 0.5)

	var ground := MeshInstance3D.new()
	ground.name = "Ground"
	var plane := PlaneMesh.new()
	plane.size = Vector2(width, depth) * 2.5  # snow runs on past the cliffs; only the world is clickable
	plane.material = WorldDressing.snowfield_material()
	WorldDressing.paint_rings(plane.material, world)
	ground.mesh = plane
	ground.position = centre
	_world.add_child(ground)
	_add_box_body(ground, Vector3(width, 0.2, depth), Vector3(0, -0.1, 0))

	for r in world.regions:
		if r["name"] == WorldDef.REGION_OUTPOST:
			_add_floor(r["polygon"], COLOR_OUTPOST_FLOOR)
	_world.add_child(WorldDressing.boundaries(world))

	for s in world.solids:
		match s["kind"]:
			WorldDef.KIND_OUTCROP:
				var rock := Props.outcrop(_box_size(s["min"], s["max"], s["height"]))
				_place_prop(rock, s["min"], s["max"])
				_add_box_body(rock, _box_size(s["min"], s["max"], s["height"]), Vector3(0, s["height"] * 0.5, 0))
			WorldDef.KIND_DECOR:
				var tent := Props.model(Props.NATURE + "tent_detailedClosed.glb", s["height"], 0.55, Color(0.72, 0.62, 0.5))
				tent.rotation.y = PI * 0.75
				_place_prop(tent, s["min"], s["max"])
				_add_box_body(tent, _box_size(s["min"], s["max"], s["height"]), Vector3(0, s["height"] * 0.5, 0))
			_:
				var box := _add_block(str(s["id"]), s["min"], s["max"], s["height"], COLOR_BY_SOLID.get(s["kind"], Color.MAGENTA))
				var look := WorldDressing.solid_mesh(world, s)
				if look != null:
					box.mesh = look  # a palisade, an ice ridge or a ruin over the same footprint
					_add_fade_twin(box)  # the twin follows the new look
				_add_box_body(box, _box_size(s["min"], s["max"], s["height"]), Vector3.ZERO)
	_add_cliff_forest(world)
	_world.add_child(WorldDressing.dressing(world))

	for id in world.objects:
		var o: Dictionary = world.objects[id]
		var kind: String = o["kind"]
		var prop: Node3D
		var label_text: String = o["label"]
		match kind:
			WorldDef.KIND_TREE, WorldDef.KIND_FROST_PINE:
				prop = Props.pine(kind)
				label_text = "" if kind == WorldDef.KIND_TREE else label_text
			WorldDef.KIND_COPPER_ROCK, WorldDef.KIND_TIN_ROCK, WorldDef.KIND_IRON_ROCK, WorldDef.KIND_ICE_CRYSTAL, \
					WorldDef.KIND_COAL_ROCK, WorldDef.KIND_RICH_IRON_ROCK:
				prop = Props.ore_rock(kind, o["max"][0] - o["min"][0])
			WorldDef.KIND_FISHING_HOLE, WorldDef.KIND_ICE_HOLE, WorldDef.KIND_DEEP_HOLE:
				prop = Props.ice_hole(o["max"][0] - o["min"][0], kind != WorldDef.KIND_FISHING_HOLE)
			WorldDef.KIND_FIRE:
				prop = Props.campfire(o["max"][0] - o["min"][0])
			WorldDef.KIND_STASH:
				prop = Props.chest(1.0)
			WorldDef.KIND_WORKBENCH:
				prop = Props.anvil(1.1)
			WorldDef.KIND_RING_GATE:
				prop = Props.ring_gate(o["max"][0] - o["min"][0], o["height"])
			WorldDef.KIND_WAYSTONE:
				var stone_at := Vector2((o["min"][0] + o["max"][0]) * 0.5, (o["min"][1] + o["max"][1]) * 0.5)
				prop = Props.waystone(o["height"], stone_at, RingLook.at(world, stone_at)["stone"])
		if prop == null:
			# The outpost gate: a timber gateway over the threshold, clickable through a taller volume.
			var gate := WorldDressing.gateway(o["min"], o["max"])
			gate.name = str(id)
			_place_prop(gate, o["min"], o["max"])
			var click_size := _box_size(o["min"], o["max"], maxf(o["height"], 1.0))
			var gate_body := _add_box_body(gate, click_size, Vector3(0, click_size.y * 0.5, 0))
			gate_body.set_meta("object_id", id)
			var gate_label := _label3d(o["label"], 64)
			gate_label.position = Vector3(0, WorldDressing.GATEWAY_HEIGHT + 0.9, 0)
			gate_label.visible = false
			gate.add_child(gate_label)
			gate_body.set_meta("hover_label", gate_label)
			continue
		prop.name = str(id)
		_place_prop(prop, o["min"], o["max"])
		# A click volume over the whole footprint, at least 1 m tall so flat holes are clickable.
		var height := maxf(o["height"], 1.0)
		var body := _add_box_body(prop, _box_size(o["min"], o["max"], height), Vector3(0, height * 0.5, 0))
		body.set_meta("object_id", id)
		if sim.is_node(id):
			_node_looks[id] = prop
		if kind == WorldDef.KIND_FIRE:
			_placed_fires.append(prop)
		if label_text != "":
			var label := _label3d(label_text, 48 if sim.is_node(id) else 64)
			label.position = Vector3(0, o["height"] + 0.8, 0)
			label.visible = false
			prop.add_child(label)
			body.set_meta("hover_label", label)
			if kind == WorldDef.KIND_RING_GATE:
				_ring_gates[id] = {"bars": prop.get_node("Bars"), "label": label}
			elif kind == WorldDef.KIND_WAYSTONE:
				_waystones[id] = {"glow": prop.get_node("Glow"), "label": label}


## Stands a prop on the centre of a footprint.
func _place_prop(prop: Node3D, min_xz: Array, max_xz: Array) -> void:
	prop.position = Vector3((min_xz[0] + max_xz[0]) * 0.5, 0.0, (min_xz[1] + max_xz[1]) * 0.5)
	_world.add_child(prop)


## A forest of pines over the cliffs at ring one's edge, drawn as one multimesh per surface.
func _add_cliff_forest(world: WorldDef) -> void:
	var points: Array[Vector3] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var edge := 61.0
	for i in 140:
		var t := rng.randf_range(-63.0, 63.0)
		var depth := rng.randf_range(0.0, 2.5)
		var side := i % 4
		var p := Vector2(t, -edge - depth) if side == 0 else Vector2(edge + depth, t) if side == 1 else Vector2(t, edge + depth) if side == 2 else Vector2(-edge - depth, t)
		if absf(p.x) < 24.0 and p.y > 0.0:
			continue  # the camera looks over this stretch at the captain's gate: keep it clear
		if not world.is_walkable(p):
			points.append(Vector3(p.x, 2.6, p.y))
	var tree := Props.model(Props.NATURE + "tree_pineDefaultA.glb", 3.6)
	for mi in tree.find_children("*", "MeshInstance3D", true, false):
		var source := mi as MeshInstance3D
		var mesh := source.mesh.duplicate() as Mesh
		for surface in mesh.get_surface_count():
			mesh.surface_set_material(surface, source.get_surface_override_material(surface))
		var inner := tree.get_child(0) as Node3D
		var scale_offset := Transform3D(inner.basis, inner.position) * Props._relative_transform(inner, source)
		_world.add_child(_multimesh(mesh, points, Vector3.ZERO, scale_offset))
	tree.free()


## One MultiMeshInstance3D drawing `mesh` at each of `points` (plus `offset`), each with a
## little turn so repeats don't line up, after the local transform `local`.
func _multimesh(mesh: Mesh, points: Array[Vector3], offset: Vector3, local := Transform3D.IDENTITY) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = points.size()
	for i in points.size():
		var turn := Basis(Vector3.UP, float(i) * 2.399)
		mm.set_instance_transform(i, Transform3D(turn, points[i] + offset) * local)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	return mmi


## A node prop shows its `Full` look while it has yields left and its `Spent` look while it
## regrows.
func _set_node_look(id: String, full: bool) -> void:
	var prop: Node3D = _node_looks[id]
	var full_look := prop.get_node_or_null("Full")
	var spent_look := prop.get_node_or_null("Spent")
	if full_look != null:
		full_look.visible = full
	if spent_look != null:
		spent_look.visible = not full


## The ring gate's bars stand while it is closed; its label says what it waits for.
func _sync_ring_gates() -> void:
	for id in _ring_gates:
		var open := sim.ring_gate_open(id)
		(_ring_gates[id]["bars"] as Node3D).visible = not open
		(_ring_gates[id]["label"] as Label3D).text = "Gate to ring two (open)" if open else "Gate to ring two (barred)"


## A waystone's runes glow once the outpost has woken it; its label says whether it knows you.
func _sync_waystones() -> void:
	for id in _waystones:
		var awake := sim.waystone_awake(id)
		(_waystones[id]["glow"] as Node3D).visible = awake
		var state := "asleep" if not awake else "attuned" if sim.waystone_attuned(id) else "visit to attune"
		(_waystones[id]["label"] as Label3D).text = "Waystone (%s)" % state


## The yard shows a piece for every built upgrade (YardLook), redrawn when the list changes.
## Redrawing ends any build beat: its piece is replaced, standing in place.
func _sync_yard() -> void:
	var built: Array = sim.state["upgrades"]
	if built == _yard_built:
		return
	_build_beat.cancel()
	_yard_pieces.clear()
	for child in _yard_layer.get_children():
		child.queue_free()
	for piece in YardLook.pieces(built):
		var node := WorldDressing.yard_piece(piece)
		_yard_layer.add_child(node)
		_yard_pieces[piece["upgrade"]] = {"node": node, "piece": piece}
	_yard_built = built.duplicate()


func _ring_gate_text(id: String) -> String:
	var gate: Dictionary = sim.world.objects[id]
	var guardian_down := (sim.state["bosses_defeated"] as Array).has(gate["guardian"])
	var built := (sim.state["upgrades"] as Array).has(gate["upgrade"])
	if not guardian_down and not built:
		return "The gate is barred. Defeat the bandit captain and build the gate winch at the outpost."
	if not guardian_down:
		return "The winch is built, but the bandit captain still holds this gate."
	return "The captain is beaten. Build the ring-two gate winch at the outpost to open it."


func _gather_verb(id: String) -> String:
	match WorldDef.NODE_KINDS[sim.world.objects[id]["kind"]]["skill"]:
		SkillTable.MINING:
			return "Mining..."
		SkillTable.FISHING:
			return "Fishing..."
	return "Chopping..."


func _has_raw_food() -> bool:
	for s in sim.state["inventory"]["pack"]:
		if s != null and RecipeTable.is_cookable(s["item"]):
			return true
	return false


# --- Field fires ----------------------------------------------------------------------

func _add_field_fire(id: String) -> void:
	var fire: Dictionary = sim.state["fires"][id]
	var prop := Props.campfire(1.2)
	prop.position = Vector3(float(fire["pos"][0]), 0.0, float(fire["pos"][1]))
	_fire_layer.add_child(prop)
	var body := _add_box_body(prop, Vector3(1.2, 1.0, 1.2), Vector3(0, 0.5, 0))
	body.set_meta("object_id", id)
	_fires[id] = prop


func _remove_field_fire(id: String) -> void:
	if _fires.has(id):
		(_fires[id] as Node).queue_free()
		_fires.erase(id)


## Fires flicker on their own (each `Flame` is a FireFx, scenes/fire_fx.gd). Here only the
## light budget is kept: the MAX_FIRE_LIGHTS fires nearest the character carry a light. The
## fires are sorted again only once the character has moved or a fire was lit or went out.
func _flicker() -> void:
	var here := _character.global_position
	var count := _placed_fires.size() + _fires.size()
	if count == _light_count and here.distance_squared_to(_light_anchor) < LIGHT_RESORT_METRES * LIGHT_RESORT_METRES:
		return
	_light_anchor = here
	_light_count = count
	var fires: Array = []
	for prop in _placed_fires:
		fires.append(prop)
	for id in _fires:
		fires.append(_fires[id])
	fires.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return a.global_position.distance_squared_to(here) < b.global_position.distance_squared_to(here))
	for i in fires.size():
		var flame := (fires[i] as Node3D).get_node_or_null("Flame") as FireFx
		if flame != null:
			flame.set_lit(i < MAX_FIRE_LIGHTS)


# --- Enemies and loot -----------------------------------------------------------------

## One figure per placed enemy: an animated model from Figures (the captain's sabre, bow and
## staff are its `captain_sabre`, `captain_bow` and `captain_staff` nodes; the one in his hand
## follows his stance),
## a click volume that becomes `attack`, a name-and-health label and a telegraph cue above it.
func _build_enemies(world: WorldDef) -> void:
	for id in world.enemies:
		var kind: String = world.enemies[id]["kind"]
		var root := Node3D.new()
		root.name = id
		_enemy_layer.add_child(root)
		var figure := Figures.enemy(kind)
		figure.name = "Figure"
		root.add_child(figure)
		var weapons := {}
		for w in ["captain_sabre", "captain_bow", "captain_staff"]:
			var piece := figure.find_child(w, true, false)
			if piece != null:
				weapons[w] = piece
		var height: float = figure.get_meta("height")
		var click := _add_box_body(root, Vector3(1.1, height, 1.3), Vector3(0, height * 0.5, 0))
		click.set_meta("enemy_id", id)
		var label := _label3d("", 48)
		label.position = Vector3(0, height + 0.2, 0)
		label.visible = false
		root.add_child(label)
		click.set_meta("hover_label", label)
		var cue := _label3d("", CUE_FONT)
		cue.position = Vector3(0, height + 0.9, 0)
		cue.visible = false
		root.add_child(cue)
		_enemies[id] = {
			"root": root, "body": click, "label": label, "cue": cue, "cue_at": 0,
			"segment": [], "length": 0.0, "weapons": weapons,
		}


## Redraws one enemy from the state: hidden and unclickable while dead, its health label, the
## weapon in its hand, and no cue unless one is still due.
func _sync_enemy(id: String) -> void:
	var drawn: Dictionary = _enemies[id]
	var e: Dictionary = sim.state["enemies"][id]
	var alive: bool = e["mode"] != Sim.MODE_DEAD
	var root: Node3D = drawn["root"]
	root.visible = alive
	(drawn["body"] as StaticBody3D).collision_layer = 1 if alive else 0
	root.position = Vector3(float(e["pos"][0]), 0.0, float(e["pos"][1]))
	var figure: FigureBody = root.get_node("Figure")
	if alive:
		figure.revive()
	else:
		figure.die()
	var c := sim.combatant(id)
	var label := drawn["label"] as Label3D
	label.text = "%s  %d / %d" % [CombatTable.enemy(e["kind"])["label"], c["health"], c["health_max"]]
	# An enemy in a fight keeps its name and health up; the rest show theirs under the mouse.
	var fighting: bool = alive and e["mode"] == Sim.MODE_ENGAGED
	label.set_meta("pinned", fighting)
	if fighting:
		label.visible = true
	elif label != _hovered_label:
		label.visible = false
	_cues.follow(id, root)
	var weapons: Dictionary = drawn["weapons"]
	if weapons.size() > 1:
		for w in weapons:
			(weapons[w] as Node3D).visible = w == c["weapon"]
	var next: Dictionary = e["next"]
	var announced := CombatTable.is_attack(str(next.get("action", ""))) or CombatTable.is_stance(str(next.get("action", "")))
	if not alive or e["mode"] != Sim.MODE_ENGAGED or not announced:
		(drawn["cue"] as Label3D).visible = false
		_cues.clear_ring(id)


## Shows the blow an enemy has telegraphed for the next tick over its head, coloured by its
## style and bigger for a heavy one, until that tick resolves.
func _show_cue(e: Dictionary) -> void:
	var drawn: Dictionary = _enemies[e["enemy_id"]]
	var cue: Label3D = drawn["cue"]
	var heavy: bool = e.get("heavy", false)
	cue.text = "%s%s" % [CombatTable.action_label(e["action"]).to_upper(), "!" if heavy else ""]
	cue.font_size = CUE_FONT_HEAVY if heavy else CUE_FONT
	cue.modulate = COLOR_BY_STYLE.get(e["style"], Color.WHITE)
	cue.visible = true
	drawn["cue_at"] = int(e["at"])
	_cues.ring(e["enemy_id"], drawn["root"], COLOR_BY_STYLE.get(e["style"], Color.WHITE), heavy)
	var figure := (drawn["root"] as Node3D).get_node("Figure") as FigureBody
	if CombatTable.is_attack(e["action"]):
		figure.strike(e["style"])
		# A bow or staff looses its shot so it arrives as this blow lands, on the next tick.
		_projectiles.loose(drawn["root"], _character, e["style"], 0.0, Sim.TICK_SECONDS - _accumulator, e["enemy_id"], false)
	elif CombatTable.is_windup(e["action"]):
		figure.wind_up(e["style"])


## The one the blow landed on recoils: the character, or an enemy whose rig has a flinch.
func _flinch(target: String) -> void:
	if target == SimVocab.PLAYER:
		_character_view.flinch()
	elif _enemies.has(target):
		((_enemies[target]["root"] as Node3D).get_node("Figure") as FigureBody).flinch()


## The blow lands (or misses): a brief arc at the enemy's feet, swung toward the character,
## in the colour of the style it was telegraphed in.
func _swing(enemy_id: String) -> void:
	if not _enemies.has(enemy_id):
		return
	var root: Node3D = _enemies[enemy_id]["root"]
	var style := str(sim.combatant(enemy_id).get("style", CombatTable.STYLE_MELEE))
	_cues.arc(root, _character.global_position, COLOR_BY_STYLE.get(style, Color.WHITE))
	_cues.clear_ring(enemy_id)


func _expire_cues() -> void:
	var tick := int(sim.state["tick"])
	for id in _enemies:
		if int(_enemies[id]["cue_at"]) <= tick:
			(_enemies[id]["cue"] as Label3D).visible = false
			_cues.clear_ring(id)


## "the wolf" for an enemy id, "you" for the player.
func _enemy_name(id: String) -> String:
	if id == SimVocab.PLAYER:
		return "you"
	return "the %s" % str(CombatTable.enemy(sim.state["enemies"][id]["kind"])["label"]).to_lower()


static func _sentence(text: String) -> String:
	return text.substr(0, 1).to_upper() + text.substr(1)


func _hit_text(e: Dictionary) -> String:
	var edge := ""
	if float(e["multiplier"]) > 1.0:
		edge = " Your style has the edge." if e["attacker"] == SimVocab.PLAYER else " Its style has the edge: counter it."
	elif float(e["multiplier"]) < 1.0:
		edge = " Their style has the edge on it." if e["attacker"] == SimVocab.PLAYER else " Your style blunts it."
	if e["attacker"] == SimVocab.PLAYER:
		return "You hit %s for %d.%s" % [_enemy_name(e["target"]), e["amount"], edge]
	return "%s hits you for %d.%s" % [_sentence(_enemy_name(e["attacker"])), e["amount"], edge]


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
	var label := _label3d(ItemTable.label(pile["item"]) + (" x%d" % count if count > 1 else ""), LOOT_FONT)
	label.position = Vector3(0, 0.8, 0)
	label.visible = false
	root.add_child(label)
	click.set_meta("hover_label", label)
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
	plane.material = WorldDressing.yard_material()
	floor_mesh.mesh = plane
	floor_mesh.position = Vector3((lo.x + hi.x) * 0.5, 0.01, (lo.y + hi.y) * 0.5)
	_world.add_child(floor_mesh)
	# Stones trodden in from the gate on the south wall to the fire in the middle.
	_world.add_child(WorldDressing.path_stones(Vector2((lo.x + hi.x) * 0.5, hi.y - 0.8), Vector2((lo.x + hi.x) * 0.5, (lo.y + hi.y) * 0.5 + 1.6)))


func _add_block(id: String, min_xz: Array, max_xz: Array, height: float, colour: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = id
	var box := BoxMesh.new()
	box.size = _box_size(min_xz, max_xz, height)
	box.material = _flat_material(colour)
	mesh.mesh = box
	mesh.position = Vector3((min_xz[0] + max_xz[0]) * 0.5, height * 0.5, (min_xz[1] + max_xz[1]) * 0.5)
	_world.add_child(mesh)
	_add_fade_twin(mesh)
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
