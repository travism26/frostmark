## A scripted player for the pacing and balance runs: the moves a person makes (head out,
## gather, go home, craft, build, fight), driven only through Sim's `command()` and `step()`.
## Not a test file itself (the runner only discovers test_*.gd); a route script calls these
## moves in order. Every accepted command the bot issues is counted, by kind and by phase, so a
## run can say how many clicks a person would have made along the way.
extends RefCounted

const H := preload("res://tests/sim_helpers.gd")
const SimScript := preload("res://sim/sim.gd")
const Vocab := preload("res://sim/vocab.gd")

const FOOD := ["cooked_char", "cooked_trout", "cooked_fish"]
const MELEE := "melee"
const RANGED := "ranged"
## The longest a wait by a fire may take: from 1 health to full is 50 ticks there.
const FIRE_TICKS := 600

## Commands a person gives by clicking in the world, and those given in a panel.
const WORLD_COMMANDS := [Vocab.MOVE_TO, Vocab.INTERACT, Vocab.GATHER, Vocab.CROSS_GATE, Vocab.ATTACK]
const PANEL_COMMANDS := [Vocab.WITHDRAW, Vocab.DEPOSIT, Vocab.DEPOSIT_HAUL, Vocab.SMITH, Vocab.BUILD, Vocab.EQUIP, Vocab.EAT, Vocab.COOK, Vocab.DROP]

var sim: Sim
var _case: WeakRef  # the TestCase whose assertions the moves record (weak: it holds the bot)
var t:
	get:
		return _case.get_ref()
var deaths := 0
var log_lines: Array[String] = []
## Warmth at which a gathering trip heads home (or to the brazier in ring two).
var turn_back_warmth := 70
## Closed phases, in order: {name, ticks, world, panel, outings, firsts}.
var phases: Array[Dictionary] = []
var _phase := {}
var _seen: Dictionary = {}  # recipes smithed and upgrades built at least once


func _init(test_case) -> void:
	_case = weakref(test_case)
	sim = SimScript.new()


func note(what: String) -> void:
	log_lines.append("%s @%d" % [what, int(sim.state["tick"])])


## Starts counting a new phase, closing the one under way.
func phase(name: String) -> void:
	end_phase()
	_phase = {"name": name, "start": int(sim.state["tick"]), "world": 0, "panel": 0, "outings": 0, "firsts": 0}


func end_phase() -> void:
	if _phase.is_empty():
		return
	_phase["ticks"] = int(sim.state["tick"]) - int(_phase["start"])
	phases.append(_phase)
	_phase = {}


## Issues a command the way a person would and counts it when it is accepted.
func cmd(kind: String, args: Dictionary = {}) -> Dictionary:
	var r := sim.command(kind, args)
	if r["ok"] and not _phase.is_empty():
		if WORLD_COMMANDS.has(kind):
			_phase["world"] += 1
		elif PANEL_COMMANDS.has(kind):
			_phase["panel"] += 1
	return r


func _first(key: String) -> void:
	if not _seen.has(key):
		_seen[key] = true
		if not _phase.is_empty():
			_phase["firsts"] += 1


func step(n := 1) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for i in n:
		sim.step()
		var got := sim.drain_events()
		deaths += H.of_kind(got, Vocab.EV_DIED).size()
		events.append_array(got)
	return events


## Steps until `cond` holds, at most `max_ticks` ticks. Running out records a failed
## assertion and returns false, so a wait that can never end fails the run instead of hanging it.
func step_until(cond: Callable, max_ticks: int, what: String) -> bool:
	for i in max_ticks:
		if cond.call():
			return true
		step()
	if cond.call():
		return true
	t.assert_true(false, "%s within %d ticks" % [what, max_ticks])
	return false


func _warm_and_mended() -> bool:
	return int(sim.state["warmth"]) >= Sim.WARMTH_MAX and int(sim.state["health"]) >= Sim.HEALTH_MAX - 20


func _healed() -> bool:
	return int(sim.state["health"]) >= Sim.HEALTH_MAX


func busy() -> bool:
	return sim.is_moving() or sim.is_gathering() or sim.is_cooking() or sim.is_attacking()


func run_idle(max_ticks: int) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for i in max_ticks:
		events.append_array(step())
		if not busy():
			break
	return events


## Puts the haul away first (Deposit haul; kit stays in the pack), so it does not ride out.
func head_out() -> void:
	if sim.in_outpost():
		deposit_haul()
		cmd(Vocab.CROSS_GATE)
		run_idle(60)
		if not _phase.is_empty():
			_phase["outings"] += 1


