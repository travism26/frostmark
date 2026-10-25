## Board-only, not shipped: renders the Aurora seer's answers from the game's default camera, with
## the real game loop running, for the seer PR's look evidence. A new character in steel stands 3 m
## from the seer in the south of ring three and does nothing but swap weapons.
##
##   godot --resolution 1280x720 -s tools/seer_shots.gd -- <out_dir>
##
## Writes seer_staff.png (the seer holding its staff, a bolt told), seer_blade.png (the blade it
## drew on its own cycle), a `_close` shot of each from a nearer camera, seer_conjures.png (a bow
## turned on it: "Conjures a blade" over its head in the melee colour, the blade in its hand) and
## seer_raises.png (a staff turned on the blade it drew on its own: "Raises its staff" in the
## magic colour, the staff back in its hand).
extends SceneTree

const H := preload("res://tests/sim_helpers.gd")

const SPOT := [30.5, 169.5]
const SEER := "seer_1"
const WAIT_FRAMES := 3000
const SETTLE_FRAMES := 12

var _out_dir := ""
var _saved_game := PackedByteArray()
var _had_save := false
var _failed := false


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		printerr("usage: godot -s tools/seer_shots.gd -- <out_dir>")
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
	# A bow turned on the seer while it holds the staff: answered on its first declaration.
	main._on_import(_fighter(main.sim.world, "steel_bow").export_code())
	_quiet(main)
	await _until(main, "conjure_blade", "seer_conjures")
	# A sword in hand: the seer works through its cycle and draws the blade on its own; a staff turned on
	# that blade is answered by raising its staff.
	main._on_import(_fighter(main.sim.world, "steel_sword").export_code())
	_quiet(main)
	await _until(main, "aurora_bolt", "seer_staff", true)
	await _until(main, "conjure_blade", "seer_blade", true)
	_swap_to(main, "steel_staff")
	await _until(main, "raise_aurora", "seer_raises")
	print("answered at tick ", main.sim.state["enemies"][SEER]["answered_tick"])
	if _had_save:
		var f := FileAccess.open("user://frostmark.save", FileAccess.WRITE)
		f.store_buffer(_saved_game)
		f.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://frostmark.save"))
	quit(1 if _failed else 0)


func _quiet(main: Node) -> void:
	main.sim.command(SimVocab.SET_AUTO_RETALIATE, {"on": false})
	main._hud._banner_left = 0.0
	main._hud._banner_box.modulate.a = 0.0
	main._hud._saved_label.modulate.a = 0.0


## Runs frames until the seer has `action` declared and its cue is up, then takes the shot `name`
## ("" for none), and with `close_up` a second one, `name` + "_close", from a camera brought in to
## show the weapon in its hand.
func _until(main: Node, action: String, name: String, close_up := false) -> void:
	var drawn: Dictionary = main._enemies[SEER]
	for i in WAIT_FRAMES:
		await process_frame
		var raw: String = str(main.sim.state["enemies"][SEER].get("next", {}).get("action", ""))
		if raw == action and (drawn["cue"] as Label3D).visible:
			if name != "":
				for j in SETTLE_FRAMES:
					await process_frame
				await _shot(name)
				if close_up:
					var rig: Node = main._camera_rig
					var far: float = rig.distance
					rig.distance = 11.0
					for j in SETTLE_FRAMES:
						await process_frame
					await _shot(name + "_close")
					rig.distance = far
			return
	printerr("never saw %s in %d frames" % [action, WAIT_FRAMES])
	_failed = true


func _swap_to(main: Node, item: String) -> void:
	var pack: Array = main.sim.state["inventory"]["pack"]
	for i in pack.size():
		if pack[i] != null and pack[i]["item"] == item:
			main.sim.command(SimVocab.EQUIP, {"index": i})
			return


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var path := "%s/%s.png" % [_out_dir, name]
	root.get_viewport().get_texture().get_image().save_png(path)
	print("wrote " + path)


## A character in steel with `weapon` in hand and a bow, a staff and meals in the pack, standing 3 m
## from the seer and idle.
static func _fighter(world: WorldDef, weapon: String) -> Sim:
	var sim := Sim.new(world)
	sim.command(SimVocab.NEW_CHARACTER, {"previous": ""})
	sim.command(SimVocab.SET_HINTS, {"on": false})
	sim.command(SimVocab.SET_AUTO_RETALIATE, {"on": false})
	H.arm(sim, weapon, [
		{"item": "steel_bow", "count": 1}, {"item": "steel_staff", "count": 1},
		{"item": "arrows", "count": 100}, {"item": "frost_shards", "count": 100}, {"item": "cooked_fish", "count": 5},
	])
	var snap := sim.snapshot()
	snap["inventory"]["equipment"].merge({"helm": "steel_helm", "body": "steel_body", "legs": "steel_legs"}, true)
	snap["player"]["region"] = WorldDef.REGION_RING_THREE
	sim.restore(snap)
	H.place(sim, SPOT)
	return sim
