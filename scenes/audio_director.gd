## Plays Frostmark's sound from the simulation's events: one-shot cues through AudioCues,
## footsteps from the character's drawn movement, the strikes of a gathering skill while it
## works, a wind-and-snow bed whose strength follows the ring, a crackle at every fire, and
## a quiet music bed inside the walls that gives way to a tenser one outside.
##
## Nothing here decides a rule: it only listens. Browsers keep audio silent until the first
## user gesture, so nothing starts before the first click or key press.
extends Node

const VOICES := 10
## Metres walked between two footsteps.
const STRIDE := 1.3
## Seconds between the strikes of an axe or a pickaxe while gathering.
const STRIKE_SECONDS := 1.0
const BED_FADE := 2.0
const MUSIC_FADE := 3.0
const MUSIC_DB := -4.0
const SILENT := AudioCues.SILENT_DB
## A heavy telegraph is the same cue, lower and louder, so the big blow is heard coming.
const HEAVY_PITCH := 0.8
const HEAVY_GAIN := 4.0
## A cue cut short (a feint's) fades out over this long rather than clicking off.
const CUT_FADE := 0.05

const SNOW_PITCH := 1.8

## The fire's crackle is heard within about this many metres.
const FIRE_REACH := 18.0

var sim: Sim
var settings := AudioSettings.new()
var _started := false
var _streams := {}  # clip path -> AudioStream, loaded once
var _voices: Array[AudioStreamPlayer] = []
var _next_voice := 0
var _cuts := {}  # voice -> the tween cutting its cue short
var _wind: AudioStreamPlayer
var _snow: AudioStreamPlayer
var _music := {}  # music cue key -> its player
var _music_key := ""
var _bed_fade: Tween
var _music_fades := {}  # music cue key -> the fade under way on its player
var _region := WorldDef.REGION_OUTPOST
var _listener: AudioListener3D
var _camera: Camera3D
var _layer: Node3D  # the listener and the fire crackles
var _fires := {}  # fire id ("fire" for the outpost's) -> its crackle
var _last_pos: Variant = null  # the character's drawn position last frame
var _walked := 0.0
var _strike := ""  # the cue key of the gathering strike under way, "" when idle
var _strike_left := 0.0


## `camera` orients the listener; `layer` is where the listener and the fire crackles sit
## in the world.
func setup(camera: Camera3D, layer: Node3D) -> void:
	_camera = camera
	_layer = layer
	settings = AudioSettings.load_from()
	settings.apply()
	for i in VOICES:
		var voice := AudioStreamPlayer.new()
		voice.bus = AudioSettings.BUS_EFFECTS
		add_child(voice)
		_voices.append(voice)
	_wind = _loop_player(AudioCues.WIND, AudioSettings.BUS_EFFECTS)
	_snow = _loop_player(AudioCues.WIND, AudioSettings.BUS_EFFECTS)
	_snow.pitch_scale = SNOW_PITCH
	for key in [AudioCues.MUSIC_OUTPOST, AudioCues.MUSIC_OUTSIDE]:
		_music[key] = _loop_player(key, AudioSettings.BUS_MUSIC)
	_listener = AudioListener3D.new()
	_layer.add_child(_listener)
	_listener.make_current()


## Starts the beds, the music and the fires. Called on the first click or key press.
func start() -> void:
	if _started:
		return
	_started = true
	settings.apply()
	for player: AudioStreamPlayer in [_wind, _snow]:
		player.volume_db = SILENT
		player.play()
	_set_beds(BED_FADE)
	for id in _fires:
		(_fires[id] as AudioStreamPlayer3D).play()


func _input(event: InputEvent) -> void:
	if not _started and (event is InputEventMouseButton or event is InputEventKey) and event.is_pressed():
		start()


func _process(delta: float) -> void:
	if _strike == "" or not _started:
		return
	_strike_left -= delta
	if _strike_left <= 0.0:
		play(_strike)
		_strike_left = STRIKE_SECONDS * randf_range(0.9, 1.1)


## Sets the settings, applies them and keeps them for the next visit.
func change_settings(volume: float, music: float, muted: bool) -> void:
	settings.volume = volume
	settings.music = music
	settings.muted = muted
	settings.apply()
	settings.save_to()


# --- From the game ---------------------------------------------------------------------

## Plays what a batch of events sounds like.
func handle(events: Array[Dictionary]) -> void:
	for e in events:
		for key in AudioCues.event_cues(e):
			var heavy: bool = e.get("heavy", false)
			play(key, HEAVY_GAIN if heavy else 0.0, HEAVY_PITCH if heavy else 1.0, AudioCues.cut_seconds(e))
		match e["kind"]:
			SimVocab.EV_INTERACTED:
				if e["action"] == SimVocab.ACTION_GATHER:
					_start_gathering(e["object_id"])
			SimVocab.EV_PATH_SET, SimVocab.EV_ACTIVITY_STOPPED, SimVocab.EV_DIED:
				_strike = ""
			SimVocab.EV_MISSED:
				# A loosed arrow that finds no one is still heard leaving the bow.
				if sim.combatant(e["attacker"]).get("style", "") == CombatTable.STYLE_RANGED:
					play(AudioCues.BOW)
			SimVocab.EV_REGION_CHANGED:
				set_region(e["to"])
			SimVocab.EV_FIRE_LIT:
				add_fire(e["fire_id"], Vector3(float(e["pos"][0]), 0.0, float(e["pos"][1])))
			SimVocab.EV_FIRE_OUT:
				remove_fire(e["fire_id"])