## Back through the gate, home safe, haul deposited at the stash unless `deposit` is false
## (kit stays in the pack), then warm and healed at the fire. From ring two that is back
## through its gate first.
func home(deposit := true) -> void:
	if sim.state["player"]["region"] == WorldDef.REGION_RING_TWO:
		if int(sim.state["health"]) < 60:
			rest_at_the_brazier()
		through_ring_gate()
	if not sim.in_outpost():
		cmd(Vocab.CROSS_GATE)
		run_idle(200)
		t.assert_true(sim.in_outpost(), "home")
		if deposit:
			deposit_haul()
			stow_finds()
	if int(sim.state["warmth"]) < Sim.WARMTH_MAX or int(sim.state["health"]) < Sim.HEALTH_MAX - 20:
		cmd(Vocab.INTERACT, {"object_id": "fire"})
		run_idle(60)
		step_until(_warm_and_mended, FIRE_TICKS, "warm and mended at the fire")


## Gathers from the first workable node in `ids` until the pack holds `want` of `item`. Waits
## by the nodes for regrowth, and heads home early when the cold bites.
func gather(ids: Array, item: String, want: int) -> void:
	var waited := 0
	while H.pack_count(sim, item) < want and waited < 200:
		if int(sim.state["warmth"]) < turn_back_warmth:
			if sim.state["player"]["region"] == WorldDef.REGION_RING_TWO:
				warm_at("brazier")
			else:
				home()
				head_out()
		var started := false
		for id in ids:
			if cmd(Vocab.GATHER, {"object_id": id})["ok"]:
				started = true
				break
		sim.drain_events()
		if not started:
			step(5)
			waited += 5
			continue
		var attackers: Array = []
		while busy() and H.pack_count(sim, item) < want and attackers.is_empty():
			attackers = _threats(step())
		if not attackers.is_empty():
			# Whatever notices the bot is fought. In ring two that is a bow for stalkers and a
			# blade for trolls, then a rest at the brazier; nearer home, whatever it holds. Then it
			# goes back to work.
			if sim.state["player"]["region"] == WorldDef.REGION_RING_TWO:
				for id in attackers:
					var kind: String = sim.state["enemies"][id]["kind"]
					fight_with(RANGED if kind == "ruin_stalker" else MELEE, [id])
				rest_at_the_brazier()
			else:
				fight(attackers)
			continue
		if sim.is_gathering():
			cmd(Vocab.MOVE_TO, {"pos": [sim.player_pos().x, sim.player_pos().y]})
			run_idle(5)
	t.assert_true(H.pack_count(sim, item) >= want, "gathered %d %s" % [want, item])


## In ring two the bot fights stalkers with a bow (a melee player eats the edge at distance and
## they back away) and trolls with a blade. Elsewhere it keeps whatever it holds.
func _style_for(id: String) -> String:
	return RANGED if sim.state["enemies"][id]["kind"] == "ruin_stalker" else MELEE


func _wrong_weapon_for(id: String) -> bool:
	if sim.state["player"]["region"] != WorldDef.REGION_RING_TWO:
		return false
	return CombatTable.weapon(sim.player_weapon())["style"] != _style_for(id) and best_weapon(_style_for(id)) != ""


## The enemies that noticed the player in these events, anywhere outside the walls: one that
## noticed from ring one follows the player into the inner ring.
func _threats(events: Array[Dictionary]) -> Array:
	var out: Array = []
	if sim.in_outpost():
		return out
	for e in H.of_kind(events, Vocab.EV_ENEMY_NOTICED):
		out.append(e["enemy_id"])
	return out


func through_ring_gate() -> void:
	var r := cmd(Vocab.INTERACT, {"object_id": "ring_two_gate"})
	t.assert_true(r["ok"], "to the ring gate: %s" % r["reason"])
	run_idle(200)


## Out of the outpost and through the ring-two gate.
func to_ring_two() -> void:
	head_out()
	through_ring_gate()
	t.assert_eq(sim.state["player"]["region"], WorldDef.REGION_RING_TWO, "in ring two")


## Walks to a fire and stands there until warm.
func warm_at(fire: String) -> void:
	cmd(Vocab.INTERACT, {"object_id": fire})
	run_idle(100)
	step_until(_warm_and_mended, FIRE_TICKS, "warm and mended at the %s" % fire)


