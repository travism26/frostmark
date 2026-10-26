## The end of the ring-one dungeon: its boss, the great frost bear, in the boss room, stronger
## than anything in ring one, and the way out beside it, shut while the boss stands and open from its fall until
## it comes back. Taking the way out is a walk-up that sets the player down on ring-one ground on
## the outpost's side of the dungeon, as waystone travel sets them down outside the gate.
extends "res://tests/run.gd".TestCase

const H := preload("res://tests/sim_helpers.gd")
const SimScript := preload("res://sim/sim.gd")
const Vocab := preload("res://sim/vocab.gd")
const WorldDefScript := preload("res://sim/world_def.gd")

const DUNGEON := "ring_one_dungeon"
const BOSS := "ring_one_dungeon_boss"
const WAY_OUT := "ring_one_dungeon_way_out"
## Beside the boss's home, within a blade's reach of it.
const BESIDE_BOSS := [74.2, 44.0]
## In the boss room's north end, out of the boss's sight.
const ROOM_NORTH := [74.5, 28.5]


## A player with a steel sword beside the boss, which has one health left and falls to the
## first blow. Returns the events of the fight.
func _fell_boss(sim: Sim) -> Array[Dictionary]:
	H.arm(sim, "steel_sword", [{"item": "iron_ore", "count": 2}])
	H.place(sim, BESIDE_BOSS)
	H.patch_enemy(sim, BOSS, {"health": 1})
	sim.drain_events()
	assert_true(sim.command(Vocab.ATTACK, {"enemy_id": BOSS})["ok"])
	var events := H.run(sim, 3)
	assert_eq(sim.state["enemies"][BOSS]["mode"], Sim.MODE_DEAD, "the boss falls")
	return events


func _use(sim: Sim) -> Array[Dictionary]:
	sim.drain_events()
	var result := sim.command(Vocab.INTERACT, {"object_id": WAY_OUT})
	assert_true(result["ok"], result["reason"])
	return H.run_until_idle(sim, 40)


static func _spot(at: Array) -> Vector2:
	return Vector2(at[0], at[1])


## The heaviest blow in any of `kind`'s cycles, its phases' included.
static func _heaviest(kind: String) -> int:
	var most := 0
	for phase in CombatTable.phase_count(kind) + 1:
		for action in CombatTable.cycle(kind, phase):
			most = maxi(most, CombatTable.action_damage(action))
	return most


# --- The boss -------------------------------------------------------------------------------

func test_the_dungeon_table_names_its_boss_way_out_and_set_down_spot() -> void:
	var w := WorldDefScript.outpost()
	var d: Dictionary = WorldDef.DUNGEONS[DUNGEON]
	assert_eq([d["boss"], d["way_out"]], [BOSS, WAY_OUT])
	assert_eq(w.enemies[BOSS]["home"], d["reserved"]["boss"], "the boss stands on its reserved spot")
	assert_eq(w.object_center(WAY_OUT), _spot(d["reserved"]["way_out"]), "and the way out on its own")
	assert_eq(w.objects[WAY_OUT]["kind"], WorldDef.KIND_WAY_OUT)
	assert_eq(WorldDef.dungeon_of_way_out(WAY_OUT), DUNGEON)
	assert_eq(WorldDef.dungeon_of_way_out(d["mouth"]), "")


func test_the_boss_is_one_placement_of_a_new_kind_stronger_than_all_of_ring_one() -> void:
	var w := WorldDefScript.outpost()
	var kind: String = w.enemies[BOSS]["kind"]
	assert_eq(w.region_at(_spot(w.enemies[BOSS]["home"])), WorldDef.REGION_RING_ONE_DUNGEON, "it lives in the dungeon")
	var room: Array = WorldDef.DUNGEONS[DUNGEON]["reserved"]["boss_room"]
	var home := _spot(w.enemies[BOSS]["home"])
	assert_true(home.x > room[0][0] and home.x < room[1][0] and home.y > room[0][1] and home.y < room[1][1], "in the boss room")
	var ring_one := {}
	for id in w.enemies:
		if id != BOSS:
			assert_ne(w.enemies[id]["kind"], kind, "%s is not of the boss's kind" % id)
		if w.region_at(_spot(w.enemies[id]["home"])) == WorldDef.REGION_RING_ONE:
			ring_one[w.enemies[id]["kind"]] = true
	assert_true(ring_one.size() >= 4, "every ring-one kind is weighed")
	var def := CombatTable.enemy(kind)
	assert_true(def["boss"], "it is flagged as a boss")
	for other in ring_one:
		assert_true(int(def["health"]) > int(CombatTable.enemy(other)["health"]), "more health than a %s" % other)
		assert_true(_heaviest(kind) > _heaviest(other), "a heavier blow than a %s's" % other)
	assert_false(def.has("boss_loot"), "it drops nothing special")


