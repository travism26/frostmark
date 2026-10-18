## Save codes and migrations: export, import, tamper detection and old versions.
extends "res://tests/run.gd".TestCase

const H := preload("res://tests/sim_helpers.gd")
const SimScript := preload("res://sim/sim.gd")
const Vocab := preload("res://sim/vocab.gd")


## A character with some history: logs banked, a woodcutting level, warmth spent.
func _played() -> Sim:
	var sim := SimScript.new()
	sim.command(Vocab.GATHER, {"object_id": "tree_3"})
	H.run_until_idle(sim, 300)
	sim.command(Vocab.CROSS_GATE)
	H.run_until_idle(sim, 60)
	sim.drain_events()
	return sim


func test_export_then_import_round_trips() -> void:
	var a := _played()
	assert_true(H.stash_count(a, "logs") > 0, "something was banked")
	var exported := a.command(Vocab.EXPORT_SAVE)
	assert_true(exported["ok"])
	var code: String = exported["code"]
	assert_true(code.length() > 0)
	var b := SimScript.new()
	var result := b.command(Vocab.IMPORT_SAVE, {"code": code})
	assert_true(result["ok"], result["reason"])
	assert_eq(b.snapshot(), a.snapshot(), "the imported state equals the exported one")
	assert_eq(JSON.stringify(b.snapshot()), JSON.stringify(a.snapshot()))
	var saved := H.of_kind(b.drain_events(), Vocab.EV_SAVED)
	assert_eq(saved.size(), 1, "an import is a save point, so it becomes the browser save")
	# Both continue identically.
	for i in 20:
		a.step()
		b.step()
	assert_eq(a.snapshot(), b.snapshot())


func test_code_carries_version_and_checksum() -> void:
	var code := SimScript.new().export_code()
	var text := Marshalls.base64_to_raw(code).get_string_from_ascii()
	var parts := text.split("|", true, 3)
	assert_eq(parts[0], SaveCode.PREFIX)
	assert_eq(parts[1].to_int(), Sim.STATE_VERSION)
	assert_eq(parts[2].length(), SaveCode.CHECKSUM_DIGITS)
	assert_true(JSON.parse_string(parts[3]) is Dictionary, "compact JSON snapshot")
	assert_false(parts[3].contains("\n"))


func test_a_mutated_code_is_rejected() -> void:
	var a := _played()
	var code := a.export_code()
	var positions := [0, 7, code.length() / 3, code.length() / 2, code.length() - 5, code.length() - 1]
	for at in positions:
		var mutated := _mutate(code, at)
		var b := SimScript.new()
		var before := b.snapshot()
		var result := b.command(Vocab.IMPORT_SAVE, {"code": mutated})
		assert_false(result["ok"], "a change at %d is caught" % at)
		assert_true(result["reason"] in [Vocab.REASON_BAD_CODE, Vocab.REASON_BAD_CHECKSUM], result["reason"])
		assert_eq(b.snapshot(), before, "the state is untouched")
		var rejected := H.of_kind(b.drain_events(), Vocab.EV_SAVE_REJECTED)
		assert_eq(rejected.size(), 1)


func test_an_edited_payload_fails_the_checksum() -> void:
	var code := SimScript.new().export_code()
	var text := Marshalls.base64_to_raw(code).get_string_from_ascii()
	var forged := Marshalls.utf8_to_base64(text.replace("\"warmth\":360", "\"warmth\":359"))
	assert_ne(forged, code)
	var result := SimScript.new().command(Vocab.IMPORT_SAVE, {"code": forged})
	assert_eq(result["reason"], Vocab.REASON_BAD_CHECKSUM)


func test_garbage_is_rejected_cleanly() -> void:
	for junk in ["", "hello world", "!!!!", "Zm9v", Marshalls.utf8_to_base64("FM|2|abc|{}"), "FM|2|x|{}"]:
		var result := SimScript.new().command(Vocab.IMPORT_SAVE, {"code": junk})
		assert_false(result["ok"], "rejects %s" % junk)
	var truncated := SimScript.new().export_code()
	truncated = truncated.substr(0, truncated.length() - 8)
	assert_false(SimScript.new().command(Vocab.IMPORT_SAVE, {"code": truncated})["ok"], "a truncated paste")


