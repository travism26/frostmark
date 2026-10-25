## Board-only, not shipped: renders the Snowveil archer's bluff from the game's default camera,
## with the real game loop running, for the archer PR's look evidence. A new character stands in
## the open beside the lone archer by the west cliff in ring three and does nothing: the first shot is the archer's
## second piercing shot told (the bluff), the second is the tick it turns out to be a feint.
##
##   godot --resolution 1280x720 -s tools/snowveil_shots.gd -- <out_dir>
##
## Writes snowveil_told.png (the ring and "Piercing shot" over the archer, a tick before the
## blow) and snowveil_feint.png (the same shot shrunk away, the word over it "Feint"), then
## snowveil_real.png, the real piercing shot told on the feint tick.
extends SceneTree

const H := preload("res://tests/sim_helpers.gd")

const SPOT := [-54.5, 160.5]
const ARCHER := "veil_archer_3"
const WAIT_FRAMES := 3000
const SETTLE_FRAMES := 12

var _out_dir := ""
var _saved_game := PackedByteArray()
var _had_save := false


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		printerr("usage: godot -s tools/snowveil_shots.gd -- <out_dir>")
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
	main._on_import(_fighter(main.sim.world).export_code())
	main._hud._banner_left = 0.0
	main._hud._banner_box.modulate.a = 0.0
	main._hud._saved_label.modulate.a = 0.0
	var drawn: Dictionary = main._enemies[ARCHER]
	var phase := 0
	for i in WAIT_FRAMES:
		await process_frame
		var tick := int(main.sim.state["tick"])
		var raw: String = str(main.sim.state["enemies"][ARCHER].get("next", {}).get("action", ""))
		if phase == 0 and raw == "feint_pierce" and (drawn["cue"] as Label3D).visible:
			await _settle()
			await _shot("snowveil_told")
			phase = 1
		elif phase == 1 and int(drawn["feint_tick"]) == tick and tick > 0:
			await _settle()
			await _shot("snowveil_feint")
			phase = 2
		elif phase == 2 and raw == "piercing_shot" and (drawn["cue"] as Label3D).visible:
			await _settle()
			await _shot("snowveil_real")
			phase = 3
			break
	if phase < 3:
		printerr("only reached phase %d in %d frames" % [phase, WAIT_FRAMES])
	if _had_save:
		var f := FileAccess.open("user://frostmark.save", FileAccess.WRITE)
		f.store_buffer(_saved_game)
		f.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://frostmark.save"))
	quit(0 if phase == 3 else 1)


func _settle() -> void:
	for i in SETTLE_FRAMES:
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var path := "%s/%s.png" % [_out_dir, name]
	root.get_viewport().get_texture().get_image().save_png(path)
	print("wrote " + path)


## A character in steel with a sword out, standing in the open beside the archer and idle.
static func _fighter(world: WorldDef) -> Sim:
	var sim := Sim.new(world)
	sim.command(SimVocab.NEW_CHARACTER, {"previous": ""})
	sim.command(SimVocab.SET_HINTS, {"on": false})
	sim.command(SimVocab.SET_AUTO_RETALIATE, {"on": false})
	H.arm(sim, "steel_sword", [{"item": "cooked_fish", "count": 5}])
	var snap := sim.snapshot()
	snap["inventory"]["equipment"].merge({"helm": "steel_helm", "body": "steel_body", "legs": "steel_legs"}, true)
	snap["player"]["region"] = WorldDef.REGION_RING_THREE
	sim.restore(snap)
	H.place(sim, SPOT)
	return sim
