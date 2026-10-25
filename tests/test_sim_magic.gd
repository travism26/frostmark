## Magic and the full triangle: melee beats ranged, ranged beats magic, magic beats melee. A
## staff sets the magic style and spends one frost shard a cast, the shards come from ice
## crystals refined at the workbench, magic levels by use, and frost witches fight with it.
extends "res://tests/run.gd".TestCase

const H := preload("res://tests/sim_helpers.gd")
const SimScript := preload("res://sim/sim.gd")
const Vocab := preload("res://sim/vocab.gd")

## Five metres north of wolf_1: inside a staff's reach.
const NEAR_WOLF := [-7.5, 23.5]
## One metre north of wolf_1: close range.
const BESIDE_WOLF := [-7.5, 27.5]
## Five metres north of witch_1: inside her sight and her staff's reach.
const NEAR_WITCH := [38.5, -19.5]
const BESIDE_CAPTAIN := [0.5, 55.5]
const NORTH_OF_CAPTAIN := [0.5, 51.5]


func test_every_pairing_of_the_triangle() -> void:
	var melee := CombatTable.STYLE_MELEE
	var ranged := CombatTable.STYLE_RANGED
	var magic := CombatTable.STYLE_MAGIC
	var close := 1.0
	var far := 5.0
	# [attacker, defender, multiplier up close, multiplier at distance]
	var table := [
		[melee, melee, 1.0, 1.0], [ranged, ranged, 1.0, 1.0], [magic, magic, 1.0, 1.0],
		# Melee beats ranged where a blade reaches; at distance the bow keeps its edge.
		[melee, ranged, 1.5, 0.5], [ranged, melee, 0.5, 1.5],
		# Ranged beats magic, at any range.
		[ranged, magic, 1.5, 1.5], [magic, ranged, 0.5, 0.5],
		# Magic beats melee, at any range.
		[magic, melee, 1.5, 1.5], [melee, magic, 0.5, 0.5],
	]
	for row in table:
		assert_eq(CombatTable.multiplier(row[0], row[1], close), row[2], "%s on %s up close" % [row[0], row[1]])
		assert_eq(CombatTable.multiplier(row[0], row[1], far), row[3], "%s on %s at distance" % [row[0], row[1]])
	assert_eq(CombatTable.edge(ranged, magic, close), {"dealt": 1.5, "taken": 0.5})
	assert_eq(CombatTable.edge(magic, melee, far), {"dealt": 1.5, "taken": 0.5})
	assert_eq(CombatTable.damage(4, magic, melee, close), 6)
	assert_eq(CombatTable.damage(4, melee, magic, close), 2)
	assert_eq(CombatTable.damage(9, ranged, magic, far, 3), 11, "armour comes off after the edge")


func test_a_staff_sets_the_magic_style() -> void:
	var sim := SimScript.new()
	H.set_pack(sim, [{"item": "wooden_staff", "count": 1}])
	assert_true(sim.command(Vocab.EQUIP, {"index": 0})["ok"])
	H.run(sim, 1)
	assert_eq(sim.player_weapon(), "wooden_staff")
	assert_eq(sim.player_style(), CombatTable.STYLE_MAGIC)
	var me := sim.combatant(Vocab.PLAYER)
	assert_eq(me["style"], CombatTable.STYLE_MAGIC)
	assert_eq(me["reach"], 6.0, "between a blade's reach and a bow's")
	for staff in ["wooden_staff", "bronze_staff", "iron_staff"]:
		var w := CombatTable.weapon(staff)
		assert_eq(w["style"], CombatTable.STYLE_MAGIC, "%s casts magic" % staff)
		assert_eq(w["ammo"], "frost_shards", "%s casts with frost shards" % staff)


func test_a_staff_has_the_edge_on_a_wolf_and_spends_a_shard() -> void:
	var sim := SimScript.new()
	H.place(sim, NEAR_WOLF)
	H.arm(sim, "wooden_staff", [{"item": "frost_shards", "count": 10}])
	assert_true(sim.command(Vocab.ATTACK, {"enemy_id": "wolf_1"})["ok"])
	var events := H.run_stamped(sim, 1)
	var mine := H.where(events, Vocab.EV_HIT, "attacker", Vocab.PLAYER)
	assert_eq(mine.size(), 1, "the staff reaches from where the player stands")
	assert_eq(mine[0]["style"], CombatTable.STYLE_MAGIC)
	assert_eq(mine[0]["multiplier"], 1.5, "magic beats melee")
	assert_eq(mine[0]["amount"], 6, "staff power 4 x 1.5")
	assert_eq(H.pack_count(sim, "frost_shards"), 9, "one shard for the cast")