func test_whitespace_in_a_pasted_code_is_ignored() -> void:
	var code := _played().export_code()
	var wrapped := ""
	for i in range(0, code.length(), 60):
		wrapped += code.substr(i, 60) + "\n"
	assert_true(SimScript.new().command(Vocab.IMPORT_SAVE, {"code": "  " + wrapped})["ok"])


func test_a_code_from_a_newer_build_is_refused() -> void:
	var snap := SimScript.new().snapshot()
	snap["version"] = Sim.STATE_VERSION + 1
	var result := SimScript.new().command(Vocab.IMPORT_SAVE, {"code": SaveCode.encode(snap)})
	assert_eq(result["reason"], Vocab.REASON_UNSUPPORTED_VERSION)


func test_a_version_1_snapshot_migrates() -> void:
	# Exactly what slice 2 could snapshot: the tick and the player, nothing else.
	var v1 := {
		"version": 1,
		"tick": 42,
		"player": {
			"pos": [3.5, -2.5], "facing": [1.0, 0.0], "path": [], "target_object": "",
			"region": "outpost",
		},
	}
	var sim := SimScript.new()
	assert_true(sim.restore(v1), "restore migrates a version-1 snapshot")
	assert_eq(sim.state["version"], Sim.STATE_VERSION)
	assert_eq(sim.state["tick"], 42)
	assert_eq(sim.player_pos(), Vector2(3.5, -2.5), "keeps where the player stood")
	assert_eq(sim.state["inventory"]["equipment"]["tool"], "wooden_axe", "gains a new character's kit")
	assert_eq(sim.state["warmth"], Sim.WARMTH_MAX)
	assert_eq(sim.state["skills"].size(), SkillTable.NAMES.size(), "every skill, magic too")
	assert_eq(sim.state["nodes"].size(), sim.world.node_ids().size(), "every tree present and full")
	# The same through a save code, the way an old exported code would arrive.
	var imported := SimScript.new()
	assert_true(imported.command(Vocab.IMPORT_SAVE, {"code": SaveCode.encode(v1)})["ok"])
	assert_eq(imported.snapshot(), sim.snapshot())
	# A migrated character plays on: it can gather straight away.
	assert_true(sim.command(Vocab.GATHER, {"object_id": "tree_1"})["ok"])


func test_a_version_2_snapshot_migrates() -> void:
	# What slice 3 could snapshot: no enemies, loot, healing or swing timer, and a stash with
	# room for the slice-4 starter kit after its banked logs.
	var stash: Array = [{"item": "logs", "count": 7}, null, null, {"item": "wooden_club", "count": 1}, null, null, null, null]
	var pack: Array = []
	pack.resize(12)
	pack[0] = {"item": "logs", "count": 2}
	var skills := {}
	for name in SkillTable.NAMES:
		skills[name] = {"xp": 0, "level": 1}
	skills["woodcutting"] = {"xp": 120, "level": 2}
	var v2 := {
		"version": 2, "tick": 300, "rng": 77,
		"player": {
			"pos": [0.5, 12.5], "facing": [0.0, 1.0], "path": [], "target_object": "",
			"region": "inner_ring", "activity": {},
		},
		"warmth": 200, "health": 90,
		"inventory": {"pack": pack, "equipment": {"weapon": "wooden_club", "armour": "", "tool": "wooden_axe"}},
		"stash": {"capacity": 8, "slots": stash},
		"skills": skills,
		"nodes": {}, "upgrades": [], "pending": [],
	}
	var sim := SimScript.new()
	assert_true(sim.restore(v2), "restore migrates a version-2 snapshot")
	assert_eq(sim.state["version"], Sim.STATE_VERSION)
	assert_eq(sim.state["tick"], 300)
	assert_eq(int(sim.state["health"]), 90, "keeps what it had")
	assert_eq(sim.state["skills"]["woodcutting"]["xp"], 120)
	assert_eq(H.pack_count(sim, "logs"), 2)
	assert_eq(sim.state["inventory"]["equipment"]["weapon"], "wooden_club")
	var slots: Array = sim.state["stash"]["slots"]
	assert_eq(slots[0], {"item": "logs", "count": 7}, "banked logs stay put")
	assert_eq(slots[1], {"item": "wooden_bow", "count": 1}, "the starter kit fills empty slots")
	assert_eq(slots[2], {"item": "arrows", "count": 30})
	assert_eq(slots[3], {"item": "wooden_club", "count": 1})
	assert_eq(slots[4], {"item": "cooked_fish", "count": 5})
	assert_eq(sim.state["enemies"].size(), sim.world.enemies.size(), "every enemy placed")
	for id in sim.state["enemies"]:
		assert_eq(sim.state["enemies"][id]["mode"], Sim.MODE_IDLE, "%s at home and idle" % id)
	assert_eq(sim.state["loot"], {})
	assert_eq(sim.state["healing"], [])
	assert_eq(sim.state["player"]["ready_tick"], 0)
	# The same through a save code, and the migrated character can fight.
	var imported := SimScript.new()
	assert_true(imported.command(Vocab.IMPORT_SAVE, {"code": SaveCode.encode(v2)})["ok"])
	assert_eq(imported.snapshot(), sim.snapshot())
	H.place(sim, [14.5, 23.5])
	assert_true(sim.command(Vocab.ATTACK, {"enemy_id": "archer_1"})["ok"])


