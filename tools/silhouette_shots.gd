## Board-only, not shipped: renders candidate monster figures in the real scene, from the
## game's own camera at play distance, each beside the player and a bandit archer for scale,
## with the HUD hidden. One idle frame and one mid-strike frame per option.
##
##   godot --resolution 1280x720 -s tools/silhouette_shots.gd -- <out_dir> <spec.json>
##
## The spec is {"spot": [x, z], "options": [{...}]}, each option:
##   name, path (res:// glb), height (m), clips {idle, walk, run, melee, ranged, magic, death},
##   or just enemy (a kind for Figures.enemy, rendering the shipped build),
##   strike (melee | ranged | magic), peak (0..1 of the strike clip, default 0.45),
##   recolour (#hex, redraws in shades), tint (#hex, multiplies), hide [part names],
##   club_bone / bow_slot / staff_slot (where to hang a weapon), face (radians the figure turns
##   from the game's forward; default a three-quarter turn toward the camera).
extends SceneTree

const H := preload("res://tests/sim_helpers.gd")
const SETTLE_FRAMES := 45
const CROP := Vector2i(1100, 620)

var _out_dir := ""
var _spec := {}
var _saved_game := PackedByteArray()
var _had_save := false


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		printerr("usage: godot -s tools/silhouette_shots.gd -- <out_dir> <spec.json>")
		quit(2)
		return
	_out_dir = args[0]
	_spec = JSON.parse_string(FileAccess.get_file_as_string(args[1]))
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
	var world: WorldDef = main.sim.world
	var spot: Array = _spec["spot"]
	var sim := Sim.new(world)
	sim.command(SimVocab.NEW_CHARACTER, {"previous": ""})
	H.place(sim, spot)
	main._on_import(sim.export_code())
	main.get_node("HUD").visible = false
	main._camera_rig.distance = float(_spec.get("distance", 32.0))
	main._camera_rig.yaw = 0.0
	var layer: Node3D = main._enemy_layer
	for id in main._enemies:
		(main._enemies[id]["root"] as Node3D).visible = false
	var centre := Vector3(spot[0], 0.0, spot[1])
	var face := float(_spec.get("face", PI - 0.7))
	var bandit := Figures.enemy("bandit_archer")
	bandit.position = centre + Vector3(2.6, 0, 0)
	bandit.rotation.y = face
	layer.add_child(bandit)
	main._character.rotation.y = face
	for option in _spec["options"]:
		var figure := _build(option)
		figure.position = centre + Vector3(-2.3, 0, 0)
		figure.rotation.y = float(option.get("face", face))
		layer.add_child(figure)
		for i in SETTLE_FRAMES:
			await process_frame
		await _shoot(main, "%s_play" % option["name"], centre)
		main._camera_rig.distance = float(_spec.get("close", 16.0))
		await process_frame
		await process_frame
		await _shoot(main, "%s_idle" % option["name"], centre)
		var style: String = option.get("strike", "melee")
		figure.strike(style)
		var player: AnimationPlayer = figure._player
		var clip: String = figure.clips.get(style, figure.clips.get("melee", ""))
		if player != null and player.has_animation(clip):
			player.seek(player.get_animation(clip).length * float(option.get("peak", 0.45)), true)
		await process_frame
		await process_frame
		await _shoot(main, "%s_strike" % option["name"], centre)
		main._camera_rig.distance = float(_spec.get("distance", 32.0))
		figure.queue_free()
		await process_frame
	if _had_save:
		var f := FileAccess.open("user://frostmark.save", FileAccess.WRITE)
		f.store_buffer(_saved_game)
		f.close()
	quit(0)


