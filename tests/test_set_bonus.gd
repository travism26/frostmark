## Set bonus steps (#248): every set carries steps at 2 and 4 pieces, and at the full count for
## a five- or six-piece set; in a fight, each set worn is counted on its own and every step at
## or below its count adds to the blows, from the moment the piece that reaches it goes on to
## the moment it comes off. Tier pieces count toward no set, the real sets' placeholder steps
## change no hit, nothing new is saved, and a set piece's tooltip shows the count worn and the
## steps, the reached ones apart from the rest. The steps are tested with stand-in values on
## real sets (`ItemTable.add_stand_in_steps`), since the real values wait for #243.
extends "res://tests/run.gd".TestCase

const H := preload("res://tests/sim_helpers.gd")
const SimScript := preload("res://sim/sim.gd")
const Vocab := preload("res://sim/vocab.gd")

## Where the stand-in brute stands, in ring one by the archer's post, and the player beside it.
const HOME := [14.5, 28.5]
const BESIDE := [14.5, 27.5]
## A melee kind that hits hard enough to show any armour and never falls in a test.
const BRUTE := {
	"stand_in_set_brute": {
		"label": "Brute", "health": 5000, "weapon": "fangs", "speed": 2.0, "sight": 6.0,
		"actions": ["cleave", CombatTable.ACTION_REST],
		"loot": [], "rare_percent": 0, "respawn_ticks": 100,
	},
}

## The four Hearthguard pieces (melee), weapon first, and the five Wolfstalker pieces (ranged).
const HEARTHGUARD := ["hearthguard_broadsword", "hearthguard_helm", "hearthguard_body", "hearthguard_legs"]
const WOLFSTALKER := ["wolfstalker_bow", "wolfstalker_helm", "wolfstalker_body", "wolfstalker_legs", "wolfstalker_quiver"]

## Stand-in steps: power and defence each step, power even so a style edge of 0.5 or 1.5 still
## moves a hit by a whole number.
const FOUR_STEPS := [
	{"pieces": 2, "power": 2, "defence": 1}, {"pieces": 4, "power": 4, "defence": 2},
]
const FIVE_STEPS := [
	{"pieces": 2, "power": 2, "defence": 1}, {"pieces": 4, "power": 4, "defence": 2},
	{"pieces": 5, "power": 6, "defence": 3},
]


func _stand_ins(steps: Dictionary) -> void:
	ItemTable.clear_stand_in_steps()
	ItemTable.add_stand_in_steps(steps)
	CombatTable.add_stand_ins(BRUTE, {})


## A sim with only the brute, the player beside it wearing `worn` (slot -> item) and nothing
## else, arrows and cooked food in the pack.
func _duel(worn: Dictionary) -> Sim:
	CombatTable.add_stand_ins(BRUTE, {})
	var sim := H.arena({"brute": {"kind": "stand_in_set_brute", "home": HOME}})
	H.place(sim, BESIDE)
	H.set_pack(sim, [{"item": "arrows", "count": 100}])
	var snap := sim.snapshot()
	for slot in ItemTable.EQUIPMENT_SLOTS:
		snap["inventory"]["equipment"][slot] = worn.get(slot, "")
	sim.restore(snap)
	sim.drain_events()
	return sim


func _worn(pieces: Array) -> Dictionary:
	var worn := {}
	for kind in pieces:
		worn[ItemTable.slot(kind)] = kind
	return worn


## The player's first blow on the brute and the brute's first on the player, wearing `pieces`:
## {dealt, taken, multiplier}.
func _blows(pieces: Array) -> Dictionary:
	var sim := _duel(_worn(pieces))
	return _fight(sim)


