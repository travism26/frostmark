## Board-only, not shipped: renders the Frost tyrant from the game's default camera, with the real
## game loop running, for the tyrant PR's look evidence. A new character in steel stands in reach
## of the tyrant in its hollow at the far south of ring three, swaps weapons and does nothing else.
##
##   godot --resolution 1280x720 --fixed-fps 30 -s tools/tyrant_shots.gd -- <out_dir>
##
## Writes tyrant_greatblade.png (its slash told, the greatblade in hand), tyrant_answers.png (a
## staff turned on the greatblade: "Draws its warbow" in the ranged colour, the bow in hand),
## tyrant_feint.png (the bluffed hail volley told as the real one), tyrant_roars.png (taken below
## half health: "Roars") and tyrant_staff.png (its staff raised), a `_close` shot of the first two
## from a nearer camera, and clip_NNN.png, every third frame of the whole run. Join those with
## ffmpeg for the clip. Its ground marks (#218) follow: tyrant_falling_ice.png (the drop marked on
## the player), tyrant_burning.png (the burning ground the ice left), tyrant_ice_shards.png (the
## quick phase's one-tick drop), tyrant_smash.png (the greatblade's front arc) and
## tyrant_stomp.png (its ring).
extends SceneTree

const H := preload("res://tests/sim_helpers.gd")

const TYRANT := "frost_tyrant"
## 1.2 m south-east of its home, inside the greatblade's reach, so it turns its visor to the camera.
const SPOT := [-23.15, 183.85]
const WAIT_FRAMES := 3000
const SETTLE_FRAMES := 12
const CLIP_EVERY := 3

var _out_dir := ""
var _saved_game := PackedByteArray()
var _had_save := false
var _failed := false
var _frame := 0
var _clip := 0


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		printerr("usage: godot -s tools/tyrant_shots.gd -- <out_dir>")
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
	_quiet(main)
	await _until(main, "tyrant_slash", "tyrant_greatblade", true)
	_swap_to(main, "steel_staff")
	await _until(main, "draw_warbow", "tyrant_answers", true)
	await _until(main, "feint_volley", "tyrant_feint")
	H.patch_enemy(main.sim, TYRANT, {"health": 299})
	await _until(main, "tyrant_roars", "tyrant_roars")
	await _until(main, "raise_tyrant_staff", "tyrant_staff")
	await _until_marked(main, "falling_ice", "tyrant_falling_ice")
	await _until_burning(main, "tyrant_burning")
	await _until_marked(main, "ice_shards", "tyrant_ice_shards")
	await _until_marked(main, "greatblade_smash", "tyrant_smash")
	await _until_marked(main, "tyrant_stomp", "tyrant_stomp")
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


## One frame of the run: kept on its feet, and every third frame saved for the clip.
func _tick(main: Node) -> void:
	await process_frame
	if int(main.sim.state["health"]) < 50:
		main.sim.state["health"] = Sim.HEALTH_MAX
	_frame += 1
	if _frame % CLIP_EVERY == 0:
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png("%s/clip_%03d.png" % [_out_dir, _clip])
		_clip += 1


## Runs frames until the tyrant has `action` declared and its cue is up, then takes the shot
## `name`, and with `close_up` a second one, `name` + "_close", from a camera brought in to show
## the weapon in its hand.
func _until(main: Node, action: String, name: String, close_up := false) -> void:
	var drawn: Dictionary = main._enemies[TYRANT]
	for i in WAIT_FRAMES:
		await _tick(main)
		var raw: String = str(main.sim.state["enemies"][TYRANT].get("next", {}).get("action", ""))
		if raw == action and (drawn["cue"] as Label3D).visible:
			for j in SETTLE_FRAMES:
				await _tick(main)
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


## Runs frames until the tyrant has told area blow `action`'s ground mark, then takes the shot
## `name` once the mark has been down a few frames.
func _until_marked(main: Node, action: String, name: String) -> void:
	for i in WAIT_FRAMES:
		await _tick(main)
		if str(main.sim.state["enemies"][TYRANT].get("next", {}).get("action", "")) == action:
			for j in SETTLE_FRAMES:
				await _tick(main)
			await _shot(name)
			return
	printerr("never saw %s marked in %d frames" % [action, WAIT_FRAMES])
	_failed = true


## Runs frames until burning ground is down, then takes the shot `name`.
func _until_burning(main: Node, name: String) -> void:
	for i in WAIT_FRAMES:
		await _tick(main)
		if not (main.sim.state["burning"] as Dictionary).is_empty():
			for j in SETTLE_FRAMES:
				await _tick(main)
			await _shot(name)
			return
	printerr("never saw burning ground in %d frames" % WAIT_FRAMES)
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


## A character in steel with a sword in hand and a bow, a staff and meals in the pack, standing
## beside the tyrant and idle.
static func _fighter(world: WorldDef) -> Sim:
	var sim := Sim.new(world)
	sim.command(SimVocab.NEW_CHARACTER, {"previous": ""})
	sim.command(SimVocab.SET_HINTS, {"on": false})
	sim.command(SimVocab.SET_AUTO_RETALIATE, {"on": false})
	H.arm(sim, "steel_sword", [
		{"item": "steel_bow", "count": 1}, {"item": "steel_staff", "count": 1},
		{"item": "arrows", "count": 100}, {"item": "frost_shards", "count": 100}, {"item": "cooked_fish", "count": 5},
	])
	var snap := sim.snapshot()
	snap["inventory"]["equipment"].merge({"helm": "steel_helm", "body": "steel_body", "legs": "steel_legs"}, true)
	snap["player"]["region"] = WorldDef.REGION_RING_THREE
	sim.restore(snap)
	H.place(sim, SPOT)
	return sim
