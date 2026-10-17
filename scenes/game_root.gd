## Presentation glue for Frostmark. Owns one Sim, ticks it on a fixed accumulator, turns
## ground clicks into `move_to`, marker, field-fire and loot clicks into `interact` (the
## outpost gate into `cross_gate`) and enemy clicks into `attack`, and plays the simulation's
## events back as motion, telegraph cues, sound, HUD, banners and the death screen. The
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
## Stakes mark where the inner ring ends and ring one's danger begins.
const RING_STAKE_SPACING := 6.0
const COLOR_STAKE := Color(0.75, 0.18, 0.15)
## Telegraph cues are coloured by the style of the blow coming, so the counter reads at a glance.
const COLOR_BY_STYLE := {
	CombatTable.STYLE_MELEE: Color(0.95, 0.35, 0.2),
	CombatTable.STYLE_RANGED: Color(0.2, 0.55, 1.0),
	CombatTable.STYLE_MAGIC: Color(0.75, 0.4, 1.0),
}
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
const SoundPanel := preload("res://scenes/sound_panel.gd")

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
var _playing := false
var _node_looks := {}  # node object id -> its prop, whose Full/Spent children show its state
var _ring_gates := {}  # ring gate object id -> {bars, label}
var _fires := {}  # field fire id -> its prop
var _placed_fires: Array = []  # the props of the fires placed in the world: the outpost's, the brazier
var _title_screen: Control
var _guide_panel: Control
var _help_panel: Control
var _hud: Control
var _death_screen: Control
var _save_notice: Control
var _save_watch := SaveWatch.new()
var _gear: Node3D
var _atmosphere: Node
var _audio: Node
var _sound_panel: Control
var _clock := 0.0  # seconds of play, for flicker
## Enemy id -> {root, body, label, cue, cue_at, segment, length}: its drawing, its telegraph
## cue (shown until the tick `cue_at` resolves) and the polyline it walked last tick.
var _enemies := {}
var _loot := {}  # loot id -> its pile's node
var _enemy_layer := Node3D.new()
var _loot_layer := Node3D.new()
var _fire_layer := Node3D.new()

@onready var _world: Node3D = $World
@onready var _character: Node3D = $Character
@onready var _camera_rig: Node3D = $CameraRig
@onready var _camera: Camera3D = $CameraRig/Camera3D
@onready var _title: Label = $HUD/Title
@onready var _status: Label = $HUD/Status
@onready var _sun: DirectionalLight3D = $Sun


func _ready() -> void:
	sim = Sim.new()
	_title.text = "Frostmark v%s" % ProjectSettings.get_setting("application/config/version")
	_build_world(sim.world)
	add_child(_enemy_layer)
	add_child(_loot_layer)
	add_child(_fire_layer)
	_build_enemies(sim.world)
	_gear = CharacterGear.new()
	_character.add_child(_gear)
	_atmosphere = Atmosphere.new()
	add_child(_atmosphere)
	_atmosphere.setup($Sun, $WorldEnvironment.environment, _camera_rig, _character)
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
	_hud.sound_requested.connect(func() -> void: _sound_panel.open(_audio.settings))
	_audio = AudioDirector.new()
	add_child(_audio)
	var sound_layer := Node3D.new()
	add_child(sound_layer)
	_audio.setup(_camera, sound_layer)
	_sound_panel = SoundPanel.new()
	_sound_panel.changed.connect(_audio.change_settings)
	$HUD.add_child(_sound_panel)
	_sound_panel.visible = false
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


func _process(delta: float) -> void:
	_clock += delta
	_flicker()
	_end_warmup(false)
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
	if _pending_click == null or not _playing or _help_panel.visible:
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
	_hud.sim = sim
	_hud.close_panels()
	_facing = sim.player_facing()
	_place_character(sim.player_pos(), _facing, 0.0)
	_camera_rig.global_position = _character.global_position
	for id in _node_looks:
		_set_node_look(id, int(sim.state["nodes"][id]["left"]) > 0)
	_sync_ring_gates()
	for id in _fires:
		(_fires[id] as Node).queue_free()
	_fires.clear()
	for id in sim.state["fires"]:
		_add_field_fire(id)
	_gear.show_equipment(sim.state["inventory"]["equipment"])
	_atmosphere.set_outside(not sim.in_outpost())
	_audio.sim = sim
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
			SimVocab.EV_REGION_CHANGED:
				_last_event = "Entered the %s." % str(e["to"]).replace("_", " ")
				if e["from"] == WorldDef.REGION_OUTPOST:
					_last_event += " The cold sets in."
				elif e["to"] == WorldDef.REGION_RING_ONE:
					_last_event += " Wolves and bandits hunt here."
				elif e["to"] == WorldDef.REGION_RING_TWO:
					_last_event += " Trolls and stalkers keep the ruins."
				_atmosphere.set_outside(e["to"] != WorldDef.REGION_OUTPOST)
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
				_last_event = "Built the %s." % label.to_lower()
			SimVocab.EV_RING_GATE_OPENED:
				_sync_ring_gates()
				_hud.banner("The gate to ring two is open.")
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
			SimVocab.EV_MISSED:
				_last_event = "%s's %s misses. You stepped clear." % [
					_sentence(_enemy_name(e["attacker"])), CombatTable.action_label(e["action"]).to_lower(),
				]
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
	var twin := (mesh.mesh.material as StandardMaterial3D).duplicate() as StandardMaterial3D
	twin.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	twin.albedo_color.a = OCCLUDER_ALPHA
	_fade_twins[mesh] = twin