func test_a_version_3_snapshot_migrates() -> void:
	# What slice 4 could snapshot: one patch of ring one, no field fires, no fallen guardians,
	# the wolves and the archer it knew about, and a stash with banked logs.
	var stash: Array = [
		{"item": "wooden_bow", "count": 1}, {"item": "arrows", "count": 22}, {"item": "cooked_fish", "count": 3},
		{"item": "logs", "count": 10}, {"item": "wolf_pelt", "count": 2}, null, null, null,
	]
	var pack: Array = []
	pack.resize(12)
	pack[0] = {"item": "iron_sword", "count": 1}
	var skills := {}
	for name in SkillTable.NAMES:
		skills[name] = {"xp": 0, "level": 1}
	skills["melee"] = {"xp": 320, "level": 4}
	var v3 := {
		"version": 3, "tick": 900, "rng": 4242,
		"player": {
			"pos": [-6.5, 24.5], "facing": [0.0, 1.0], "path": [], "target_object": "",
			"region": "ring_one", "activity": {}, "ready_tick": 880,
		},
		"warmth": 150, "health": 70, "healing": [6, 6],
		"inventory": {"pack": pack, "equipment": {"weapon": "wooden_club", "armour": "", "tool": "wooden_axe"}},
		"stash": {"capacity": 8, "slots": stash},
		"skills": skills,
		"nodes": {"tree_1": {"left": 1, "respawn_tick": 0}, "tree_2": {"left": 0, "respawn_tick": 950}},
		"enemies": {
			"wolf_1": {"kind": "wolf", "pos": [-7.0, 26.0], "facing": [0.0, -1.0], "health": 9, "mode": "engaged",
				"next": {"action": "bite", "at": 901}, "step": 1, "respawn_tick": 0},
			"archer_1": {"kind": "bandit_archer", "pos": [14.5, 28.5], "facing": [0.0, -1.0], "health": 0,
				"mode": "dead", "next": {}, "step": 0, "respawn_tick": 960},
		},
		"loot": {"loot_3": {"item": "wolf_pelt", "count": 1, "pos": [-7.0, 27.0], "expires_tick": 1400}},
		"loot_seq": 3,
		"upgrades": [], "pending": [],
	}
	var sim := SimScript.new()
	assert_true(sim.restore(v3), "restore migrates a version-3 snapshot")
	assert_eq(sim.state["version"], Sim.STATE_VERSION)
	assert_eq(sim.state["tick"], 900)
	assert_eq(sim.state["rng"], 4242)
	assert_eq(int(sim.state["health"]), 70, "keeps what it had")
	assert_eq(sim.state["healing"], [6, 6])
	assert_eq(sim.state["skills"]["melee"], {"xp": 320, "level": 4})
	assert_eq(H.pack_count(sim, "iron_sword"), 1)
	assert_eq(sim.state["stash"]["slots"], stash, "the stash is exactly as banked")
	assert_eq(int(sim.state["stash"]["capacity"]), 8)
	assert_eq(sim.state["fires"], {}, "no field fires yet")
	assert_eq(sim.state["fire_seq"], 0)
	assert_eq(sim.state["bosses_defeated"], [], "the captain has not fallen")
	assert_eq(sim.state["nodes"]["tree_1"], {"left": 1, "respawn_tick": 0}, "known nodes keep their state")
	assert_eq(sim.state["nodes"]["tree_2"], {"left": 0, "respawn_tick": 950})
	assert_eq(int(sim.state["nodes"]["copper_1"]["left"]), int(WorldDef.NODE_KINDS[WorldDef.KIND_COPPER_ROCK]["yield"]), "new nodes start full")
	assert_eq(sim.state["enemies"]["wolf_1"]["mode"], Sim.MODE_ENGAGED, "a fight in progress carries on")
	assert_eq(int(sim.state["enemies"]["wolf_1"]["health"]), 9)
	assert_eq(sim.state["enemies"]["archer_1"]["mode"], Sim.MODE_DEAD)
	assert_eq(sim.state["enemies"]["captain"]["mode"], Sim.MODE_IDLE, "the captain waits at his gate")
	assert_eq(sim.state["enemies"].size(), sim.world.enemies.size(), "every enemy placed")
	assert_eq(sim.state["loot"]["loot_3"]["item"], "wolf_pelt")
	# The same through a save code, and the migrated character plays the new rules.
	var imported := SimScript.new()
	assert_true(imported.command(Vocab.IMPORT_SAVE, {"code": SaveCode.encode(v3)})["ok"])
	assert_eq(imported.snapshot(), sim.snapshot())
	H.place(sim, [0.5, 4.5])
	assert_true(sim.command(Vocab.BUILD, {"upgrade": "stash_shelves"})["ok"], "can build from the old stash")
	H.place(sim, [-6.5, 24.5])
	H.set_pack(sim, [{"item": "logs", "count": 3}])
	assert_true(sim.command(Vocab.LIGHT_FIRE)["ok"], "can light a field fire")


