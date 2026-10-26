## How a dungeon's way out reads: its prop has an open look and a shut one, its label says which
## and, while shut, why, and the great wolf has a figure of its own.
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
	assert_eq(GameRootScript.way_out_text(true, "Great wolf"), "Way out (open)")
	assert_eq(GameRootScript.way_out_text(false, "Great wolf"), "Way out (shut while the great wolf stands)")


func test_the_great_wolf_is_a_wolf_nearly_twice_the_size() -> void:
	var wolf := Figures.enemy("wolf")
	var great := Figures.enemy("great_wolf")
	assert_true(float(great.get_meta("height")) > 1.8 * float(wolf.get_meta("height")), "nearly twice the size")
	wolf.free()
	great.free()