func _fight(sim: Sim) -> Dictionary:
	assert_true(sim.command(Vocab.ATTACK, {"enemy_id": "brute"})["ok"], "attack the brute")
	var events := H.run_stamped(sim, 12)
	var mine := H.where(events, Vocab.EV_HIT, "attacker", Vocab.PLAYER)
	var theirs := H.where(events, Vocab.EV_HIT, "attacker", "brute")
	assert_true(mine.size() > 0 and theirs.size() > 0, "both sides land a blow")
	if mine.is_empty() or theirs.is_empty():
		return {"dealt": -1, "taken": -1, "multiplier": 1.0}
	return {"dealt": int(mine[0]["amount"]), "taken": int(theirs[0]["amount"]), "multiplier": float(mine[0]["multiplier"])}


## How much the stand-in steps move the blows when the first `n` of `pieces` are worn: the
## blows with `steps` in place, less the blows with the real (placeholder) steps.
func _moved(set_key: String, steps: Array, pieces: Array, n: int) -> Dictionary:
	ItemTable.clear_stand_in_steps()
	var plain := _blows(pieces.slice(0, n))
	_stand_ins({set_key: steps})
	var with_steps := _blows(pieces.slice(0, n))
	ItemTable.clear_stand_in_steps()
	return {
		"dealt": int(with_steps["dealt"]) - int(plain["dealt"]),
		"taken": int(plain["taken"]) - int(with_steps["taken"]),
		"multiplier": float(plain["multiplier"]),
	}


func _assert_moved(moved: Dictionary, power: int, defence: int, what: String) -> void:
	assert_eq(moved["dealt"], roundi(float(moved["multiplier"]) * power), "%s: hits harder by %d power" % [what, power])
	assert_eq(moved["taken"], defence, "%s: takes %d off each hit" % [what, defence])


func test_every_set_has_steps_at_2_and_4_and_at_the_full_count_past_4() -> void:
	ItemTable.clear_stand_in_steps()
	for set_key in ItemTable.SETS:
		var size := ItemTable.set_size(set_key)
		assert_true(size >= 4 and size <= 6, "%s has 4 to 6 pieces: %d" % [set_key, size])
		var counts: Array = []
		for step in ItemTable.set_steps(set_key):
			counts.append(int(step["pieces"]))
			for stat in step:
				assert_true(stat == "pieces" or ItemTable.STEP_STATS.has(stat), "%s's step gives a known stat: %s" % [set_key, stat])
		assert_eq(counts, [2, 4] if size == 4 else [2, 4, size], "%s's steps" % set_key)
	assert_eq(ItemTable.set_size("wolfstalker"), 5)
	assert_eq(ItemTable.set_size("auroral_warden"), 6)
	assert_eq(ItemTable.set_steps("steel"), [], "a tier has no steps")


func test_the_real_sets_ship_zero_valued_placeholder_steps() -> void:
	ItemTable.clear_stand_in_steps()
	for set_key in ItemTable.SETS:
		for step in ItemTable.set_steps(set_key):
			for stat in ItemTable.STEP_STATS:
				assert_eq(int(step.get(stat, 0)), 0, "%s's %d-piece %s waits for #243" % [set_key, step["pieces"], stat])


func test_a_four_piece_set_moves_the_hits_at_2_and_at_4_only() -> void:
	var expected := [[0, 0], [2, 1], [2, 1], [6, 3]]
	for n in range(1, 5):
		_assert_moved(_moved("hearthguard", FOUR_STEPS, HEARTHGUARD, n), expected[n - 1][0], expected[n - 1][1], "%d Hearthguard pieces" % n)
	CombatTable.clear_stand_ins()


func test_the_4_step_adds_to_the_2() -> void:
	var two := _moved("hearthguard", FOUR_STEPS, HEARTHGUARD, 2)
	var four := _moved("hearthguard", FOUR_STEPS, HEARTHGUARD, 4)
	assert_true(int(four["dealt"]) > int(two["dealt"]) and int(two["dealt"]) > 0, "4 pieces hit harder than 2: %s, %s" % [four, two])
	assert_eq(int(four["dealt"]), int(two["dealt"]) + 4, "the 4 step's power comes on top of the 2 step's")
	assert_eq(int(four["taken"]), int(two["taken"]) + 2, "and so does its defence")
	CombatTable.clear_stand_ins()


