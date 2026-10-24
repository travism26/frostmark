## The banners a return and a Deposit haul raise, from the pure functions GameRoot shows them
## with: the "You can now build" line appears only when the return made an upgrade newly
## affordable, naming each one, and the Deposit haul banner names what stayed only when the
## stash filled.
extends "res://tests/run.gd".TestCase

const GameRootScript := preload("res://scenes/game_root.gd")


func _returned(items: Array, newly: Array) -> Dictionary:
	return {"kind": SimVocab.EV_RETURNED, "items": items, "newly_affordable": newly}


func test_a_return_names_what_the_pack_holds() -> void:
	var text := GameRootScript._returned_text(_returned([{"item": "logs", "count": 4}, {"item": "raw_fish", "count": 2}], []))
	assert_eq(text, "Home safe. Carrying 4 Logs, 2 Raw fish.")
	assert_false(text.contains("You can now build"), "it does not nag on every trip")


func test_an_empty_return_is_just_home_safe() -> void:
	assert_eq(GameRootScript._returned_text(_returned([], [])), "Home safe.")


func test_one_newly_affordable_upgrade_is_named() -> void:
	assert_eq(GameRootScript._returned_text(_returned([{"item": "logs", "count": 4}], ["forge"])),
		"Home safe. Carrying 4 Logs.\nYou can now build: Forge.")


func test_several_are_listed_together() -> void:
	var text := GameRootScript._returned_text(_returned([{"item": "logs", "count": 4}], ["stash_shelves", "forge"]))
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
