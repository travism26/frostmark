## The ring-one dungeon as a place: a pocket of the grid east of ring one, walled off by cliffs
## from every ring but through its mouth in ring one's east cliff. The mouth is always open and
## walked through both ways; nothing notices, chases or fights across it; the first walk in is
## marked once and kept by a save; and the dungeon table reserves the ground the fire, the
## fights, the death chest, the boss and the way out will take.
extends "res://tests/run.gd".TestCase

const H := preload("res://tests/sim_helpers.gd")
const SimScript := preload("res://sim/sim.gd")
const Vocab := preload("res://sim/vocab.gd")
const WorldDefScript := preload("res://sim/world_def.gd")

const DUNGEON := "ring_one_dungeon"
const MOUTH := "ring_one_dungeon_mouth"
## Ring one's side of the mouth, and the dungeon's, just through it.
const OUTSIDE := [57.5, -47.0]
const INSIDE := [66.5, -47.0]


func _pass(sim: Sim) -> Array[Dictionary]:
	sim.drain_events()
	var result := sim.command(Vocab.INTERACT, {"object_id": MOUTH})
	assert_true(result["ok"], result["reason"])
	return H.run_until_idle(sim, 40)


func _sturdy(sim: Sim) -> void:
	var snap := sim.snapshot()
	snap["inventory"]["equipment"].merge({"helm": "steel_helm", "body": "steel_body", "legs": "steel_legs"}, true)
	sim.restore(snap)


## Every walkable cell reached from `from` by four-way steps.
static func _flood(w: WorldDef, from: Vector2) -> Dictionary:
	var start := w.cell_of(from)
	var seen := {start: true}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_back()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if not seen.has(n) and w.is_walkable_cell(n):
				seen[n] = true
				queue.append(n)
	return seen


## The region a point had before the dungeon: the rings' rectangles, innermost first.
static func _old_region(pos: Vector2) -> String:
	if absf(pos.x) < 10.0 and absf(pos.y) < 10.0:
		return WorldDef.REGION_OUTPOST
	if absf(pos.x) < 24.0 and absf(pos.y) < 24.0:
		return WorldDef.REGION_INNER_RING
	if absf(pos.x) < 60.0 and absf(pos.y) < 60.0:
		return WorldDef.REGION_RING_ONE
	return WorldDef.REGION_RING_TWO if pos.y < WorldDef.RING_TWO_FAR else WorldDef.REGION_RING_THREE


static func _spot(at: Array) -> Vector2:
	return Vector2(at[0], at[1])


# --- The ground ---------------------------------------------------------------------------

func test_the_grid_grows_east_and_every_ring_keeps_its_ground() -> void:
	var w := WorldDefScript.outpost()
	assert_eq(w.origin, [-64.0, -64.0])
	assert_eq([w.cols, w.rows], [176, 256], "the grid runs on east of the rings, as far south as before")
	assert_eq(w.regions[0]["name"], WorldDef.REGION_RING_ONE_DUNGEON, "the dungeon comes ahead of every ring")
	for at in [Vector2(64.5, -59.5), Vector2(107.5, 59.5), Vector2(86.0, 0.0)]:
		assert_eq(w.region_at(at), WorldDef.REGION_RING_ONE_DUNGEON, "the dungeon at %s" % at)
	# Every cell of the old grid, x -64 to 64, keeps the region it had, but for the mouth's own
	# cells in ring one's cliff, which are the dungeon's so that the walk through never crosses
	# ring two's.
	var changed := 0
	for z in range(-64, 192):
		for x in range(-64, 64):
			var at := Vector2(x + 0.5, z + 0.5)
			if w.distance_to_object(MOUTH, at) == 0.0:
				assert_eq(w.region_at(at), WorldDef.REGION_RING_ONE_DUNGEON, "the mouth's cell %s is the dungeon's" % at)
			elif w.region_at(at) != _old_region(at):
				changed += 1
	assert_eq(changed, 0, "no ring's ground moved")


func test_the_new_ground_is_walked_only_inside_the_dungeon() -> void:
	var w := WorldDefScript.outpost()
	var walkable := 0
	for y in w.rows:
		for x in range(int(WorldDef.RINGS_EAST - w.origin[0]), w.cols):
			var cell := Vector2i(x, y)
			if w.is_walkable_cell(cell):
				walkable += 1
				assert_eq(w.region_at(w.cell_center(cell)), WorldDef.REGION_RING_ONE_DUNGEON, "%s is the dungeon's" % cell)
	assert_true(walkable > 4000, "the pocket is open ground")


