## The status line on crossing into a ring, from the pure function GameRoot shows it with:
## every region reads naturally, the numbered rings without "the".
extends "res://tests/run.gd".TestCase

const GameRootScript := preload("res://scenes/game_root.gd")


func _entered(from: String, to: String) -> String:
	return GameRootScript._entered_text({"kind": SimVocab.EV_REGION_CHANGED, "from": from, "to": to})


func test_leaving_the_outpost_names_the_inner_ring_and_the_cold() -> void:
	assert_eq(_entered(WorldDef.REGION_OUTPOST, WorldDef.REGION_INNER_RING), "Entered the inner ring. The cold sets in.")


func test_the_numbered_rings_are_named_bare() -> void:
	assert_eq(_entered(WorldDef.REGION_INNER_RING, WorldDef.REGION_RING_ONE), "Entered ring one. Wolves and bandits hunt here.")
	assert_eq(_entered(WorldDef.REGION_RING_ONE, WorldDef.REGION_RING_TWO), "Entered ring two. Trolls and stalkers keep the ruins.")


func test_walking_back_in_names_the_inner_rings_with_the() -> void:
	assert_eq(_entered(WorldDef.REGION_RING_ONE, WorldDef.REGION_INNER_RING), "Entered the inner ring.")
	assert_eq(_entered(WorldDef.REGION_INNER_RING, WorldDef.REGION_OUTPOST), "Entered the outpost.")
