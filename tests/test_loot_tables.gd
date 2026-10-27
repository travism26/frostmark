## Loot tables (#238): every enemy kind's drops come from its loot table, its guaranteed loot
## plus one rare roll against the rarity bands it names. Today's iron drop is the uncommon band
## rings one and two share, at each kind's odds of before, and a seeded kill draws exactly what
## it drew before.
extends "res://tests/run.gd".TestCase

const H := preload("res://tests/sim_helpers.gd")
const Vocab := preload("res://sim/vocab.gd")

const IRON_BAND := "rings_one_two_uncommon"
## Each kind's chance at an iron piece before loot tables; every other kind had none.
const IRON_ODDS := {"wolf": 5, "bandit_archer": 10, "frost_witch": 10, "bandit_captain": 25, "ice_troll": 15, "ruin_stalker": 10}
## The iron pool, in the order its draws index it.
const IRON_POOL := ["iron_sword", "iron_helm", "iron_body", "iron_legs", "iron_bow", "iron_axe", "iron_pickaxe", "iron_staff"]
## Where the arena's two foes stand, either side of the player, in ring one by the archer.
const FIRST_HOME := [14.5, 28.5]
const SECOND_HOME := [14.5, 26.5]
const BETWEEN := [14.5, 27.5]
## Two kills in a row, the first kind then the second, from a seeded generator: what each drops,
## captured from the rare roll before loot tables (a single rare percent and one rare list).
## The first kind of each pair rolls for nothing or draws for its boss piece first, so the second
## kill's drop shows how many draws the first one took.
const PAIRS := [["frostbound_knight", "ice_troll"], ["bandit_captain", "wolf"], ["snowveil_archer", "frost_witch"]]
const SEEDS := 30
const BEFORE: Array[String] = [
	"frostbound_knight+ice_troll@1: rime_steel x1 | troll_hide x1",
	"frostbound_knight+ice_troll@2: rime_steel x1 | troll_hide x1",
	"frostbound_knight+ice_troll@3: rime_steel x1 | troll_hide x1, iron_axe x1",
	"frostbound_knight+ice_troll@4: rime_steel x1 | troll_hide x1",
	"frostbound_knight+ice_troll@5: rime_steel x1 | troll_hide x1",
	"frostbound_knight+ice_troll@6: rime_steel x1 | troll_hide x1",
	"frostbound_knight+ice_troll@7: rime_steel x1 | troll_hide x1, iron_bow x1",
	"frostbound_knight+ice_troll@8: rime_steel x1 | troll_hide x1",
	"frostbound_knight+ice_troll@9: rime_steel x1 | troll_hide x1",
	"frostbound_knight+ice_troll@10: rime_steel x1 | troll_hide x1, iron_axe x1",
	"frostbound_knight+ice_troll@11: rime_steel x1 | troll_hide x1, iron_legs x1",
	"frostbound_knight+ice_troll@12: rime_steel x1 | troll_hide x1",
	"frostbound_knight+ice_troll@13: rime_steel x1 | troll_hide x1",
	"frostbound_knight+ice_troll@14: rime_steel x1 | troll_hide x1, iron_bow x1",
	"frostbound_knight+ice_troll@15: rime_steel x1 | troll_hide x1, iron_body x1",
	"frostbound_knight+ice_troll@16: rime_steel x1 | troll_hide x1",
	"frostbound_knight+ice_troll@17: rime_steel x1 | troll_hide x1",
	"frostbound_knight+ice_troll@18: rime_steel x1 | troll_hide x1",
	"frostbound_knight+ice_troll@19: rime_steel x1 | troll_hide x1, iron_helm x1",
	"frostbound_knight+ice_troll@20: rime_steel x1 | troll_hide x1",
	"frostbound_knight+ice_troll@21: rime_steel x1 | troll_hide x1",
	"frostbound_knight+ice_troll@22: rime_steel x1 | troll_hide x1",
	"frostbound_knight+ice_troll@23: rime_steel x1 | troll_hide x1",
	"frostbound_knight+ice_troll@24: rime_steel x1 | troll_hide x1",
	"frostbound_knight+ice_troll@25: rime_steel x1 | troll_hide x1",
	"frostbound_knight+ice_troll@26: rime_steel x1 | troll_hide x1",
	"frostbound_knight+ice_troll@27: rime_steel x1 | troll_hide x1",
	"frostbound_knight+ice_troll@28: rime_steel x1 | troll_hide x1",
	"frostbound_knight+ice_troll@29: rime_steel x1 | troll_hide x1",
	"frostbound_knight+ice_troll@30: rime_steel x1 | troll_hide x1",
	"bandit_captain+wolf@1: arrows x20, iron_staff x1 | wolf_pelt x1",
	"bandit_captain+wolf@2: arrows x20, iron_staff x1, iron_staff x1 | wolf_pelt x1",
	"bandit_captain+wolf@3: arrows x20, iron_legs x1, iron_axe x1 | wolf_pelt x1",
	"bandit_captain+wolf@4: arrows x20, iron_legs x1 | wolf_pelt x1",
	"bandit_captain+wolf@5: arrows x20, iron_bow x1 | wolf_pelt x1",
	"bandit_captain+wolf@6: arrows x20, iron_staff x1, iron_pickaxe x1 | wolf_pelt x1",
	"bandit_captain+wolf@7: arrows x20, iron_body x1, iron_bow x1 | wolf_pelt x1",
	"bandit_captain+wolf@8: arrows x20, iron_body x1 | wolf_pelt x1",
	"bandit_captain+wolf@9: arrows x20, iron_sword x1 | wolf_pelt x1",
	"bandit_captain+wolf@10: arrows x20, iron_bow x1, iron_axe x1 | wolf_pelt x1",
	"bandit_captain+wolf@11: arrows x20, iron_helm x1, iron_legs x1 | wolf_pelt x1",
	"bandit_captain+wolf@12: arrows x20, iron_helm x1 | wolf_pelt x1",
	"bandit_captain+wolf@13: arrows x20, iron_sword x1 | wolf_pelt x1",
	"bandit_captain+wolf@14: arrows x20, iron_sword x1, iron_bow x1 | wolf_pelt x1",
	"bandit_captain+wolf@15: arrows x20, iron_staff x1, iron_body x1 | wolf_pelt x1",
	"bandit_captain+wolf@16: arrows x20, iron_helm x1 | wolf_pelt x1",
	"bandit_captain+wolf@17: arrows x20, iron_legs x1 | wolf_pelt x1",
	"bandit_captain+wolf@18: arrows x20, iron_legs x1 | wolf_pelt x1",
	"bandit_captain+wolf@19: arrows x20, iron_staff x1, iron_helm x1 | wolf_pelt x1",
	"bandit_captain+wolf@20: arrows x20, iron_staff x1 | wolf_pelt x1, iron_staff x1",
	"bandit_captain+wolf@21: arrows x20, iron_body x1 | wolf_pelt x1",
	"bandit_captain+wolf@22: arrows x20, iron_body x1 | wolf_pelt x1",
	"bandit_captain+wolf@23: arrows x20, iron_bow x1 | wolf_pelt x1",
	"bandit_captain+wolf@24: arrows x20, iron_bow x1 | wolf_pelt x1",
	"bandit_captain+wolf@25: arrows x20, iron_helm x1 | wolf_pelt x1",
	"bandit_captain+wolf@26: arrows x20, iron_body x1 | wolf_pelt x1",
	"bandit_captain+wolf@27: arrows x20, iron_sword x1 | wolf_pelt x1",
	"bandit_captain+wolf@28: arrows x20, iron_sword x1 | wolf_pelt x1",
	"bandit_captain+wolf@29: arrows x20, iron_helm x1 | wolf_pelt x1",
	"bandit_captain+wolf@30: arrows x20, iron_helm x1 | wolf_pelt x1",
	"snowveil_archer+frost_witch@1: frost_sinew x1 | frost_shards x10",
	"snowveil_archer+frost_witch@2: frost_sinew x1 | frost_shards x10",
	"snowveil_archer+frost_witch@3: frost_sinew x1 | frost_shards x10, iron_axe x1",
	"snowveil_archer+frost_witch@4: frost_sinew x1 | frost_shards x10",
	"snowveil_archer+frost_witch@5: frost_sinew x1 | frost_shards x10",
	"snowveil_archer+frost_witch@6: frost_sinew x1 | frost_shards x10",
	"snowveil_archer+frost_witch@7: frost_sinew x1 | frost_shards x10, iron_bow x1",
	"snowveil_archer+frost_witch@8: frost_sinew x1 | frost_shards x10",
	"snowveil_archer+frost_witch@9: frost_sinew x1 | frost_shards x10",
	"snowveil_archer+frost_witch@10: frost_sinew x1 | frost_shards x10",
	"snowveil_archer+frost_witch@11: frost_sinew x1 | frost_shards x10, iron_legs x1",
	"snowveil_archer+frost_witch@12: frost_sinew x1 | frost_shards x10",
	"snowveil_archer+frost_witch@13: frost_sinew x1 | frost_shards x10",
	"snowveil_archer+frost_witch@14: frost_sinew x1 | frost_shards x10",
	"snowveil_archer+frost_witch@15: frost_sinew x1 | frost_shards x10, iron_body x1",
	"snowveil_archer+frost_witch@16: frost_sinew x1 | frost_shards x10",
	"snowveil_archer+frost_witch@17: frost_sinew x1 | frost_shards x10",
	"snowveil_archer+frost_witch@18: frost_sinew x1 | frost_shards x10",
	"snowveil_archer+frost_witch@19: frost_sinew x1 | frost_shards x10, iron_helm x1",
	"snowveil_archer+frost_witch@20: frost_sinew x1 | frost_shards x10",
	"snowveil_archer+frost_witch@21: frost_sinew x1 | frost_shards x10",
	"snowveil_archer+frost_witch@22: frost_sinew x1 | frost_shards x10",
	"snowveil_archer+frost_witch@23: frost_sinew x1 | frost_shards x10",
	"snowveil_archer+frost_witch@24: frost_sinew x1 | frost_shards x10",
	"snowveil_archer+frost_witch@25: frost_sinew x1 | frost_shards x10",
	"snowveil_archer+frost_witch@26: frost_sinew x1 | frost_shards x10",
	"snowveil_archer+frost_witch@27: frost_sinew x1 | frost_shards x10",
	"snowveil_archer+frost_witch@28: frost_sinew x1 | frost_shards x10",
	"snowveil_archer+frost_witch@29: frost_sinew x1 | frost_shards x10",
	"snowveil_archer+frost_witch@30: frost_sinew x1 | frost_shards x10",
]


