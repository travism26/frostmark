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
