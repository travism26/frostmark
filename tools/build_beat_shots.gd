## Board-only, not shipped: renders the build beat from the real scene, frame by frame, for
## the PR's capture. A character stands in the yard with the logs for the stash shelves in
## the stash and builds them; then builds them again and clicks the ground half a second in,
## to show the click ending the beat.
##
##   godot --resolution 960x540 --fixed-fps 60 -s tools/build_beat_shots.gd -- <out_dir>
##
## Writes beat_NNN.png for the whole beat and cancel_NNN.png for the cancelled one, one per
## sixtieth of a second of game time however slowly they save (`--fixed-fps`). Join them with
## ffmpeg for a gif. Frame rates are measured in the browser, not here.
extends SceneTree

const H := preload("res://tests/sim_helpers.gd")

const SETTLE_FRAMES := 40
const BEAT_FRAMES := 120  # two seconds at 60 fps: the beat, and the camera back on the player
const CANCEL_AT := 30
const OUTPOST_SPOT := [-4.5, -1.0]

var _out_dir := ""
var _saved_game := PackedByteArray()
var _had_save := false


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		printerr("usage: godot -s tools/build_beat_shots.gd -- <out_dir>")
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
	for run in ["beat", "cancel"]:
		main._on_import(_builder(main.sim.world).export_code())
		_quiet(main)
		main._camera_rig.distance = 22.0
		main._camera_rig.yaw = 0.0
		for i in SETTLE_FRAMES:
			await process_frame
		main._on_hud_command(SimVocab.BUILD, {"upgrade": "stash_shelves"})
		for i in BEAT_FRAMES:
			if run == "cancel" and i == CANCEL_AT:
				main._pending_click = Vector2(root.get_visible_rect().size.x * 0.7, root.get_visible_rect().size.y * 0.6)
			await _shot("%s/%s_%03d.png" % [_out_dir, run, i])
		print("wrote %d %s frames" % [BEAT_FRAMES, run])
	if _had_save:
		var f := FileAccess.open("user://frostmark.save", FileAccess.WRITE)
		f.store_buffer(_saved_game)
		f.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://frostmark.save"))
	quit(0)


## Drops the welcome banner and the Saved flash an import raises, so the beat's banner shows.
static func _quiet(main: Node) -> void:
	main._hud._banner_left = 0.0
	main._hud._banner_box.modulate.a = 0.0
	main._hud._saved_label.modulate.a = 0.0


func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(path)


## A new character in the yard, east of the stash, with the shelves' logs in the stash.
static func _builder(world: WorldDef) -> Sim:
	var sim := Sim.new(world)
	sim.command(SimVocab.NEW_CHARACTER, {"previous": ""})
	sim.command(SimVocab.SET_HINTS, {"on": false})
	var snap := sim.snapshot()
	snap["stash"]["slots"][0] = {"item": "logs", "count": 20}
	sim.restore(snap)
	H.place(sim, OUTPOST_SPOT)
	return sim
