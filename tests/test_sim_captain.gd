## The bandit captain at the ring-two gate: he alternates sabre and bow on a readable
## pattern, drops iron, and the gate opens only once he has fallen and the outpost has built
## the gate upgrade. Walking through is the first playable's ending.
extends "res://tests/run.gd".TestCase

const H := preload("res://tests/sim_helpers.gd")
const SimScript := preload("res://sim/sim.gd")
const Vocab := preload("res://sim/vocab.gd")

## Just north of the captain's home, inside his sabre's reach.
const BESIDE_CAPTAIN := [0.5, 55.5]
const NORTH_OF_GATE := [0.5, 50.5]


func _sturdy(sim: Sim) -> void:
	var snap := sim.snapshot()
	snap["inventory"]["equipment"]["armour"] = "iron_armour"
	sim.restore(snap)


func test_the_captain_alternates_sabre_and_bow_on_his_pattern() -> void:
	var sim := SimScript.new()
	_sturdy(sim)
	H.place(sim, BESIDE_CAPTAIN)
	var events := H.run_stamped(sim, 21)
	var cues: Array = []
	for e in events:
		if e.get("enemy_id", "") != "captain":
			continue
		if e["kind"] == Vocab.EV_ENEMY_TELEGRAPHED:
			cues.append("%s:%s" % [e["action"], e["style"]])
		elif e["kind"] == Vocab.EV_ENEMY_STANCE:
			cues.append("%s:%s" % [e["action"], e["style"]])
	assert_eq(cues.slice(0, 8), [
		"slash:melee", "cleave:melee", "draw_bow:ranged", "loose:ranged", "volley:ranged",
		"draw_sabre:melee", "slash:melee", "cleave:melee",
	])
	var heavy := H.where(events, Vocab.EV_ENEMY_TELEGRAPHED, "action", "cleave")
	assert_true(heavy[0]["heavy"], "the second blow of a stance is the heavy one")
	assert_true(int(heavy[0]["damage"]) > int(CombatTable.ACTIONS["lunge"]["damage"]), "he hits harder than a wolf")


func test_his_style_follows_his_stance() -> void:
	var sim := SimScript.new()
	_sturdy(sim)
	H.place(sim, BESIDE_CAPTAIN)
	var styles := {}
	for i in 12:
		sim.step()
		sim.drain_events()
		styles[sim.combatant("captain")["style"]] = true
	assert_true(styles.has(CombatTable.STYLE_MELEE) and styles.has(CombatTable.STYLE_RANGED), "both styles in one cycle")


func test_he_is_a_boss() -> void:
	var captain: Dictionary = CombatTable.ENEMIES["bandit_captain"]
	for kind in ["wolf", "bandit_archer"]:
		assert_true(int(captain["health"]) > 3 * int(CombatTable.ENEMIES[kind]["health"]), "far more health than a %s" % kind)
	assert_true(captain["boss"])


func test_the_captain_drops_iron_gear() -> void:
	var sim := SimScript.new()
	H.place(sim, BESIDE_CAPTAIN)
	H.arm(sim, "iron_sword")
	H.patch_enemy(sim, "captain", {"health": 1})
	sim.command(Vocab.ATTACK, {"enemy_id": "captain"})
	var events := H.run(sim, 4)
	assert_eq(H.where(events, Vocab.EV_ENEMY_DIED, "enemy_id", "captain").size(), 1)
	var iron := 0
	for e in H.of_kind(events, Vocab.EV_LOOT_DROPPED):
		if ItemTable.tier(e["item"]) == ItemTable.TIER_IRON:
			iron += 1
	assert_true(iron >= 1, "at least one piece of iron gear")
	assert_eq(sim.state["bosses_defeated"], ["captain"], "his fall is recorded")


# --- The ring-two gate --------------------------------------------------------------------

## Builds the gate upgrade from a stocked stash, with everything it requires already built.
func _build_gate_upgrade(sim: Sim) -> Array[Dictionary]:
	var slots := Inventory.empty_slots(12)
	var cost: Dictionary = UpgradeTable.get_upgrade("ring_two_gate")["cost"]
	for kind in cost:
		Inventory.add(slots, kind, int(cost[kind]))
	var snap := sim.snapshot()
	snap["stash"] = {"capacity": 12, "slots": slots}
	snap["upgrades"] = ["stash_shelves", "forge", "armoury"]
	var player_at: Array = snap["player"]["pos"]
	snap["player"]["pos"] = [0.5, 4.5]
	sim.restore(snap)
	assert_true(sim.command(Vocab.BUILD, {"upgrade": "ring_two_gate"})["ok"])
	var events := H.run(sim, 1)
	H.place(sim, player_at)
	return events