## Flooding the walkable ground from just inside the mouth never leaves the dungeon: the mouth's
## own cells block, and so does every cliff around it.
func test_the_dungeon_is_walled_off_from_every_ring_but_by_its_mouth() -> void:
	var w := WorldDefScript.outpost()
	var inside := _flood(w, _spot(INSIDE))
	for c: Vector2i in inside:
		assert_eq(w.region_at(w.cell_center(c)), WorldDef.REGION_RING_ONE_DUNGEON, "%s is the dungeon's" % w.cell_center(c))
	assert_true(inside.size() > 4000, "and all of its ground is one piece")
	var outside := _flood(w, _spot(OUTSIDE))
	assert_true(outside.has(w.cell_of(Vector2(w.spawn[0], w.spawn[1]))), "ring one's side of the mouth is the outpost's ground")
	for c: Vector2i in outside:
		assert_false(inside.has(c), "%s is not reached from both sides" % w.cell_center(c))


func test_no_route_crosses_the_mouth() -> void:
	var sim := SimScript.new()
	H.place(sim, OUTSIDE)
	assert_eq(sim.command(Vocab.MOVE_TO, {"pos": INSIDE})["reason"], Vocab.REASON_UNREACHABLE, "no route around it")
	assert_eq(sim.command(Vocab.MOVE_TO, {"pos": [100.5, 40.5]})["reason"], Vocab.REASON_UNREACHABLE, "nor deep inside")
	H.place(sim, INSIDE)
	assert_eq(sim.command(Vocab.MOVE_TO, {"pos": OUTSIDE})["reason"], Vocab.REASON_UNREACHABLE)
	assert_eq(sim.command(Vocab.MOVE_TO, {"pos": [0.5, 30.5]})["reason"], Vocab.REASON_UNREACHABLE, "nor to anywhere in ring one")
	assert_eq(sim.command(Vocab.INTERACT, {"object_id": "ring_one_waystone"})["reason"], Vocab.REASON_UNREACHABLE)
	assert_eq(sim.command(Vocab.CROSS_GATE)["reason"], Vocab.REASON_UNREACHABLE, "the outpost gate is back through the mouth")
	assert_true(sim.command(Vocab.MOVE_TO, {"pos": [100.5, 40.5]})["ok"], "but the far end is walked to from inside")


# --- The mouth ----------------------------------------------------------------------------

func test_the_mouth_is_an_always_open_ring_gate_in_ring_ones_east_cliff() -> void:
	var w := WorldDefScript.outpost()
	var mouth: Dictionary = w.objects[MOUTH]
	assert_eq(mouth["kind"], WorldDef.KIND_RING_GATE)
	assert_true(mouth["blocks"], "it always blocks the grid: the walk through is the only way")
	assert_false(mouth.has("upgrade"), "no upgrade opens it")
	assert_false(mouth.has("guardian"), "no guardian holds it")
	assert_eq(mouth["outward"], [1.0, 0.0], "it opens east, into the dungeon")
	var at := w.object_center(MOUTH)
	assert_true(at.x > 60.0 and at.x < 64.0, "in ring one's east cliff")
	assert_true(at.y > -60.0 and at.y < 60.0, "alongside ring one")
	for cell in w.approach_cells(MOUTH):
		var region := w.region_at(w.cell_center(cell))
		assert_true(region in [WorldDef.REGION_RING_ONE, WorldDef.REGION_RING_ONE_DUNGEON], "%s steps up to it from ring one or the dungeon" % w.cell_center(cell))
	var sim := SimScript.new()
	assert_true(sim.ring_gate_open(MOUTH), "a new character finds it open")
	for id in ["captain", "witch_1", "witch_2"]:
		var home := _spot(w.enemies[id]["home"])
		var sight := float(CombatTable.enemy(w.enemies[id]["kind"])["sight"])
		for cell in w.approach_cells(MOUTH):
			assert_true(w.cell_center(cell).distance_to(home) > sight, "%s does not see the mouth's step %s" % [id, w.cell_center(cell)])


func test_the_road_to_the_captain_does_not_pass_the_mouth() -> void:
	var sim := SimScript.new()
	assert_true(sim.command(Vocab.MOVE_TO, {"pos": [0.5, 54.5]})["ok"])
	var mouth := sim.world.object_center(MOUTH)
	for p in sim.state["player"]["path"]:
		assert_true(_spot(p).distance_to(mouth) > 40.0, "the road at %s keeps well clear of the mouth" % [p])


