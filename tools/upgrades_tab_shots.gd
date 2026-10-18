## Board-only, not shipped: renders the Upgrades tab for the UI tools' stocked character
## (shelves and forge built, the cellar affordable), then builds the cellar and catches its
## row mid-flash and settled.
##
##   godot --resolution 1280x720 -s tools/upgrades_tab_shots.gd -- <out_prefix>
##
## Writes <out_prefix>_tab.png, _flash.png and _built.png (only _tab.png on a HUD without
## the flash).
extends SceneTree

const Shots := preload("res://tools/ui_shots.gd")

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var had := FileAccess.file_exists("user://frostmark.save")
	var saved := FileAccess.get_file_as_bytes("user://frostmark.save") if had else PackedByteArray()
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	var main: Node = current_scene
	main._on_import(Shots._stocked(main.sim.world).export_code())
	Shots._quiet(main)
	main._camera_rig.distance = 22.0
	main._camera_rig.yaw = 0.0
	for i in 40:
		await process_frame
	main._hud.show_tab(IconTable.TAB_UPGRADES)
	for i in 3:
		await process_frame
	await _shot(out + "_tab.png")
	if main._hud.has_method("flash_upgrade"):
		main._on_hud_command(SimVocab.BUILD, {"upgrade": "stash_cellar"})
		main._hud.refresh()
		var t0 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < 430:
			await process_frame
		await _shot(out + "_flash.png")
		while Time.get_ticks_msec() - t0 < 2500:
			await process_frame
		Shots._quiet(main)
		await process_frame
		await _shot(out + "_built.png")
	if had:
		var f := FileAccess.open("user://frostmark.save", FileAccess.WRITE)
		f.store_buffer(saved)
		f.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://frostmark.save"))
	quit(0)

func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(path)
	print("wrote " + path)
