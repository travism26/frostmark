## Board-only, not shipped: renders a boss calling in its adds from the game's default camera,
## with the real game loop running, for the adds PR's look evidence. No game kind calls adds yet,
## so the ring-one dungeon's boss is swapped for a stand-in copy of it that calls two wolves from
## the sides of its room at half health. A character in iron stands beside it, idle.
##
##   godot --resolution 1280x720 --fixed-fps 30 -s tools/add_shots.gd -- <out_dir>
##
## Writes adds_called.png (the two entry rings on the snow, the tick before the wolves come in)
## and adds_in.png (the wolves come in and close on the player).
extends SceneTree

const H := preload("res://tests/sim_helpers.gd")

const BOSS := "ring_one_dungeon_boss"
const CALLER := "shot_great_wolf"
## A metre and a half south of the boss's home, in its fangs' reach.
const SPOT := [73.0, 45.5]
const ENTRIES := [[-8.0, 0.0], [8.0, 0.0]]
const WAIT_FRAMES := 900
const SETTLE_FRAMES := 12

var _out_dir := ""
var _saved_game := PackedByteArray()
var _had_save := false
var _failed := false


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		printerr("usage: godot -s tools/add_shots.gd -- <out_dir>")
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
	var caller: Dictionary = CombatTable.enemy("great_wolf").duplicate(true)
	caller["phases"] = [{
		"below": 50, "actions": ["tyrant_roars", "slash", CombatTable.ACTION_REST, CombatTable.ACTION_REST],
		"adds": [{"kind": "wolf", "entry": ENTRIES[0]}, {"kind": "wolf", "entry": ENTRIES[1]}],
	}]
	CombatTable.add_stand_ins({CALLER: caller}, {})
	main.sim.world.enemies[BOSS]["kind"] = CALLER
	var home: Array = main.sim.world.enemies[BOSS]["home"]
	for entry: Array in ENTRIES:
		if not main.sim.world.is_walkable(Vector2(home[0] + entry[0], home[1] + entry[1])):
			printerr("entry %s is not open ground" % [entry])
			_failed = true
	main._on_import(_fighter(main.sim.world).export_code())
	main.sim.command(SimVocab.SET_AUTO_RETALIATE, {"on": false})
	main._hud._banner_left = 0.0
	main._hud._banner_box.modulate.a = 0.0
	main._hud._saved_label.modulate.a = 0.0
	H.patch_enemy(main.sim, BOSS, {"health": 149})
	main._show_sim()
	await _until(main, func() -> bool: return main._cues.call_point(BOSS + "_add_1") != null, "adds_called")
	await _until(main, func() -> bool:
		var add: Variant = main.sim.state["enemies"].get(BOSS + "_add_1")
		return add != null and add["mode"] == Sim.MODE_ENGAGED and _moved(add, home), "adds_in")
	if _had_save:
		var f := FileAccess.open("user://frostmark.save", FileAccess.WRITE)
		f.store_buffer(_saved_game)
		f.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://frostmark.save"))
	quit(1 if _failed else 0)


## Whether an add has walked a few metres in from its entry.
static func _moved(add: Dictionary, home: Array) -> bool:
	return Vector2(add["pos"][0], add["pos"][1]).distance_to(Vector2(home[0], home[1])) < 6.0


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


## A character in iron with a sword in hand, standing beside the boss and idle.
static func _fighter(world: WorldDef) -> Sim:
	var sim := Sim.new(world)
	sim.command(SimVocab.NEW_CHARACTER, {"previous": ""})
	sim.command(SimVocab.SET_HINTS, {"on": false})
	sim.command(SimVocab.SET_AUTO_RETALIATE, {"on": false})
	H.arm(sim, "iron_sword", [{"item": "cooked_fish", "count": 5}])
	var snap := sim.snapshot()
	snap["inventory"]["equipment"].merge({"helm": "iron_helm", "body": "iron_body", "legs": "iron_legs"}, true)
	sim.restore(snap)
	H.place(sim, SPOT)
	return sim
