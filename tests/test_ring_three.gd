## Ring three: the glacier south of ring two, behind a gate in ring two's southern cliffs that
## the Ring-three gate hoist opens on its own. The gate is walked through both ways and nothing
## follows; the first arrival is marked once; a fire burns past the gate; and nothing notices,
## chases or fights across either ring gate.
extends "res://tests/run.gd".TestCase

const H := preload("res://tests/sim_helpers.gd")
const SimScript := preload("res://sim/sim.gd")
const Vocab := preload("res://sim/vocab.gd")
const WorldDefScript := preload("res://sim/world_def.gd")

## Ring two's side of the gate, in the alcove's mouth, and ring three's, just through it.
const NORTH_OF_GATE := [-39.5, 121.5]
const PAST_THE_GATE := [-39.5, 131.5]
## Standing at the workbench, inside the outpost.
const AT_WORKBENCH := [-2.0, -5.0]
const UPGRADES_TO_THE_FURNACE := ["stash_shelves", "forge", "armoury", "ring_two_gate", "blast_furnace"]


## A character whose ring-three gate stands open: the hoist is built. The captain still stands.
func _gate_open() -> Sim:
	var sim := SimScript.new()
	H.patch(sim, {"upgrades": UPGRADES_TO_THE_FURNACE + ["ring_three_gate"]})
	return sim


func _sturdy(sim: Sim) -> void:
	var snap := sim.snapshot()
	snap["inventory"]["equipment"].merge({"helm": "steel_helm", "body": "steel_body", "legs": "steel_legs"}, true)
	sim.restore(snap)


func _pass(sim: Sim) -> Array[Dictionary]:
	sim.drain_events()
	var result := sim.command(Vocab.INTERACT, {"object_id": "ring_three_gate"})
	assert_true(result["ok"], result["reason"])
	return H.run_until_idle(sim, 40)


## A stash holding the hoist's cost, with the player at the workbench.
func _hoist_ready(sim: Sim) -> void:
	var slots := Inventory.empty_slots(12)
	var cost: Dictionary = UpgradeTable.get_upgrade("ring_three_gate")["cost"]
	for kind in cost:
		Inventory.add(slots, kind, int(cost[kind]))
	H.patch(sim, {"stash": {"capacity": 12, "slots": slots}})
	H.place(sim, AT_WORKBENCH)


# --- The ground ---------------------------------------------------------------------------

func test_ring_three_lies_south_of_ring_twos_cliffs() -> void:
	var w := WorldDefScript.outpost()
	assert_eq(w.rows, 256, "the grid runs on south")
	assert_eq(w.cols, 128)
	assert_eq(w.origin, [-64.0, -64.0])
	for at in [Vector2(0.5, 64.5), Vector2(0.5, 100.0), Vector2(-50.0, 127.5), Vector2(63.5, 0.0)]:
		assert_eq(w.region_at(at), WorldDef.REGION_RING_TWO, "ring two at %s" % at)
	for at in [Vector2(0.5, 128.5), Vector2(-59.5, 140.0), Vector2(59.5, 187.5), Vector2(0.5, 191.5)]:
		assert_eq(w.region_at(at), WorldDef.REGION_RING_THREE, "ring three at %s" % at)
	# Walkable from x -60 to 60 and z 128 to 188, cliffs on every other side.
	assert_true(w.is_walkable(Vector2(-59.5, 128.5)) and w.is_walkable(Vector2(59.5, 187.5)))
	for at in [Vector2(-60.5, 150.0), Vector2(60.5, 150.0), Vector2(0.5, 188.5), Vector2(0.5, 191.5)]:
		assert_false(w.is_walkable(at), "a cliff at %s" % at)