func test_a_wolf_bites_into_a_staff() -> void:
	var sim := SimScript.new()
	H.place(sim, BESIDE_WOLF)
	H.arm(sim, "wooden_staff", [{"item": "frost_shards", "count": 10}])
	var events := H.run_stamped(sim, 6)
	var bites := H.where(events, Vocab.EV_HIT, "attacker", "wolf_1")
	assert_true(bites.size() > 0, "the wolf attacks")
	assert_eq(bites[0]["multiplier"], 0.5, "melee walks into magic's edge, even up close")


func test_casting_without_shards_is_refused() -> void:
	var sim := SimScript.new()
	H.place(sim, NEAR_WOLF)
	H.arm(sim, "wooden_staff", [{"item": "arrows", "count": 20}])
	assert_eq(sim.command(Vocab.ATTACK, {"enemy_id": "wolf_1"})["reason"], Vocab.REASON_NO_AMMO, "arrows are no use to a staff")
	assert_false(sim.is_attacking())


func test_each_cast_spends_one_shard_until_none_are_left() -> void:
	var sim := SimScript.new()
	H.place(sim, NEAR_WOLF)
	H.arm(sim, "wooden_staff", [{"item": "frost_shards", "count": 2}])
	assert_true(sim.command(Vocab.ATTACK, {"enemy_id": "wolf_1"})["ok"])
	var casts := 0
	var stopped: Array[Dictionary] = []
	for i in 10:
		var events := H.run_stamped(sim, 1)
		casts += H.where(events, Vocab.EV_HIT, "attacker", Vocab.PLAYER).size()
		assert_eq(H.pack_count(sim, "frost_shards"), 2 - casts, "one shard per cast")
		stopped.append_array(H.of_kind(events, Vocab.EV_ACTIVITY_STOPPED))
	assert_eq(casts, 2)
	assert_eq(int(sim.state["enemies"]["wolf_1"]["health"]), 15 - 2 * 6, "two casts with the edge")
	assert_eq(stopped.size(), 1)
	assert_eq(stopped[0]["reason"], Vocab.REASON_NO_AMMO, "the attack stops when the shards run out")
	assert_eq(sim.command(Vocab.ATTACK, {"enemy_id": "wolf_1"})["reason"], Vocab.REASON_NO_AMMO)


func test_casting_trains_magic() -> void:
	var sim := SimScript.new()
	H.place(sim, NEAR_WOLF)
	H.arm(sim, "wooden_staff", [{"item": "frost_shards", "count": 10}])
	sim.command(Vocab.ATTACK, {"enemy_id": "wolf_1"})
	H.run(sim, 1)
	assert_eq(int(sim.state["skills"][SkillTable.MAGIC]["xp"]), 6 * CombatTable.XP_PER_DAMAGE)
	assert_eq(int(sim.state["skills"][SkillTable.MELEE]["xp"]), 0)
	assert_eq(int(sim.state["skills"][SkillTable.RANGED]["xp"]), 0)
	# Enough casts level it, and a higher level hits harder.
	H.patch(sim, {"skills": {SkillTable.MAGIC: {"xp": SkillTable.xp_for_level(7), "level": 7}}})
	var before := int(sim.state["skills"][SkillTable.MAGIC]["xp"])
	var events := H.run_stamped(sim, 8)
	var hits := H.where(events, Vocab.EV_HIT, "attacker", Vocab.PLAYER)
	assert_true(hits.size() > 0)
	assert_eq(hits[0]["amount"], roundi((4 + 2) * 1.5), "two levels of power at magic 7")
	assert_true(int(sim.state["skills"][SkillTable.MAGIC]["xp"]) > before)


# --- Frost witches -----------------------------------------------------------------------

