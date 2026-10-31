## A dropped item lies in a pile (#234): where the player stands, the same pile an enemy's loot
## leaves, picked up again until the snow takes it; one timer for every pile, shown as a
## countdown and a blink in the last minute; and a dropped rare keeps its glow on the ground.
extends "res://tests/run.gd".TestCase

const SimScript := preload("res://sim/sim.gd")
const H := preload("res://tests/sim_helpers.gd")
const Vocab := preload("res://sim/vocab.gd")
const GameRootScript := preload("res://scenes/game_root.gd")


func _dropped(sim: Sim, entries: Array, args: Dictionary) -> Array[Dictionary]:
	H.walk_to(sim, H.OUTSIDE)
	H.set_pack(sim, entries)
	assert_true(sim.command(Vocab.DROP, args)["ok"])
	return H.run(sim, 1)


func test_a_drop_leaves_a_pile_where_the_player_stands() -> void:
	var sim := SimScript.new()
	var events := _dropped(sim, [{"item": "logs", "count": 6}], {"index": 0, "count": 2})
	assert_eq(H.pack_count(sim, "logs"), 4)
	var piles: Array[Dictionary] = H.of_kind(events, Vocab.EV_LOOT_DROPPED)
	assert_eq(piles.size(), 1)
	var pile: Dictionary = sim.state["loot"][piles[0]["loot_id"]]
	assert_eq([pile["item"], pile["count"]], ["logs", 2])
	assert_eq(Vector2(pile["pos"][0], pile["pos"][1]), sim.player_pos())
	assert_true(piles[0]["by_player"], "the event says the player dropped it")


func test_a_dropped_pile_can_be_picked_up_again() -> void:
	var sim := SimScript.new()
	_dropped(sim, [{"item": "logs", "count": 6}], {"index": 0, "count": 6})
	assert_eq(H.pack_count(sim, "logs"), 0)
	var id: String = (sim.state["loot"] as Dictionary).keys()[0]
	assert_true(sim.command(Vocab.INTERACT, {"object_id": id})["ok"])
	H.run(sim, 3)
	assert_eq(H.pack_count(sim, "logs"), 6, "the whole drop is back in the pack")
	assert_true(sim.state["loot"].is_empty())


func test_a_dropped_pile_and_an_enemys_pile_share_one_timer() -> void:
	var sim := SimScript.new()
	_dropped(sim, [{"item": "logs", "count": 1}], {"index": 0})
	var id: String = (sim.state["loot"] as Dictionary).keys()[0]
	assert_eq(sim.loot_ticks_left(id), Sim.LOOT_TICKS)
	var events := H.run(sim, Sim.LOOT_TICKS)
	assert_eq(H.of_kind(events, Vocab.EV_LOOT_GONE).size(), 1, "the snow takes it")
	assert_true(sim.state["loot"].is_empty())
	assert_eq(sim.loot_ticks_left(id), -1)


func test_test_mode_can_shorten_the_one_timer() -> void:
	var sim := SimScript.new()
	sim.loot_ticks = 10
	_dropped(sim, [{"item": "logs", "count": 1}], {"index": 0})
	var id: String = (sim.state["loot"] as Dictionary).keys()[0]
	assert_eq(sim.loot_ticks_left(id), 10)
	H.run(sim, 10)
	assert_true(sim.state["loot"].is_empty())


func test_the_countdown_reads_minutes_and_seconds() -> void:
	assert_eq(PileTimer.countdown(Sim.LOOT_TICKS), "5:00")
	assert_eq(PileTimer.countdown(1), "0:01")
	assert_eq(PileTimer.countdown(0), "0:00")
	assert_eq(PileTimer.countdown(247), "2:04", "rounded up to the second")


func test_a_pile_blinks_only_in_its_last_minute() -> void:
	for t in [0.0, 0.3, 0.6, 0.9]:
		assert_true(PileTimer.lit(Sim.LOOT_FADE_TICKS + 1, t), "lit before the last minute at %s" % t)
	var seen := {}
	for i in 20:
		seen[PileTimer.lit(Sim.LOOT_FADE_TICKS, i * 0.05)] = true
	assert_eq(seen.size(), 2, "it is lit and dark within a second of its last minute")
	assert_false(PileTimer.lit(1, 0.9), "dark for most of each blink as the snow comes")


func test_a_dropped_rare_keeps_its_glow_without_the_chime_or_the_find_line() -> void:
	var item := "stand_in_gold_ring"
	ItemTable.add_stand_ins({item: {
		"label": "Gold ring", "stack": 1, "weight": 0, "value": 50, "slot": "", "rarity": ItemTable.RARITY_ULTRA_RARE,
	}})
	var sim := SimScript.new()
	var events := _dropped(sim, [{"item": item, "count": 1}], {"index": 0})
	var drop: Dictionary = H.of_kind(events, Vocab.EV_LOOT_DROPPED)[0]
	assert_eq(drop["rarity"], ItemTable.RARITY_ULTRA_RARE)
	assert_true(PileGlow.of_band(drop["rarity"]) != null, "the pile glows in its band colour")
	assert_eq(AudioCues.event_cues(drop), [], "no find chime for what you dropped yourself")
	assert_eq(GameRootScript.drop_text(drop), "", "and no find line")
	ItemTable.clear_stand_ins()