func test_the_mouth_is_walked_through_both_ways() -> void:
	var sim := SimScript.new()
	H.place(sim, OUTSIDE)
	H.set_pack(sim, [{"item": "iron_ore", "count": 2}])
	var mouth := sim.world.object_center(MOUTH)
	var into := _pass(sim)
	assert_eq(sim.state["player"]["region"], WorldDef.REGION_RING_ONE_DUNGEON, "through to the dungeon")
	assert_almost_eq(sim.player_pos().x, mouth.x + Sim.RING_GATE_STEP, 0.01, "a gate step past it")
	assert_almost_eq(sim.player_pos().y, mouth.y, 0.01)
	assert_false(sim.is_moving(), "and standing there")
	assert_eq(H.pack_count(sim, "iron_ore"), 2, "still in the pack, still at risk")
	assert_eq(H.of_kind(into, Vocab.EV_INTERACTED)[0]["action"], Vocab.ACTION_RING_GATE, "the mouth works like a ring gate")
	var back := _pass(sim)
	assert_eq(sim.state["player"]["region"], WorldDef.REGION_RING_ONE, "back through to ring one")
	assert_almost_eq(sim.player_pos().x, mouth.x - Sim.RING_GATE_STEP, 0.01, "a gate step short of it")
	assert_eq(H.of_kind(back, Vocab.EV_DUNGEON_REACHED).size(), 0)


# --- Nothing crosses the mouth ------------------------------------------------------------

func test_the_dungeon_has_a_band_of_its_own() -> void:
	var band := Sim._band(WorldDef.REGION_RING_ONE_DUNGEON)
	for ring in [WorldDef.REGION_OUTPOST, WorldDef.REGION_INNER_RING, WorldDef.REGION_RING_ONE, WorldDef.REGION_RING_TWO, WorldDef.REGION_RING_THREE]:
		assert_true(Sim._band(ring) != band, "no ring shares it: %s" % ring)


func test_ring_one_does_not_notice_a_player_through_the_mouth() -> void:
	var sim := SimScript.new()
	H.patch_enemy(sim, "archer_3", {"pos": [58.5, -47.5]})
	H.place(sim, [65.5, -47.5])  # 7 m off, inside its sight but past the mouth
	var events := H.run(sim, 3)
	assert_eq(H.where(events, Vocab.EV_ENEMY_NOTICED, "enemy_id", "archer_3").size(), 0, "deaf and blind through the mouth")
	assert_eq(sim.command(Vocab.ATTACK, {"enemy_id": "archer_3"})["reason"], Vocab.REASON_UNREACHABLE, "it can't be shot from inside")
	H.place(sim, [54.5, -47.5])
	events = H.run(sim, 1)
	assert_eq(H.where(events, Vocab.EV_ENEMY_NOTICED, "enemy_id", "archer_3").size(), 1, "but not on its own side")


func test_ring_one_breaks_off_when_the_player_walks_in() -> void:
	var sim := SimScript.new()
	_sturdy(sim)
	H.patch_enemy(sim, "archer_3", {"pos": [53.5, -47.5]})
	H.place(sim, OUTSIDE)
	H.run(sim, 2)
	assert_eq(sim.state["enemies"]["archer_3"]["mode"], Sim.MODE_ENGAGED, "the archer joins the fight")
	_pass(sim)
	assert_eq(sim.state["player"]["region"], WorldDef.REGION_RING_ONE_DUNGEON)
	assert_eq(sim.state["enemies"]["archer_3"]["mode"], Sim.MODE_RETURNING, "and breaks off")
	assert_eq(sim.command(Vocab.ATTACK, {"enemy_id": "archer_3"})["reason"], Vocab.REASON_UNREACHABLE, "it can't be fought across")
	assert_eq(sim.command(Vocab.ATTACK, {"enemy_id": "wolf_1"})["reason"], Vocab.REASON_UNREACHABLE, "nor can anything else in ring one")


func test_warmth_drains_inside() -> void:
	var sim := SimScript.new()
	H.place(sim, [86.5, -19.5])
	H.run(sim, 5)
	assert_eq(int(sim.state["warmth"]), Sim.WARMTH_MAX - 5 * Sim.WARMTH_DRAIN, "cold in the dark")


# --- First arrival ------------------------------------------------------------------------