func test_frost_witches_live_in_ring_one_and_cast_magic() -> void:
	var w := WorldDef.outpost()
	var witches := 0
	for id in w.enemies:
		var kind: String = w.enemies[id]["kind"]
		if CombatTable.weapon(CombatTable.enemy(kind)["weapon"])["style"] != CombatTable.STYLE_MAGIC:
			continue
		if kind == "aurora_seer":
			continue  # ring three's own magic enemy (tests/test_ring_three.gd)
		witches += 1
		var home: Array = w.enemies[id]["home"]
		assert_eq(w.region_at(Vector2(home[0], home[1])), WorldDef.REGION_RING_ONE, "%s lives in ring one" % id)
	assert_true(witches >= 1, "a magic enemy is out there")


func test_a_witch_telegraphs_magic_and_has_the_edge_on_a_blade() -> void:
	var sim := SimScript.new()
	H.place(sim, NEAR_WITCH)
	H.arm(sim, "wooden_club")
	var events := H.run_stamped(sim, 8)
	var told := H.where(events, Vocab.EV_ENEMY_TELEGRAPHED, "enemy_id", "witch_1")
	assert_true(told.size() > 0, "she notices and casts from range")
	for t in told:
		assert_eq(t["style"], CombatTable.STYLE_MAGIC, "her cues read as magic")
		assert_eq(t["at"], t["tick"] + 1, "a tick ahead")
	var bolts := H.where(events, Vocab.EV_HIT, "attacker", "witch_1")
	assert_true(bolts.size() > 0)
	assert_eq(bolts[0]["style"], CombatTable.STYLE_MAGIC)
	assert_eq(bolts[0]["multiplier"], 1.5, "magic beats melee")
	assert_true(told.filter(func(t: Dictionary) -> bool: return t["heavy"]).size() > 0, "the ice lance is flagged heavy")


func test_a_bow_has_the_edge_on_a_witch() -> void:
	var sim := SimScript.new()
	H.place(sim, NEAR_WITCH)
	H.arm(sim, "wooden_bow", [{"item": "arrows", "count": 20}])
	assert_true(sim.command(Vocab.ATTACK, {"enemy_id": "witch_1"})["ok"])
	var events := H.run_stamped(sim, 6)
	var mine := H.where(events, Vocab.EV_HIT, "attacker", Vocab.PLAYER)
	var theirs := H.where(events, Vocab.EV_HIT, "attacker", "witch_1")
	assert_true(mine.size() > 0 and theirs.size() > 0, "both sides land blows")
	assert_eq(mine[0]["multiplier"], 1.5, "ranged beats magic")
	assert_eq(mine[0]["amount"], 6)
	assert_eq(theirs[0]["multiplier"], 0.5, "she casts into the edge")


func test_a_witch_drops_frost_shards() -> void:
	var sim := SimScript.new()
	H.place(sim, NEAR_WITCH)
	H.arm(sim, "wooden_bow", [{"item": "arrows", "count": 20}])
	H.patch_enemy(sim, "witch_1", {"health": 1})
	sim.command(Vocab.ATTACK, {"enemy_id": "witch_1"})
	var events := H.run(sim, 2)
	assert_eq(H.where(events, Vocab.EV_ENEMY_DIED, "enemy_id", "witch_1").size(), 1)
	assert_eq(H.where(events, Vocab.EV_LOOT_DROPPED, "item", "frost_shards").size(), 1, "her shards drop where she fell")


# --- The captain's third stance ----------------------------------------------------------

func test_a_bow_beats_the_captain_while_he_holds_his_staff() -> void:
	var sim := SimScript.new()
	H.place(sim, NORTH_OF_CAPTAIN)
	H.arm(sim, "wooden_bow", [{"item": "arrows", "count": 20}])
	# Step 10 is the first cast after "raises his staff": the staff is in his hand.
	H.patch_enemy(sim, "captain", {"step": 10})
	assert_eq(sim.combatant("captain")["style"], CombatTable.STYLE_MAGIC)
	assert_true(sim.command(Vocab.ATTACK, {"enemy_id": "captain"})["ok"])
	var events := H.run_stamped(sim, 1)
	var mine := H.where(events, Vocab.EV_HIT, "attacker", Vocab.PLAYER)
	assert_eq(mine.size(), 1)
	assert_eq(mine[0]["multiplier"], 1.5, "ranged beats magic")


func test_a_blade_walks_into_the_captain_s_staff() -> void:
	var sim := SimScript.new()
	H.place(sim, BESIDE_CAPTAIN)
	H.arm(sim, "iron_sword")
	H.patch_enemy(sim, "captain", {"step": 10})
	assert_true(sim.command(Vocab.ATTACK, {"enemy_id": "captain"})["ok"])
	var events := H.run_stamped(sim, 1)
	var mine := H.where(events, Vocab.EV_HIT, "attacker", Vocab.PLAYER)
	assert_eq(mine.size(), 1)
	assert_eq(mine[0]["multiplier"], 0.5, "melee walks into magic's edge")


