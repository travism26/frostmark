## State as plain data: snapshot/restore round-trips, determinism, the command vocabulary.
extends "res://tests/run.gd".TestCase

const SimScript := preload("res://sim/sim.gd")
const Vocab := preload("res://sim/vocab.gd")


func test_snapshot_restore_round_trips_mid_walk() -> void:
	var a := SimScript.new()
	a.command(Vocab.MOVE_TO, {"pos": [6.5, -3.5]})
	a.step()
	var snap := a.snapshot()
	assert_true(snap["player"]["path"].size() > 0, "snapshot taken mid-walk")

	var b := SimScript.new()
	assert_true(b.restore(snap), "restore accepts the snapshot")
	assert_eq(b.snapshot(), snap, "restored state equals the snapshot")
	assert_eq(b.player_pos(), a.player_pos())
	assert_eq(b.state["tick"], a.state["tick"])
	a.drain_events()
	b.drain_events()

	# Both copies continue identically.
	for i in 10:
		a.step()
		b.step()
	assert_eq(a.snapshot(), b.snapshot(), "diverged after restore")
	assert_eq(a.drain_events(), b.drain_events(), "same events after restore")


func test_snapshot_survives_json() -> void:
	var a := SimScript.new()
	a.command(Vocab.INTERACT, {"object_id": "fire"})
	a.step()
	var text := JSON.stringify(a.snapshot())
	var parsed: Variant = JSON.parse_string(text)
	assert_true(parsed is Dictionary, "snapshot is JSON-serialisable")
	var b := SimScript.new()
	assert_true(b.restore(parsed))
	assert_eq(JSON.stringify(b.snapshot()), text, "JSON round-trip is lossless")
	assert_true(b.state["tick"] is int, "tick stays an int after JSON")


func test_snapshot_is_a_copy() -> void:
	var sim := SimScript.new()
	var snap := sim.snapshot()
	snap["player"]["pos"][0] = 99.0
	assert_ne(sim.player_pos().x, 99.0, "mutating the snapshot does not touch the sim")


func test_restore_rejects_unknown_versions() -> void:
	var sim := SimScript.new()
	var before := sim.snapshot()
	var bad := sim.snapshot()
	bad["version"] = 999
	assert_false(sim.restore(bad))
	assert_false(sim.restore({}))
	assert_eq(sim.snapshot(), before, "state untouched after a rejected restore")


func test_same_commands_give_the_same_state() -> void:
	var a := SimScript.new()
	var b := SimScript.new()
	for sim in [a, b]:
		sim.command(Vocab.MOVE_TO, {"pos": [-6.5, 2.5]})
		for i in 4:
			sim.step()
		sim.command(Vocab.INTERACT, {"object_id": "stash"})
		for i in 6:
			sim.step()
	assert_eq(a.snapshot(), b.snapshot())


func test_tick_length_is_about_half_a_second() -> void:
	assert_almost_eq(Sim.TICK_SECONDS, 0.5, 0.001)
	assert_almost_eq(Sim.WALK_PER_TICK, Sim.WALK_SPEED * Sim.TICK_SECONDS, 0.0001)


func test_every_spec_command_is_known() -> void:
	var sim := SimScript.new()
	for kind in Vocab.COMMANDS:
		var result := sim.command(kind, {})
		assert_ne(result["reason"], Vocab.REASON_UNKNOWN_COMMAND, "%s is in the vocabulary" % kind)
		if not Vocab.IMPLEMENTED.has(kind):
			assert_eq(result["reason"], Vocab.REASON_NOT_IMPLEMENTED, "%s is reserved" % kind)
	assert_eq(Vocab.COMMANDS.size(), 21, "the spec's fifteen commands, the brief's field fire, the guide's two, waystone travel, auto-retaliate and Deposit haul")
	assert_eq(Vocab.IMPLEMENTED.size(), Vocab.COMMANDS.size(), "the first playable implements every command")


func test_unknown_command_is_rejected() -> void:
	var sim := SimScript.new()
	var result := sim.command("teleport", {})
	assert_false(result["ok"])
	assert_eq(result["reason"], Vocab.REASON_UNKNOWN_COMMAND)
	var rejected := sim.drain_events()
	assert_eq(rejected.size(), 1)
	assert_eq(rejected[0]["kind"], Vocab.EV_COMMAND_REJECTED)
	assert_eq(rejected[0]["command"], "teleport")


func test_drain_events_empties_the_list() -> void:
	var sim := SimScript.new()
	sim.command(Vocab.MOVE_TO, {"pos": [2.5, 4.5]})
	assert_eq(sim.drain_events().size(), 1)
	assert_eq(sim.drain_events().size(), 0)
	sim.step()
	assert_true(sim.drain_events().size() >= 1)