# --- Shader warm-up -------------------------------------------------------------------

## The browser compiles a shader the first time something draws with it, freezing the game
## for 50 to 275 ms. So behind the title screen a tiny sample of every look the world can
## show is drawn in front of the camera for a few frames: each material once plain and once
## instanced, beside and away from a fire's light (both change the compiled shader), plus
## the see-through fade twins and every label size with every glyph it can print. The HUD
## is drawn under the title too, so its text is rasterised before the first click.
func _build_warmup() -> void:
	var looks := {}  # shader key -> [a mesh, a material with that key]
	for root: Node in [_world, _enemy_layer, _character]:
		for node in root.find_children("*", "GeometryInstance3D", true, false):
			var mesh: Mesh = null
			if node is MeshInstance3D:
				mesh = (node as MeshInstance3D).mesh
			elif node is MultiMeshInstance3D:
				mesh = (node as MultiMeshInstance3D).multimesh.mesh
			if mesh == null:
				continue
			for i in mesh.get_surface_count():
				var material: Material = (node as GeometryInstance3D).material_override
				if material == null and node is MeshInstance3D:
					material = (node as MeshInstance3D).get_active_material(i)
				elif material == null:
					material = mesh.surface_get_material(i)
				_add_look(looks, mesh, material)
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
	plane.size = Vector2(width, depth)
	plane.material = _flat_material(COLOR_GROUND)
	ground.mesh = plane
	ground.position = centre
	_world.add_child(ground)
	_add_box_body(ground, Vector3(width, 0.2, depth), Vector3(0, -0.1, 0))

	for r in world.regions:
		if r["name"] == WorldDef.REGION_OUTPOST:
			_add_floor(r["polygon"], COLOR_OUTPOST_FLOOR)
		elif r["name"] == WorldDef.REGION_INNER_RING:
			_add_ring_stakes(r["polygon"])

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
				_add_box_body(box, _box_size(s["min"], s["max"], s["height"]), Vector3.ZERO)
	_add_cliff_forest(world)

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
		if prop == null:
			# The outpost gate: a flat threshold block, clickable through a taller volume.
			var gate := _add_block(str(id), o["min"], o["max"], o["height"], COLOR_GATE)
			var click_size := _box_size(o["min"], o["max"], maxf(o["height"], 1.0))
			var gate_body := _add_box_body(gate, click_size, Vector3(0, (click_size.y - o["height"]) * 0.5, 0))
			gate_body.set_meta("object_id", id)
			var gate_label := _label3d(o["label"], 64)
			gate_label.position = Vector3(0, o["height"] * 0.5 + 1.0, 0)
			gate.add_child(gate_label)
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
			prop.add_child(label)
			if kind == WorldDef.KIND_RING_GATE:
				_ring_gates[id] = {"bars": prop.get_node("Bars"), "label": label}


## Stands a prop on the centre of a footprint.
func _place_prop(prop: Node3D, min_xz: Array, max_xz: Array) -> void:
	prop.position = Vector3((min_xz[0] + max_xz[0]) * 0.5, 0.0, (min_xz[1] + max_xz[1]) * 0.5)
	_world.add_child(prop)


## Red-topped stakes along the inner ring's edge: past them, ring one's enemies roam.
func _add_ring_stakes(polygon: Array) -> void:
	var points: Array[Vector3] = []
	for i in polygon.size():
		var a := Vector2(polygon[i][0], polygon[i][1])
		var b := Vector2(polygon[(i + 1) % polygon.size()][0], polygon[(i + 1) % polygon.size()][1])
		var steps := int(a.distance_to(b) / RING_STAKE_SPACING)
		for k in steps:
			var p := a.lerp(b, float(k) / steps)
			if sim.world.is_walkable(p):
				points.append(Vector3(p.x, 0.0, p.y))
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.06
	mesh.bottom_radius = 0.08
	mesh.height = 1.1
	mesh.radial_segments = 5
	mesh.material = _flat_material(COLOR_STAKE)
	_world.add_child(_multimesh(mesh, points, Vector3(0, 0.55, 0)))


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