func test_a_five_piece_set_moves_the_hits_again_at_5() -> void:
	var expected := [[0, 0], [2, 1], [2, 1], [6, 3], [12, 6]]
	for n in range(1, 6):
		_assert_moved(_moved("wolfstalker", FIVE_STEPS, WOLFSTALKER, n), expected[n - 1][0], expected[n - 1][1], "%d Wolfstalker pieces" % n)
	CombatTable.clear_stand_ins()


func test_two_sets_worn_together_are_counted_apart() -> void:
	# Two Hearthguard pieces and two Shardweaver pieces: each set reaches its own 2 step, and
	# four pieces of mixed sets reach no 4 step.
	var steps := {"hearthguard": FOUR_STEPS, "shardweaver": [{"pieces": 2, "power": 0, "defence": 5}, {"pieces": 4, "power": 0, "defence": 50}]}
	var mixed := ["hearthguard_broadsword", "hearthguard_helm", "shardweaver_body", "shardweaver_legs"]
	ItemTable.clear_stand_in_steps()
	var plain := _blows(mixed)
	_stand_ins(steps)
	var both := _blows(mixed)
	assert_eq(int(both["dealt"]) - int(plain["dealt"]), 2, "Hearthguard's 2 step adds its power; no 4 step is reached")
	assert_eq(int(plain["taken"]) - int(both["taken"]), 1 + 5, "each set's own 2 step adds its defence")
	assert_eq(ItemTable.worn_set_counts(_worn(mixed)), {"hearthguard": 2, "shardweaver": 2})
	ItemTable.clear_stand_in_steps()
	CombatTable.clear_stand_ins()


func test_tier_pieces_count_toward_no_set() -> void:
	# A Hearthguard broadsword and helm with steel body and legs: two pieces, not four.
	var worn := ["hearthguard_broadsword", "hearthguard_helm", "steel_body", "steel_legs"]
	assert_eq(ItemTable.worn_set_counts(_worn(worn)), {"hearthguard": 2}, "steel counts toward no set")
	assert_eq(ItemTable.worn_set_counts(_worn(["steel_sword", "steel_helm", "fur_coat", "iron_legs"])), {}, "tiers and fur count toward none")
	var moved := _moved("hearthguard", FOUR_STEPS, worn, 4)
	_assert_moved(moved, 2, 1, "two Hearthguard pieces beside two steel ones")
	CombatTable.clear_stand_ins()


func test_a_sets_power_counts_only_for_its_own_style() -> void:
	# Four Hearthguard pieces worn with a steel bow: the defence still counts, the melee power not.
	var worn := ["steel_bow", "hearthguard_helm", "hearthguard_body", "hearthguard_legs"]
	ItemTable.clear_stand_in_steps()
	assert_eq(ItemTable.set_bonus(_worn(worn), CombatTable.STYLE_RANGED), {"power": 0, "defence": 0})
	_stand_ins({"hearthguard": FOUR_STEPS})
	assert_eq(ItemTable.set_bonus(_worn(worn), CombatTable.STYLE_RANGED), {"power": 0, "defence": 1}, "three pieces reach the 2 step: its defence, not its melee power")
	assert_eq(ItemTable.set_bonus(_worn(worn), CombatTable.STYLE_MELEE), {"power": 2, "defence": 1})
	_assert_moved(_moved("hearthguard", FOUR_STEPS, worn, 4), 0, 1, "Hearthguard armour behind a bow")
	CombatTable.clear_stand_ins()