func test_the_boss_telegraphs_its_ordinary_blows_like_any_enemy() -> void:
	var sim := SimScript.new()
	H.arm(sim, "", [])
	H.place(sim, BESIDE_BOSS)
	sim.command(Vocab.SET_AUTO_RETALIATE, {"on": false})
	var events := H.run_stamped(sim, 12)
	var told := H.where(events, Vocab.EV_ENEMY_TELEGRAPHED, "enemy_id", BOSS)
	var hits := H.where(events, Vocab.EV_HIT, "attacker", BOSS).filter(func(e: Dictionary) -> bool: return not e.get("area", false))
	assert_true(hits.size() >= 1, "it strikes")
	for hit in hits:
		var warned := told.filter(func(t: Dictionary) -> bool: return int(t["at"]) == int(hit["tick"]))
		assert_eq(warned.size(), 1, "the blow at tick %d was told a tick ahead" % hit["tick"])


func test_the_boss_comes_back_after_its_respawn_time() -> void:
	var sim := SimScript.new()
	_fell_boss(sim)
	H.place(sim, ROOM_NORTH)
	var ticks := int(CombatTable.enemy("great_frost_bear")["respawn_ticks"])
	assert_eq(H.of_kind(H.run(sim, ticks - 3), Vocab.EV_ENEMY_RESPAWNED).size(), 0, "not before its time")
	var back := H.run(sim, 3)
	assert_eq(H.where(back, Vocab.EV_ENEMY_RESPAWNED, "enemy_id", BOSS).size(), 1, "back at home")
	assert_eq(int(sim.state["enemies"][BOSS]["health"]), int(CombatTable.enemy("great_frost_bear")["health"]))


# --- The way out --------------------------------------------------------------------------

func test_the_way_out_is_refused_with_a_reason_while_the_boss_stands() -> void:
	var sim := SimScript.new()
	H.place(sim, ROOM_NORTH)
	assert_false(sim.way_out_open(WAY_OUT))
	sim.drain_events()
	var result := sim.command(Vocab.INTERACT, {"object_id": WAY_OUT})
	assert_false(result["ok"])
	assert_eq(result["reason"], Vocab.REASON_WAY_OUT_SHUT)
	var rejected := H.of_kind(sim.drain_events(), Vocab.EV_COMMAND_REJECTED)
	assert_eq(rejected[0]["reason"], Vocab.REASON_WAY_OUT_SHUT, "the refusal names why")
	assert_false(sim.is_moving(), "and nobody walks")


func test_after_the_boss_falls_the_way_out_sets_the_player_down_in_ring_one() -> void:
	var sim := SimScript.new()
	_fell_boss(sim)
	assert_true(sim.way_out_open(WAY_OUT), "open once the boss falls")
	var from := sim.player_pos()
	var events := _use(sim)
	assert_eq(H.of_kind(events, Vocab.EV_INTERACTED)[0]["action"], Vocab.ACTION_WAY_OUT)
	assert_eq(H.of_kind(events, Vocab.EV_TRAVEL_STARTED).size(), 0, "a walk-up, with no channel")
	var set_down := _spot(WorldDef.DUNGEONS[DUNGEON]["set_down"])
	assert_eq(sim.player_pos(), set_down, "at the set-down spot")
	assert_eq(sim.state["player"]["region"], WorldDef.REGION_RING_ONE)
	assert_false(sim.is_moving())
	var left := H.of_kind(events, Vocab.EV_LEFT_DUNGEON)
	assert_eq(left.size(), 1, "a travelled-style event")
	assert_eq([left[0]["dungeon_id"], left[0]["object_id"]], [DUNGEON, WAY_OUT])
	assert_true(_spot(left[0]["from"]).distance_to(sim.world.object_center(WAY_OUT)) < from.distance_to(sim.world.object_center(WAY_OUT)), "from the way out")
	assert_eq(_spot(left[0]["to"]), set_down)
	var changes := H.of_kind(events, Vocab.EV_REGION_CHANGED)
	assert_eq([changes[-1]["from"], changes[-1]["to"]], [WorldDef.REGION_RING_ONE_DUNGEON, WorldDef.REGION_RING_ONE])
	assert_eq(H.of_kind(events, Vocab.EV_SAVED)[-1]["reason"], "way_out", "a save point")
	assert_eq(H.of_kind(events, Vocab.EV_RETURNED).size(), 0, "it is not a return")
	assert_eq(H.pack_count(sim, "iron_ore"), 2, "the pack still at risk")


