## Pacing: a scripted new character plays the whole first playable through the command
## interface, from an empty pack to the bandit captain and through the ring-two gate, using
## all seven skills. It plays a plain, sensible route, not a perfect one; a person reading the
## world and clicking takes longer, so the bot's time is held well under thirty minutes.
extends "res://tests/run.gd".TestCase

const H := preload("res://tests/sim_helpers.gd")
const SimScript := preload("res://sim/sim.gd")
const Vocab := preload("res://sim/vocab.gd")

## The bot must reach the captain inside this window (ticks are half a second).
const MIN_TICKS := 1200   # 10 minutes: the route must not be trivial
const MAX_TICKS := 2700   # 22.5 minutes of perfect clicking: about thirty for a person

const SOUTH_TREES := ["tree_1", "tree_2", "tree_3", "tree_4", "tree_5", "tree_6"]
const NORTH_TREES := ["tree_7", "tree_8", "tree_9", "tree_10"]
const COPPER := ["copper_1", "copper_2", "copper_3"]
const TIN := ["tin_1", "tin_2", "tin_3"]
const IRON := ["iron_1", "iron_2", "iron_3"]
const FOOD := ["cooked_trout", "cooked_fish"]

var sim: Sim
var deaths := 0
var log_lines: Array[String] = []


func test_a_new_character_reaches_and_beats_the_captain_in_time() -> void:
	sim = SimScript.new()
	# 1. Wood for the first tools and the shelves.
	_head_out()
	_gather(SOUTH_TREES, "logs", 20)
	_home()
	_withdraw("logs", 6)
	_smith("wooden_pickaxe")
	_smith("fishing_rod")
	_build("stash_shelves")
	_note("tools and shelves")
	# 2. Ore, fish and more wood in the inner ring. The gate banks the whole pack, tools too,
	# so every trip starts by taking them back out of the stash.
	_kit(["wooden_pickaxe", "fishing_rod"])
	_head_out()
	_gather(NORTH_TREES, "logs", 10)
	_gather(["fishing_hole"], "raw_fish", 8)
	_gather(COPPER, "copper_ore", 10)
	_home()
	_kit(["wooden_pickaxe"])
	_head_out()
	_gather(TIN, "tin_ore", 10)
	_gather(SOUTH_TREES, "logs", 20)
	_home()
	_build("forge")
	_withdraw("raw_fish")
	_cook_all()
	_withdraw("copper_ore")
	_withdraw("tin_ore")
	_withdraw("logs", 3)
	for i in 7:
		_smith("bronze_bar")
	_smith("bronze_pickaxe")
	_smith("bronze_sword")
	_note("forge, food and bronze")
	# 3. Ring one: the bow against the archer, the sword against the wolves.
	_withdraw("wooden_bow", 1)
	_withdraw("arrows", 30)
	_withdraw("cooked_fish", 10)
	_equip("wooden_bow")
	_head_out()
	_fight(["archer_1"])
	_equip("bronze_sword")
	_fight(["wolf_1", "wolf_2"])
	_fight(["wolf_3", "wolf_4", "wolf_5"])
	_fight(["wolf_6", "wolf_7"])
	_home()
	_note("first fights")
	# 4. More ore, iron from ring one, then the armoury, armour and the gate winch.
	_kit(["bronze_pickaxe"])
	_head_out()
	_gather(COPPER, "copper_ore", 9)
	_gather(IRON, "iron_ore", 8)
	_home()
	_kit(["bronze_pickaxe", "fishing_rod"])
	_head_out()
	_gather(TIN, "tin_ore", 9)
	_gather(NORTH_TREES, "logs", 10)
	_gather(["fishing_hole"], "raw_fish", 6)
	_home()
	_withdraw("copper_ore")
	_withdraw("tin_ore")
	for i in 9:
		_smith("bronze_bar")
	_build("armoury")
	_smith("bronze_armour")
	_equip("bronze_armour")
	_build("ring_two_gate")
	_withdraw("raw_fish")
	_cook_all()
	_withdraw("cooked_fish", 10)
	_note("armour and the winch")
	assert_true((sim.state["upgrades"] as Array).has("ring_two_gate"), "the winch is built")
	# 5. The captain, then through the gate.
	_head_out()
	var start := int(sim.state["tick"])
	_fight(["captain"])
	var reached := int(sim.state["tick"])
	assert_true(sim.ring_gate_open("ring_two_gate"), "the gate stands open")
	sim.command(Vocab.INTERACT, {"object_id": "ring_two_gate"})
	var events := _run_idle(60)
	assert_eq(H.of_kind(events, Vocab.EV_RING_TWO_REACHED).size(), 1, "walked through to ring two")
	_note("captain down after a %d-tick fight" % (reached - start))

	print("pacing: %s" % " | ".join(log_lines))
	print("pacing: the captain fell at tick %d (%.1f minutes), %d deaths" % [reached, reached * Sim.TICK_SECONDS / 60.0, deaths])
	assert_true(reached >= MIN_TICKS, "the route takes a while (%d ticks)" % reached)
	assert_true(reached <= MAX_TICKS, "the captain is reached in time (%d ticks)" % reached)
	for skill in SkillTable.NAMES:
		assert_true(int(sim.state["skills"][skill]["xp"]) > 0, "%s was used along the way" % skill)
	assert_eq(deaths, 0, "a sensible route needs no deaths")


