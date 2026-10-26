## Board-only, not shipped: renders the great frost bear from the game's default camera, with the
## real game loop running, for its PR's look evidence. The boss test code's character stands
## beside it in its room, idle, its health topped up so it outlasts the shots.
##
##   godot --resolution 1280x720 --fixed-fps 30 -s tools/bear_shots.gd -- <out_dir>
##
## Writes bear_smash.png (it rears over the front mark of its smash), bear_stomp.png (over the
## ring of its stomp) and bear_wolves.png (below half health, its two wolves come in).
extends SceneTree

const H := preload("res://tests/sim_helpers.gd")
const RingCodes := preload("res://tools/ring_codes.gd")

const BOSS := "ring_one_dungeon_boss"
## A metre and a bit west of the bear's home, in its claws' reach, so the default camera sees it
## side on.
const SPOT := [71.8, 44.0]
const WAIT_FRAMES := 900
const SETTLE_FRAMES := 13

var _out_dir := ""
var _saved_game := PackedByteArray()
var _had_save := false
var _failed := false


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		printerr("usage: godot -s tools/bear_shots.gd -- <out_dir>")
		quit(2)
		return
	_out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(_out_dir)
	if FileAccess.file_exists("user://frostmark.save"):
		_had_save = true
		_saved_game = FileAccess.get_file_as_bytes("user://frostmark.save")
	_run.call_deferred()


func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	var main: Node = current_scene
	var fighter := RingCodes.boss_sim()
	fighter.command(SimVocab.SET_HINTS, {"on": false})
	H.place(fighter, SPOT)
	main._on_import(fighter.export_code())
	main.sim.command(SimVocab.SET_AUTO_RETALIATE, {"on": false})
	main._hud._banner_left = 0.0
	main._hud._banner_box.modulate.a = 0.0
	main._hud._saved_label.modulate.a = 0.0
	main._show_sim()
	root.get_viewport().warp_mouse(Vector2(8, 8))  # off the bear, so its name stays hidden
	await _until(main, func() -> bool: return _telling(main, "bear_smash"), "bear_smash")
	await _until(main, func() -> bool: return _telling(main, "bear_stomp"), "bear_stomp")
	H.patch_enemy(main.sim, BOSS, {"health": 290})
	await _until(main, func() -> bool:
		var add: Variant = main.sim.state["enemies"].get(BOSS + "_add_1")
		return add != null and add["mode"] == Sim.MODE_ENGAGED and _closed_in(add), "bear_wolves")
	if _had_save:
		var f := FileAccess.open("user://frostmark.save", FileAccess.WRITE)
		f.store_buffer(_saved_game)
		f.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://frostmark.save"))
	quit(1 if _failed else 0)


## Whether the bear has told `action` and it has not landed yet.
static func _telling(main: Node, action: String) -> bool:
	var next: Dictionary = main.sim.state["enemies"][BOSS]["next"]
	return next.get("action", "") == action and int(next.get("at", 0)) > int(main.sim.state["tick"])


## Whether an add has walked a few metres in from its entry.
static func _closed_in(add: Dictionary) -> bool:
	return Vector2(add["pos"][0], add["pos"][1]).distance_to(Vector2(SPOT[0], SPOT[1])) < 5.0


## Runs frames until `ready` holds, then takes the shot `name`.
func _until(main: Node, ready: Callable, name: String) -> void:
	for i in WAIT_FRAMES:
		await process_frame
		if int(main.sim.state["health"]) < 50:
			main.sim.state["health"] = Sim.HEALTH_MAX
		if ready.call():
			for j in SETTLE_FRAMES:
				await process_frame
			await RenderingServer.frame_post_draw
			var path := "%s/%s.png" % [_out_dir, name]
			root.get_viewport().get_texture().get_image().save_png(path)
			print("wrote " + path)
			return
	printerr("never got to %s in %d frames" % [name, WAIT_FRAMES])
	_failed = true