## Flames lick: every fire's flame stretches and settles a little out of step with the others.
func _flicker() -> void:
	var i := 0
	for prop in _placed_fires + _fires.values():
		if prop == null:
			continue
		var flame := (prop as Node3D).get_node_or_null("Flame") as Node3D
		if flame != null:
			flame.scale = Vector3(1.0, 1.0 + 0.15 * sin(_clock * 9.0 + i * 1.7), 1.0)
		i += 1


# --- Enemies and loot -----------------------------------------------------------------

## One figure per placed enemy: a low box for a wolf, an upright capsule with a bow stave for
## an archer, a stalker or a frost-tipped staff for a witch, a bigger caped capsule carrying a
## sabre, a bow and a staff for the captain (the one in his hand follows his stance), a hulking
## pale capsule with an ice club for a troll, a click volume that becomes `attack`, a
## name-and-health label and a telegraph cue above it.
func _build_enemies(world: WorldDef) -> void:
	for id in world.enemies:
		var kind: String = world.enemies[id]["kind"]
		var colour: Color = COLOR_BY_ENEMY.get(kind, Color.MAGENTA)
		var root := Node3D.new()
		root.name = id
		_enemy_layer.add_child(root)
		var weapons := {}
		var height := 1.8
		if kind == "wolf":
			_add_part(root, _box_mesh(Vector3(0.5, 0.55, 1.1), colour), Vector3(0, 0.45, 0))
			_add_part(root, _box_mesh(Vector3(0.3, 0.3, 0.35), colour.darkened(0.3)), Vector3(0, 0.65, -0.65))
			_add_part(root, _box_mesh(Vector3(0.12, 0.12, 0.45), colour.lightened(0.2)), Vector3(0, 0.6, 0.65))
		else:
			var boss := kind == "bandit_captain"
			var troll := kind == "ice_troll"
			var size := 1.3 if boss else 1.6 if troll else 1.0
			height = 1.8 * size + 0.2
			var body := CapsuleMesh.new()
			body.radius = 0.32 * size
			body.height = 1.5 * size
			body.material = _flat_material(colour)
			_add_part(root, body, Vector3(0, 0.75 * size, 0))
			var hood := SphereMesh.new()
			hood.radius = 0.22 * size
			hood.height = 0.4 * size
			hood.radial_segments = 6
			hood.rings = 3
			hood.material = _flat_material(colour.darkened(0.35))
			_add_part(root, hood, Vector3(0, 1.45 * size, 0))
			if kind == "frost_witch":
				_add_part(root, _box_mesh(Vector3(0.06, 1.6, 0.06), Props.COLOR_WOOD), Vector3(0.42, 0.85, -0.2))
				_add_part(root, _box_mesh(Vector3(0.16, 0.16, 0.16), Props.COLOR_FROST), Vector3(0.42, 1.7, -0.2))
			elif troll:
				# A club of ice in its right hand instead of a bow.
				var club := _add_part(root, _box_mesh(Vector3(0.22, 1.0, 0.22), Props.COLOR_ICE), Vector3(0.62, 1.0, -0.3))
				club.rotation.x = -0.5
			else:
				var bow := _add_part(root, _box_mesh(Vector3(0.06, 1.1 * size, 0.06), Props.COLOR_WOOD), Vector3(-0.42 * size, 0.9 * size, -0.2))
				weapons["captain_bow"] = bow
			if boss:
				_add_part(root, _box_mesh(Vector3(0.9, 1.2, 0.06), Color(0.55, 0.08, 0.08)), Vector3(0, 1.05, 0.42))  # cape
				var sabre := _add_part(root, _box_mesh(Vector3(0.08, 0.9, 0.03), CharacterGear.TIER_COLORS[ItemTable.TIER_IRON]), Vector3(0.5, 1.0, -0.25))
				sabre.rotation.x = -0.4
				weapons["captain_sabre"] = sabre
				var staff := _add_part(root, _box_mesh(Vector3(0.07, 1.8, 0.07), Props.COLOR_FROST), Vector3(0.5, 1.0, -0.25))
				weapons["captain_staff"] = staff
		var click := _add_box_body(root, Vector3(1.1, height, 1.3), Vector3(0, height * 0.5, 0))
		click.set_meta("enemy_id", id)
		var label := _label3d("", 48)
		label.position = Vector3(0, height + 0.2, 0)
		root.add_child(label)
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
	var c := sim.combatant(id)
	(drawn["label"] as Label3D).text = "%s  %d / %d" % [CombatTable.enemy(e["kind"])["label"], c["health"], c["health_max"]]
	var weapons: Dictionary = drawn["weapons"]
	if weapons.size() > 1:
		for w in weapons:
			(weapons[w] as Node3D).visible = w == c["weapon"]
	var next: Dictionary = e["next"]
	var announced := CombatTable.is_attack(str(next.get("action", ""))) or CombatTable.is_stance(str(next.get("action", "")))
	if not alive or e["mode"] != Sim.MODE_ENGAGED or not announced:
		(drawn["cue"] as Label3D).visible = false


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