## Out to ring two with food, both weapons, arrows and the tools in `tools`, at full health.
func ready_for_ring_two(tools: Array) -> void:
	if int(sim.state["health"]) < Sim.HEALTH_MAX:
		warm_at("fire")
		step_until(_healed, FIRE_TICKS, "healed at the fire")
	kit(tools)
	withdraw_food()
	for style in [MELEE, RANGED]:
		var w := best_weapon(style)
		if w != "" and sim.state["inventory"]["equipment"]["weapon"] != w and H.pack_count(sim, w) == 0:
			withdraw(w, 1)
	for slot in ItemTable.ARMOUR_SLOTS:
		var armour := best_of_slot(slot)
		var outgrown: String = sim.state["inventory"]["equipment"][slot]
		if armour != "" and outgrown != armour:
			if H.pack_count(sim, armour) == 0:
				withdraw(armour, 1)
			equip(armour)
			# The piece it outgrew is dropped, so it crowds neither the trip's loot nor the stash.
			if outgrown != "":
				_drop_carried(outgrown)
	if H.stash_count(sim, "arrows") > 0:
		withdraw("arrows")
	to_ring_two()


## The best weapon of `style` worn, carried or stashed, or "".
func best_weapon(style: String) -> String:
	var best := ""
	for kind in ItemTable.ITEMS:
		if ItemTable.ITEMS[kind].get("style", "") == style and owned(kind):
			if best == "" or ItemTable.tier_rank(ItemTable.tier(kind)) > ItemTable.tier_rank(ItemTable.tier(best)):
				best = kind
	return best


func best_of_slot(slot: String) -> String:
	var best := ""
	for kind in ItemTable.ITEMS:
		if ItemTable.slot(kind) == slot and owned(kind):
			if best == "" or ItemTable.tier_rank(ItemTable.tier(kind)) > ItemTable.tier_rank(ItemTable.tier(best)):
				best = kind
	return best


func owned(kind: String) -> bool:
	return H.pack_count(sim, kind) > 0 or H.stash_count(sim, kind) > 0 or (sim.state["inventory"]["equipment"] as Dictionary).values().has(kind)


## Fights with the best weapon of `style`: a bow for the stalkers, a blade for the trolls.
func fight_with(style: String, ids: Array) -> void:
	var w := best_weapon(style)
	if sim.state["inventory"]["equipment"]["weapon"] != w:
		equip(w)
	fight(ids)


## Back to the brazier past the ring-two gate to warm up and heal before the next fight.
func rest_at_the_brazier() -> void:
	warm_at("brazier")
	step_until(_healed, FIRE_TICKS, "healed at the brazier")


## Clicks Deposit haul at the stash when the pack holds any haul and the stash has room.
func deposit_haul() -> void:
	if sim.check(Vocab.DEPOSIT_HAUL, {}) != "":
		return
	t.assert_true(cmd(Vocab.DEPOSIT_HAUL)["ok"], "deposit haul")
	step()


## Takes the stash's cooked food, up to ten of each kind.
func withdraw_food() -> void:
	for kind in FOOD:
		var n := mini(10, H.stash_count(sim, kind))
		if n > 0:
			withdraw(kind, n)


## Takes one of each tool in `kinds` out of the stash unless it is already carried.
func kit(kinds: Array) -> void:
	for kind in kinds:
		if H.pack_count(sim, kind) == 0:
			withdraw(kind, 1)


## Withdraws `count` of `kind` from the stash, or all of it when `count` is -1.
func withdraw(kind: String, count := -1) -> void:
	var slots: Array = sim.state["stash"]["slots"]
	if count < 0:
		count = H.stash_count(sim, kind)
	var left := count
	for i in slots.size():
		if left <= 0:
			break
		if slots[i] != null and slots[i]["item"] == kind:
			var n := mini(left, int(slots[i]["count"]))
			t.assert_true(cmd(Vocab.WITHDRAW, {"index": i, "count": n})["ok"], "withdraw %s" % kind)
			step()
			left -= n
	t.assert_true(H.pack_count(sim, kind) >= count, "withdrew %d %s" % [count, kind])


## Deposits everything of each kind in `kinds` from the pack: kit the next trips do not need.
func put_away(kinds: Array) -> void:
	for kind in kinds:
		var pack: Array = sim.state["inventory"]["pack"]
		for i in pack.size():
			if pack[i] != null and pack[i]["item"] == kind:
				t.assert_true(cmd(Vocab.DEPOSIT, {"index": i, "count": int(pack[i]["count"])})["ok"], "deposit %s" % kind)
				step()


## Deposits every item the pack holds that has a rarity band, such as a dropped iron piece: a
## person stows a find at home rather than carry it, and takes it back out once it is the best
## they own (`ready_for_ring_two`). Left in the pack, a lucky run's finds would crowd out its loot.
func stow_finds() -> void:
	var finds := []
	for slot in sim.state["inventory"]["pack"]:
		if slot != null and ItemTable.rarity(slot["item"]) != "" and not finds.has(slot["item"]):
			finds.append(slot["item"])
	put_away(finds)