## Flooding the walkable ground from just past the gate never reaches ring two: the gate's own
## cells block, and so does every cliff around it.
func test_ring_three_is_walled_off_from_ring_two_but_for_the_gate() -> void:
	var w := WorldDefScript.outpost()
	var start := w.cell_of(Vector2(PAST_THE_GATE[0], PAST_THE_GATE[1]))
	var seen := {start: true}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_back()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if not seen.has(n) and w.is_walkable_cell(n):
				seen[n] = true
				queue.append(n)
	var gate := w.object_center("ring_three_gate")
	for c: Vector2i in seen:
		var at := w.cell_center(c)
		assert_true(at.y > gate.y, "%s is past the gate" % at)
		assert_eq(w.region_at(at), WorldDef.REGION_RING_THREE, "%s is ring three's" % at)
	assert_true(seen.size() > 120 * 50, "and all of ring three's open ice is one piece")


func test_the_gate_is_the_only_way_between_ring_two_and_three() -> void:
	var sim := _gate_open()
	H.place(sim, NORTH_OF_GATE)
	assert_eq(sim.command(Vocab.MOVE_TO, {"pos": PAST_THE_GATE})["reason"], Vocab.REASON_UNREACHABLE, "no route around it")
	H.place(sim, PAST_THE_GATE)
	assert_eq(sim.command(Vocab.MOVE_TO, {"pos": NORTH_OF_GATE})["reason"], Vocab.REASON_UNREACHABLE)
	assert_eq(sim.command(Vocab.MOVE_TO, {"pos": [0.5, 100.5]})["reason"], Vocab.REASON_UNREACHABLE, "nor to anywhere in ring two")
	assert_eq(sim.command(Vocab.INTERACT, {"object_id": "ring_two_waystone"})["reason"], Vocab.REASON_UNREACHABLE)
	assert_eq(sim.command(Vocab.CROSS_GATE)["reason"], Vocab.REASON_UNREACHABLE, "the outpost gate is back through both")


func test_ring_three_has_no_nodes_and_no_waystone() -> void:
	var w := WorldDefScript.outpost()
	for id in w.objects:
		if w.region_at(w.object_center(id)) != WorldDef.REGION_RING_THREE:
			continue
		assert_false(w.node_ids().has(id), "%s is not a node" % id)
		assert_true(w.objects[id]["kind"] != WorldDef.KIND_WAYSTONE, "%s is not a waystone" % id)
	assert_eq(UpgradeTable.get_upgrade("waystone")["effects"]["waystones"], ["ring_one_waystone", "ring_two_waystone"])


func test_every_object_in_ring_three_is_reached_from_inside_it() -> void:
	var w := WorldDefScript.outpost()
	var from := w.cell_of(Vector2(PAST_THE_GATE[0], PAST_THE_GATE[1]))
	var count := 0
	for id in w.objects:
		if w.region_at(w.object_center(id)) != WorldDef.REGION_RING_THREE:
			continue
		count += 1
		var reachable := false
		for cell in w.approach_cells(id):
			reachable = reachable or not GridPath.find(w, from, cell).is_empty()
		assert_true(reachable, "%s can be walked to" % id)
	assert_true(count >= 1, "the fire stands in ring three")
	for at in [[-59.5, 187.5], [59.5, 129.5], [0.5, 160.5]]:
		assert_false(GridPath.find(w, from, w.cell_of(Vector2(at[0], at[1]))).is_empty(), "the ice at %s is reached" % [at])


# --- The gate -----------------------------------------------------------------------------

func test_the_gate_stands_in_ring_twos_southern_cliff_out_of_every_sight() -> void:
	var w := WorldDefScript.outpost()
	var gate: Dictionary = w.objects["ring_three_gate"]
	assert_eq(gate["kind"], WorldDef.KIND_RING_GATE)
	assert_true(gate["blocks"], "barred: nothing walks through it")
	assert_false(gate.has("guardian"), "no guardian holds it")
	assert_eq(gate["upgrade"], "ring_three_gate")
	assert_eq(gate["outward"], [0.0, 1.0])
	var two: Dictionary = w.objects["ring_two_gate"]
	assert_eq([gate["max"][0] - gate["min"][0], gate["max"][1] - gate["min"][1], gate["height"]], [two["max"][0] - two["min"][0], two["max"][1] - two["min"][1], two["height"]], "shaped like the ring-two gate")
	var at := w.object_center("ring_three_gate")
	assert_true(at.y > 124.0 and at.y < 128.0, "in the southern cliff")
	assert_true(at.x < -30.0, "in its south-west")
	assert_true(at.distance_to(w.object_center("ring_two_waystone")) >= 30.0, "a stretch of ring two from its waystone")
	for id in w.enemies:
		var home := Vector2(w.enemies[id]["home"][0], w.enemies[id]["home"][1])
		if w.region_at(home) != WorldDef.REGION_RING_TWO:
			continue
		var sight := float(CombatTable.enemy(w.enemies[id]["kind"])["sight"])
		for cell in w.approach_cells("ring_three_gate"):
			assert_true(w.cell_center(cell).distance_to(home) > sight, "%s does not see the gate's step %s" % [id, w.cell_center(cell)])