func test_the_first_walk_in_is_marked_once_and_is_a_save_point() -> void:
	var sim := SimScript.new()
	H.place(sim, OUTSIDE)
	var into := _pass(sim)
	var reached := H.of_kind(into, Vocab.EV_DUNGEON_REACHED)
	assert_eq(reached.size(), 1, "the first arrival is marked")
	assert_eq(reached[0]["dungeon_id"], DUNGEON, "with the dungeon's id")
	assert_eq(reached[0]["object_id"], MOUTH)
	assert_eq(H.of_kind(into, Vocab.EV_SAVED)[-1]["reason"], DUNGEON, "and is a save point")
	assert_eq(sim.state["dungeons_reached"], [DUNGEON])
	assert_eq(sim.state["rings_reached"], [], "it is no ring's arrival")
	assert_eq(H.of_kind(into, Vocab.EV_RING_TWO_REACHED).size(), 0, "and the walk through never crosses ring two's ground")
	var changes := H.of_kind(into, Vocab.EV_REGION_CHANGED)
	assert_eq(changes.size(), 1, "one step from ring one into the dungeon")
	assert_eq([changes[0]["from"], changes[0]["to"]], [WorldDef.REGION_RING_ONE, WorldDef.REGION_RING_ONE_DUNGEON])
	_pass(sim)
	var again := _pass(sim)
	assert_eq(sim.state["player"]["region"], WorldDef.REGION_RING_ONE_DUNGEON)
	assert_eq(H.of_kind(again, Vocab.EV_DUNGEON_REACHED).size(), 0, "only the first arrival is marked")
	assert_eq(H.of_kind(again, Vocab.EV_SAVED).size(), 0)


func test_the_dungeon_stays_reached_through_a_save() -> void:
	var sim := SimScript.new()
	H.place(sim, OUTSIDE)
	_pass(sim)
	var other := SimScript.new()
	assert_true(other.restore(sim.snapshot()))
	assert_eq(other.state["dungeons_reached"], [DUNGEON], "restore keeps it")
	var imported := SimScript.new()
	assert_true(imported.command(Vocab.IMPORT_SAVE, {"code": sim.export_code()})["ok"])
	assert_eq(imported.state["dungeons_reached"], [DUNGEON], "and so does a save code")
	_pass(other)
	other.drain_events()
	assert_eq(H.of_kind(_pass(other), Vocab.EV_DUNGEON_REACHED).size(), 0, "not announced again")


func test_a_save_without_the_entry_or_with_a_bad_one_loads_unreached() -> void:
	for bad in [null, "ring_one_dungeon", ["no_such_dungeon", 7, DUNGEON, DUNGEON]]:
		var sim := SimScript.new()
		var snap := sim.snapshot()
		if bad == null:
			snap.erase("dungeons_reached")
		else:
			snap["dungeons_reached"] = bad
		assert_true(sim.restore(snap), "%s loads" % [bad])
		var expected := [DUNGEON] if bad is Array else []
		assert_eq(sim.state["dungeons_reached"], expected, "%s keeps only known dungeons, once" % [bad])


func test_every_save_fixture_loads_with_the_dungeon_unreached() -> void:
	var dir := DirAccess.open("res://tests/fixtures")
	var count := 0
	for name in dir.get_files():
		if not name.ends_with(".txt"):
			continue
		var sim := SimScript.new()
		var code := FileAccess.get_file_as_string("res://tests/fixtures/" + name).strip_edges()
		assert_true(sim.command(Vocab.IMPORT_SAVE, {"code": code})["ok"], "%s loads" % name)
		assert_eq(sim.state["dungeons_reached"], [], "%s has not reached the dungeon" % name)
		assert_true(sim.ring_gate_open(MOUTH), "%s finds the mouth open" % name)
		count += 1
	assert_true(count > 0, "some fixtures")


# --- The dungeon table and the reserved layout ---------------------------------------------

func test_the_dungeon_table_names_this_dungeon() -> void:
	var d: Dictionary = WorldDef.DUNGEONS[DUNGEON]
	assert_eq(d["ring"], WorldDef.REGION_RING_ONE)
	assert_eq(d["depth"], WorldDef.DUNGEON_GENTLE)
	assert_eq(d["region"], WorldDef.REGION_RING_ONE_DUNGEON)
	assert_eq(d["mouth"], MOUTH)
	assert_eq(WorldDef.dungeon_of_region(WorldDef.REGION_RING_ONE_DUNGEON), DUNGEON)
	assert_eq(WorldDef.dungeon_of_region(WorldDef.REGION_RING_ONE), "")
	assert_eq(WorldDef.dungeon_of_mouth(MOUTH), DUNGEON)
	assert_eq(WorldDef.dungeon_of_mouth("ring_two_gate"), "")


