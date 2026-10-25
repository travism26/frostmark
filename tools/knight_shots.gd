## Board-only, not shipped: renders the Frostbound knight's wind-up, feint and quick phase from
## the game's default camera, with the real game loop running, for the knight PR's look evidence.
## A new character in steel stands in reach of the lone knight in the south of ring three and does
## nothing, so the knight plays its cycle at them.
##
##   godot --resolution 1280x720 -s tools/knight_shots.gd -- <out_dir>
##
## Writes knight_windup.png ("Raises its blade" over the knight, a tick before the committed
## cleave is told), knight_feint.png (the bluffed cleave shrunk away, the word over it "Feint")
## and knight_real.png (the real cleave told on the feint tick). A second character, whose
## knight is already below half health, gives knight_quickens.png ("Its frost cracks") and
## knight_quick.png (a cleave told with no wind-up before it).
extends SceneTree

const H := preload("res://tests/sim_helpers.gd")

const KNIGHT := "frost_knight_3"
## 1.2 m west of its home, inside the blade's reach and beside it on the screen, so its figure is
## not behind the player's.
const SPOT := [-9.2, 180.0]
const WAIT_FRAMES := 3000
const SETTLE_FRAMES := 12

var _out_dir := ""
var _saved_game := PackedByteArray()
var _had_save := false


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		printerr("usage: godot -s tools/knight_shots.gd -- <out_dir>")
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
	var done := 0
	main._on_import(_fighter(main.sim.world, 120).export_code())
	_quiet(main)
	done += await _cycle(main)
	main._on_import(_fighter(main.sim.world, 59).export_code())
	_quiet(main)
	done += await _quick(main)
	if done < 5:
		printerr("only %d of 5 shots" % done)
	if _had_save:
		var f := FileAccess.open("user://frostmark.save", FileAccess.WRITE)
		f.store_buffer(_saved_game)
		f.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://frostmark.save"))
	quit(0 if done == 5 else 1)


func _quiet(main: Node) -> void:
	main._hud._banner_left = 0.0
	main._hud._banner_box.modulate.a = 0.0
	main._hud._saved_label.modulate.a = 0.0


## The wind-up, the feint, and the real cleave told on the feint tick.
func _cycle(main: Node) -> int:
	var drawn: Dictionary = main._enemies[KNIGHT]
	var phase := 0
	for i in WAIT_FRAMES:
		await process_frame
		var tick := int(main.sim.state["tick"])
		var raw: String = str(main.sim.state["enemies"][KNIGHT].get("next", {}).get("action", ""))
		var cue_up: bool = (drawn["cue"] as Label3D).visible
		if phase == 0 and raw == "raise_blade" and cue_up:
			await _shot("knight_windup")
			phase = 1
		elif phase == 1 and raw == "feint_cleave":
			phase = 2
		elif phase == 2 and int(drawn["feint_tick"]) == tick and tick > 0:
			await _shot("knight_feint")
			phase = 3
		elif phase == 3 and raw == "rime_cleave" and cue_up:
			await _shot("knight_real")
			return 3
	return phase


## The first stance of the quick phase, and the first cleave told after it.
func _quick(main: Node) -> int:
	var drawn: Dictionary = main._enemies[KNIGHT]
	var phase := 0
	for i in WAIT_FRAMES:
		await process_frame
		var raw: String = str(main.sim.state["enemies"][KNIGHT].get("next", {}).get("action", ""))
		var cue_up: bool = (drawn["cue"] as Label3D).visible
		if phase == 0 and raw == "knight_quickens" and cue_up:
			await _shot("knight_quickens")
			phase = 1
		elif phase == 1 and raw == "rime_cleave" and cue_up:
			await _shot("knight_quick")
			return 2
	return phase


func _shot(name: String) -> void:
	for i in SETTLE_FRAMES:
		await process_frame
	await RenderingServer.frame_post_draw
	var path := "%s/%s.png" % [_out_dir, name]
	root.get_viewport().get_texture().get_image().save_png(path)
	print("wrote " + path)


## A character in steel with a sword out, standing in reach of the lone knight and idle; the
## knight has `health` left.
static func _fighter(world: WorldDef, health: int) -> Sim:
	var sim := Sim.new(world)
	sim.command(SimVocab.NEW_CHARACTER, {"previous": ""})
	sim.command(SimVocab.SET_HINTS, {"on": false})
	sim.command(SimVocab.SET_AUTO_RETALIATE, {"on": false})
	H.arm(sim, "steel_sword", [{"item": "cooked_fish", "count": 5}])
	var snap := sim.snapshot()
	snap["inventory"]["equipment"].merge({"helm": "steel_helm", "body": "steel_body", "legs": "steel_legs"}, true)
	snap["player"]["region"] = WorldDef.REGION_RING_THREE
	snap["enemies"][KNIGHT]["health"] = health
	sim.restore(snap)
	H.place(sim, SPOT)
	return sim
