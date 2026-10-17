## Woodcutting through the command interface: gather, tools, a full pack, depletion,
## regrowth, experience and the level curve.
extends "res://tests/run.gd".TestCase

const H := preload("res://tests/sim_helpers.gd")
const SimScript := preload("res://sim/sim.gd")
const Vocab := preload("res://sim/vocab.gd")


func test_new_character_starts_with_a_wooden_axe() -> void:
	var sim := SimScript.new()
	assert_eq(sim.state["inventory"]["equipment"]["tool"], "wooden_axe")
	assert_true(sim.has_tool(ItemTable.TOOL_AXE))
	assert_eq(sim.state["inventory"]["pack"].size(), 12, "a twelve-slot pack")
	assert_eq(Inventory.contents(sim.state["inventory"]["pack"]), [], "the pack starts empty")


func test_gather_fills_the_pack_and_grants_xp() -> void:
	var sim := SimScript.new()
	var result := sim.command(Vocab.GATHER, {"object_id": "tree_3"})
	assert_true(result["ok"], result["reason"])
	var events := H.run_until_idle(sim, 300)
	var gathered := H.of_kind(events, Vocab.EV_GATHERED)
	var yield_count := int(WorldDef.NODE_KINDS[WorldDef.KIND_TREE]["yield"])
	assert_eq(gathered.size(), yield_count, "cuts the tree until it is spent")
	assert_eq(H.pack_count(sim, "logs"), yield_count, "logs are in the pack")
	assert_eq(gathered[0]["item"], "logs")
	assert_eq(gathered[0]["skill"], SkillTable.WOODCUTTING)
	var xp := int(WorldDef.NODE_KINDS[WorldDef.KIND_TREE]["xp"])
	assert_eq(sim.state["skills"]["woodcutting"]["xp"], xp * yield_count, "xp per log")
	assert_eq(sim.state["skills"]["mining"]["xp"], 0, "other skills untouched")
	var stopped := H.of_kind(events, Vocab.EV_ACTIVITY_STOPPED)
	assert_eq(stopped[stopped.size() - 1]["reason"], Vocab.REASON_DEPLETED)
	assert_eq(sim.state["nodes"]["tree_3"]["left"], 0)


func test_logs_stack_in_one_slot() -> void:
	var sim := SimScript.new()
	sim.command(Vocab.GATHER, {"object_id": "tree_3"})
	H.run_until_idle(sim, 300)
	var used := Inventory.contents(sim.state["inventory"]["pack"])
	assert_eq(used.size(), 1, "four logs share one slot")


func test_a_full_pack_refuses_gathering() -> void:
	var sim := SimScript.new()
	var full: Array = []
	for i in Sim.PACK_SLOTS:
		full.append({"item": "logs", "count": ItemTable.stack_size("logs")})
	H.set_pack(sim, full)
	var result := sim.command(Vocab.GATHER, {"object_id": "tree_1"})
	assert_false(result["ok"])
	assert_eq(result["reason"], Vocab.REASON_PACK_FULL)
	assert_false(sim.is_moving())


func test_gathering_stops_when_the_pack_fills() -> void:
	var sim := SimScript.new()
	var nearly: Array = []
	for i in Sim.PACK_SLOTS:
		nearly.append({"item": "logs", "count": ItemTable.stack_size("logs")})
	nearly[0] = {"item": "logs", "count": ItemTable.stack_size("logs") - 1}
	H.set_pack(sim, nearly)
	assert_true(sim.command(Vocab.GATHER, {"object_id": "tree_3"})["ok"])
	var events := H.run_until_idle(sim, 300)
	assert_eq(H.of_kind(events, Vocab.EV_GATHERED).size(), 1, "room for exactly one more")
	var stopped := H.of_kind(events, Vocab.EV_ACTIVITY_STOPPED)
	assert_eq(stopped[stopped.size() - 1]["reason"], Vocab.REASON_PACK_FULL)
	assert_eq(sim.state["nodes"]["tree_3"]["left"], 3, "the tree keeps what was not cut")


func test_gathering_needs_an_axe() -> void:
	var sim := SimScript.new()
	var snap := sim.snapshot()
	snap["inventory"]["equipment"]["tool"] = ""
	sim.restore(snap)
	var result := sim.command(Vocab.GATHER, {"object_id": "tree_1"})
	assert_eq(result["reason"], Vocab.REASON_NO_TOOL)
	assert_eq(sim.command(Vocab.INTERACT, {"object_id": "tree_1"})["reason"], Vocab.REASON_NO_TOOL, "clicking the tree too")
	# An axe carried in the pack counts as well as one in the tool slot.
	H.set_pack(sim, [{"item": "wooden_axe", "count": 1}])
	assert_true(sim.command(Vocab.GATHER, {"object_id": "tree_1"})["ok"])


func test_only_nodes_are_gatherable() -> void:
	var sim := SimScript.new()
	assert_eq(sim.command(Vocab.GATHER, {"object_id": "stash"})["reason"], Vocab.REASON_NOT_GATHERABLE)
	assert_eq(sim.command(Vocab.GATHER, {"object_id": "nope"})["reason"], Vocab.REASON_UNKNOWN_OBJECT)


func test_clicking_a_tree_gathers_it() -> void:
	var sim := SimScript.new()
	assert_true(sim.command(Vocab.INTERACT, {"object_id": "tree_3"})["ok"])
	var events := H.run_until_idle(sim, 300)
	var interacted := H.of_kind(events, Vocab.EV_INTERACTED)
	assert_eq(interacted[0]["action"], Vocab.ACTION_GATHER)
	assert_true(H.pack_count(sim, "logs") > 0)


