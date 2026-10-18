## Board-only, not shipped: renders the side panel, orbs and a telegraph ring from the real
## scene with a stocked character, as the UI board did for its frame styles.
##
##   godot --resolution 1280x720 -s tools/ui_shots.gd -- <out_dir>
##
## Writes ui_<tab>.png for every tab and ui_fight.png with a wolf's telegraph ring up.
extends SceneTree

const H := preload("res://tests/sim_helpers.gd")

const SETTLE_FRAMES := 40
const FIGHT_FRAMES := 900
const OUTPOST_SPOT := [0.5, 4.5]
const FIGHT_SPOT := [-5.0, 28.5]  # beside wolf_1's home in ring one

var _out_dir := ""
var _saved_game := PackedByteArray()
var _had_save := false


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		printerr("usage: godot -s tools/ui_shots.gd -- <out_dir>")
		quit(2)
		return
	_out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(_out_dir)
	if FileAccess.file_exists("user://frostmark.save"):
		_had_save = true
		_saved_game = FileAccess.get_file_as_bytes("user://frostmark.save")
	_run.call_deferred()


func _run() -> void:
	for style in ["ui"]:
		change_scene_to_file("res://scenes/main.tscn")
		await process_frame
		await process_frame
		var main: Node = current_scene
		main._on_import(_stocked(main.sim.world).export_code())
		_quiet(main)
		main._camera_rig.distance = 22.0
		main._camera_rig.yaw = 0.0
		for i in SETTLE_FRAMES:
			await process_frame
		for tab in IconTable.TABS:
			main._hud.show_tab(tab)
			for i in 3:
				await process_frame
			await _shot("%s/%s_%s.png" % [_out_dir, style, tab.trim_prefix("tab_")])
		main._hud.show_tab(IconTable.TAB_PACK)
		# A fight: stand by a wolf with a sword out and wait for its telegraph.
		main._on_import(_fighter(main.sim.world).export_code())
		_quiet(main)
		main._camera_rig.distance = 16.0
		var drawn: Dictionary = main._enemies["wolf_1"]
		for i in FIGHT_FRAMES:
			await process_frame
			if (drawn["cue"] as Label3D).visible:
				break
		for i in 4:
			await process_frame
		await _shot("%s/%s_fight.png" % [_out_dir, style])
	if _had_save:
		var f := FileAccess.open("user://frostmark.save", FileAccess.WRITE)
		f.store_buffer(_saved_game)
		f.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://frostmark.save"))
	quit(0)


## Drops the welcome banner and the Saved flash an import raises, so the shot is the HUD.
static func _quiet(main: Node) -> void:
	main._hud._banner_left = 0.0
	main._hud._banner_box.modulate.a = 0.0
	main._hud._saved_label.modulate.a = 0.0


func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(path)
	print("wrote " + path)


## A mid-game character in the outpost yard: bronze gear, a mixed pack, some levels, cold.
static func _stocked(world: WorldDef) -> Sim:
	var sim := Sim.new(world)
	sim.command(SimVocab.NEW_CHARACTER, {"previous": ""})
	sim.command(SimVocab.SET_HINTS, {"on": false})
	H.arm(sim, "bronze_sword", [
		{"item": "logs", "count": 7}, {"item": "copper_ore", "count": 3}, {"item": "iron_ore", "count": 2},
		{"item": "cooked_fish", "count": 4}, {"item": "raw_trout", "count": 2}, {"item": "wolf_pelt", "count": 2},
		{"item": "bronze_bar", "count": 3}, {"item": "arrows", "count": 40}, {"item": "wooden_bow", "count": 1},
		{"item": "ice_crystal", "count": 2},
	])
	var snap := sim.snapshot()
	snap["inventory"]["equipment"]["body"] = "bronze_body"
	snap["inventory"]["equipment"]["tool"] = "bronze_pickaxe"
	snap["warmth"] = int(Sim.WARMTH_MAX * 0.62)
	snap["health"] = int(Sim.HEALTH_MAX * 0.71)
	var levels := {"woodcutting": 7, "mining": 5, "fishing": 4, "cooking": 6, "smithing": 5, "melee": 8, "ranged": 3, "magic": 1}
	for name in levels:
		var level: int = levels[name]
		snap["skills"][name] = {"xp": SkillTable.xp_for_level(level) + SkillTable.XP_STEP * level / 2, "level": level}
	snap["stash"]["slots"][0] = {"item": "logs", "count": 10}
	snap["stash"]["slots"][1] = {"item": "bronze_bar", "count": 4}
	snap["upgrades"] = ["stash_shelves", "forge"]
	sim.restore(snap)
	H.place(sim, OUTPOST_SPOT)
	return sim


## The same character beside a wolf, attacking it.
static func _fighter(world: WorldDef) -> Sim:
	var sim := _stocked(world)
	H.place(sim, FIGHT_SPOT)
	sim.command(SimVocab.ATTACK, {"enemy_id": "wolf_1"})
	return sim