func test_the_iron_pieces_are_uncommon_and_no_other_item_has_a_rarity_band() -> void:
	assert_eq(ItemTable.RARITIES, [ItemTable.RARITY_UNCOMMON, ItemTable.RARITY_RARE, ItemTable.RARITY_SUPER_RARE, ItemTable.RARITY_ULTRA_RARE] as Array[String], "commonest first")
	for kind in ItemTable.ITEMS:
		assert_eq(ItemTable.rarity(kind), ItemTable.RARITY_UNCOMMON if IRON_POOL.has(kind) else "", kind)
	assert_eq(ItemTable.rarity("no_such_item"), "", "an unknown item has none")


func test_each_kind_keeps_its_chance_at_an_iron_piece_and_the_pool_it_draws_from() -> void:
	var band := CombatTable.rarity_band(IRON_BAND)
	assert_eq(band["rarity"], ItemTable.RARITY_UNCOMMON)
	assert_eq(band["pool"], IRON_POOL, "the same pieces in the same order")
	assert_eq(CombatTable.RARITY_BANDS.keys(), [IRON_BAND], "the only band so far")
	for kind in CombatTable.ENEMIES:
		var def: Dictionary = CombatTable.ENEMIES[kind]
		var table := CombatTable.loot_table(kind)
		var odds := {IRON_BAND: IRON_ODDS[kind]} if IRON_ODDS.has(kind) else {}
		assert_eq(table["rare_roll"], odds, "%s rolls as it did" % kind)
		assert_eq(table["loot"], def["loot"], "%s keeps its guaranteed loot" % kind)
		assert_eq(table["boss_loot"], def.get("boss_loot", []), "%s keeps its guaranteed piece" % kind)
		assert_eq(CombatTable.rare_roll_problems(table), [] as Array[String], kind)