func test_walking_away_stops_gathering() -> void:
	var sim := SimScript.new()
	sim.command(Vocab.GATHER, {"object_id": "tree_3"})
	for i in 60:
		sim.step()
		if sim.is_gathering():
			break
	assert_true(sim.is_gathering(), "started cutting")
	sim.drain_events()
	sim.command(Vocab.MOVE_TO, {"pos": H.OUTSIDE})
	var stopped := H.of_kind(sim.drain_events(), Vocab.EV_ACTIVITY_STOPPED)
	assert_eq(stopped.size(), 1)
	assert_eq(stopped[0]["reason"], Vocab.REASON_MOVED)
	assert_false(sim.is_gathering())


func test_a_spent_tree_refuses_then_regrows() -> void:
	var sim := SimScript.new()
	sim.command(Vocab.GATHER, {"object_id": "tree_3"})
	var events := H.run_until_idle(sim, 300)
	var depleted := H.of_kind(events, Vocab.EV_NODE_DEPLETED)
	assert_eq(depleted.size(), 1)
	assert_eq(sim.command(Vocab.GATHER, {"object_id": "tree_3"})["reason"], Vocab.REASON_DEPLETED)
	var respawn_tick := int(depleted[0]["respawn_tick"])
	assert_eq(respawn_tick - int(sim.state["tick"]) <= int(WorldDef.NODE_KINDS[WorldDef.KIND_TREE]["respawn_ticks"]), true)
	var later := H.run(sim, respawn_tick - int(sim.state["tick"]))
	assert_eq(H.of_kind(later, Vocab.EV_NODE_RESPAWNED).size(), 1, "regrows on its tick")
	assert_eq(sim.state["nodes"]["tree_3"]["left"], WorldDef.NODE_KINDS[WorldDef.KIND_TREE]["yield"])
	assert_true(sim.command(Vocab.GATHER, {"object_id": "tree_3"})["ok"])


func test_level_up_at_the_curve_threshold() -> void:
	var sim := SimScript.new()
	var xp := int(WorldDef.NODE_KINDS[WorldDef.KIND_TREE]["xp"])
	var need := SkillTable.xp_for_level(2)
	H.patch(sim, {"skills": {"woodcutting": {"xp": need - xp, "level": 1}}})
	assert_eq(sim.skill_level("woodcutting"), 1, "one log short of level 2")
	sim.command(Vocab.GATHER, {"object_id": "tree_3"})
	var levelled: Array[Dictionary] = []
	var gathered := 0
	for i in 300:
		sim.step()
		var events := sim.drain_events()
		gathered += H.of_kind(events, Vocab.EV_GATHERED).size()
		levelled.append_array(H.of_kind(events, Vocab.EV_LEVELLED))
		if gathered >= 1:
			break
	assert_eq(levelled.size(), 1, "the first log levels up")
	assert_eq(levelled[0]["skill"], "woodcutting")
	assert_eq(levelled[0]["level"], 2)
	assert_eq(sim.skill_level("woodcutting"), 2)
	assert_eq(sim.state["skills"]["woodcutting"]["xp"], need)


func test_the_curve_is_shared_and_rising() -> void:
	assert_eq(SkillTable.NAMES.size(), 8, "eight skills")
	assert_eq(SkillTable.xp_for_level(1), 0)
	var gap := 0
	for level in range(2, 20):
		var step := SkillTable.xp_for_level(level) - SkillTable.xp_for_level(level - 1)
		assert_true(step > gap, "each level costs more than the last")
		gap = step
		assert_eq(SkillTable.level_for_xp(SkillTable.xp_for_level(level)), level)
		assert_eq(SkillTable.level_for_xp(SkillTable.xp_for_level(level) - 1), level - 1)


func test_levels_never_decrease() -> void:
	var sim := SimScript.new()
	H.patch(sim, {"skills": {"woodcutting": {"xp": 0, "level": 5}}})
	assert_eq(sim.skill_level("woodcutting"), 5, "a stored level is kept even above the curve")
	for name in SkillTable.NAMES:
		assert_true(sim.state["skills"].has(name), "%s is in the table" % name)


func test_higher_level_cuts_faster_and_more_reliably() -> void:
	assert_true(Sim.gather_ticks(10) < Sim.gather_ticks(1), "fewer ticks per attempt")
	assert_true(Sim.gather_chance(10) > Sim.gather_chance(1), "better odds per attempt")
	var novice := _ticks_for_logs(1, 4)
	var expert := _ticks_for_logs(SkillTable.level_for_xp(SkillTable.xp_for_level(12)), 4)
	assert_true(expert < novice, "a level-12 woodcutter fells the tree sooner (%d < %d ticks)" % [expert, novice])


func _ticks_for_logs(level: int, logs: int) -> int:
	var sim := SimScript.new()
	H.patch(sim, {"skills": {"woodcutting": {"xp": SkillTable.xp_for_level(level), "level": level}}})
	sim.command(Vocab.GATHER, {"object_id": "tree_3"})
	for i in 60:  # walk there and begin
		sim.step()
		if sim.is_gathering():
			break
	var start := int(sim.state["tick"])
	while H.pack_count(sim, "logs") < logs and int(sim.state["tick"]) - start < 500:
		sim.step()
		sim.drain_events()
	return int(sim.state["tick"]) - start