## Takes everything of each kind in `kinds` out of the stash and drops it, to free the slots.
func discard(kinds: Array) -> void:
	for kind in kinds:
		withdraw(kind)
		var pack: Array = sim.state["inventory"]["pack"]
		for i in pack.size():
			if pack[i] != null and pack[i]["item"] == kind:
				t.assert_true(cmd(Vocab.DROP, {"index": i})["ok"], "drop %s" % kind)
				step()


## Drops one `kind` from the pack.
func _drop_carried(kind: String) -> void:
	var pack: Array = sim.state["inventory"]["pack"]
	for i in pack.size():
		if pack[i] != null and pack[i]["item"] == kind:
			t.assert_true(cmd(Vocab.DROP, {"index": i})["ok"], "drop %s" % kind)
			step()
			return


func smith(recipe: String) -> void:
	if not sim.near_kind(WorldDef.KIND_WORKBENCH, Sim.USE_REACH):
		cmd(Vocab.INTERACT, {"object_id": "workbench"})
		run_idle(60)
	var result := cmd(Vocab.SMITH, {"recipe": recipe})
	t.assert_true(result["ok"], "smith %s: %s" % [recipe, result["reason"]])
	_first(recipe)
	step()


func build(upgrade: String) -> void:
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
				cmd(Vocab.DEPOSIT, {"index": i, "count": n})
				step()
				short -= n
	var result := cmd(Vocab.BUILD, {"upgrade": upgrade})
	t.assert_true(result["ok"], "build %s: %s" % [upgrade, result["reason"]])
	_first(upgrade)
	step()


func equip(kind: String) -> void:
	var pack: Array = sim.state["inventory"]["pack"]
	for i in pack.size():
		if pack[i] != null and pack[i]["item"] == kind:
			cmd(Vocab.EQUIP, {"index": i})
			step()
			return
	t.assert_true(false, "no %s to equip" % kind)


func cook_all() -> void:
	cmd(Vocab.INTERACT, {"object_id": "fire"})
	run_idle(60)
	for raw in RecipeTable.COOKING:
		var pack: Array = sim.state["inventory"]["pack"]
		for i in pack.size():
			if pack[i] != null and pack[i]["item"] == raw:
				if cmd(Vocab.COOK, {"index": i})["ok"]:
					run_idle(200)
				break


func food_index() -> int:
	var pack: Array = sim.state["inventory"]["pack"]
	for kind in FOOD:
		for i in pack.size():
			if pack[i] != null and pack[i]["item"] == kind:
				return i
	return -1


## Fights each enemy in turn: attacks, eats when hurt, picks up what it drops. Any other enemy
## that joins in is fought too.
func fight(ids: Array) -> void:
	var queue := ids.duplicate()
	var guard := 0
	var dodging := 0
	while not queue.is_empty() and guard < 800:
		var id: String = queue[0]
		if sim.state["enemies"][id]["mode"] == Sim.MODE_DEAD:
			queue.pop_front()
			continue
		if dodging > 0:
			dodging -= 1
		elif not sim.is_attacking() and _wrong_weapon_for(id):
			equip(best_weapon(_style_for(id)))
			continue
		elif not sim.is_attacking():
			var r := cmd(Vocab.ATTACK, {"enemy_id": id})
			t.assert_true(r["ok"], "attack %s: %s" % [id, r["reason"]])
		if int(sim.state["health"]) < 50 and (sim.state["healing"] as Array).is_empty():
			var food := food_index()
			if food >= 0:
				cmd(Vocab.EAT, {"index": food})
		var events := step()
		guard += 1
		for e in H.of_kind(events, Vocab.EV_ENEMY_NOTICED):
			if not queue.has(e["enemy_id"]):
				queue.append(e["enemy_id"])
		# A troll winding up is stepped away from, so its crush misses.
		for e in H.where(events, Vocab.EV_ENEMY_STANCE, "action", "wind_up"):
			var troll := pos_of(sim.state["enemies"][e["enemy_id"]])
			var away := (sim.player_pos() - troll).normalized()
			if cmd(Vocab.MOVE_TO, {"pos": [sim.player_pos().x + away.x * 3.0, sim.player_pos().y + away.y * 3.0]})["ok"]:
				dodging = 2
		if deaths > 0:
			return
	t.assert_true(queue.is_empty(), "won the fight against %s" % [ids])
	pick_up_loot()


func pick_up_loot() -> void:
	for id in (sim.state["loot"] as Dictionary).keys():
		if not sim.state["loot"].has(id):
			continue
		if pos_of(sim.state["loot"][id]).distance_to(sim.player_pos()) > 15.0:
			continue
		if cmd(Vocab.INTERACT, {"object_id": id})["ok"]:
			run_idle(30)


static func pos_of(entry: Dictionary) -> Vector2:
	return Vector2(entry["pos"][0], entry["pos"][1])