func test_a_rare_roll_naming_a_missing_band_too_much_chance_or_a_wrong_item_has_problems() -> void:
	CombatTable.add_stand_in_loot({}, {
		"stand_in_mixed": {"rarity": ItemTable.RARITY_UNCOMMON, "pool": ["iron_sword", "logs"]},
		"stand_in_unranked": {"rarity": "", "pool": []},
	})
	assert_eq(CombatTable.rare_roll_problems({"rare_roll": {"no_such_band": 5}}), ["no band no_such_band"] as Array[String])
	assert_eq(CombatTable.rare_roll_problems({"rare_roll": {IRON_BAND: 101}}), ["the chances add up to 101, past 100"] as Array[String])
	assert_eq(CombatTable.rare_roll_problems({"rare_roll": {IRON_BAND: -1}}), ["%s has a chance below zero" % IRON_BAND] as Array[String])
	assert_eq(CombatTable.rare_roll_problems({"rare_roll": {"stand_in_mixed": 5}}), ["logs in stand_in_mixed is not uncommon"] as Array[String])
	assert_eq(CombatTable.rare_roll_problems({"rare_roll": {"stand_in_unranked": 5}}), ["stand_in_unranked has no rarity"] as Array[String])
	assert_eq(CombatTable.rare_roll_problems({"rare_roll": {}}), [] as Array[String], "no bands is a table")
	CombatTable.clear_stand_ins()


