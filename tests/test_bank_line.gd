## The banner a bank raises, from the pure function GameRoot shows it with: the "You can now
## build" line appears only when the bank made an upgrade newly affordable, naming each one.
extends "res://tests/run.gd".TestCase

const GameRootScript := preload("res://scenes/game_root.gd")


func _banked(newly: Array) -> Dictionary:
	return {"kind": SimVocab.EV_BANKED, "items": [{"item": "logs", "count": 4}], "overflow": [], "newly_affordable": newly}


func test_no_line_when_nothing_became_affordable() -> void:
	var text := GameRootScript._banked_text(_banked([]))
	assert_eq(text, "Home safe. Banked 4 Logs.")
	assert_false(text.contains("You can now build"), "it does not nag on every trip")


func test_one_newly_affordable_upgrade_is_named() -> void:
	assert_eq(GameRootScript._banked_text(_banked(["forge"])), "Home safe. Banked 4 Logs.\nYou can now build: Forge.")


func test_several_are_listed_together() -> void:
	var text := GameRootScript._banked_text(_banked(["stash_shelves", "forge"]))
	assert_true(text.ends_with("\nYou can now build: Stash shelves, Forge."), text)
