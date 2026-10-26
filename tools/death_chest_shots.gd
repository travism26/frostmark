## Board-only, not shipped: renders the ring-one dungeon's death chest from the game's default
## camera, with the real game loop running, for the death chest PR's look evidence. A new
## character carrying a haul stands just inside the dungeon's mouth by the chest, dies of the
## cold there, and is set back beside the chest that now holds what it lost.
##
##   godot --resolution 1280x720 --fixed-fps 30 -s tools/death_chest_shots.gd -- <out_dir>
##
## Writes chest_empty.png (the chest unlit), death_screen.png (the death screen naming the
## chest) and chest_full.png (the chest lit), and a `_label` shot of each chest with its label
## up, as the mouse resting on it shows it, listing what it holds.
extends SceneTree

const H := preload("res://tests/sim_helpers.gd")

const CHEST := "ring_one_dungeon_chest"
## Just inside the mouth, a few metres north-east of the chest, out of the fire's reach.
const SPOT := [71.5, -49.5]
const HAUL := [
	{"item": "iron_sword", "count": 1}, {"item": "arrows", "count": 30}, {"item": "troll_hide", "count": 1},
	{"item": "bronze_bar", "count": 2}, {"item": "copper_ore", "count": 5}, {"item": "cooked_fish", "count": 2},
	{"item": "tin_ore", "count": 4}, {"item": "wolf_pelt", "count": 1}, {"item": "logs", "count": 3},
]
const SETTLE_FRAMES := 60

var _out_dir := ""
var _saved_game := PackedByteArray()
var _had_save := false


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		printerr("usage: godot -s tools/death_chest_shots.gd -- <out_dir>")
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
	var sim := Sim.new()
	H.place(sim, SPOT)
	H.arm(sim, "wooden_club", HAUL)
	main._on_import(sim.export_code())
	_quiet(main)
	await _settle()
	await _shot("chest_empty")
	_show_label(main)
	await _shot("chest_empty_label")

	H.patch(main.sim, {"warmth": 0, "health": 1})
	for i in 120:
		await process_frame
		if main._death_screen.visible:
			break
	await _settle()
	await _shot("death_screen")

	var after := Sim.new()
	after.restore(main.sim.snapshot())
	H.place(after, SPOT)
	main._on_import(after.export_code())
	_quiet(main)
	(main._death_chests[CHEST]["label"] as Label3D).visible = false
	await _settle()
	await _shot("chest_full")
	_show_label(main)
	await _shot("chest_full_label")

	if _had_save:
		var f := FileAccess.open("user://frostmark.save", FileAccess.WRITE)
		f.store_buffer(_saved_game)
		f.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://frostmark.save"))
	quit(0)


func _quiet(main: Node) -> void:
	main._hud._banner_left = 0.0
	main._hud._banner_box.modulate.a = 0.0
	main._hud._saved_label.modulate.a = 0.0


## The chest's label, as the mouse resting on it would show it.
func _show_label(main: Node) -> void:
	(main._death_chests[CHEST]["label"] as Label3D).visible = true


func _settle() -> void:
	for i in SETTLE_FRAMES:
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_out_dir, name])
	print("wrote %s/%s.png" % [_out_dir, name])
