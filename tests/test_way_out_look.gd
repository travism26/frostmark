## How a dungeon's way out reads: its prop has an open look and a shut one, its label says which
## and, while shut, why; the great frost bear has a figure of its own, and only its first fall
## has a banner.
extends "res://tests/run.gd".TestCase

const GameRootScript := preload("res://scenes/game_root.gd")


func test_the_way_out_has_an_open_look_and_a_shut_one() -> void:
	var prop := Props.way_out(2.0, 3.0, Props.COLOR_STONE)
	var open := prop.get_node_or_null("Open")
	var shut := prop.get_node_or_null("Shut")
	assert_true(open != null and shut != null, "both looks are there to switch")
	assert_eq(open.find_children("*", "OmniLight3D", true, false).size(), 1, "the open look carries the light")
	assert_eq(shut.find_children("*", "OmniLight3D", true, false).size(), 0, "the shut look none")
	prop.free()


func test_the_label_says_open_or_why_it_is_shut() -> void:
	var bear: String = CombatTable.enemy("great_frost_bear")["label"]
	assert_eq(GameRootScript.way_out_text(true, bear), "Way out (open)")
	assert_eq(GameRootScript.way_out_text(false, bear), "Way out (shut while the great frost bear stands)")


func test_the_great_frost_bear_is_a_bear_taller_than_the_player_on_all_fours() -> void:
	var wolf := Figures.enemy("wolf")
	var bear := Figures.enemy("great_frost_bear")
	assert_true(bear is BeastBody, "a model moved in code, with no rig")
	assert_true(float(bear.get_meta("height")) >= 1.8, "as tall as the player on all fours")
	assert_true(float(bear.get_meta("height")) > 1.5 * float(wolf.get_meta("height")), "and far bigger than a wolf")
	assert_eq(bear.find_children("*", "MeshInstance3D", true, false).size(), 1, "the bear's one mesh")
	wolf.free()
	bear.free()


func test_only_the_bears_first_fall_has_a_banner() -> void:
	assert_eq(GameRootScript.dungeon_boss_fall_text("the great frost bear", true), "The great frost bear falls. The way out beside it stands open.")
	assert_eq(GameRootScript.dungeon_boss_fall_text("the great frost bear", false), "", "a later fall has none")