func test_the_gate_opens_on_the_hoist_alone() -> void:
	var sim := SimScript.new()
	H.patch(sim, {"upgrades": UPGRADES_TO_THE_FURNACE.duplicate()})
	assert_false(sim.ring_gate_open("ring_three_gate"), "barred before the hoist")
	H.patch(sim, {"bosses_defeated": ["captain"]})
	assert_false(sim.ring_gate_open("ring_three_gate"), "the captain's fall does not open it")
	assert_true(sim.ring_gate_open("ring_two_gate"), "though it opens his")
	H.patch(sim, {"bosses_defeated": [], "upgrades": UPGRADES_TO_THE_FURNACE + ["ring_three_gate"]})
	assert_true(sim.ring_gate_open("ring_three_gate"), "the hoist alone opens it")
	assert_false(sim.ring_gate_open("ring_two_gate"), "the ring-two gate still needs the captain as well as the winch")


func test_building_the_hoist_opens_the_gate() -> void:
	var sim := SimScript.new()
	H.patch(sim, {"upgrades": UPGRADES_TO_THE_FURNACE.duplicate()})
	_hoist_ready(sim)
	sim.drain_events()
	assert_true(sim.command(Vocab.BUILD, {"upgrade": "ring_three_gate"})["ok"])
	var events := H.run(sim, 1)
	assert_eq(H.of_kind(events, Vocab.EV_BUILT)[0]["upgrade"], "ring_three_gate")
	var opened := H.of_kind(events, Vocab.EV_RING_GATE_OPENED)
	assert_eq(opened.size(), 1, "one gate opened")
	assert_eq(opened[0]["object_id"], "ring_three_gate")
	assert_true(sim.ring_gate_open("ring_three_gate"))
	assert_eq(H.stash_count(sim, "steel_bar"), 0, "paid for")


func test_the_hoist_costs_steel_hides_coal_and_logs_and_needs_the_blast_furnace() -> void:
	var hoist := UpgradeTable.get_upgrade("ring_three_gate")
	assert_eq(hoist["label"], "Ring-three gate hoist")
	assert_eq(hoist["cost"], {"steel_bar": 8, "troll_hide": 4, "coal": 12, "logs": 16})
	assert_eq(hoist["requires"], ["blast_furnace"])
	assert_eq(hoist["effects"], {"ring_gate": "ring_three_gate"})
	var sim := SimScript.new()
	H.patch(sim, {"upgrades": ["stash_shelves", "forge", "armoury", "ring_two_gate"]})
	_hoist_ready(sim)
	assert_eq(sim.command(Vocab.BUILD, {"upgrade": "ring_three_gate"})["reason"], Vocab.REASON_UPGRADE_MISSING, "refused before the blast furnace")