func test_the_bonus_turns_on_with_equipping_and_off_with_unequipping() -> void:
	_stand_ins({"hearthguard": FOUR_STEPS})
	# Wearing the broadsword, the helm in the pack.
	var sim := _duel(_worn(["hearthguard_broadsword"]))
	H.set_pack(sim, [{"item": "hearthguard_helm", "count": 1}])
	var one := sim.combatant(Vocab.PLAYER)
	assert_true(sim.command(Vocab.EQUIP, {"index": 0})["ok"], "put the helm on")
	H.run(sim, 1)
	assert_eq(sim.state["inventory"]["equipment"]["helm"], "hearthguard_helm", "the helm is worn")
	var two := sim.combatant(Vocab.PLAYER)
	assert_eq(int(two["power"]) - int(one["power"]), 2, "the 2 step's power comes on with the second piece")
	assert_eq(int(two["defence"]) - int(one["defence"]), ItemTable.defence("hearthguard_helm") + 1, "and its defence beside the helm's own")
	var on := _fight(sim)
	assert_true(sim.command(Vocab.EQUIP, {"unequip": ItemTable.SLOT_HELM})["ok"], "take the helm off")
	H.run(sim, 1)
	assert_eq(sim.state["inventory"]["equipment"]["helm"], "", "the helm is off")
	assert_eq(sim.combatant(Vocab.PLAYER)["power"], one["power"], "the step's power goes with it")
	assert_eq(sim.combatant(Vocab.PLAYER)["defence"], one["defence"], "and its defence")
	# The same fight wearing only the broadsword from the start, for the hit amounts.
	var off := _blows(["hearthguard_broadsword"])
	assert_eq(int(on["dealt"]) - int(off["dealt"]), 2, "a blow lands harder while the step is on")
	ItemTable.clear_stand_in_steps()
	CombatTable.clear_stand_ins()


func test_the_placeholder_steps_leave_every_hit_unchanged() -> void:
	ItemTable.clear_stand_in_steps()
	CombatTable.add_stand_ins(BRUTE, {})
	# A full Hearthguard set hits and is hit exactly as its pieces' own stats say.
	var full := _blows(HEARTHGUARD)
	var bare := _blows([])
	var power := int(CombatTable.weapon("hearthguard_broadsword")["power"])
	assert_eq(full["dealt"], roundi(float(full["multiplier"]) * power), "the broadsword's own power, nothing more")
	assert_eq(int(bare["taken"]) - int(full["taken"]), ItemTable.worn_defence(_worn(HEARTHGUARD)), "the armour's own defence, nothing more")
	for set_key in ItemTable.SETS:
		var pieces: Array = []
		for kind in ItemTable.ITEMS:
			if ItemTable.set_of(kind) == set_key:
				pieces.append(kind)
		var style := ItemTable.set_style(set_key)
		assert_eq(ItemTable.set_bonus(_worn(pieces), style), {"power": 0, "defence": 0}, "a full %s set adds nothing yet" % set_key)
	CombatTable.clear_stand_ins()


func test_nothing_new_is_saved() -> void:
	_stand_ins({"hearthguard": FOUR_STEPS})
	var sim := _duel(_worn(HEARTHGUARD))
	var plain := _duel(_worn(["steel_sword", "steel_helm", "steel_body", "steel_legs"]))
	assert_eq(sim.snapshot().keys(), plain.snapshot().keys(), "a set wearer's save has the same fields")
	assert_eq((sim.snapshot()["inventory"] as Dictionary).keys(), (plain.snapshot()["inventory"] as Dictionary).keys())
	assert_eq((sim.snapshot()["player"] as Dictionary).keys(), (plain.snapshot()["player"] as Dictionary).keys())
	var back := SimScript.new()
	assert_true(back.command(Vocab.IMPORT_SAVE, {"code": SaveCode.encode(sim.snapshot())})["ok"], "the save code imports")
	assert_eq(back.combatant(Vocab.PLAYER)["power"], sim.combatant(Vocab.PLAYER)["power"], "the bonus comes back from the worn pieces alone")
	assert_eq(back.combatant(Vocab.PLAYER)["defence"], sim.combatant(Vocab.PLAYER)["defence"])
	ItemTable.clear_stand_in_steps()
	CombatTable.clear_stand_ins()
