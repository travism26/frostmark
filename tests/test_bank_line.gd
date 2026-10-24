## The banners a bank and a Deposit haul raise, from the pure functions GameRoot shows them
## with: the "You can now build" line appears only when the bank made an upgrade newly
## affordable, naming each one, and the Deposit haul banner names what stayed only when the
## stash filled.
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


func _deposited(items: Array, stayed: Array) -> Dictionary:
	return {"kind": SimVocab.EV_DEPOSITED_HAUL, "items": items, "stayed": stayed}


func test_deposit_haul_lists_what_was_stored() -> void:
	var text := GameRootScript._deposited_haul_text(_deposited(
		[{"item": "logs", "count": 4}, {"item": "raw_fish", "count": 2}], [],
	))
	assert_eq(text, "Stored 4 Logs, 2 Raw fish.")


func test_deposit_haul_names_what_stayed_for_a_full_stash() -> void:
	var text := GameRootScript._deposited_haul_text(_deposited(
		[{"item": "logs", "count": 2}], [{"item": "logs", "count": 3}, {"item": "copper_ore", "count": 5}],
	))
	assert_eq(text, "Stored 2 Logs.\nStash full: 3 Logs, 5 Copper ore stayed in your pack.")
