## Warmth and health: the cold outside, the fire inside, and collapsing at zero health.
extends "res://tests/run.gd".TestCase

const H := preload("res://tests/sim_helpers.gd")
const SimScript := preload("res://sim/sim.gd")
const Vocab := preload("res://sim/vocab.gd")


func test_warmth_drains_outside() -> void:
	var sim := SimScript.new()
	H.walk_to(sim, H.OUTSIDE)
	var before := int(sim.state["warmth"])
	var events := H.run(sim, 10)
	assert_eq(int(sim.state["warmth"]), before - 10 * Sim.WARMTH_DRAIN, "drains every tick outside")
	assert_eq(H.of_kind(events, Vocab.EV_WARMTH_CHANGED).size(), 10)
	assert_eq(int(sim.state["health"]), Sim.HEALTH_MAX, "health holds while warmth lasts")


func test_warmth_does_not_drain_inside() -> void:
	var sim := SimScript.new()
	H.patch(sim, {"warmth": 100})
	H.walk_to(sim, H.INSIDE_COLD_CORNER)
	assert_false(sim.near_fire(), "away from the fire")
	H.run(sim, 20)
	assert_eq(int(sim.state["warmth"]), 100, "no meter moves inside the outpost")


func test_the_fire_restores_warmth() -> void:
	var sim := SimScript.new()
	H.patch(sim, {"warmth": 10, "health": 40})
	sim.command(Vocab.INTERACT, {"object_id": "fire"})
	H.run_until_idle(sim, 40)
	assert_true(sim.near_fire())
	H.run(sim, 40)
	assert_eq(int(sim.state["warmth"]), Sim.WARMTH_MAX, "full again")
	assert_true(int(sim.state["health"]) > 40, "resting by the fire mends health")


func test_health_drains_at_zero_warmth() -> void:
	var sim := SimScript.new()
	H.walk_to(sim, H.OUTSIDE)
	H.patch(sim, {"warmth": 2})
	var events := H.run(sim, 6)
	assert_eq(int(sim.state["warmth"]), 0)
	assert_eq(int(sim.state["health"]), Sim.HEALTH_MAX - 4 * Sim.COLD_DAMAGE, "four ticks at zero warmth")
	var hurt := H.of_kind(events, Vocab.EV_TOOK_DAMAGE)
	assert_eq(hurt.size(), 4)
	assert_eq(hurt[0]["cause"], "cold")


func test_collapse_wakes_by_the_fire_with_the_pack_intact() -> void:
	var sim := SimScript.new()
	H.walk_to(sim, H.OUTSIDE)
	H.set_pack(sim, [{"item": "logs", "count": 6}])
	H.patch(sim, {"warmth": 0, "health": 2})
	var events := H.run(sim, 3)
	var collapsed := H.of_kind(events, Vocab.EV_COLLAPSED)
	assert_eq(collapsed.size(), 1)
	assert_eq(sim.state["player"]["region"], WorldDef.REGION_OUTPOST)
	assert_true(sim.near_fire(), "beside the fire")
	assert_eq(H.pack_count(sim, "logs"), 6, "the pack is intact")
	assert_eq(H.of_kind(events, Vocab.EV_BANKED).size(), 0, "waking inside is not crossing the gate")
	assert_true(int(sim.state["health"]) > 0)


func test_a_full_gauge_lasts_an_outing() -> void:
	# The trees are at most 12 m beyond the gate; a full gauge must cover a fair outing
	# (walk out, fell two trees, walk back) with room to spare, and run out on a long dawdle.
	var ticks := Sim.WARMTH_MAX / Sim.WARMTH_DRAIN
	assert_true(ticks * Sim.TICK_SECONDS >= 150.0, "at least two and a half minutes of warmth")
	assert_true(ticks * Sim.TICK_SECONDS <= 300.0, "but not more than five")
