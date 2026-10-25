## Warmth and health: the cold outside, the fire inside, and freezing to death at zero health.
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


func test_freezing_to_death_is_a_real_death() -> void:
	var sim := SimScript.new()
	H.walk_to(sim, H.OUTSIDE)
	H.set_pack(sim, [{"item": "logs", "count": 6}])
	H.patch(sim, {"warmth": 0, "health": 2})
	var events := H.run(sim, 3)
	var died := H.of_kind(events, Vocab.EV_DIED)
	assert_eq(died.size(), 1)
	assert_eq(died[0]["cause"], "cold")
	assert_eq(sim.state["player"]["region"], WorldDef.REGION_OUTPOST)
	assert_true(sim.near_fire(), "beside the fire")
	assert_eq(H.of_kind(events, Vocab.EV_RETURNED).size(), 0, "waking inside is not crossing the gate")
	assert_eq(int(sim.state["health"]), Sim.HEALTH_MAX)
	assert_eq(int(sim.state["warmth"]), Sim.WARMTH_MAX)


func test_a_full_gauge_lasts_an_outing() -> void:
	# The trees are at most 12 m beyond the gate; a full gauge must cover a fair outing
	# (walk out, fell two trees, walk back) with room to spare, and run out on a long dawdle.
	var ticks := Sim.WARMTH_MAX / Sim.WARMTH_DRAIN
	assert_true(ticks * Sim.TICK_SECONDS >= 150.0, "at least two and a half minutes of warmth")
	assert_true(ticks * Sim.TICK_SECONDS <= 300.0, "but not more than five")


func test_worn_warmth_adds_up_the_fur_pieces() -> void:
	var sim := SimScript.new()
	assert_eq(sim.worn_warmth(), 0, "a new character wears nothing warm")
	assert_eq(ItemTable.warmth("bronze_helm"), 0, "items without warmth keep none out")
	assert_eq(ItemTable.warmth("logs"), 0)
	_wear(sim, ["fur_hood"])
	assert_eq(sim.worn_warmth(), 1)
	_wear(sim, ["fur_hood", "fur_coat", "fur_legs"])
	assert_eq(sim.worn_warmth(), 3, "a full fur set")


func test_worn_fur_makes_a_full_gauge_last_longer() -> void:
	var expected := [360, 420, 480, 540]
	var fur := ["fur_hood", "fur_coat", "fur_legs"]
	for n in expected.size():
		var sim := SimScript.new()
		H.walk_to(sim, H.OUTSIDE)
		_wear(sim, fur.slice(0, n))
		H.patch(sim, {"tick": 0, "warmth": Sim.WARMTH_MAX})
		var ticks := 0
		while int(sim.state["warmth"]) > 0 and ticks < 1000:
			sim.step()
			ticks += 1
		assert_eq(ticks, expected[n], "a full gauge with %d fur pieces worn" % n)
		assert_eq(int(sim.state["health"]), Sim.HEALTH_MAX, "nothing else drained the gauge")


func test_taking_fur_off_changes_the_rate_from_the_next_tick() -> void:
	# With one piece worn the first tick of every seven keeps its warmth; bare, every tick drains.
	var worn := SimScript.new()
	H.walk_to(worn, H.OUTSIDE)
	H.set_pack(worn, [])
	_wear(worn, ["fur_coat"])
	H.patch(worn, {"tick": 0, "warmth": 200})
	var stripped := SimScript.new()
	stripped.restore(worn.snapshot())
	assert_true(stripped.command(Vocab.EQUIP, {"unequip": ItemTable.SLOT_BODY})["ok"])
	H.run(worn, 1)
	H.run(stripped, 1)
	assert_eq(int(worn.state["warmth"]), 200, "the coat holds the cold off this tick")
	assert_eq(stripped.state["inventory"]["equipment"]["body"], "", "the coat came off")
	assert_eq(int(stripped.state["warmth"]), 199, "without it the same tick drains")


func test_fur_changes_nothing_by_a_fire_or_inside() -> void:
	for fur in [[], ["fur_hood", "fur_coat", "fur_legs"]]:
		var by_fire := SimScript.new()
		_wear(by_fire, fur)
		H.patch(by_fire, {"warmth": 10})
		by_fire.command(Vocab.INTERACT, {"object_id": "fire"})
		H.run_until_idle(by_fire, 40)
		assert_true(by_fire.near_fire())
		var before := int(by_fire.state["warmth"])
		H.run(by_fire, 2)
		assert_eq(int(by_fire.state["warmth"]), mini(Sim.WARMTH_MAX, before + 2 * Sim.FIRE_WARMTH), "the fire refills as ever, %s worn" % [fur])
		var inside := SimScript.new()
		_wear(inside, fur)
		H.patch(inside, {"warmth": 100})
		H.walk_to(inside, H.INSIDE_COLD_CORNER)
		H.run(inside, 20)
		assert_eq(int(inside.state["warmth"]), 100, "no drain inside, %s worn" % [fur])


func test_fur_does_not_soften_the_cold_at_zero_warmth() -> void:
	var sim := SimScript.new()
	H.walk_to(sim, H.OUTSIDE)
	_wear(sim, ["fur_hood", "fur_coat", "fur_legs"])
	H.patch(sim, {"tick": 0, "warmth": 0})
	var events := H.run(sim, 7)
	assert_eq(int(sim.state["health"]), Sim.HEALTH_MAX - 7 * Sim.COLD_DAMAGE, "every tick at zero hurts, fur or not")
	assert_eq(H.of_kind(events, Vocab.EV_TOOK_DAMAGE).size(), 7)


func test_a_restore_mid_outing_drains_like_an_unbroken_run() -> void:
	var unbroken := SimScript.new()
	H.walk_to(unbroken, H.OUTSIDE)
	_wear(unbroken, ["fur_hood", "fur_legs"])
	var keys := unbroken.snapshot().keys()
	var broken := SimScript.new()
	broken.restore(unbroken.snapshot())
	var a := _warmth_trace(unbroken, 100)
	var b := _warmth_trace(broken, 37)
	var snap := broken.snapshot()
	assert_eq(snap.keys(), keys, "worn fur adds nothing to the save")
	assert_eq(int(snap["version"]), Sim.STATE_VERSION)
	var resumed := SimScript.new()
	assert_true(resumed.restore(snap))
	b.append_array(_warmth_trace(resumed, 63))
	assert_eq(b, a, "the same warmth every tick across the restore")


## Puts `kinds` on through restore(), each in its own slot, and clears the armour slots first.
static func _wear(sim: Sim, kinds: Array) -> void:
	var snap := sim.snapshot()
	for slot in ItemTable.ARMOUR_SLOTS:
		snap["inventory"]["equipment"][slot] = ""
	for kind in kinds:
		snap["inventory"]["equipment"][ItemTable.slot(kind)] = kind
	sim.restore(snap)


## Steps `ticks` ticks and returns the warmth after each.
static func _warmth_trace(sim: Sim, ticks: int) -> Array:
	var out := []
	for i in ticks:
		sim.step()
		out.append(int(sim.state["warmth"]))
	return out