func test_taking_the_way_out_sends_every_engaged_enemy_home() -> void:
	var home: Array = WorldDef.DUNGEONS[DUNGEON]["reserved"]["boss"]
	var sim := H.arena({BOSS: {"kind": "great_frost_bear", "home": home}, "foe": {"kind": "wolf", "home": [76.5, 46.5]}})
	_fell_boss(sim)
	assert_eq(sim.state["enemies"]["foe"]["mode"], Sim.MODE_ENGAGED, "a wolf in the room joins the fight")
	var events := _use(sim)
	assert_eq(H.of_kind(events, Vocab.EV_LEFT_DUNGEON).size(), 1)
	assert_eq(sim.state["enemies"]["foe"]["mode"], Sim.MODE_RETURNING, "it loses the trail and heads home")
	assert_eq(H.where(events, Vocab.EV_ENEMY_DISENGAGED, "enemy_id", "foe").size(), 1)


func test_when_the_boss_comes_back_the_way_out_shuts_again() -> void:
	var sim := SimScript.new()
	_fell_boss(sim)
	H.place(sim, ROOM_NORTH)
	H.run(sim, int(CombatTable.enemy("great_frost_bear")["respawn_ticks"]))
	assert_eq(sim.state["enemies"][BOSS]["mode"], Sim.MODE_IDLE, "the boss is back")
	assert_false(sim.way_out_open(WAY_OUT), "and the way out shut")
	assert_eq(sim.command(Vocab.INTERACT, {"object_id": WAY_OUT})["reason"], Vocab.REASON_WAY_OUT_SHUT)


func test_a_way_out_that_shuts_on_the_walk_to_it_does_nothing() -> void:
	var sim := SimScript.new()
	_fell_boss(sim)
	H.place(sim, ROOM_NORTH)
	H.patch_enemy(sim, BOSS, {"respawn_tick": int(sim.state["tick"]) + 2})
	var events := _use(sim)
	assert_eq(H.of_kind(events, Vocab.EV_INTERACTED)[0]["action"], Vocab.ACTION_WAY_OUT, "the walk ends at it")
	assert_eq(H.of_kind(events, Vocab.EV_LEFT_DUNGEON).size(), 0, "but it is shut again")
	assert_eq(sim.state["player"]["region"], WorldDef.REGION_RING_ONE_DUNGEON)


func test_defeating_the_boss_opens_and_shuts_no_ring_gate() -> void:
	var gates := ["ring_two_gate", "ring_three_gate"]
	var shut := SimScript.new()
	var events := _fell_boss(shut)
	for gate in gates:
		assert_false(shut.ring_gate_open(gate), "%s stays shut" % gate)
	assert_eq(H.of_kind(events, Vocab.EV_RING_GATE_OPENED).size(), 0)
	var open := SimScript.new()
	var upgrades: Array = []
	for gate in gates:
		upgrades.append(open.world.objects[gate]["upgrade"])
	H.patch(open, {"upgrades": upgrades, "bosses_defeated": ["captain"]})
	_fell_boss(open)
	H.place(open, ROOM_NORTH)
	H.run(open, int(CombatTable.enemy("great_frost_bear")["respawn_ticks"]))
	assert_eq(open.state["enemies"][BOSS]["mode"], Sim.MODE_IDLE)
	for gate in gates:
		assert_true(open.ring_gate_open(gate), "%s stays open through its fall and return" % gate)


func test_a_snapshot_keeps_the_way_out_open_or_shut() -> void:
	var sim := SimScript.new()
	H.place(sim, ROOM_NORTH)
	var shut := SimScript.new()
	assert_true(shut.restore(sim.snapshot()))
	assert_false(shut.way_out_open(WAY_OUT), "restored shut")
	_fell_boss(sim)
	var open := SimScript.new()
	assert_true(open.restore(sim.snapshot()))
	assert_true(open.way_out_open(WAY_OUT), "restored open")
	_use(open)
	assert_eq(open.state["player"]["region"], WorldDef.REGION_RING_ONE, "and usable")


# --- The set-down spot ----------------------------------------------------------------------

func test_the_set_down_spot_is_ring_one_ground_nearer_the_outpost_gate_than_the_mouth() -> void:
	var w := WorldDefScript.outpost()
	var p := _spot(WorldDef.DUNGEONS[DUNGEON]["set_down"])
	assert_true(w.is_walkable_with_margin(p, 1.0), "walkable")
	assert_eq(w.region_at(p), WorldDef.REGION_RING_ONE, "in ring one, outside the outpost and short of every ring gate")
	var gate := w.object_center(w.objects_of_kind(WorldDef.KIND_GATE)[0])
	var mouth := w.object_center(WorldDef.DUNGEONS[DUNGEON]["mouth"])
	assert_true(p.distance_to(gate) < mouth.distance_to(gate), "nearer the outpost gate than the mouth is")
	var route := GridPath.find(w, w.cell_of(p), w.cell_of(Vector2(w.spawn[0], w.spawn[1])))
	assert_false(route.is_empty(), "the walk home is open")