# --- The bot's moves ----------------------------------------------------------------------

func _note(what: String) -> void:
	log_lines.append("%s @%d" % [what, int(sim.state["tick"])])


func _step(n := 1) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for i in n:
		sim.step()
		var got := sim.drain_events()
		deaths += H.of_kind(got, Vocab.EV_DIED).size()
		events.append_array(got)
	return events


func _busy() -> bool:
	return sim.is_moving() or sim.is_gathering() or sim.is_cooking() or sim.is_attacking()


func _run_idle(max_ticks: int) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for i in max_ticks:
		events.append_array(_step())
		if not _busy():
			break
	return events


func _head_out() -> void:
	if sim.in_outpost():
		sim.command(Vocab.CROSS_GATE)
		_run_idle(60)


## Back through the gate (banking), then warm and healed at the fire.
func _home() -> void:
	if not sim.in_outpost():
		sim.command(Vocab.CROSS_GATE)
		_run_idle(200)
		assert_true(sim.in_outpost(), "home")
	if int(sim.state["warmth"]) < Sim.WARMTH_MAX or int(sim.state["health"]) < Sim.HEALTH_MAX - 20:
		sim.command(Vocab.INTERACT, {"object_id": "fire"})
		_run_idle(60)
		while int(sim.state["warmth"]) < Sim.WARMTH_MAX or int(sim.state["health"]) < Sim.HEALTH_MAX - 20:
			_step()


## Gathers from the first workable node in `ids` until the pack holds `want` of `item`. Waits
## by the nodes for regrowth, and heads home early when the cold bites.
func _gather(ids: Array, item: String, want: int) -> void:
	var waited := 0
	while H.pack_count(sim, item) < want and waited < 200:
		if int(sim.state["warmth"]) < 70:
			_home()
			_head_out()
		var started := false
		for id in ids:
			if sim.command(Vocab.GATHER, {"object_id": id})["ok"]:
				started = true
				break
		sim.drain_events()
		if not started:
			_step(5)
			waited += 5
			continue
		var target := want
		while _busy() and H.pack_count(sim, item) < target:
			_step()
		if sim.is_gathering():
			sim.command(Vocab.MOVE_TO, {"pos": [sim.player_pos().x, sim.player_pos().y]})
			_run_idle(5)
	assert_true(H.pack_count(sim, item) >= want, "gathered %d %s" % [want, item])


## Takes one of each tool in `kinds` out of the stash unless it is already carried.
func _kit(kinds: Array) -> void:
	for kind in kinds:
		if H.pack_count(sim, kind) == 0:
			_withdraw(kind, 1)


## Withdraws `count` of `kind` from the stash, or all of it when `count` is -1.
func _withdraw(kind: String, count := -1) -> void:
	var slots: Array = sim.state["stash"]["slots"]
	if count < 0:
		count = H.stash_count(sim, kind)
	var left := count
	for i in slots.size():
		if left <= 0:
			break
		if slots[i] != null and slots[i]["item"] == kind:
			var n := mini(left, int(slots[i]["count"]))
			assert_true(sim.command(Vocab.WITHDRAW, {"index": i, "count": n})["ok"], "withdraw %s" % kind)
			_step()
			left -= n
	assert_true(H.pack_count(sim, kind) >= count, "withdrew %d %s" % [count, kind])


