## Board-only, not shipped: renders the character's visible gear from the game's default camera,
## with the real game loop running, for the equipped-gear PR's before and after evidence. A new
## character stands south of the gate with one set of gear worn per scene: an axe, a pickaxe, a
## sword, a bow and a staff, the axe again while chopping a pine, and the armour sets (a full
## wooden, bronze, iron, steel and fur set, fur mixed with metal both ways, a helm alone and
## legs alone).
##
##   godot --resolution 1280x720 -s tools/gear_shots.gd -- <out_dir> [scene ...]
##
## Writes <scene>.png from the default camera, <scene>_close.png from the nearest zoom and
## <scene>_back.png from the nearest zoom turned round behind the character.
extends SceneTree

const H := preload("res://tests/sim_helpers.gd")
const OrbitCamera := preload("res://scenes/orbit_camera.gd")

const SETTLE_FRAMES := 60
const WAIT_FRAMES := 900
const SPOT := [0.5, 3.5]
## Each scene's equipment; a slot it does not name is empty.
const SCENES := [
	{"name": "axe", "tool": "steel_axe"},
	{"name": "pickaxe", "tool": "steel_pickaxe"},
	{"name": "sword", "weapon": "steel_sword", "tool": "steel_pickaxe", "body": "steel_body"},
	{"name": "bow", "weapon": "steel_bow", "tool": "steel_axe"},
	{"name": "staff", "weapon": "steel_staff", "tool": "steel_axe"},
	{"name": "chopping", "weapon": "steel_sword", "tool": "steel_axe", "gather": "tree_3"},
	{"name": "wooden_set", "weapon": "wooden_club", "tool": "wooden_axe", "helm": "wooden_helm", "body": "wooden_body", "legs": "wooden_legs"},
	{"name": "bronze_set", "weapon": "bronze_sword", "tool": "bronze_axe", "helm": "bronze_helm", "body": "bronze_body", "legs": "bronze_legs"},
	{"name": "iron_set", "weapon": "iron_sword", "tool": "iron_pickaxe", "helm": "iron_helm", "body": "iron_body", "legs": "iron_legs"},
	{"name": "steel_set", "weapon": "steel_sword", "tool": "steel_pickaxe", "helm": "steel_helm", "body": "steel_body", "legs": "steel_legs"},
	{"name": "fur_set", "weapon": "bronze_sword", "tool": "bronze_axe", "helm": "fur_hood", "body": "fur_coat", "legs": "fur_legs"},
	{"name": "fur_hood_legs_iron_body", "weapon": "iron_sword", "tool": "iron_axe", "helm": "fur_hood", "body": "iron_body", "legs": "fur_legs"},
	{"name": "fur_coat_steel_helm_legs", "weapon": "steel_sword", "tool": "steel_pickaxe", "helm": "steel_helm", "body": "fur_coat", "legs": "steel_legs"},
	{"name": "helm_only", "weapon": "iron_sword", "tool": "iron_axe", "helm": "iron_helm"},
	{"name": "legs_only", "weapon": "iron_sword", "tool": "iron_axe", "legs": "iron_legs"},
]

var _out_dir := ""
var _only: Array = []  # scene names to render; empty for all
var _saved_game := PackedByteArray()
var _had_save := false


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		printerr("usage: godot -s tools/gear_shots.gd -- <out_dir>")
		quit(2)
		return
	_out_dir = args[0]
	_only = args.slice(1)
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
	var rig: Node3D = main._camera_rig
	for scene in SCENES:
		if not _only.is_empty() and not _only.has(scene["name"]):
			continue
		main._on_import(_wearer(main.sim.world, scene).export_code())
		_quiet(main)
		if scene.has("gather"):
			main.sim.command(SimVocab.GATHER, {"object_id": scene["gather"]})
			var working := false
			for i in WAIT_FRAMES:
				await process_frame
				if str(main.sim.state["player"]["activity"].get("kind", "")) == SimVocab.GATHER:
					working = true
					break
			if not working:
				printerr("%s: never started gathering" % scene["name"])
				continue
		for i in SETTLE_FRAMES:
			await process_frame
		rig.distance = 32.0
		await process_frame
		await _shot("%s/%s.png" % [_out_dir, scene["name"]])
		rig.distance = OrbitCamera.MIN_DISTANCE
		await process_frame
		await process_frame
		await _shot("%s/%s_close.png" % [_out_dir, scene["name"]])
		rig.yaw = PI
		await process_frame
		await process_frame
		await _shot("%s/%s_back.png" % [_out_dir, scene["name"]])
		rig.yaw = 0.0
		rig.distance = 32.0
	if _had_save:
		var f := FileAccess.open("user://frostmark.save", FileAccess.WRITE)
		f.store_buffer(_saved_game)
		f.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://frostmark.save"))
	quit(0)


## Drops the welcome banner and the Saved flash an import raises, so the shot is the character.
static func _quiet(main: Node) -> void:
	main._hud._banner_left = 0.0
	main._hud._banner_box.modulate.a = 0.0
	main._hud._saved_label.modulate.a = 0.0


func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(path)
	print("wrote " + path)


## A new character wearing the scene's gear, standing at the spot.
static func _wearer(world: WorldDef, scene: Dictionary) -> Sim:
	var sim := Sim.new(world)
	sim.command(SimVocab.NEW_CHARACTER, {"previous": ""})
	sim.command(SimVocab.SET_HINTS, {"on": false})
	H.set_pack(sim, [{"item": "cooked_fish", "count": 5}])
	var snap := sim.snapshot()
	for slot in ItemTable.EQUIPMENT_SLOTS:
		snap["inventory"]["equipment"][slot] = scene.get(slot, "")
	sim.restore(snap)
	H.place(sim, SPOT)
	return sim