func _build(option: Dictionary) -> FigureBody:
	if option.has("enemy"):  # a shipped build out of the figure factory, for the after shots
		return Figures.enemy(option["enemy"])
	var figure := FigureBody.new()
	var path: String = option["path"]
	var clips: Dictionary = option["clips"]
	var model_height := float(option.get("model_height", 0.0))
	if model_height <= 0.0:
		model_height = _rig_height(path)
	figure.setup(path, model_height, float(option["height"]), clips, bool(option.get("faces_plus_z", true)))
	figure.hide_parts(option.get("hide", []))
	if option.has("paint"):
		var colours := {}
		for key in option["paint"]:
			colours[key] = Color.html(option["paint"][key])
		figure.paint(colours)
	if option.has("recolour"):
		figure.recolour(Color.html(option["recolour"]))
	if option.has("tint"):
		figure.tint(Color.html(option["tint"]))
	if option.has("bow_slot"):
		figure.mount(option["bow_slot"], "bow").add_child(Figures.bow(Figures.COLOR_BONE, 1.2))
	if option.has("staff_slot"):
		figure.mount(option["staff_slot"], "staff").add_child(Figures.staff(Props.COLOR_WOOD, 1.5))
	if option.has("spikes_bone"):
		var skeleton: Skeleton3D = figure._skeleton
		var attach := BoneAttachment3D.new()
		attach.bone_name = option["spikes_bone"]
		skeleton.add_child(attach)
		var k: float = 1.0 / maxf(figure._frame_of(attach).basis.get_scale().y, 0.0001)
		var spikes: Array = option.get("spikes", [])
		for sp in spikes:
			var cone := CylinderMesh.new()
			cone.top_radius = 0.0
			cone.bottom_radius = float(sp[3]) * 0.45
			cone.height = float(sp[3])
			cone.radial_segments = 5
			cone.material = Props.flat(Props.COLOR_ICE, 1.2)
			var m := MeshInstance3D.new()
			m.mesh = cone
			m.position = Vector3(sp[0], sp[1], sp[2]) * k
			m.scale = Vector3.ONE * k
			m.rotation = Vector3(float(sp[4]), 0.0, float(sp[5]))
			attach.add_child(m)
	if option.has("club_bone"):
		var skeleton: Skeleton3D = figure._skeleton
		var bone := skeleton.find_bone(option["club_bone"])
		if bone >= 0:
			var attach := BoneAttachment3D.new()
			attach.bone_name = option["club_bone"]
			skeleton.add_child(attach)
			var club := Figures.club(Props.COLOR_ICE)
			var bone_scale: float = figure._frame_of(attach).basis.get_scale().y
			club.scale = Vector3.ONE * float(option.get("club_scale", 1.6)) / maxf(bone_scale, 0.0001)
			var offset: Array = option.get("club_offset", [0.0, 0.0, 0.0])
			club.position = Vector3(offset[0], offset[1], offset[2])
			var rot: Array = option.get("club_rotation", [0.0, 0.0, 0.0])
			club.rotation = Vector3(rot[0], rot[1], rot[2])
			attach.add_child(club)
	return figure


## The rig's height in model units: the merged AABB of its meshes in the rest pose.
static func _rig_height(path: String) -> float:
	var scene: PackedScene = load(path)
	var inst: Node3D = scene.instantiate()
	var top := -INF
	var bottom := INF
	for node in inst.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var aabb := mi.get_aabb()
		var xf := mi.transform
		var p: Node = mi.get_parent()
		while p != null and p != inst:
			if p is Node3D:
				xf = (p as Node3D).transform * xf
			p = p.get_parent()
		for i in 8:
			var y := (xf * aabb.get_endpoint(i)).y
			top = maxf(top, y)
			bottom = minf(bottom, y)
	inst.free()
	return maxf(top - bottom, 0.001)


func _shoot(main: Node, name: String, centre: Vector3) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_viewport().get_texture().get_image()
	var camera: Camera3D = main._camera_rig.camera
	var at := camera.unproject_position(centre + Vector3(0, 1.0, 0))
	var logical := root.get_visible_rect().size
	at = Vector2(at.x * image.get_width() / logical.x, at.y * image.get_height() / logical.y)
	var origin := Vector2i(int(at.x) - CROP.x / 2, int(at.y) - CROP.y / 2)
	origin.x = clampi(origin.x, 0, image.get_width() - CROP.x)
	origin.y = clampi(origin.y, 0, image.get_height() - CROP.y)
	var crop := image.get_region(Rect2i(origin, CROP))
	var path := "%s/%s.png" % [_out_dir, name]
	crop.save_png(path)
	print("wrote " + path)