# --- Gathering and crafting ----------------------------------------------------------------

func test_ice_crystals_are_mined_past_the_first_level() -> void:
	var sim := SimScript.new()
	var snap := sim.snapshot()
	snap["inventory"]["equipment"]["tool"] = "wooden_pickaxe"
	sim.restore(snap)
	var def: Dictionary = WorldDef.NODE_KINDS[WorldDef.KIND_ICE_CRYSTAL]
	assert_eq(def["skill"], SkillTable.MINING, "no new gathering skill")
	assert_eq(sim.world.region_at(sim.world.object_center("ice_crystal_1")), WorldDef.REGION_INNER_RING, "safe to reach")
	assert_eq(sim.command(Vocab.GATHER, {"object_id": "ice_crystal_1"})["reason"], Vocab.REASON_LEVEL_TOO_LOW)
	H.patch(sim, {"skills": {SkillTable.MINING: {"xp": SkillTable.xp_for_level(2), "level": 2}}})
	assert_true(sim.command(Vocab.GATHER, {"object_id": "ice_crystal_1"})["ok"])
	H.run_until_idle(sim, 400)
	assert_eq(H.pack_count(sim, "ice_crystal"), int(def["yield"]))
	assert_eq(int(sim.state["skills"][SkillTable.MINING]["xp"]), SkillTable.xp_for_level(2) + int(def["yield"]) * int(def["xp"]))


func _at_workbench(entries: Array) -> Sim:
	var sim := SimScript.new()
	sim.command(Vocab.INTERACT, {"object_id": "workbench"})
	H.run_until_idle(sim, 60)
	H.set_pack(sim, entries)
	sim.drain_events()
	return sim


func test_the_workbench_refines_crystals_into_shards_and_makes_staffs() -> void:
	var sim := _at_workbench([{"item": "ice_crystal", "count": 3}, {"item": "logs", "count": 5}])
	assert_true(sim.command(Vocab.SMITH, {"recipe": "frost_shards"})["ok"])
	H.run(sim, 1)
	assert_eq(H.pack_count(sim, "frost_shards"), 10, "one crystal, a pouch of shards")
	assert_eq(H.pack_count(sim, "ice_crystal"), 2)
	assert_true(int(sim.state["skills"][SkillTable.SMITHING]["xp"]) > 0, "refining is smithing")
	assert_true(sim.command(Vocab.SMITH, {"recipe": "wooden_staff"})["ok"])
	H.run(sim, 1)
	assert_eq(H.pack_count(sim, "wooden_staff"), 1)
	assert_eq(H.pack_count(sim, "ice_crystal"), 1, "a staff takes a crystal")
	H.set_pack(sim, [{"item": "ice_crystal", "count": 1}, {"item": "bronze_bar", "count": 2}, {"item": "logs", "count": 2}])
	H.patch(sim, {"skills": {SkillTable.SMITHING: {"xp": SkillTable.xp_for_level(2), "level": 2}}})
	assert_eq(sim.command(Vocab.SMITH, {"recipe": "bronze_staff"})["reason"], Vocab.REASON_UPGRADE_MISSING, "bronze needs the forge")
	H.patch(sim, {"upgrades": ["forge"]})
	assert_true(sim.command(Vocab.SMITH, {"recipe": "bronze_staff"})["ok"])
	H.run(sim, 1)
	assert_eq(H.pack_count(sim, "bronze_staff"), 1)


func test_the_iron_staff_is_smithed_at_the_bloomery_and_still_drops() -> void:
	assert_true(CombatTable.RARE_LOOT.has("iron_staff"), "a rare drop in ring one")
	assert_true((CombatTable.ENEMIES["bandit_captain"]["boss_loot"] as Array).has("iron_staff"), "the captain may carry one")
	var recipe := RecipeTable.get_recipe("iron_staff")
	assert_eq(recipe["upgrade"], "bloomery", "the Bloomery makes it")
	assert_eq(recipe["inputs"], {"iron_bar": 2, "logs": 2, "ice_crystal": 1}, "from bars, logs and an ice crystal")
