## Board-only, not shipped: renders the outpost and each ring under a palette for the
## ring-palette board, from the real scene with the HUD hidden. A palette with no entry for a
## ring shows that ring as the table has it.
##
##   godot --resolution 1280x720 -s tools/ring_shots.gd -- <out_dir> [palette]
##
## Palettes: `table` (the ring-look module as written) or a name in PALETTES below.
extends SceneTree

const H := preload("res://tests/sim_helpers.gd")

## Where the character stands for each ring's shot.
const SPOTS := {
	WorldDef.REGION_OUTPOST: [0.5, 4.5],
	WorldDef.REGION_INNER_RING: [-1.5, 16.5],
	WorldDef.REGION_RING_ONE: [-11.5, 36.5],
	WorldDef.REGION_RING_TWO: [2.5, 71.5],
	WorldDef.REGION_RING_THREE: [-33.5, 136.5],
	# Both sides of the ring-one dungeon's mouth: ring one's, looking at the cave in its cliff,
	# and the dungeon's, just inside.
	"dungeon_mouth": [57.5, -47.0],
	WorldDef.REGION_RING_ONE_DUNGEON: [69.5, -47.5],
}
const CAMERA_DISTANCE := 26.0
const SETTLE_FRAMES := 90

const PALETTES := {
	"steel_blue": {
		WorldDef.REGION_OUTPOST: {
			"tint": Color(1.00, 0.95, 0.88), "sky": Color(0.40, 0.44, 0.52),
			"fog_color": Color(0.58, 0.62, 0.70), "fog_distance": 80.0,
			"sun_color": Color(1.00, 0.80, 0.58), "sun_energy": 1.1,
			"ambient_color": Color(0.55, 0.62, 0.78), "ambient_energy": 0.5,
			"snow_density": 0.2, "wind": 0.1, "aurora": 0.0, "ambience": "hearth",
		},
		WorldDef.REGION_INNER_RING: {
			"tint": Color(0.90, 0.94, 1.00), "sky": Color(0.34, 0.40, 0.52),
			"fog_color": Color(0.60, 0.66, 0.78), "fog_distance": 64.0,
			"sun_color": Color(1.00, 0.76, 0.56), "sun_energy": 0.95,
			"ambient_color": Color(0.50, 0.58, 0.78), "ambient_energy": 0.55,
			"snow_density": 0.4, "wind": 0.25, "aurora": 0.2, "ambience": "calm",
		},
		WorldDef.REGION_RING_ONE: {
			"tint": Color(0.76, 0.82, 0.92), "sky": Color(0.24, 0.30, 0.40),
			"fog_color": Color(0.46, 0.53, 0.64), "fog_distance": 46.0,
			"sun_color": Color(0.94, 0.70, 0.56), "sun_energy": 0.8,
			"ambient_color": Color(0.42, 0.50, 0.70), "ambient_energy": 0.58,
			"snow_density": 0.65, "wind": 0.6, "aurora": 0.6, "ambience": "wind",
		},
		WorldDef.REGION_RING_TWO: {
			"tint": Color(0.56, 0.60, 0.70), "sky": Color(0.07, 0.09, 0.14),
			"fog_color": Color(0.20, 0.24, 0.31), "fog_distance": 30.0,
			"sun_color": Color(0.78, 0.62, 0.58), "sun_energy": 0.5,
			"ambient_color": Color(0.30, 0.34, 0.46), "ambient_energy": 0.56,
			"snow_density": 1.0, "wind": 1.0, "aurora": 1.0, "ambience": "blizzard",
		},
	},
	"ember_and_ink": {
		WorldDef.REGION_OUTPOST: {
			"tint": Color(1.00, 0.93, 0.84), "sky": Color(0.30, 0.20, 0.38),
			"fog_color": Color(0.48, 0.36, 0.54), "fog_distance": 76.0,
			"sun_color": Color(1.00, 0.70, 0.46), "sun_energy": 1.15,
			"ambient_color": Color(0.50, 0.40, 0.72), "ambient_energy": 0.55,
			"snow_density": 0.2, "wind": 0.1, "aurora": 0.0, "ambience": "hearth",
		},
		WorldDef.REGION_INNER_RING: {
			"tint": Color(0.94, 0.90, 1.00), "sky": Color(0.26, 0.20, 0.44),
			"fog_color": Color(0.54, 0.48, 0.74), "fog_distance": 60.0,
			"sun_color": Color(1.00, 0.62, 0.40), "sun_energy": 1.05,
			"ambient_color": Color(0.48, 0.38, 0.78), "ambient_energy": 0.6,
			"snow_density": 0.4, "wind": 0.25, "aurora": 0.25, "ambience": "calm",
		},
		WorldDef.REGION_RING_ONE: {
			"tint": Color(0.78, 0.78, 0.98), "sky": Color(0.16, 0.14, 0.36),
			"fog_color": Color(0.38, 0.38, 0.64), "fog_distance": 42.0,
			"sun_color": Color(0.94, 0.56, 0.42), "sun_energy": 0.85,
			"ambient_color": Color(0.38, 0.34, 0.76), "ambient_energy": 0.62,
			"snow_density": 0.65, "wind": 0.6, "aurora": 0.65, "ambience": "wind",
		},
		WorldDef.REGION_RING_TWO: {
			"tint": Color(0.54, 0.54, 0.74), "sky": Color(0.04, 0.04, 0.12),
			"fog_color": Color(0.16, 0.15, 0.30), "fog_distance": 26.0,
			"sun_color": Color(0.80, 0.50, 0.46), "sun_energy": 0.5,
			"ambient_color": Color(0.26, 0.24, 0.50), "ambient_energy": 0.56,
			"snow_density": 1.0, "wind": 1.0, "aurora": 1.0, "ambience": "blizzard",
		},
	},
}

var _out_dir := ""
var _palette := "table"
var _saved_game := PackedByteArray()
var _had_save := false


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		printerr("usage: godot -s tools/ring_shots.gd -- <out_dir> [palette]")
		quit(2)
		return
	_out_dir = args[0]
	if args.size() > 1:
		_palette = args[1]
	DirAccess.make_dir_recursive_absolute(_out_dir)
	# The import below writes the browser save; keep whatever this machine had.
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
	for ring in SPOTS:
		var sim := Sim.new(world)
		sim.command(SimVocab.NEW_CHARACTER, {"previous": ""})
		H.place(sim, SPOTS[ring])
		main._on_import(sim.export_code())
		main.get_node("HUD").visible = false
		main._camera_rig.distance = CAMERA_DISTANCE
		main._camera_rig.yaw = 0.0
		var look: Variant = null
		if _palette != "table":
			look = PALETTES[_palette].get(ring)
		main._atmosphere.set_look_override(look)
		for i in SETTLE_FRAMES:
			await process_frame
		await RenderingServer.frame_post_draw
		var image := root.get_viewport().get_texture().get_image()
		var path := "%s/%s_%s.png" % [_out_dir, _palette, ring]
		image.save_png(path)
		print("wrote " + path)
	if _had_save:
		var f := FileAccess.open("user://frostmark.save", FileAccess.WRITE)
		f.store_buffer(_saved_game)
		f.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://frostmark.save"))
	quit(0)
