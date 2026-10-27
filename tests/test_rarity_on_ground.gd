## Rarity on the ground (#241), from the drop event alone: a pile of a rare, super rare or ultra
## rare item glows blue, purple or gold, and a super rare or ultra rare one also sends up a light
## column; a super rare drop chimes and an ultra rare one chimes louder and longer; and the log
## line names the band in words. Uncommon and band-less piles stay plain and quiet. No real item
## is rare or better yet (#138), so stand-in items carry those bands, and each drop event comes
## from a real kill in the sim, its stand-in loot table rolling one band every time.
extends "res://tests/run.gd".TestCase

const H := preload("res://tests/sim_helpers.gd")
const Vocab := preload("res://sim/vocab.gd")
const GameRootScript := preload("res://scenes/game_root.gd")

## Where the wolf stands, by the player, in ring one by the archer.
const HOME := [14.5, 28.5]
const SPOT := [14.5, 27.5]

const ITEMS := {
	"stand_in_blue_ring": {"label": "Blue ring", "stack": 1, "weight": 0, "value": 50, "slot": "", "rarity": ItemTable.RARITY_RARE},
	"stand_in_purple_ring": {"label": "Purple ring", "stack": 1, "weight": 0, "value": 50, "slot": "", "rarity": ItemTable.RARITY_SUPER_RARE},
	"stand_in_gold_ring": {"label": "Gold ring", "stack": 1, "weight": 0, "value": 50, "slot": "", "rarity": ItemTable.RARITY_ULTRA_RARE},
}
## A band of each rarity, each giving one item.
const BANDS := {
	"uncommon": {"rarity": ItemTable.RARITY_UNCOMMON, "pool": ["iron_axe"]},
	"rare": {"rarity": ItemTable.RARITY_RARE, "pool": ["stand_in_blue_ring"]},
	"super_rare": {"rarity": ItemTable.RARITY_SUPER_RARE, "pool": ["stand_in_purple_ring"]},
	"ultra_rare": {"rarity": ItemTable.RARITY_ULTRA_RARE, "pool": ["stand_in_gold_ring"]},
}
const ITEM_OF_BAND := {
	ItemTable.RARITY_UNCOMMON: "iron_axe", ItemTable.RARITY_RARE: "stand_in_blue_ring",
	ItemTable.RARITY_SUPER_RARE: "stand_in_purple_ring", ItemTable.RARITY_ULTRA_RARE: "stand_in_gold_ring",
}


func test_a_rare_or_better_pile_glows_in_its_band_colour_and_a_plain_one_does_not() -> void:
	for band in ItemTable.RARITIES:
		var drop := _drop(band)
		assert_eq(drop["rarity"], band, "the drop event carries the band")
		var glow := PileGlow.of_band(drop["rarity"])
		if band == ItemTable.RARITY_UNCOMMON:
			assert_eq(glow, null, "an uncommon pile does not glow")
			continue
		assert_true(glow != null, "a %s pile glows" % band)
		if glow == null:
			continue
		assert_eq(glow.colour, RarityLook.colour(band), "in the %s colour" % band)
		for part in glow.get_children():
			var mat := (part as MeshInstance3D).material_override as StandardMaterial3D
			assert_eq(Color(mat.albedo_color, 1.0), Color(RarityLook.colour(band), 1.0), "%s: every part in the band colour" % band)
			assert_eq(mat.shading_mode, BaseMaterial3D.SHADING_MODE_UNSHADED, "%s: unshaded, for the web renderer" % band)
		glow.free()
	assert_eq(PileGlow.of_band(_logs()["rarity"]), null, "the guaranteed logs, band-less, do not glow")
	CombatTable.clear_stand_ins()


func test_only_purple_and_gold_piles_send_up_a_column() -> void:
	var expected := {
		ItemTable.RARITY_RARE: false, ItemTable.RARITY_SUPER_RARE: true, ItemTable.RARITY_ULTRA_RARE: true,
	}
	for band in expected:
		var glow := PileGlow.of_band(_drop(band)["rarity"])
		assert_eq(glow.column != null, expected[band], "%s: a column only for purple and gold" % band)
		if glow.column != null:
			assert_eq(glow.column.get_parent(), glow, "the column is part of the glow")
			assert_true(glow.column.position.y > 2.0, "and stands tall over the pile")
		glow.free()
	CombatTable.clear_stand_ins()