func _kill_captain(sim: Sim) -> Array[Dictionary]:
	var keep := sim.player_pos()
	H.place(sim, BESIDE_CAPTAIN)
	var snap := sim.snapshot()
	var weapon: String = snap["inventory"]["equipment"]["weapon"]
	sim.restore(snap)
	H.arm(sim, "iron_sword", Inventory.contents(sim.state["inventory"]["pack"]))
	H.patch_enemy(sim, "captain", {"health": 1})
	sim.command(Vocab.ATTACK, {"enemy_id": "captain"})
	var events := H.run(sim, 4)
	assert_eq(sim.state["enemies"]["captain"]["mode"], Sim.MODE_DEAD, "the captain is down")
	H.arm(sim, weapon, Inventory.contents(sim.state["inventory"]["pack"]))
	H.place(sim, [keep.x, keep.y])
	return events


func _walk_through(sim: Sim) -> Array[Dictionary]:
	H.place(sim, NORTH_OF_GATE)
	var result := sim.command(Vocab.INTERACT, {"object_id": "ring_two_gate"})
	assert_true(result["ok"], result["reason"])
	return H.run_until_idle(sim, 30)


func test_the_gate_stays_barred_while_the_captain_lives() -> void:
	var sim := SimScript.new()
	var built := _build_gate_upgrade(sim)
	assert_eq(H.of_kind(built, Vocab.EV_BUILT).size(), 1)
	assert_eq(H.of_kind(built, Vocab.EV_RING_GATE_OPENED).size(), 0, "the upgrade alone does not open it")
	assert_false(sim.ring_gate_open("ring_two_gate"))
	H.patch_enemy(sim, "captain", {"pos": [40.5, 40.5]})  # away from his post, so the walk is quiet
	var events := _walk_through(sim)
	var interacted := H.of_kind(events, Vocab.EV_INTERACTED)
	assert_eq(interacted[0]["action"], Vocab.ACTION_RING_GATE)
	assert_eq(H.of_kind(events, Vocab.EV_RING_TWO_REACHED).size(), 0)
	assert_eq(sim.state["player"]["region"], WorldDef.REGION_RING_ONE, "still on this side")


func test_the_gate_stays_barred_until_the_upgrade_is_built() -> void:
	var sim := SimScript.new()
	var killed := _kill_captain(sim)
	assert_eq(H.of_kind(killed, Vocab.EV_RING_GATE_OPENED).size(), 0, "his fall alone does not open it")
	assert_false(sim.ring_gate_open("ring_two_gate"))
	var events := _walk_through(sim)
	assert_eq(H.of_kind(events, Vocab.EV_RING_TWO_REACHED).size(), 0)
	var built := _build_gate_upgrade(sim)
	var opened := H.of_kind(built, Vocab.EV_RING_GATE_OPENED)
	assert_eq(opened.size(), 1, "building the winch opens it now")
	assert_eq(opened[0]["object_id"], "ring_two_gate")
	assert_true(sim.ring_gate_open("ring_two_gate"))


func test_walking_through_the_open_gate_ends_the_first_playable_and_comes_home() -> void:
	var sim := SimScript.new()
	_build_gate_upgrade(sim)
	var killed := _kill_captain(sim)
	assert_eq(H.of_kind(killed, Vocab.EV_RING_GATE_OPENED).size(), 1, "his fall opens the readied gate")
	H.set_pack(sim, [{"item": "iron_ore", "count": 3}, {"item": "wolf_pelt", "count": 2}])
	var skills_before: Dictionary = sim.state["skills"].duplicate(true)
	var events := _walk_through(sim)
	var reached := H.of_kind(events, Vocab.EV_RING_TWO_REACHED)
	assert_eq(reached.size(), 1, "the ending")
	assert_eq(sim.state["player"]["region"], WorldDef.REGION_OUTPOST, "back at the outpost")
	assert_true(sim.near_fire(), "beside the fire")
	assert_eq(Inventory.contents(sim.state["inventory"]["pack"]), [], "the haul is banked")
	assert_eq(H.stash_count(sim, "iron_ore"), 3)
	assert_eq(sim.state["skills"], skills_before, "the character is intact")
	assert_eq(int(sim.state["health"]) > 0, true)
	assert_eq(H.of_kind(events, Vocab.EV_DIED).size(), 0)
	assert_eq(H.of_kind(events, Vocab.EV_SAVED)[-1]["reason"], "ring_two")


func test_his_fall_is_kept_through_his_respawn_and_a_save() -> void:
	var sim := SimScript.new()
	_kill_captain(sim)
	H.place(sim, [0.5, 4.5])
	H.run(sim, int(CombatTable.ENEMIES["bandit_captain"]["respawn_ticks"]) + 1)
	assert_eq(sim.state["enemies"]["captain"]["mode"], Sim.MODE_IDLE, "he is back at his post")
	assert_eq(sim.state["bosses_defeated"], ["captain"], "but his first fall still counts")
	var other := SimScript.new()
	assert_true(other.command(Vocab.IMPORT_SAVE, {"code": sim.export_code()})["ok"])
	assert_eq(other.state["bosses_defeated"], ["captain"])
	_build_gate_upgrade(other)
	assert_true(other.ring_gate_open("ring_two_gate"))
