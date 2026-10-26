## What the presentation says about a death chest, from the pure functions it says it with: the
## death screen names the chest after a death in a gentle dungeon and nothing after one outside,
## the chest's label lists what it holds, and taking from it says what a full pack left behind.
extends "res://tests/run.gd".TestCase

const DeathScreenScript := preload("res://scenes/death_screen.gd")
const GameRootScript := preload("res://scenes/game_root.gd")

const CHEST := "ring_one_dungeon_chest"


func test_a_death_in_the_dungeon_names_its_chest() -> void:
	var e := {"chest": CHEST, "lost": [{"item": "logs", "count": 3}]}
	assert_eq(DeathScreenScript._lost_heading_text(e), "In the death chest")
	assert_eq(DeathScreenScript._chest_text(e), "What you did not keep waits in the death chest just inside the mouth of the ring-one dungeon, until you come back for it.")


func test_a_death_anywhere_else_loses_things_for_good() -> void:
	for e in [{"chest": "", "lost": []}, {"lost": []}]:
		assert_eq(DeathScreenScript._lost_heading_text(e), "Lost for good")
		assert_eq(DeathScreenScript._chest_text(e), "")


func test_the_chest_label_lists_what_it_holds() -> void:
	assert_eq(GameRootScript._death_chest_text([]), "Death chest (empty)")
	assert_eq(GameRootScript._death_chest_text([{"item": "iron_helm", "count": 1}, {"item": "logs", "count": 3}]), "Death chest\nIron helm\n3 Logs")


func test_taking_from_the_chest_says_what_stays() -> void:
	assert_eq(GameRootScript._took_from_chest_text({"items": [{"item": "logs", "count": 3}], "left": []}), "You take 3 Logs from the death chest.")
	assert_eq(GameRootScript._took_from_chest_text({"items": [{"item": "logs", "count": 3}], "left": [{"item": "coal", "count": 4}]}),
		"You take 3 Logs from the death chest. Pack full: 4 Coal stays in it.")