func test_the_open_gate_is_walked_through_both_ways() -> void:
	var sim := _gate_open()
	H.place(sim, NORTH_OF_GATE)
	H.set_pack(sim, [{"item": "steel_bar", "count": 2}])
	var gate := sim.world.object_center("ring_three_gate")
	var into := _pass(sim)
	assert_eq(sim.state["player"]["region"], WorldDef.REGION_RING_THREE, "through to ring three")
	assert_almost_eq(sim.player_pos().y, gate.y + Sim.RING_GATE_STEP, 0.01, "a gate step past it")
	assert_false(sim.is_moving(), "and standing there")
	assert_eq(H.pack_count(sim, "steel_bar"), 2, "still in the pack, still at risk")
	var reached := H.of_kind(into, Vocab.EV_RING_THREE_REACHED)
	assert_eq(reached.size(), 1, "the first arrival is marked")
	assert_eq(reached[0]["object_id"], "ring_three_gate")
	assert_eq(H.of_kind(into, Vocab.EV_SAVED)[-1]["reason"], "ring_three", "and is a save point")
	assert_eq(sim.state["rings_reached"], [WorldDef.REGION_RING_THREE])
	assert_eq(H.of_kind(into, Vocab.EV_RING_TWO_REACHED).size(), 0, "ring two's arrival is its own")
	var back := _pass(sim)
	assert_eq(sim.state["player"]["region"], WorldDef.REGION_RING_TWO, "back through to ring two")
	assert_almost_eq(sim.player_pos().y, gate.y - Sim.RING_GATE_STEP, 0.01, "a gate step short of it")
	assert_eq(H.of_kind(back, Vocab.EV_RING_THREE_REACHED).size(), 0)
	var again := _pass(sim)
	assert_eq(sim.state["player"]["region"], WorldDef.REGION_RING_THREE)
	assert_eq(H.of_kind(again, Vocab.EV_RING_THREE_REACHED).size(), 0, "only the first arrival is marked")
	assert_eq(H.of_kind(again, Vocab.EV_SAVED).size(), 0)


func test_ring_three_stays_reached_through_a_save() -> void:
	var sim := _gate_open()
	H.place(sim, NORTH_OF_GATE)
	_pass(sim)
	var other := SimScript.new()
	assert_true(other.restore(sim.snapshot()))
	assert_eq(other.state["rings_reached"], [WorldDef.REGION_RING_THREE], "restore keeps it")
	var imported := SimScript.new()
	assert_true(imported.command(Vocab.IMPORT_SAVE, {"code": sim.export_code()})["ok"])
	assert_eq(imported.state["rings_reached"], [WorldDef.REGION_RING_THREE], "and so does a save code")
	H.place(other, NORTH_OF_GATE)
	other.drain_events()
	assert_eq(H.of_kind(_pass(other), Vocab.EV_RING_THREE_REACHED).size(), 0, "not announced again")


func test_a_barred_gate_is_not_walked_through() -> void:
	var sim := SimScript.new()
	H.patch(sim, {"upgrades": UPGRADES_TO_THE_FURNACE.duplicate(), "bosses_defeated": ["captain"]})
	H.place(sim, NORTH_OF_GATE)
	var events := _pass(sim)
	assert_eq(sim.state["player"]["region"], WorldDef.REGION_RING_TWO)
	assert_eq(H.of_kind(events, Vocab.EV_INTERACTED)[0]["action"], Vocab.ACTION_RING_GATE)
	assert_eq(H.of_kind(events, Vocab.EV_RING_THREE_REACHED).size(), 0)


func test_the_fire_past_the_gate_warms_and_heals() -> void:
	var sim := _gate_open()
	H.place(sim, PAST_THE_GATE)
	H.patch(sim, {"warmth": 100, "health": 40})
	assert_true(sim.command(Vocab.INTERACT, {"object_id": "ring_three_fire"})["ok"])
	var events := H.run_until_idle(sim, 20)
	assert_eq(H.of_kind(events, Vocab.EV_INTERACTED)[0]["action"], Vocab.ACTION_WARM)
	assert_true(sim.world.distance_to_object("ring_three_fire", sim.player_pos()) <= Sim.FIRE_REACH)
	assert_true(sim.near_fire())
	var warmth := int(sim.state["warmth"])
	var health := int(sim.state["health"])
	H.run(sim, 3)
	assert_eq(int(sim.state["warmth"]), mini(Sim.WARMTH_MAX, warmth + 3 * Sim.FIRE_WARMTH), "it warms like the outpost fire")
	assert_eq(int(sim.state["health"]), health + 3 * Sim.FIRE_HEALTH, "and heals")
	var fire := sim.world.object_center("ring_three_fire")
	var gate := sim.world.object_center("ring_three_gate")
	assert_true(fire.distance_to(gate) < 10.0, "a few metres in from the gate")