func test_the_reserved_spots_are_the_dungeons_open_ground_reached_from_the_mouth() -> void:
	var w := WorldDefScript.outpost()
	var r: Dictionary = WorldDef.DUNGEONS[DUNGEON]["reserved"]
	var inside := _flood(w, _spot(INSIDE))
	var spots: Array = [r["fire"], r["chest"], r["boss"], r["way_out"]] + r["fights"] + r["nodes"]
	for at in spots:
		var p := _spot(at)
		assert_eq(w.region_at(p), WorldDef.REGION_RING_ONE_DUNGEON, "%s is in the dungeon" % p)
		assert_true(w.is_walkable_with_margin(p, 1.0), "%s is open ground a metre round" % p)
		assert_true(inside.has(w.cell_of(p)), "%s is reached from the mouth" % p)
	for i in spots.size():
		for j in range(i + 1, spots.size()):
			assert_true(_spot(spots[i]).distance_to(_spot(spots[j])) >= 3.0, "%s and %s do not collide" % [spots[i], spots[j]])
	var room: Array = r["boss_room"]
	for at in [r["boss"], r["way_out"]]:
		var p := _spot(at)
		assert_true(p.x > room[0][0] and p.x < room[1][0] and p.y > room[0][1] and p.y < room[1][1], "%s is in the boss room" % p)
	for at in r["fights"] + r["nodes"] + [r["fire"], r["chest"]]:
		var p := _spot(at)
		assert_false(p.x > room[0][0] and p.x < room[1][0] and p.y > room[0][1] and p.y < room[1][1], "%s is short of the boss room" % p)


func test_the_fire_and_chest_spots_are_just_inside_the_mouth() -> void:
	var w := WorldDefScript.outpost()
	var r: Dictionary = WorldDef.DUNGEONS[DUNGEON]["reserved"]
	for at in [r["fire"], r["chest"]]:
		assert_true(w.distance_to_object(MOUTH, _spot(at)) < 10.0, "%s is a few metres in" % [at])


## Three or four fights in a lane from the mouth to the boss room, each out of a fight's noise
## and every ring-one kind's sight of the next, of the fire and of the boss, and farther along
## the lane than the one before.
func test_the_fight_lane_runs_from_the_mouth_to_the_boss_with_each_fight_on_its_own() -> void:
	var w := WorldDefScript.outpost()
	var r: Dictionary = WorldDef.DUNGEONS[DUNGEON]["reserved"]
	var fights: Array = r["fights"]
	assert_true(fights.size() >= 3 and fights.size() <= 4, "three or four fights")
	var apart := CombatTable.NOISE_FIGHT
	for kind in ["wolf", "bandit_archer", "frost_witch"]:
		apart = maxf(apart, float(CombatTable.enemy(kind)["sight"]))
	var marks: Array = [r["fire"]] + fights + [r["boss"]]
	for i in marks.size():
		for j in range(i + 1, marks.size()):
			assert_true(_spot(marks[i]).distance_to(_spot(marks[j])) > apart, "%s and %s are out of each other's sight and earshot" % [marks[i], marks[j]])
	var from := w.cell_of(_spot(INSIDE))
	var walked := -1
	for at in fights + [r["boss"]]:
		var cells := GridPath.find(w, from, w.cell_of(_spot(at)))
		assert_true(cells.size() > walked, "%s lies farther along the lane" % [at])
		walked = cells.size()


func test_the_set_down_spot_is_ring_one_ground_outside_the_outpost() -> void:
	var w := WorldDefScript.outpost()
	var p := _spot(WorldDef.DUNGEONS[DUNGEON]["reserved"]["set_down"])
	assert_eq(w.region_at(p), WorldDef.REGION_RING_ONE, "in ring one, never inside the outpost")
	assert_true(w.is_walkable_with_margin(p, 1.0))
	assert_false(GridPath.find(w, w.cell_of(Vector2(w.spawn[0], w.spawn[1])), w.cell_of(p)).is_empty(), "on the outpost's side")
	assert_true(p.x < w.object_center(MOUTH).x, "on the side nearest home")
