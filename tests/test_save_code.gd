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
	assert_eq(sim.state["skills"].size(), 7)
	assert_eq(sim.state["nodes"].size(), sim.world.node_ids().size(), "every tree present and full")
	# The same through a save code, the way an old exported code would arrive.
	var imported := SimScript.new()
	assert_true(imported.command(Vocab.IMPORT_SAVE, {"code": SaveCode.encode(v1)})["ok"])
	assert_eq(imported.snapshot(), sim.snapshot())
	# A migrated character plays on: it can gather straight away.
	assert_true(sim.command(Vocab.GATHER, {"object_id": "tree_1"})["ok"])


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