func test_a_version_4_snapshot_migrates_with_the_guide_off() -> void:
	# What slice 5 could snapshot: a played character with no guide in its state.
	var sim := SimScript.new()
	H.walk_to(sim, H.OUTSIDE)
	var v4 := sim.snapshot()
	v4.erase("guide")
	v4["version"] = 4
	var migrated: Dictionary = SaveCode.migrate(v4, 5)
	assert_eq(migrated["version"], 5)
	assert_eq(migrated["guide"], {"on": false, "step": 4, "tips": {}}, "already played: no first-outing hints")
	var loaded := SimScript.new()
	assert_true(loaded.command(Vocab.IMPORT_SAVE, {"code": SaveCode.encode(v4)})["ok"])
	assert_eq(loaded.state["version"], Sim.STATE_VERSION)
	assert_false(loaded.hints_on())
	assert_eq(loaded.hint(), "")
	assert_eq(loaded.state["player"]["pos"], sim.state["player"]["pos"], "everything else as it was")
	var events := H.run(loaded, 5)
	assert_eq(H.of_kind(events, Vocab.EV_TIP).size() + H.of_kind(events, Vocab.EV_HINT).size(), 0)


func test_a_version_5_snapshot_migrates_with_magic() -> void:
	# What the guide build could snapshot: seven skills, no ice crystals, no frost witches, and the
	# captain partway through his two-stance cycle.
	var sim := SimScript.new()
	var v5 := sim.snapshot()
	v5["version"] = 5
	v5["tick"] = 1200
	(v5["skills"] as Dictionary).erase("magic")
	v5["skills"]["melee"] = {"xp": 320, "level": 4}
	v5["skills"]["ranged"] = {"xp": 160, "level": 3}
	for id in ["ice_crystal_1", "ice_crystal_2"]:
		(v5["nodes"] as Dictionary).erase(id)
	for id in ["witch_1", "witch_2"]:
		(v5["enemies"] as Dictionary).erase(id)
	v5["nodes"]["tree_1"] = {"left": 0, "respawn_tick": 1250}
	v5["enemies"]["captain"]["step"] = 7
	v5["stash"]["slots"][3] = {"item": "iron_bow", "count": 1}
	var migrated: Dictionary = SaveCode.migrate(v5, 6)
	assert_eq(migrated["version"], 6)
	assert_eq(migrated["skills"]["magic"], {"xp": 0, "level": 1}, "the eighth skill starts fresh")
	assert_eq(migrated["skills"].size(), 8)
	var loaded := SimScript.new()
	assert_true(loaded.restore(v5), "restore migrates a version-5 snapshot")
	assert_eq(loaded.state["version"], Sim.STATE_VERSION)
	assert_eq(loaded.state["tick"], 1200)
	assert_eq(loaded.state["skills"]["magic"], {"xp": 0, "level": 1})
	assert_eq(loaded.state["skills"]["melee"], {"xp": 320, "level": 4}, "the other skills are kept")
	assert_eq(loaded.state["skills"]["ranged"], {"xp": 160, "level": 3})
	assert_eq(loaded.state["stash"]["slots"], v5["stash"]["slots"], "the stash is exactly as banked")
	assert_eq(loaded.state["nodes"]["tree_1"], {"left": 0, "respawn_tick": 1250}, "known nodes keep their state")
	for id in ["ice_crystal_1", "ice_crystal_2"]:
		assert_eq(int(loaded.state["nodes"][id]["left"]), int(WorldDef.NODE_KINDS[WorldDef.KIND_ICE_CRYSTAL]["yield"]), "%s starts full" % id)
	for id in ["witch_1", "witch_2"]:
		assert_eq(loaded.state["enemies"][id]["mode"], Sim.MODE_IDLE, "%s waits at home" % id)
	assert_eq(int(loaded.state["enemies"]["captain"]["step"]), 7, "the captain carries on from his step")
	# The same through a save code, and the migrated character can level magic.
	var imported := SimScript.new()
	assert_true(imported.command(Vocab.IMPORT_SAVE, {"code": SaveCode.encode(v5)})["ok"])
	assert_eq(imported.snapshot(), loaded.snapshot())
	H.place(loaded, [-7.5, 23.5])
	H.arm(loaded, "wooden_staff", [{"item": "frost_shards", "count": 5}])
	assert_true(loaded.command(Vocab.ATTACK, {"enemy_id": "wolf_1"})["ok"])
	H.run(loaded, 1)
	assert_true(int(loaded.state["skills"]["magic"]["xp"]) > 0, "magic levels by use")