func test_warmth_drains_in_ring_three() -> void:
	var sim := _gate_open()
	H.place(sim, [0.5, 160.5])
	H.run(sim, 5)
	assert_eq(int(sim.state["warmth"]), Sim.WARMTH_MAX - 5 * Sim.WARMTH_DRAIN, "cold on the glacier")


# --- Nothing crosses the gate -------------------------------------------------------------

func test_ring_two_does_not_notice_a_player_through_the_gate() -> void:
	var sim := _gate_open()
	H.patch_enemy(sim, "stalker_5", {"pos": [-39.5, 122.5]})
	H.place(sim, [-39.5, 131.5])  # 9 m off, inside its sight but past the gate
	var events := H.run(sim, 3)
	assert_eq(H.where(events, Vocab.EV_ENEMY_NOTICED, "enemy_id", "stalker_5").size(), 0, "deaf and blind through the gate")
	H.place(sim, [-39.5, 115.5])
	events = H.run(sim, 1)
	assert_eq(H.where(events, Vocab.EV_ENEMY_NOTICED, "enemy_id", "stalker_5").size(), 1, "but not on its own side")


func test_ring_two_breaks_off_when_the_player_passes_the_gate() -> void:
	var sim := _gate_open()
	_sturdy(sim)
	H.patch_enemy(sim, "stalker_5", {"pos": [-39.5, 115.5]})
	H.place(sim, [-39.5, 121.5])
	H.run(sim, 2)
	assert_eq(sim.state["enemies"]["stalker_5"]["mode"], Sim.MODE_ENGAGED, "the stalker joins the fight")
	_pass(sim)
	assert_eq(sim.state["player"]["region"], WorldDef.REGION_RING_THREE)
	assert_eq(sim.state["enemies"]["stalker_5"]["mode"], Sim.MODE_RETURNING, "and breaks off")
	assert_eq(sim.command(Vocab.ATTACK, {"enemy_id": "stalker_5"})["reason"], Vocab.REASON_UNREACHABLE, "it can't be fought across")
	assert_eq(sim.command(Vocab.ATTACK, {"enemy_id": "wolf_1"})["reason"], Vocab.REASON_UNREACHABLE, "nor can ring one, two gates back")


func test_bands_part_the_world_at_each_ring_gate() -> void:
	assert_eq(Sim._band(WorldDef.REGION_OUTPOST), 0)
	assert_eq(Sim._band(WorldDef.REGION_INNER_RING), 0)
	assert_eq(Sim._band(WorldDef.REGION_RING_ONE), 0)
	assert_eq(Sim._band(WorldDef.REGION_RING_TWO), 1)
	assert_eq(Sim._band(WorldDef.REGION_RING_THREE), 2)


# --- Saves --------------------------------------------------------------------------------

func test_every_save_fixture_loads_with_ring_three_unreached_and_the_hoist_unbuilt() -> void:
	var dir := DirAccess.open("res://tests/fixtures")
	var count := 0
	for name in dir.get_files():
		if not name.ends_with(".txt"):
			continue
		var sim := SimScript.new()
		var code := FileAccess.get_file_as_string("res://tests/fixtures/" + name).strip_edges()
		assert_true(sim.command(Vocab.IMPORT_SAVE, {"code": code})["ok"], "%s loads" % name)
		assert_false((sim.state["rings_reached"] as Array).has(WorldDef.REGION_RING_THREE), "%s has not reached ring three" % name)
		assert_false((sim.state["upgrades"] as Array).has("ring_three_gate"), "%s has not built the hoist" % name)
		assert_false(sim.ring_gate_open("ring_three_gate"), "%s finds the gate barred" % name)
		count += 1
	assert_true(count > 0, "some fixtures")