func test_the_glow_and_column_go_when_the_pile_does() -> void:
	var pile := Node3D.new()
	var glow := PileGlow.of_band(_drop(ItemTable.RARITY_ULTRA_RARE)["rarity"])
	pile.add_child(glow)
	var column := glow.column
	pile.free()
	assert_false(is_instance_valid(glow), "the glow goes with its pile")
	assert_false(is_instance_valid(column), "and so does the column")
	CombatTable.clear_stand_ins()


func test_a_purple_drop_chimes_and_a_gold_drop_chimes_louder_and_longer() -> void:
	var heard := {}
	for band in ItemTable.RARITIES:
		heard[band] = AudioCues.event_cues(_drop(band))
	assert_eq(heard[ItemTable.RARITY_SUPER_RARE], [AudioCues.CHIME_SUPER_RARE], "purple: the super rare chime")
	assert_eq(heard[ItemTable.RARITY_ULTRA_RARE], [AudioCues.CHIME_ULTRA_RARE], "gold: the ultra rare chime")
	assert_eq(heard[ItemTable.RARITY_RARE], [], "blue: none")
	assert_eq(heard[ItemTable.RARITY_UNCOMMON], [], "uncommon: none")
	assert_eq(AudioCues.event_cues(_logs()), [], "band-less: none")
	assert_true(float(AudioCues.GAIN[AudioCues.CHIME_ULTRA_RARE]) > float(AudioCues.GAIN[AudioCues.CHIME_SUPER_RARE]),
		"the gold chime is louder")
	var super_rare := load(AudioCues.paths(AudioCues.CHIME_SUPER_RARE)[0]) as AudioStream
	var ultra_rare := load(AudioCues.paths(AudioCues.CHIME_ULTRA_RARE)[0]) as AudioStream
	assert_true(ultra_rare.get_length() > super_rare.get_length(), "and longer")
	CombatTable.clear_stand_ins()


func test_the_log_line_names_the_band_in_words() -> void:
	assert_eq(GameRootScript.drop_text(_drop(ItemTable.RARITY_RARE)), "Rare: Blue ring.")
	assert_eq(GameRootScript.drop_text(_drop(ItemTable.RARITY_SUPER_RARE)), "Super rare: Purple ring.")
	assert_eq(GameRootScript.drop_text(_drop(ItemTable.RARITY_ULTRA_RARE)), "Ultra rare: Gold ring.")
	assert_eq(GameRootScript.drop_text(_drop(ItemTable.RARITY_UNCOMMON)), "", "an uncommon drop has no line of its own")
	assert_eq(GameRootScript.drop_text(_logs()), "", "nor does the guaranteed loot")
	CombatTable.clear_stand_ins()


## The drop event for the one item a wolf's kill rolls from band `band`, every time.
func _drop(band: String) -> Dictionary:
	return _kill_drops(band)[1]


## The drop event for the wolf's guaranteed logs.
func _logs() -> Dictionary:
	return _kill_drops(ItemTable.RARITY_UNCOMMON)[0]


## Kills a wolf whose stand-in loot table is three logs and a certain roll in `band`, and
## answers its drop events. The stand-ins stay until the test clears them, so the stand-in
## items keep their labels.
func _kill_drops(band: String) -> Array[Dictionary]:
	CombatTable.clear_stand_ins()
	CombatTable.add_stand_in_loot(
		{"wolf": {"loot": [{"item": "logs", "count": 3}], "boss_loot": [], "rare_roll": {band: 100}}},
		BANDS, ITEMS,
	)
	var sim := H.arena({"foe": {"kind": "wolf", "home": HOME}})
	H.place(sim, SPOT)
	H.arm(sim, "iron_sword")
	sim.drain_events()
	H.patch_enemy(sim, "foe", {"health": 1})
	sim.command(Vocab.ATTACK, {"enemy_id": "foe"})
	var drops := H.of_kind(H.run(sim, 3), Vocab.EV_LOOT_DROPPED)
	assert_eq(drops.size(), 2, "%s: the logs and one rare drop" % band)
	assert_eq(drops[1]["item"], ITEM_OF_BAND[band], "%s: the band's item" % band)
	return drops