func test_a_version_5_magic_entry_is_kept() -> void:
	var migrated: Dictionary = SaveCode.migrate({"version": 5, "tick": 1, "skills": {"magic": {"xp": 60, "level": 2}}}, 6)
	assert_eq(migrated["skills"]["magic"], {"xp": 60, "level": 2})


func test_a_version_6_snapshot_migrates() -> void:
	# What the magic build could snapshot: the captain beaten and the winch built (a character
	# who saw the old ending), stood by the gate, with ring two unknown to it.
	var v6 := SimScript.new().snapshot()
	v6["version"] = 6
	v6.erase("rings_reached")
	for id in v6["enemies"].keys():
		if not id.begins_with("wolf") and not id.begins_with("archer") and not id.begins_with("witch") and id != "captain":
			v6["enemies"].erase(id)
	for id in v6["nodes"].keys():
		if id.begins_with("coal") or id.begins_with("rich_iron") or id.begins_with("deep_hole"):
			v6["nodes"].erase(id)
	v6["tick"] = 5000
	v6["bosses_defeated"] = ["captain"]
	v6["upgrades"] = ["stash_shelves", "forge", "armoury", "ring_two_gate"]
	v6["player"]["pos"] = [0.5, 50.5]
	v6["player"]["region"] = "ring_one"
	v6["enemies"]["captain"]["mode"] = "dead"
	v6["enemies"]["captain"]["respawn_tick"] = 9000
	v6["inventory"]["pack"][0] = {"item": "iron_ore", "count": 4}
	var migrated: Dictionary = SaveCode.migrate(v6, 7)
	assert_eq(migrated["version"], 7)
	assert_eq(migrated["rings_reached"], [])
	var sim := SimScript.new()
	assert_true(sim.restore(v6), "restore migrates a version-6 snapshot")
	assert_eq(sim.state["version"], Sim.STATE_VERSION)
	assert_eq(sim.state["rings_reached"], [], "no ring reached yet")
	assert_eq(sim.state["bosses_defeated"], ["captain"])
	assert_eq(sim.state["upgrades"], v6["upgrades"], "upgrades are kept")
	assert_eq(H.pack_count(sim, "iron_ore"), 4)
	assert_eq(sim.state["enemies"]["troll_1"]["mode"], Sim.MODE_IDLE, "ring two's monsters wait at home")
	assert_eq(int(sim.state["nodes"]["coal_1"]["left"]), int(WorldDef.NODE_KINDS[WorldDef.KIND_COAL_ROCK]["yield"]), "and its nodes are full")
	assert_true(sim.ring_gate_open("ring_two_gate"), "the gate the old ending opened stands open")
	# The same through a save code, and the migrated character walks into ring two.
	var imported := SimScript.new()
	assert_true(imported.command(Vocab.IMPORT_SAVE, {"code": SaveCode.encode(v6)})["ok"])
	assert_eq(imported.snapshot(), sim.snapshot())
	sim.command(Vocab.INTERACT, {"object_id": "ring_two_gate"})
	var events := H.run_until_idle(sim, 40)
	assert_eq(sim.state["player"]["region"], WorldDef.REGION_RING_TWO)
	assert_eq(H.of_kind(events, Vocab.EV_RING_TWO_REACHED).size(), 1, "the first walk through is still announced")


