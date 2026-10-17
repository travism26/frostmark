## The sound pass's data: every cue key the event mapping and the audio director can ask for
## resolves to a clip that exists, every shipped clip is used, the events a real walk and
## chop produce map only to known cues, and the sound settings persist.
extends "res://tests/run.gd".TestCase

const H := preload("res://tests/sim_helpers.gd")
const SimScript := preload("res://sim/sim.gd")
const Vocab := preload("res://sim/vocab.gd")

const SETTINGS_PATH := "user://test_audio_settings.cfg"


func test_every_cue_key_resolves_to_an_existing_clip() -> void:
	for key in AudioCues.all_keys():
		var paths := AudioCues.paths(key)
		assert_false(paths.is_empty(), "%s names at least one clip" % key)
		for p in paths:
			assert_true(ResourceLoader.exists(p), "%s: %s exists" % [key, p])
			assert_true(load(p) is AudioStreamOggVorbis, "%s: %s loads as Ogg Vorbis" % [key, p])


func test_every_shipped_clip_is_used() -> void:
	var used := {}
	for key in AudioCues.all_keys():
		for p in AudioCues.paths(key):
			used[p] = true
	for file in DirAccess.get_files_at(AudioCues.DIR):
		if file.ends_with(".ogg"):
			assert_true(used.has(AudioCues.DIR + file), "%s is referenced by a cue (prune it otherwise)" % file)


func test_every_event_kind_maps_only_to_known_cues() -> void:
	var known := AudioCues.all_keys()
	var samples: Array[Dictionary] = []
	for kind in _event_kinds():
		samples.append({"kind": kind})
		for style in [CombatTable.STYLE_MELEE, CombatTable.STYLE_RANGED]:
			for target in [Vocab.PLAYER, "wolf_1"]:
				samples.append({"kind": kind, "style": style, "target": target, "heavy": true})
		for skill in SkillTable.NAMES:
			samples.append({"kind": kind, "skill": skill})
	for e in samples:
		for key in AudioCues.event_cues(e):
			assert_true(known.has(key), "%s maps to known cue %s" % [e["kind"], key])


func test_the_combat_and_milestone_events_each_sound() -> void:
	var cases := {
		Vocab.EV_ENEMY_TELEGRAPHED: AudioCues.CUE_MELEE,
		Vocab.EV_ENEMY_STANCE: AudioCues.CUE_MELEE,
		Vocab.EV_ENEMY_DIED: AudioCues.FALL,
		Vocab.EV_DIED: AudioCues.STING_DEATH,
		Vocab.EV_BANKED: AudioCues.STING_BANK,
		Vocab.EV_COOKED: AudioCues.COOK,
		Vocab.EV_CRAFTED: AudioCues.SMITH,
	}
	for kind in cases:
		var cues := AudioCues.event_cues({"kind": kind, "style": CombatTable.STYLE_MELEE})
		assert_true(cues.has(cases[kind]), "%s sounds %s" % [kind, cases[kind]])
	var shot := AudioCues.event_cues({"kind": Vocab.EV_HIT, "style": CombatTable.STYLE_RANGED, "target": Vocab.PLAYER})
	assert_eq(shot, [AudioCues.BOW, AudioCues.HIT_TAKEN], "an arrow into the player: the bow, then the blow")
	var ranged_cue := AudioCues.event_cues({"kind": Vocab.EV_ENEMY_TELEGRAPHED, "style": CombatTable.STYLE_RANGED})
	assert_eq(ranged_cue, [AudioCues.CUE_RANGED], "a ranged telegraph has its own cue")
	var fish := AudioCues.event_cues({"kind": Vocab.EV_GATHERED, "skill": SkillTable.FISHING})
	assert_eq(fish, [AudioCues.CATCH], "a caught fish splashes")


func test_the_levels_strikes_loops_and_beds_resolve() -> void:
	var known := AudioCues.all_keys()
	for key in AudioCues.GAIN:
		assert_true(known.has(key), "the director's level for %s is a known cue" % key)
	for key in AudioCues.GATHER_STRIKE.values() + AudioCues.GATHER_SUCCESS.values() + AudioCues.CUE_BY_STYLE.values():
		assert_true(known.has(key), "%s is a known cue" % key)
	for key in AudioCues.LOOPS:
		assert_true(known.has(key), "loop %s is a known cue" % key)
	for r in WorldDef.outpost().regions:
		if r["name"] != WorldDef.REGION_RING_TWO:
			assert_true(AudioCues.BEDS.has(r["name"]), "%s has a wind and snow bed" % r["name"])


func test_a_real_walk_out_and_chop_maps_only_to_known_cues() -> void:
	var sim := SimScript.new()
	sim.command(Vocab.GATHER, {"object_id": "tree_3"})
	var events := H.run_until_idle(sim, 300)
	sim.command(Vocab.CROSS_GATE, {})
	events.append_array(H.run_until_idle(sim, 100))
	var known := AudioCues.all_keys()
	var heard := {}
	for e in events:
		for key in AudioCues.event_cues(e):
			assert_true(known.has(key), "%s maps to known cue %s" % [e["kind"], key])
			heard[key] = true
	assert_true(heard.has(AudioCues.STING_BANK), "walking the logs home sounds the banking stinger")


func test_settings_persist_volume_music_and_mute() -> void:
	DirAccess.remove_absolute(SETTINGS_PATH)
	var fresh := AudioSettings.load_from(SETTINGS_PATH)
	assert_almost_eq(fresh.volume, AudioSettings.DEFAULT_VOLUME, 0.0001, "no file: the default volume")
	assert_almost_eq(fresh.music, AudioSettings.DEFAULT_MUSIC, 0.0001, "no file: the default music volume")
	assert_false(fresh.muted, "no file: not muted")
	assert_false(fresh.reduced_motion, "no file: full motion")
	var settings := AudioSettings.new()
	settings.volume = 0.35
	settings.music = 0.1
	settings.muted = true
	settings.reduced_motion = true
	assert_true(settings.save_to(SETTINGS_PATH), "the settings are written")
	var back := AudioSettings.load_from(SETTINGS_PATH)
	assert_almost_eq(back.volume, 0.35, 0.0001, "volume persists")
	assert_almost_eq(back.music, 0.1, 0.0001, "music volume persists")
	assert_true(back.muted, "mute persists")
	assert_true(back.reduced_motion, "reduced motion persists")
	DirAccess.remove_absolute(SETTINGS_PATH)


func test_unreadable_settings_fall_back_and_clamp() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value(AudioSettings.SECTION, "volume", 7.0)
	cfg.set_value(AudioSettings.SECTION, "music", -2.0)
	cfg.save(SETTINGS_PATH)
	var settings := AudioSettings.load_from(SETTINGS_PATH)
	assert_almost_eq(settings.volume, 1.0, 0.0001, "volume is clamped to 1")
	assert_almost_eq(settings.music, 0.0, 0.0001, "music is clamped to 0")
	assert_false(settings.muted, "a missing mute is not muted")
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	f.store_string("not a config file [[[")
	f.close()
	assert_almost_eq(AudioSettings.load_from(SETTINGS_PATH).volume, AudioSettings.DEFAULT_VOLUME, 0.0001, "garbage: the defaults")
	DirAccess.remove_absolute(SETTINGS_PATH)


## Every event kind SimVocab names.
static func _event_kinds() -> Array[String]:
	var out: Array[String] = []
	var vocab: Script = Vocab
	var constants := vocab.get_script_constant_map()
	for name: String in constants:
		if name.begins_with("EV_"):
			out.append(constants[name])
	return out
