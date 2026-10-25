## Board-only, not shipped: renders each kit builder on the character from the game camera,
## with the real game loop running, for the kit PR's evidence (#160). A new character with no
## gear stands south of the gate, and each GearLook.KIT_SAMPLES look is built in the kit palette
## and hung on the bone slot its kind belongs to (the hood, crystal, fin and prism stack on the
## head with the shard crown and antlers; the robe, cloak, collar, plates, studs, edge trim,
## sash, ruff and seam on the chest; the faulds and tassets on the hips; the weapons in the
## right hand, the longbow in the left), one at a time and then all together.
##
##   godot --resolution 1280x720 -s tools/kit_shots.gd -- <out_dir> [shape ...]
##
## Writes <shape>.png from the default camera (32 m), <shape>_close.png from the nearest zoom
## (14 m) and <shape>_back.png from the nearest zoom turned round behind the character, and the
## same three as all.png, all_close.png and all_back.png with every sample worn at once.
extends SceneTree

const H := preload("res://tests/sim_helpers.gd")
const OrbitCamera := preload("res://scenes/orbit_camera.gd")
const CharacterGear := preload("res://scenes/character_gear.gd")

const SETTLE_FRAMES := 60
const SPOT := [0.5, 3.5]
const ALL := "all"
## The bone slot each kit shape hangs on in these shots.
const SLOTS := {
	GearLook.SHAPE_PEAKED_HOOD: "head", GearLook.SHAPE_CRYSTAL: "head", GearLook.SHAPE_FIN: "head",
	GearLook.SHAPE_PRISM_STACK: "head", GearLook.SHAPE_UNDER_ROBE: "chest", GearLook.SHAPE_CLOAK: "chest",
	GearLook.SHAPE_COLLAR: "chest", GearLook.SHAPE_STACKED_PLATES: "chest", GearLook.SHAPE_STUDS: "chest",
	GearLook.SHAPE_EDGE_TRIM: "chest", GearLook.SHAPE_SASH: "chest", GearLook.SHAPE_RUFF: "chest",
	GearLook.SHAPE_FAULDS: "hips", GearLook.SHAPE_TASSETS: "hips",
	GearLook.SHAPE_SEAM: "chest", GearLook.SHAPE_SHARD_CROWN: "head", GearLook.SHAPE_ANTLERS: "head",
	GearLook.SHAPE_BROADSWORD: "handslot_r", GearLook.SHAPE_BEARDED_AXE: "handslot_r", GearLook.SHAPE_GREATSWORD: "handslot_r",
	GearLook.SHAPE_FORGE_HAMMER: "handslot_r", GearLook.SHAPE_GLAIVE: "handslot_r", GearLook.SHAPE_CLEAVER: "handslot_r",
	GearLook.SHAPE_LONGBOW: "handslot_l", GearLook.SHAPE_PLUMES: "head",
	GearLook.SHAPE_POUCH: "chest", GearLook.SHAPE_MAGE_STAFF: "handslot_r",
}

var _out_dir := ""
var _only: Array = []  # shape names to render; empty for all
var _saved_game := PackedByteArray()
var _had_save := false


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		printerr("usage: godot -s tools/kit_shots.gd -- <out_dir> [shape ...]")
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
	main._on_import(_bare(main.sim.world).export_code())
	_quiet(main)
	for i in SETTLE_FRAMES:
		await process_frame
	var view: CharacterView = main._character_view
	var scenes: Array = []
	for own in GearLook.KIT_SAMPLES:
		scenes.append([own["shape"], [own]])
	scenes.append([ALL, GearLook.KIT_SAMPLES])
	for scene in scenes:
		if not _only.is_empty() and not _only.has(scene[0]):
			continue
		var mounts: Array = []
		for own in scene[1]:
			var holder := view.mount(SLOTS[own["shape"]])
			holder.add_child(CharacterGear.kit_builder(own["shape"]).call(GearLook.numbers(own), GearLook.KIT))
			mounts.append(holder)
		for i in 10:
			await process_frame
		rig.yaw = 0.0
		rig.distance = 32.0
		await process_frame
		await _shot("%s/%s.png" % [_out_dir, scene[0]])
		rig.distance = OrbitCamera.MIN_DISTANCE
		await process_frame
		await process_frame
		await _shot("%s/%s_close.png" % [_out_dir, scene[0]])
		rig.yaw = PI
		await process_frame
		await process_frame
		await _shot("%s/%s_back.png" % [_out_dir, scene[0]])
		for holder in mounts:
			(holder as Node).free()
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


## A new character with nothing worn, standing at the spot.
static func _bare(world: WorldDef) -> Sim:
	var sim := Sim.new(world)
	sim.command(SimVocab.NEW_CHARACTER, {"previous": ""})
	sim.command(SimVocab.SET_HINTS, {"on": false})
	H.set_pack(sim, [{"item": "cooked_fish", "count": 5}])
	var snap := sim.snapshot()
	for slot in ItemTable.EQUIPMENT_SLOTS:
		snap["inventory"]["equipment"][slot] = ""
	sim.restore(snap)
	H.place(sim, SPOT)
	return sim
