## A boss stays in its room: the ring-one dungeon's boss never steps out of the boss room, and
## breaks off, walks home and heals when the player is outside it.
extends "res://tests/run.gd".TestCase

const H := preload("res://tests/sim_helpers.gd")
const Vocab := preload("res://sim/vocab.gd")
const WorldDefScript := preload("res://sim/world_def.gd")

const DUNGEON := "ring_one_dungeon"
const BOSS := "ring_one_dungeon_boss"
const HOME := [73.0, 44.0]
## Inside the room, a blade's reach from the boss's home.
const BESIDE_BOSS := [74.2, 44.0]
## Outside the room, in the leg's open south end past the room's east wall.
const OUTSIDE := [88.0, 56.0]


func _boss(sim: Sim) -> Dictionary:
	return sim.state["enemies"][BOSS]


func _in_room(at: Array) -> bool:
	return WorldDef.in_boss_room(BOSS, Vector2(at[0], at[1]))


func test_the_dungeon_table_gives_the_boss_a_room_with_its_home_in_it() -> void:
	var w := WorldDefScript.outpost()
	var room := WorldDef.boss_room_of(BOSS)
	assert_eq(room, WorldDef.DUNGEONS[DUNGEON]["reserved"]["boss_room"])
	assert_true(_in_room(w.enemies[BOSS]["home"]), "its home is inside it")
	assert_eq(WorldDef.boss_room_of("dungeon_wolf_1_1"), [], "the dungeon's other enemies have no room")
	assert_true(WorldDef.in_boss_room("dungeon_wolf_1_1", Vector2(0, 0)), "and nowhere to keep out of")


func test_a_boss_walking_out_of_its_room_stops_at_the_edge() -> void:
	var w := WorldDefScript.outpost()
	# A kiting kind backs away from a player who closes in, and here that is out of the room;
	# the kite step is driven directly, as the cycle only reaches it between blows.
	var kiter := ""
	for kind in CombatTable.ENEMIES:
		if CombatTable.enemy(kind).has("kite"):
			kiter = kind
			break
	assert_true(kiter != "", "a kiting kind to back the boss out with")
	w.enemies[BOSS]["kind"] = kiter
	var sim := Sim.new(w)
	var room := WorldDef.boss_room_of(BOSS)
	H.patch_enemy(sim, BOSS, {"pos": [room[1][0] - 0.5, 55.0], "mode": Sim.MODE_ENGAGED})
	H.place(sim, [room[1][0] - 1.5, 55.0])
	assert_eq(_boss(sim)["pos"], [room[1][0] - 0.5, 55.0])
	for i in 20:
		sim._kite(BOSS)
		assert_true(_in_room(_boss(sim)["pos"]), "the boss is in its room on tick %d" % i)


func test_a_boss_chasing_a_player_never_steps_out_of_its_room() -> void:
	var sim := Sim.new(WorldDefScript.outpost())
	H.arm(sim, "steel_sword", [])
	H.place(sim, BESIDE_BOSS)
	assert_true(sim.command(Vocab.ATTACK, {"enemy_id": BOSS})["ok"])
	for i in 60:
		sim.step()
		assert_true(_in_room(_boss(sim)["pos"]), "in its room on tick %d" % i)
		var p := sim.player_pos()
		if i % 6 == 0:
			H.place(sim, [clampf(p.x + 3.0, 64.5, 83.5), clampf(p.y - 5.0, 24.5, 59.5)])


func test_a_boss_breaks_off_when_the_player_walks_out_of_the_room_and_resets() -> void:
	var sim := Sim.new(WorldDefScript.outpost())
	H.arm(sim, "steel_sword", [])
	H.place(sim, BESIDE_BOSS)
	H.patch_enemy(sim, BOSS, {"health": 100, "phase": 1, "answered_tick": 7})
	sim.drain_events()
	assert_true(sim.command(Vocab.ATTACK, {"enemy_id": BOSS})["ok"])
	H.run(sim, 2)
	assert_eq(_boss(sim)["mode"], Sim.MODE_ENGAGED)
	H.place(sim, OUTSIDE)
	var events := H.run(sim, 1)
	assert_eq(H.of_kind(events, Vocab.EV_ENEMY_DISENGAGED).size(), 1, "it breaks off")
	assert_eq(_boss(sim)["mode"], Sim.MODE_RETURNING)
	H.run(sim, 60)
	var boss := _boss(sim)
	assert_eq(boss["mode"], Sim.MODE_IDLE, "it is home")
	assert_eq(boss["pos"], HOME)
	assert_eq(boss["health"], int(CombatTable.enemy(boss["kind"])["health"]), "healed to full")
	assert_eq([boss["phase"], boss["answered_tick"]], [0, -1], "back on its own cycle")


func test_coming_back_into_the_room_starts_the_fight_from_the_beginning() -> void:
	var sim := Sim.new(WorldDefScript.outpost())
	H.patch_enemy(sim, BOSS, {"health": 100, "phase": 1, "answered_tick": 7, "mode": Sim.MODE_ENGAGED})
	H.place(sim, OUTSIDE)
	H.run(sim, 60)
	H.place(sim, BESIDE_BOSS)
	var events := H.run(sim, 2)
	assert_eq(H.of_kind(events, Vocab.EV_ENEMY_NOTICED).size(), 1, "it notices them again")
	assert_eq(_boss(sim)["health"], int(CombatTable.enemy(_boss(sim)["kind"])["health"]))
	assert_eq(_boss(sim)["phase"], 0)


func test_a_player_outside_the_room_is_not_noticed_however_near() -> void:
	var sim := Sim.new(WorldDefScript.outpost())
	H.place(sim, OUTSIDE)
	var events := H.run(sim, 10)
	assert_eq(H.of_kind(events, Vocab.EV_ENEMY_NOTICED).filter(func(ev): return ev["enemy_id"] == BOSS).size(), 0)
	assert_eq(_boss(sim)["mode"], Sim.MODE_IDLE)


func test_a_ranged_attack_from_outside_the_room_cannot_pull_the_boss_out_and_it_resets() -> void:
	var sim := Sim.new(WorldDefScript.outpost())
	H.arm(sim, "wooden_bow", [{"item": "arrows", "count": 30}])
	H.place(sim, OUTSIDE)
	H.patch_enemy(sim, BOSS, {"pos": [82.0, 56.0]})
	sim.drain_events()
	var shot := sim.command(Vocab.ATTACK, {"enemy_id": BOSS})
	assert_true(shot["ok"], shot["reason"])
	var events := H.run(sim, 80)
	assert_true(_in_room(_boss(sim)["pos"]), "it stays in its room")
	assert_eq(H.of_kind(events, Vocab.EV_ENEMY_DISENGAGED).size() > 0, true, "and breaks off")
	assert_eq(_boss(sim)["pos"], HOME, "walks home")
	assert_eq(_boss(sim)["health"], int(CombatTable.enemy(_boss(sim)["kind"])["health"]), "and heals")