## Deposits every pack slot whose item is in `kinds`, keeping `keep` of them in the pack.
func _deposit_all(kinds: Array, keep := 0) -> void:
	for kind in kinds:
		var extra := H.pack_count(sim, kind) - keep
		var pack: Array = sim.state["inventory"]["pack"]
		for i in pack.size():
			if extra <= 0:
				break
			if pack[i] != null and pack[i]["item"] == kind:
				var n := mini(extra, int(pack[i]["count"]))
				sim.command(Vocab.DEPOSIT, {"index": i, "count": n})
				_step()
				extra -= n


func _smith(recipe: String) -> void:
	if not sim.near_kind(WorldDef.KIND_WORKBENCH, Sim.USE_REACH):
		sim.command(Vocab.INTERACT, {"object_id": "workbench"})
		_run_idle(60)
	var result := sim.command(Vocab.SMITH, {"recipe": recipe})
	assert_true(result["ok"], "smith %s: %s" % [recipe, result["reason"]])
	_step()


func _build(upgrade: String) -> void:
	# Build from the stash: deposit whatever of the cost the stash is short of.
	var cost: Dictionary = UpgradeTable.get_upgrade(upgrade)["cost"]
	for kind in cost:
		var short := int(cost[kind]) - H.stash_count(sim, kind)
		var pack: Array = sim.state["inventory"]["pack"]
		for i in pack.size():
			if short <= 0:
				break
			if pack[i] != null and pack[i]["item"] == kind:
				var n := mini(short, int(pack[i]["count"]))
				sim.command(Vocab.DEPOSIT, {"index": i, "count": n})
				_step()
				short -= n
	var result := sim.command(Vocab.BUILD, {"upgrade": upgrade})
	assert_true(result["ok"], "build %s: %s" % [upgrade, result["reason"]])
	_step()


func _equip(kind: String) -> void:
	var pack: Array = sim.state["inventory"]["pack"]
	for i in pack.size():
		if pack[i] != null and pack[i]["item"] == kind:
			sim.command(Vocab.EQUIP, {"index": i})
			_step()
			return
	assert_true(false, "no %s to equip" % kind)


func _cook_all() -> void:
	sim.command(Vocab.INTERACT, {"object_id": "fire"})
	_run_idle(60)
	for raw in RecipeTable.COOKING:
		var pack: Array = sim.state["inventory"]["pack"]
		for i in pack.size():
			if pack[i] != null and pack[i]["item"] == raw:
				if sim.command(Vocab.COOK, {"index": i})["ok"]:
					_run_idle(200)
				break


func _food_index() -> int:
	var pack: Array = sim.state["inventory"]["pack"]
	for kind in FOOD:
		for i in pack.size():
			if pack[i] != null and pack[i]["item"] == kind:
				return i
	return -1


## Fights each enemy in turn: attacks, eats when hurt, picks up what it drops. Any other enemy
## that joins in is fought too.
func _fight(ids: Array) -> void:
	var queue := ids.duplicate()
	var guard := 0
	while not queue.is_empty() and guard < 800:
		var id: String = queue[0]
		if sim.state["enemies"][id]["mode"] == Sim.MODE_DEAD:
			queue.pop_front()
			continue
		if not sim.is_attacking():
			var r := sim.command(Vocab.ATTACK, {"enemy_id": id})
			assert_true(r["ok"], "attack %s: %s" % [id, r["reason"]])
		if int(sim.state["health"]) < 50 and (sim.state["healing"] as Array).is_empty():
			var food := _food_index()
			if food >= 0:
				sim.command(Vocab.EAT, {"index": food})
		var events := _step()
		guard += 1
		for e in H.of_kind(events, Vocab.EV_ENEMY_NOTICED):
			if not queue.has(e["enemy_id"]):
				queue.append(e["enemy_id"])
		if deaths > 0:
			return
	assert_true(queue.is_empty(), "won the fight against %s" % [ids])
	_pick_up_loot()


func _pick_up_loot() -> void:
	for id in (sim.state["loot"] as Dictionary).keys():
		if not sim.state["loot"].has(id):
			continue
		if _pos(sim.state["loot"][id]).distance_to(sim.player_pos()) > 15.0:
			continue
		if sim.command(Vocab.INTERACT, {"object_id": id})["ok"]:
			_run_idle(30)


static func _pos(entry: Dictionary) -> Vector2:
	return Vector2(entry["pos"][0], entry["pos"][1])