func test_a_version_7_snapshot_migrates() -> void:
	# What the ring-two build could snapshot: deep in ring two with a haul, the winch and the
	# blast furnace built, standing beside where its waystone now stands.
	var v7 := SimScript.new().snapshot()
	v7["version"] = 7
	v7.erase("waystones")
	v7["tick"] = 8000
	v7["bosses_defeated"] = ["captain"]
	v7["rings_reached"] = ["ring_two"]
	v7["upgrades"] = ["stash_shelves", "forge", "armoury", "ring_two_gate", "blast_furnace"]
	v7["player"]["pos"] = [-0.5, 118.5]
	v7["player"]["region"] = "ring_two"
	v7["inventory"]["pack"][0] = {"item": "coal", "count": 7}
	var migrated: Dictionary = SaveCode.migrate(v7, 8)
	assert_eq(migrated["version"], 8)
	assert_eq(migrated["waystones"], [])
	var sim := SimScript.new()
	assert_true(sim.restore(v7), "restore migrates a version-7 snapshot")
	assert_eq(sim.state["version"], Sim.STATE_VERSION)
	assert_eq(sim.state["waystones"], [], "no waystone visited yet")
	assert_eq(sim.state["upgrades"], v7["upgrades"], "upgrades are kept")
	assert_eq(sim.state["rings_reached"], ["ring_two"])
	assert_eq(H.pack_count(sim, "coal"), 7)
	var imported := SimScript.new()
	assert_true(imported.command(Vocab.IMPORT_SAVE, {"code": SaveCode.encode(v7)})["ok"])
	assert_eq(imported.snapshot(), sim.snapshot())
	# The stone beside it has to be visited, and the upgrade built, before it carries anyone.
	assert_eq(sim.command(Vocab.TRAVEL, {"object_id": "ring_two_waystone"})["reason"], Vocab.REASON_UPGRADE_MISSING)
	H.patch(sim, {"upgrades": v7["upgrades"] + ["waystone"]})
	assert_eq(sim.command(Vocab.TRAVEL, {"object_id": "ring_two_waystone"})["reason"], Vocab.REASON_NOT_ATTUNED)


func test_a_version_8_snapshot_migrates_with_only_its_version_raised() -> void:
	# Every upgrade a version-8 build could have, the stash grown to 16 and full.
	var v8 := SimScript.new().snapshot()
	v8["version"] = 8
	v8["tick"] = 9000
	v8["upgrades"] = ["stash_shelves", "forge", "stash_cellar", "armoury", "ring_two_gate", "blast_furnace", "waystone"]
	var slots: Array = []
	for i in 16:
		slots.append({"item": "logs", "count": 10})
	v8["stash"] = {"capacity": 16, "slots": slots}
	v8["waystones"] = ["ring_one_waystone"]
	var migrated: Dictionary = SaveCode.migrate(v8, 9)
	var expected := v8.duplicate(true)
	expected["version"] = 9
	assert_eq(migrated, expected, "nothing changes but the version")
	var sim := SimScript.new()
	assert_true(sim.restore(v8), "restore migrates a version-8 snapshot")
	assert_eq(sim.state["upgrades"], v8["upgrades"], "the same upgrades, the vault not among them")
	assert_eq(int(sim.state["stash"]["capacity"]), 16, "no vault slots are added")
	var imported := SimScript.new()
	assert_true(imported.command(Vocab.IMPORT_SAVE, {"code": SaveCode.encode(v8)})["ok"])
	assert_eq(imported.snapshot(), sim.snapshot())