## Called every frame with where the character is drawn: footsteps by distance walked, and
## the listener rides with the character, turned with the camera.
func follow(pos: Vector3) -> void:
	_listener.global_position = pos
	_listener.global_rotation = Vector3(0.0, _camera.global_rotation.y, 0.0)
	if _last_pos != null:
		var step := (pos - (_last_pos as Vector3)).length()
		if step > 0.0 and step < 2.0:  # a longer jump is a respawn, not a walk
			_walked += step
			if _walked >= STRIDE:
				_walked -= STRIDE
				play(AudioCues.STEP, 0.0, randf_range(0.9, 1.1))
		elif step == 0.0:
			_walked = STRIDE * 0.6  # the first step of the next walk comes quickly
	_last_pos = pos


## The wind, the snow and the music for a region, faded in over a moment.
func set_region(region: String) -> void:
	_region = region
	if _started:
		_set_beds(BED_FADE)


## Matches the fire crackles to a fresh state (a new, continued or imported character).
func sync_fires(outpost_fire: Vector3, fires: Dictionary) -> void:
	for id in _fires.keys():
		remove_fire(id)
	add_fire("fire", outpost_fire)
	for id in fires:
		add_fire(id, Vector3(float(fires[id]["pos"][0]), 0.0, float(fires[id]["pos"][1])))


func add_fire(id: String, pos: Vector3) -> void:
	remove_fire(id)
	var crackle := AudioStreamPlayer3D.new()
	crackle.stream = _stream(AudioCues.FIRE)
	crackle.bus = AudioSettings.BUS_EFFECTS
	crackle.unit_size = 3.0
	crackle.max_distance = FIRE_REACH
	crackle.volume_db = -2.0
	crackle.position = pos + Vector3(0, 0.5, 0)
	_layer.add_child(crackle)
	if _started:
		crackle.play()
	_fires[id] = crackle


func remove_fire(id: String) -> void:
	if _fires.has(id):
		(_fires[id] as Node).queue_free()
		_fires.erase(id)


## Plays one clip of a cue on the next free voice, `gain` dB over its level, cut off after
## `cut` seconds when that is above zero.
func play(key: String, gain := 0.0, pitch := 1.0, cut := 0.0) -> void:
	if not _started:
		return
	var voice := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % _voices.size()
	if _cuts.has(voice):
		(_cuts[voice] as Tween).kill()
		_cuts.erase(voice)
	voice.stream = _stream(key)
	voice.volume_db = float(AudioCues.GAIN.get(key, 0.0)) + gain
	voice.pitch_scale = pitch
	voice.play()
	if cut > 0.0:
		var fade := create_tween()
		fade.tween_property(voice, "volume_db", SILENT, CUT_FADE).set_delay(cut)
		fade.tween_callback(voice.stop)
		_cuts[voice] = fade


# --- Inside ----------------------------------------------------------------------------

func _start_gathering(object_id: String) -> void:
	var skill: String = WorldDef.NODE_KINDS[sim.world.objects[object_id]["kind"]]["skill"]
	if skill == SkillTable.FISHING:
		play(AudioCues.CAST)
	_strike = AudioCues.GATHER_STRIKE.get(skill, "")
	_strike_left = 0.3


func _set_beds(fade: float) -> void:
	var bed: Dictionary = AudioCues.BEDS.get(_region, AudioCues.BEDS[WorldDef.REGION_INNER_RING])
	if _bed_fade != null:
		_bed_fade.kill()
	_bed_fade = create_tween().set_parallel()
	_bed_fade.tween_property(_wind, "volume_db", bed["wind"], fade)
	_bed_fade.tween_property(_wind, "pitch_scale", bed["pitch"], fade)
	_bed_fade.tween_property(_snow, "volume_db", bed["snow"], fade)
	var key := AudioCues.MUSIC_OUTPOST if _region == WorldDef.REGION_OUTPOST else AudioCues.MUSIC_OUTSIDE
	if key == _music_key:
		return
	_music_key = key
	for k in _music:
		var player: AudioStreamPlayer = _music[k]
		if k != key and not player.playing:
			continue
		if _music_fades.has(k):
			(_music_fades[k] as Tween).kill()  # a fade still running the other way
		var fade_music := create_tween()
		_music_fades[k] = fade_music
		if k == key:
			if not player.playing:
				player.volume_db = SILENT
				player.play()
			fade_music.tween_property(player, "volume_db", MUSIC_DB, MUSIC_FADE)
		else:
			fade_music.tween_property(player, "volume_db", SILENT, MUSIC_FADE)
			fade_music.tween_callback(player.stop)


## A looping player for a bed or the music, made silent and stopped.
func _loop_player(key: String, bus: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = _stream(key)
	player.bus = bus
	player.volume_db = SILENT
	add_child(player)
	return player


## One of a cue's clips at random, loaded once and looped when the cue is a loop.
func _stream(key: String) -> AudioStream:
	var options := AudioCues.paths(key)
	var clip: String = options[randi() % options.size()]
	if not _streams.has(clip):
		var stream := load(clip) as AudioStream
		if key in AudioCues.LOOPS and stream is AudioStreamOggVorbis:
			(stream as AudioStreamOggVorbis).loop = true
		_streams[clip] = stream
	return _streams[clip]
