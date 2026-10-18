## Board-only, not shipped: renders a shot in flight from the game's default camera, with the
## real game loop running, for the projectile PR's before and after evidence. A new character
## stands beside a monster and the scene plays on its own: the player looses a bow shot and a
## staff cast at a wolf, and a bandit archer and a frost witch shoot at the player.
##
##   godot --resolution 1280x720 -s tools/projectile_shots.gd -- <out_dir>
##
## Writes <scene>.png for each scene, taken `delay` seconds after the blow is struck: for the
## player, after the target's health falls; for a monster, after its telegraph goes up. The
## impact scene is the bow shot again, taken as it lands.
extends SceneTree

const H := preload("res://tests/sim_helpers.gd")

const SETTLE_FRAMES := 40
const WAIT_FRAMES := 900
const SCENES := [
	{"name": "player_bow", "spot": [-1.5, 28.5], "weapon": "steel_bow", "ammo": "arrows", "enemy": "wolf_1", "attack": true, "delay": 0.05},
	{"name": "player_bow_impact", "spot": [-1.5, 28.5], "weapon": "steel_bow", "ammo": "arrows", "enemy": "wolf_1", "attack": true, "delay": 0.32},
	{"name": "player_staff", "spot": [-2.5, 28.5], "weapon": "steel_staff", "ammo": "frost_shards", "enemy": "wolf_1", "attack": true, "delay": 0.05},
	{"name": "enemy_archer", "spot": [8.5, 28.5], "weapon": "steel_sword", "ammo": "", "enemy": "archer_1", "attack": false, "delay": 0.38},
	{"name": "enemy_witch", "spot": [38.5, -19.5], "weapon": "steel_sword", "ammo": "", "enemy": "witch_1", "attack": false, "delay": 0.38},
]

var _out_dir := ""
var _saved_game := PackedByteArray()
var _had_save := false


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		printerr("usage: godot -s tools/projectile_shots.gd -- <out_dir>")
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
	for scene in SCENES:
		main._on_import(_fighter(main.sim.world, scene).export_code())
		_quiet(main)
		var id: String = scene["enemy"]
		var drawn: Dictionary = main._enemies[id]
		var health := int(main.sim.combatant(id)["health"])
		var struck := false
		for i in WAIT_FRAMES:
			await process_frame
			if scene["attack"]:
				struck = int(main.sim.combatant(id)["health"]) < health
			else:
				struck = (drawn["cue"] as Label3D).visible
			if struck:
				break
		if not struck:
			printerr("%s: no blow within %d frames" % [scene["name"], WAIT_FRAMES])
			continue
		await create_timer(float(scene["delay"])).timeout
		await _shot("%s/%s.png" % [_out_dir, scene["name"]])
	if _had_save:
		var f := FileAccess.open("user://frostmark.save", FileAccess.WRITE)
		f.store_buffer(_saved_game)
		f.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://frostmark.save"))
	quit(0)


## Drops the welcome banner and the Saved flash an import raises, so the shot is the fight.
static func _quiet(main: Node) -> void:
	main._hud._banner_left = 0.0
	main._hud._banner_box.modulate.a = 0.0
	main._hud._saved_label.modulate.a = 0.0


func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(path)
	print("wrote " + path)


## A new character with the scene's weapon out, standing at its spot, attacking when asked.
static func _fighter(world: WorldDef, scene: Dictionary) -> Sim:
	var sim := Sim.new(world)
	sim.command(SimVocab.NEW_CHARACTER, {"previous": ""})
	sim.command(SimVocab.SET_HINTS, {"on": false})
	var pack: Array = [{"item": "cooked_fish", "count": 5}]
	if scene["ammo"] != "":
		pack.append({"item": scene["ammo"], "count": 50})
	H.arm(sim, scene["weapon"], pack)
	H.place(sim, scene["spot"])
	if scene["attack"]:
		sim.command(SimVocab.ATTACK, {"enemy_id": scene["enemy"]})
	return sim
