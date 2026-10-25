## Board-only, not shipped: renders the quiver and cape places on the character from the game
## camera, with the real game loop running, for the slot PR's evidence (#161). No quiver or cape
## item exists until the ranged and magic set tickets add them, so each scene wears real items in
## the other slots and hangs a sample quiver and cape look, in colours from the approved
## mock-ups, on the bone slots CharacterGear hangs them from, through the same builders and
## layering: the cape hung clear of the body worn, the quiver and the slung tool over the cape.
## The barbarian's own cape is hidden while a cape is worn, as in the game.
##
##   godot --resolution 1280x720 -s tools/slot_shots.gd -- <out_dir> [scene ...]
##
## Writes <scene>.png from the default camera (32 m), <scene>_close.png from the nearest zoom
## (14 m), <scene>_back.png from the nearest zoom turned round behind the character and
## <scene>_side.png from the nearest zoom on the character's right.
extends SceneTree

const H := preload("res://tests/sim_helpers.gd")
const OrbitCamera := preload("res://scenes/orbit_camera.gd")
const CharacterGear := preload("res://scenes/character_gear.gd")

const SETTLE_FRAMES := 60
const WAIT_FRAMES := 900
const SPOT := [0.5, 3.5]
## Wolfstalker: dark leather under bone, pale fletching.
const WOLF := {
	"base": Color(0.23, 0.18, 0.16), "dark": Color(0.14, 0.11, 0.09), "trim": Color(0.86, 0.84, 0.75),
	"accent": Color(0.86, 0.84, 0.75), "glow": Color.BLACK, "glow_energy": 0.0,
}
## Ruin Stalker's Shroud: ink-black leathers, bone, violet glow.
const INK := {
	"base": Color(0.08, 0.08, 0.11), "dark": Color(0.04, 0.04, 0.06), "trim": Color(0.86, 0.83, 0.74),
	"accent": Color(0.86, 0.83, 0.74), "glow": Color(0.60, 0.42, 1.0), "glow_energy": 1.5,
}
## Hoarfrost Sovereign: glacier white over steel blue, frost glow.
const FROST := {
	"base": Color(0.86, 0.91, 0.98), "dark": Color(0.37, 0.50, 0.69), "trim": Color(0.62, 0.71, 0.84),
	"accent": Color(0.77, 0.86, 0.96), "glow": Color(0.65, 0.89, 1.0), "glow_energy": 1.5,
}
## Each scene's worn items (a slot it does not name is empty) and the quiver and cape looks hung
## beside them, each [look, palette].
const SCENES := [
	{
		"name": "wolf_quiver", "weapon": "steel_bow", "tool": "steel_axe",
		"helm": "steel_helm", "body": "steel_body", "legs": "steel_legs",
		"quiver": [{"shape": GearLook.SHAPE_QUIVER}, WOLF],
	},
	{
		"name": "shroud", "weapon": "steel_bow", "tool": "steel_pickaxe",
		"helm": "fur_hood", "body": "fur_coat", "legs": "steel_legs",
		"quiver": [{"shape": GearLook.SHAPE_QUIVER, "tip_count": 4}, INK],
		"cape": [{"shape": GearLook.SHAPE_CLOAK, "outline": GearLook.OUTLINE_TORN, "length_left": 1.0, "length_right": 0.92, "teeth": 4}, INK],
	},
	{
		"name": "forked_cloak", "weapon": "steel_staff", "tool": "steel_axe",
		"quiver": [{"shape": GearLook.SHAPE_QUIVER, "tips": GearLook.TIPS_SHARDS, "tip_count": 4, "glow": 1.2}, FROST],
		"cape": [{"shape": GearLook.SHAPE_CLOAK, "outline": GearLook.OUTLINE_FORKED, "length_left": 0.95, "length_right": 0.85, "glow": 0.6}, FROST],
	},
	{
		"name": "chopping", "weapon": "steel_bow", "tool": "steel_axe", "body": "iron_body", "gather": "tree_3",
		"quiver": [{"shape": GearLook.SHAPE_QUIVER}, WOLF],
		"cape": [{"shape": GearLook.SHAPE_CLOAK, "outline": GearLook.OUTLINE_TORN, "length_left": 1.0, "length_right": 0.92, "teeth": 4}, INK],
	},
]

var _out_dir := ""
var _only: Array = []  # scene names to render; empty for all
var _saved_game := PackedByteArray()
var _had_save := false


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		printerr("usage: godot -s tools/slot_shots.gd -- <out_dir> [scene ...]")
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
		var view: CharacterView = main._character_view
		var body: String = scene.get("body", "")
		var mounts: Array = []
		var cape := {}
		if scene.has("cape"):
			cape = CharacterGear.hang_cape(GearLook.numbers(scene["cape"][0]), body)
			var holder := view.mount(CharacterGear.CAPE_SLOT)
			holder.add_child(CharacterGear.cloak(cape, scene["cape"][1]))
			mounts.append(holder)
			view.set_part_visible("Barbarian_Cape", false)
			# The game slings the tool over a worn cape; no cape item exists, so move it here.
			var slung: Array = main._gear._pieces[GearLayout.BACK]
			if not slung.is_empty():
				var sling: Node3D = (slung[0] as Node3D).get_child(0)
				sling.position = CharacterGear.hang_sling(GearLook.piece(scene["tool"], GearLook.PART_TOOL), cape)
		if scene.has("quiver"):
			var holder := view.mount(CharacterGear.QUIVER_SLOT)
			var look := CharacterGear.hang_quiver(GearLook.numbers(scene["quiver"][0]), body, cape)
			holder.add_child(CharacterGear.quiver(look, scene["quiver"][1]))
			mounts.append(holder)
		for i in 10:
			await process_frame
		for shot in [["", 0.0, 32.0], ["_close", 0.0, OrbitCamera.MIN_DISTANCE], ["_back", PI, OrbitCamera.MIN_DISTANCE], ["_side", -PI * 0.5, OrbitCamera.MIN_DISTANCE]]:
			rig.yaw = shot[1]
			rig.distance = shot[2]
			await process_frame
			await process_frame
			await _shot("%s/%s%s.png" % [_out_dir, scene["name"], shot[0]])
		rig.yaw = 0.0
		rig.distance = 32.0
		for holder in mounts:
			(holder as Node).free()
		view.set_part_visible("Barbarian_Cape", not scene.has("body"))
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


## A new character wearing the scene's items, standing at the spot.
static func _wearer(world: WorldDef, scene: Dictionary) -> Sim:
	var sim := Sim.new(world)
	sim.command(SimVocab.NEW_CHARACTER, {"previous": ""})
	sim.command(SimVocab.SET_HINTS, {"on": false})
	H.set_pack(sim, [{"item": "cooked_fish", "count": 5}])
	var snap := sim.snapshot()
	for slot in ItemTable.EQUIPMENT_SLOTS:
		var item: Variant = scene.get(slot, "")
		snap["inventory"]["equipment"][slot] = item if item is String else ""
	sim.restore(snap)
	H.place(sim, SPOT)
	return sim