## A version-9 snapshot: iron armour worn, another carried, steel armour stashed and bronze
## armour lying as loot.
func _v9_in_iron() -> Dictionary:
	var v9 := SimScript.new().snapshot()
	v9["version"] = 9
	v9["tick"] = 4200
	v9["inventory"]["equipment"] = {"weapon": "iron_sword", "armour": "iron_armour", "tool": "wooden_axe"}
	v9["inventory"]["pack"][0] = {"item": "iron_armour", "count": 1}
	v9["inventory"]["pack"][1] = {"item": "logs", "count": 4}
	v9["stash"]["slots"][7] = {"item": "steel_armour", "count": 1}
	v9["loot"] = {"loot_1": {"item": "bronze_armour", "count": 1, "pos": [0.5, 20.5], "expires_tick": 4500}}
	v9["loot_seq"] = 1
	return v9


func test_a_version_9_snapshot_wears_its_armour_as_a_body_piece() -> void:
	var v9 := _v9_in_iron()
	var migrated: Dictionary = SaveCode.migrate(v9, 10)
	assert_eq(migrated["version"], 10)
	assert_eq(migrated["inventory"]["equipment"], {
		"weapon": "iron_sword", "helm": "", "body": "iron_body", "legs": "", "tool": "wooden_axe",
	}, "the armour slot becomes the body slot; helm and legs start empty")
	assert_eq(migrated["inventory"]["pack"][0], {"item": "iron_body", "count": 1}, "carried armour too")
	assert_eq(migrated["inventory"]["pack"][1], {"item": "logs", "count": 4}, "everything else as it was")
	assert_eq(migrated["stash"]["slots"][7], {"item": "steel_body", "count": 1}, "stashed armour too")
	assert_eq(migrated["loot"]["loot_1"]["item"], "bronze_body", "and armour lying in the snow")


func test_a_version_9_code_in_iron_armour_imports_with_an_iron_body_worn_and_carried() -> void:
	var sim := SimScript.new()
	var result := sim.command(Vocab.IMPORT_SAVE, {"code": SaveCode.encode(_v9_in_iron())})
	assert_true(result["ok"], "the version-9 code imports: %s" % result["reason"])
	assert_eq(sim.state["version"], Sim.STATE_VERSION)
	var worn: Dictionary = sim.state["inventory"]["equipment"]
	assert_eq(worn["body"], "iron_body", "the iron armour worn is an iron body piece worn")
	assert_eq(worn["helm"], "")
	assert_eq(worn["legs"], "")
	assert_false(worn.has("armour"), "no armour slot is left")
	assert_eq(H.pack_count(sim, "iron_body"), 1, "the iron armour carried is an iron body piece carried")
	assert_eq(H.stash_count(sim, "steel_body"), 1)
	assert_eq(sim.combatant(Vocab.PLAYER)["defence"], 1, "an iron body alone takes 1 off a hit")


func test_a_full_version_2_stash_gets_no_kit() -> void:
	var full: Array = []
	for i in 8:
		full.append({"item": "logs", "count": 10})
	var migrated: Dictionary = SaveCode.migrate({"version": 2, "tick": 1, "stash": {"capacity": 8, "slots": full}}, 3)
	assert_eq(migrated["stash"]["slots"], full, "nothing is squeezed in")


func test_migrate_refuses_unknown_versions() -> void:
	assert_eq(SaveCode.migrate({}, Sim.STATE_VERSION), null)
	assert_eq(SaveCode.migrate({"version": 0}, Sim.STATE_VERSION), null)
	assert_eq(SaveCode.migrate({"version": Sim.STATE_VERSION + 1}, Sim.STATE_VERSION), null)
	assert_eq(SaveCode.migrate({"version": "two"}, Sim.STATE_VERSION), null)


func test_unknown_items_in_a_snapshot_are_dropped() -> void:
	var sim := SimScript.new()
	var snap := sim.snapshot()
	snap["inventory"]["pack"][0] = {"item": "dragon_egg", "count": 1}
	snap["inventory"]["pack"][1] = {"item": "logs", "count": 3.0}
	assert_true(sim.restore(snap))
	assert_eq(sim.state["inventory"]["pack"][0], null)
	assert_eq(sim.state["inventory"]["pack"][1], {"item": "logs", "count": 3})
	assert_true(sim.state["inventory"]["pack"][1]["count"] is int)


func _mutate(code: String, at: int) -> String:
	var c := code[at]
	var swap := "B" if c != "B" else "C"
	return code.substr(0, at) + swap + code.substr(at + 1)