func test_a_stand_in_loot_table_replaces_a_kinds_own_until_the_stand_ins_are_cleared() -> void:
	CombatTable.add_stand_in_loot(
		{"wolf": {"loot": [{"item": "logs", "count": 3}], "boss_loot": [], "rare_roll": {"stand_in_axe": 100}}},
		{"stand_in_axe": {"rarity": ItemTable.RARITY_UNCOMMON, "pool": ["iron_axe"]}},
	)
	var drops := _kill(_arena("wolf", "wolf"), "first")
	CombatTable.clear_stand_ins()
	assert_eq(drops, ["logs x3", "iron_axe x1"], "its loot, and the stand-in band's piece every kill")
	assert_eq(CombatTable.loot_table("wolf")["loot"], [{"item": "wolf_pelt", "count": 1}], "cleared, the wolf's own again")
	assert_true(CombatTable.rarity_band("stand_in_axe").is_empty(), "and the stand-in band gone")


func test_seeded_kills_drop_what_they_dropped_before_loot_tables() -> void:
	assert_eq(_drops_by_seed(), BEFORE)


## Every pair's two kills for each seed from 1 to SEEDS, one line each.
static func _drops_by_seed() -> Array[String]:
	var out: Array[String] = []
	for pair in PAIRS:
		for rng in range(1, SEEDS + 1):
			var sim := _arena(pair[0], pair[1])
			H.patch(sim, {"rng": rng})
			var first := _kill(sim, "first")
			var second := _kill(sim, "second")
			out.append("%s+%s@%d: %s | %s" % [pair[0], pair[1], rng, ", ".join(first), ", ".join(second)])
	return out


static func _arena(first: String, second: String) -> Sim:
	var sim := H.arena({"first": {"kind": first, "home": FIRST_HOME}, "second": {"kind": second, "home": SECOND_HOME}})
	H.place(sim, BETWEEN)
	H.arm(sim, "iron_sword")
	sim.drain_events()
	return sim


## Kills foe `id` at one health with a single blow, and answers its piles as "item xcount".
static func _kill(sim: Sim, id: String) -> Array[String]:
	H.patch_enemy(sim, id, {"health": 1})
	sim.command(Vocab.ATTACK, {"enemy_id": id})
	var out: Array[String] = []
	for drop in H.of_kind(H.run(sim, 3), Vocab.EV_LOOT_DROPPED):
		out.append("%s x%d" % [drop["item"], drop["count"]])
	return out
