## Board-only, not shipped: renders the real scene with the HUD hidden at any list of spots,
## for checking dressing and landmarks without a browser build.
##
##   godot --resolution 1280x720 -s tools/spot_shots.gd -- <out_dir> <name>=<x>,<z>[,<distance>] ...
##   e.g. godot --resolution 1280x720 -s tools/spot_shots.gd -- /tmp/shots wreck=6.5,45.5 keep=0.5,95,30
extends SceneTree

const H := preload("res://tests/sim_helpers.gd")
const SETTLE_FRAMES := 60

var _out_dir := ""
var _spots: Array = []
var _saved_game := PackedByteArray()
var _had_save := false


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		printerr("usage: godot -s tools/spot_shots.gd -- <out_dir> <name>=<x>,<z>[,<distance>] ...")
		quit(2)
		return
	_out_dir = args[0]
	for a in args.slice(1):
		var parts: PackedStringArray = a.split("=")
		var nums: PackedStringArray = parts[1].split(",")
		_spots.append({"name": parts[0], "at": [float(nums[0]), float(nums[1])], "distance": float(nums[2]) if nums.size() > 2 else 24.0})
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
	var world: WorldDef = main.sim.world
	main.get_node("HUD").visible = false
	for spot in _spots:
		var sim := Sim.new(world)
		sim.command(SimVocab.NEW_CHARACTER, {"previous": ""})
		H.place(sim, spot["at"])
		main._on_import(sim.export_code())
		main.get_node("HUD").visible = false
		main._camera_rig.distance = spot["distance"]
		main._camera_rig.yaw = 0.0
		for i in SETTLE_FRAMES:
			await process_frame
		await RenderingServer.frame_post_draw
		var image := root.get_viewport().get_texture().get_image()
		var path := "%s/%s.png" % [_out_dir, spot["name"]]
		image.save_png(path)
		print("wrote " + path)
	if _had_save:
		var f := FileAccess.open("user://frostmark.save", FileAccess.WRITE)
		f.store_buffer(_saved_game)
		f.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://frostmark.save"))
	quit(0)
