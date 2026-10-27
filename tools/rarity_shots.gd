## Board-only, not shipped: renders rare drops on the ground from the game's default camera, with
## the real game loop running, for the ground-rarity PR's look evidence (#241). No real item is
## rare or better yet (#138), so the far pack's three wolves are swapped for a stand-in wolf that
## only rests (so no bite overwrites the log line), its loot table rolling a stand-in item of one
## band at 1 %, under a drop-rate scale of 100. A character in iron kills them, one band each: a
## blue, a purple and a gold pile land in the snow. Then the snow takes the purple and gold piles,
## so their columns go. Nothing is picked up: a stand-in item has no icon for the pack to draw.
##
##   godot --resolution 1280x720 --fixed-fps 30 -s tools/rarity_shots.gd -- <out_dir>
##
## Writes rare.png, super_rare.png and ultra_rare.png (each kill's pile and its log line),
## all_three.png, and after.png (the purple and gold piles gone), and prints
## a `PILE` line per pile drawn: its item, band, glow colour and whether it has a column.
extends SceneTree

const H := preload("res://tests/sim_helpers.gd")

## The far pack, and a spot just north of it, in reach of all three.
const WOLVES := ["wolf_3", "wolf_4", "wolf_5"]
const RESTING_WOLF := "shot_resting_wolf"
const SPOT := [-26.0, 30.0]
const SCALE := 100.0
const ITEMS := {
	"shot_blue_ring": {"label": "Blue ring", "stack": 1, "weight": 0, "value": 50, "slot": "", "rarity": ItemTable.RARITY_RARE},
	"shot_purple_crown": {"label": "Purple crown", "stack": 1, "weight": 0, "value": 50, "slot": "", "rarity": ItemTable.RARITY_SUPER_RARE},
	"shot_gold_star": {"label": "Gold star", "stack": 1, "weight": 0, "value": 50, "slot": "", "rarity": ItemTable.RARITY_ULTRA_RARE},
}
const BANDS := {
	"shot_rare": {"rarity": ItemTable.RARITY_RARE, "pool": ["shot_blue_ring"]},
	"shot_super_rare": {"rarity": ItemTable.RARITY_SUPER_RARE, "pool": ["shot_purple_crown"]},
	"shot_ultra_rare": {"rarity": ItemTable.RARITY_ULTRA_RARE, "pool": ["shot_gold_star"]},
}
## The band each wolf's kill rolls, and the shot it makes.
const KILLS := [["wolf_3", "shot_rare", "rare"], ["wolf_4", "shot_super_rare", "super_rare"], ["wolf_5", "shot_ultra_rare", "ultra_rare"]]
const WAIT_FRAMES := 900
const SETTLE_FRAMES := 20
const NOTICE_FRAMES := 90

var _out_dir := ""
var _saved_game := PackedByteArray()
var _had_save := false
var _failed := false


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		printerr("usage: godot -s tools/rarity_shots.gd -- <out_dir>")
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
	var resting: Dictionary = CombatTable.enemy("wolf").duplicate(true)
	resting["actions"] = [CombatTable.ACTION_REST]
	CombatTable.add_stand_ins({RESTING_WOLF: resting}, {})
	for id in WOLVES:
		main.sim.world.enemies[id]["kind"] = RESTING_WOLF
	main._on_import(_fighter(main.sim.world).export_code())
	main._hud._banner_left = 0.0
	main._hud._banner_box.modulate.a = 0.0
	main._hud._saved_label.modulate.a = 0.0
	CombatTable.set_drop_rate_scale(SCALE)
	# Lets the pack notice the player first, so its line does not overwrite the first drop's.
	for i in NOTICE_FRAMES:
		await process_frame
	for kill: Array in KILLS:
		CombatTable.add_stand_in_loot(
			{RESTING_WOLF: {"loot": [{"item": "wolf_pelt", "count": 1}], "boss_loot": [], "rare_roll": {kill[1]: 1}}},
			BANDS, ITEMS,
		)
		H.patch_enemy(main.sim, kill[0], {"health": 1})
		main.sim.command(SimVocab.ATTACK, {"enemy_id": kill[0]})
		var item: String = BANDS[kill[1]]["pool"][0]
		await _until(main, func() -> bool: return _pile_of(main, item) != "", kill[2])
		print("LOG %s: %s" % [kill[2], main._status.text.replace("\n", " | ")])
	await _until(main, func() -> bool: return true, "all_three")
	_report(main)

	for item in ["shot_purple_crown", "shot_gold_star"]:
		main.sim.state["loot"][_pile_of(main, item)]["expires_tick"] = int(main.sim.state["tick"]) + 1
	await _until(main, func() -> bool:
		return _pile_of(main, "shot_purple_crown") == "" and _pile_of(main, "shot_gold_star") == "", "after")
	_report(main)

	CombatTable.clear_stand_ins()
	if _had_save:
		var f := FileAccess.open("user://frostmark.save", FileAccess.WRITE)
		f.store_buffer(_saved_game)
		f.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://frostmark.save"))
	quit(1 if _failed else 0)


## The id of the pile holding `item`, "" when none lies on the ground.
static func _pile_of(main: Node, item: String) -> String:
	for id in main.sim.state["loot"]:
		if main.sim.state["loot"][id]["item"] == item:
			return id
	return ""


## Prints every pile drawn: its item, band, and the glow and column under its node.
static func _report(main: Node) -> void:
	for id in main._loot:
		var item: String = main.sim.state["loot"][id]["item"]
		var glow := (main._loot[id] as Node).get_node_or_null("pile_glow") as PileGlow
		print("PILE %s %s band=%s glow=%s column=%s" % [
			id, item, ItemTable.rarity(item), glow.colour if glow != null else "none",
			glow != null and glow.column != null,
		])


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


## A character in iron with a sword in hand, standing by the far pack.
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
