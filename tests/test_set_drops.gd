## Set pieces drop in their ring (#249): each ring's uncommon band holds the pieces of the sets
## of its level, mid in ring one, mid-high in ring two and high in ring three, built from the
## set levels; rings one and two's still hold the iron pieces, ring three's ordinary kinds roll
## against a band of their own, and every found set piece is uncommon. Seeded kills in each ring
## drop that ring's set pieces and never another ring's.
extends "res://tests/run.gd".TestCase

const H := preload("res://tests/sim_helpers.gd")
const Vocab := preload("res://sim/vocab.gd")

## Each ring's uncommon band, the set level it holds, whether it holds the iron pieces, the kinds
## that roll against it, and a home in that ring for the seeded kills (beside a real placement).
const RINGS := {
	"ring_one_uncommon": {
		"level": ItemTable.LEVEL_MID, "iron": true, "home": [14.5, 28.5],
		"kinds": ["wolf", "bandit_archer", "frost_witch", "bandit_captain"],
	},
	"ring_two_uncommon": {
		"level": ItemTable.LEVEL_MID_HIGH, "iron": true, "home": [-32.5, 72.5],
		"kinds": ["ice_troll", "ruin_stalker"],
	},
	"ring_three_uncommon": {
		"level": ItemTable.LEVEL_HIGH, "iron": false, "home": [11.5, 146.0],
		"kinds": ["snowveil_archer", "frostbound_knight", "aurora_seer"],
	},
}
const IRON_POOL := ["iron_sword", "iron_helm", "iron_body", "iron_legs", "iron_bow", "iron_axe", "iron_pickaxe", "iron_staff"]
## Seeded kills of each kind; enough that every ring's band lands on its set pieces, and rings
## one and two's on iron too.
const SEEDS := 60


## Every set piece of `level`, read from the item table one piece at a time.
static func _pieces_of(level: String) -> Array:
	var out := []
	for kind in ItemTable.ITEMS:
		if ItemTable.set_of(kind) != "" and ItemTable.set_level(ItemTable.set_of(kind)) == level:
			out.append(kind)
	return out


func test_each_rings_band_holds_the_pieces_of_its_level_and_rings_one_and_two_the_iron() -> void:
	assert_eq(CombatTable.RARITY_BANDS.keys(), RINGS.keys(), "one uncommon band a ring")
	for id in RINGS:
		var ring: Dictionary = RINGS[id]
		var band := CombatTable.rarity_band(id)
		assert_eq(band["rarity"], ItemTable.RARITY_UNCOMMON, id)
		var expected: Array = (IRON_POOL if ring["iron"] else []) + _pieces_of(ring["level"])
		assert_eq(Array(band["pool"]), expected, "%s: iron first if any, then the %s sets' pieces" % [id, ring["level"]])
		assert_true(_pieces_of(ring["level"]).size() >= 12, "%s holds three sets' pieces" % id)


func test_a_band_naming_a_set_level_takes_in_its_pieces_and_one_naming_none_takes_none() -> void:
	CombatTable.add_stand_in_loot({}, {
		"stand_in_top": {"rarity": ItemTable.RARITY_UNCOMMON, "pool": ["iron_axe"], "set_level": ItemTable.LEVEL_MID},
		"stand_in_plain": {"rarity": ItemTable.RARITY_UNCOMMON, "pool": ["iron_axe"]},
	})
	var with_level := CombatTable.rarity_band("stand_in_top")
	var plain := CombatTable.rarity_band("stand_in_plain")
	CombatTable.clear_stand_ins()
	assert_eq(Array(with_level["pool"]), ["iron_axe"] + _pieces_of(ItemTable.LEVEL_MID))
	assert_eq(Array(plain["pool"]), ["iron_axe"])
	assert_eq(ItemTable.set_pieces(ItemTable.LEVEL_TOP).size(), _pieces_of(ItemTable.LEVEL_TOP).size(), "every level answers its pieces")
	assert_eq(ItemTable.set_pieces(""), [] as Array[String], "no level, no pieces")


func test_every_kind_rolls_against_its_rings_band_and_ring_three_ordinary_kinds_gain_one() -> void:
	var rolled := {}
	for id in RINGS:
		for kind in RINGS[id]["kinds"]:
			rolled[kind] = true
			var roll: Dictionary = CombatTable.loot_table(kind)["rare_roll"]
			assert_eq(roll.keys(), [id], "%s rolls against %s alone" % [kind, id])
			assert_true(int(roll[id]) > 0, "%s has a chance at it" % kind)
	for kind in ["snowveil_archer", "frostbound_knight", "aurora_seer"]:
		assert_false(CombatTable.enemy(kind).get("boss", false), "%s is one of ring three's ordinary kinds" % kind)
	for kind in CombatTable.ENEMIES:
		assert_eq(CombatTable.rare_roll_problems(CombatTable.loot_table(kind)), [] as Array[String], kind)
		if not rolled.has(kind):
			assert_eq(CombatTable.loot_table(kind)["rare_roll"], {}, "%s rolls for nothing" % kind)


func test_found_set_pieces_report_the_uncommon_band_and_top_set_pieces_none() -> void:
	for kind in ItemTable.ITEMS:
		var set_key := ItemTable.set_of(kind)
		if set_key == "":
			continue
		var found := ItemTable.set_level(set_key) != ItemTable.LEVEL_TOP
		assert_eq(ItemTable.rarity(kind), ItemTable.RARITY_UNCOMMON if found else "", kind)
		assert_eq(RecipeTable.has(kind), not found, "%s: found or crafted, never both" % kind)


func test_seeded_kills_in_each_ring_drop_its_set_pieces_and_never_another_rings() -> void:
	for id in RINGS:
		var ring: Dictionary = RINGS[id]
		var own: Array = _pieces_of(ring["level"])
		var sets_seen := {}
		var iron_seen := 0
		for kind in ring["kinds"]:
			for rng in range(1, SEEDS + 1):
				for item in _kill(kind, ring["home"], rng):
					var set_key := ItemTable.set_of(item)
					if set_key != "":
						assert_true(own.has(item), "%s at seed %d dropped %s, a %s piece, in %s" % [kind, rng, item, ItemTable.set_level(set_key), id])
						sets_seen[set_key] = true
					elif IRON_POOL.has(item):
						iron_seen += 1
		assert_false(sets_seen.is_empty(), "%s's kills drop %s set pieces" % [id, ring["level"]])
		if ring["iron"]:
			assert_true(iron_seen > 0, "%s still drops iron pieces" % id)
		else:
			assert_eq(iron_seen, 0, "%s drops no iron" % id)


## Kills one `kind` at `home`, seeded with `rng`, with a single blow from beside it, and answers
## the items it dropped.
static func _kill(kind: String, home: Array, rng: int) -> Array:
	var sim := H.arena({"foe": {"kind": kind, "home": home}})
	H.place(sim, [home[0] + 1.0, home[1]])
	H.arm(sim, "iron_sword")
	H.patch(sim, {"rng": rng})
	H.patch_enemy(sim, "foe", {"health": 1})
	sim.drain_events()
	sim.command(Vocab.ATTACK, {"enemy_id": "foe"})
	var out := []
	for drop in H.of_kind(H.run(sim, 3), Vocab.EV_LOOT_DROPPED):
		out.append(drop["item"])
	return out
