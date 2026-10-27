## The rare roll climbs the ladder (#239): a kill's one rare roll checks the four rarity bands,
## rarest first, lands in at most one, and draws one item from its pool, or nothing from an empty
## one. The drop event names the item's rarity band. A drop-rate scale raises the odds of every
## band rarer than uncommon and lives outside the state, so no save code carries or restores it.
## Shown through stand-in bands and items, since real kinds still roll only their uncommon band.
extends "res://tests/run.gd".TestCase

const H := preload("res://tests/sim_helpers.gd")
const Vocab := preload("res://sim/vocab.gd")
const FieldKit := preload("res://scenes/field_kit.gd")

## Where the arena's two foes stand, either side of the player, in ring one by the archer.
const FIRST_HOME := [14.5, 28.5]
const SECOND_HOME := [14.5, 26.5]
const BETWEEN := [14.5, 27.5]

## One stand-in piece of each band rarer than uncommon, and a stand-in band of each rarity whose
## ids run against the ladder (a_ commonest), so only the roll's order puts the rarest first.
const ITEMS := {
	"stand_in_blue_ring": {"label": "Blue ring", "stack": 1, "weight": 0, "value": 50, "slot": "", "rarity": ItemTable.RARITY_RARE},
	"stand_in_purple_ring": {"label": "Purple ring", "stack": 1, "weight": 0, "value": 50, "slot": "", "rarity": ItemTable.RARITY_SUPER_RARE},
	"stand_in_gold_ring": {"label": "Gold ring", "stack": 1, "weight": 0, "value": 50, "slot": "", "rarity": ItemTable.RARITY_ULTRA_RARE},
}
const BANDS := {
	"a_uncommon": {"rarity": ItemTable.RARITY_UNCOMMON, "pool": ["iron_axe"]},
	"b_rare": {"rarity": ItemTable.RARITY_RARE, "pool": ["stand_in_blue_ring"]},
	"c_super_rare": {"rarity": ItemTable.RARITY_SUPER_RARE, "pool": ["stand_in_purple_ring"]},
	"d_ultra_rare": {"rarity": ItemTable.RARITY_ULTRA_RARE, "pool": ["stand_in_gold_ring"]},
	"d_ultra_rare_empty": {"rarity": ItemTable.RARITY_ULTRA_RARE, "pool": []},
}
## The item each band gives, and the band each of those items is.
const BAND_OF := {
	"iron_axe": ItemTable.RARITY_UNCOMMON, "stand_in_blue_ring": ItemTable.RARITY_RARE,
	"stand_in_purple_ring": ItemTable.RARITY_SUPER_RARE, "stand_in_gold_ring": ItemTable.RARITY_ULTRA_RARE,
}
const LOGS := "logs x3"
## A ladder whose chances fill the hundred, so every kill lands in exactly one band.
const FULL_LADDER := {"a_uncommon": 25, "b_rare": 25, "c_super_rare": 25, "d_ultra_rare": 25}
## A ladder at about the spec's shape, every band rarer than uncommon at a small chance.
const LADDER := {"a_uncommon": 20, "b_rare": 5, "c_super_rare": 5, "d_ultra_rare": 5}
const SCALE := 3.0
const SEEDS := 300

static var _arenas := {}


func test_a_kill_gives_its_guaranteed_loot_and_at_most_one_rare_drop() -> void:
	_stand_in({"wolf": _table(FULL_LADDER)})
	var seen := {}
	for rng in range(1, 41):
		var drops := _kill(_arena("wolf", rng), "first")
		assert_eq(drops.size(), 2, "seed %d: its loot and one rare drop" % rng)
		assert_eq(drops[0], LOGS, "seed %d: the guaranteed loot first" % rng)
		seen[drops[1]] = true
	CombatTable.clear_stand_ins()
	assert_eq(seen.keys().size(), 4, "every band gives on some kill: %s" % [seen.keys()])


func test_bands_are_checked_rarest_first() -> void:
	_stand_in({"wolf": _table({"a_uncommon": 100, "d_ultra_rare": 100})})
	for rng in range(1, 11):
		assert_eq(_kill(_arena("wolf", rng), "first"), [LOGS, "stand_in_gold_ring x1"], "seed %d: the ultra rare, never the iron" % rng)
	CombatTable.clear_stand_ins()


func test_a_roll_landing_in_a_band_with_an_empty_pool_gives_nothing() -> void:
	_stand_in({"wolf": _table({"a_uncommon": 100, "d_ultra_rare_empty": 100})})
	for rng in range(1, 11):
		assert_eq(_kill(_arena("wolf", rng), "first"), [LOGS], "seed %d: no commoner band in its place" % rng)
	CombatTable.clear_stand_ins()


func test_the_drop_event_names_the_items_rarity_band() -> void:
	_stand_in({"wolf": _table(FULL_LADDER)})
	for kind in BAND_OF:
		assert_eq(ItemTable.rarity(kind), BAND_OF[kind], "the item table answers %s's band" % kind)
	var seen := {}
	for rng in range(1, 41):
		for drop in H.of_kind(_kill_events(_arena("wolf", rng), "first"), Vocab.EV_LOOT_DROPPED):
			assert_eq(drop["rarity"], BAND_OF.get(drop["item"], ""), "seed %d: %s" % [rng, drop["item"]])
			seen[drop["rarity"]] = true
	CombatTable.clear_stand_ins()
	assert_eq(seen.size(), 5, "none for the logs, and each of the four bands: %s" % [seen.keys()])
	assert_eq(ItemTable.rarity("stand_in_gold_ring"), "", "a cleared stand-in item has no band")
	var drops := H.of_kind(_kill_events(_arena("bandit_captain", 1), "first"), Vocab.EV_LOOT_DROPPED)
	assert_eq(drops[0]["rarity"], "", "the captain's arrows have none")
	assert_eq(drops[1]["rarity"], ItemTable.RARITY_UNCOMMON, "its guaranteed iron piece is uncommon")


func test_a_captains_guaranteed_piece_stays_on_top_of_its_rare_drop() -> void:
	var table := _table({"d_ultra_rare": 100})
	table["boss_loot"] = ["iron_helm"]
	_stand_in({"bandit_captain": table})
	var drops := _kill(_arena("bandit_captain", 1), "first")
	CombatTable.clear_stand_ins()
	assert_eq(drops, [LOGS, "iron_helm x1", "stand_in_gold_ring x1"])


func test_the_drop_rate_scale_raises_the_rarer_bands_and_leaves_uncommon_alone() -> void:
	_stand_in({"wolf": _table(LADDER)})
	var plain := _counts()
	CombatTable.set_drop_rate_scale(SCALE)
	var scaled := _counts()
	CombatTable.clear_stand_ins()
	# The ladder's chances out of SEEDS kills: uncommon 20 % either way; each rarer band 5 %, and
	# 15 % at the scale.
	for counts in [plain, scaled]:
		assert_true(_near(counts[ItemTable.RARITY_UNCOMMON], 60), "uncommon near 60 of 300: %s" % [counts])
	for band in [ItemTable.RARITY_RARE, ItemTable.RARITY_SUPER_RARE, ItemTable.RARITY_ULTRA_RARE]:
		assert_true(_near(plain[band], 15), "%s near 15 of 300 at 1: %s" % [band, plain])
		assert_true(_near(scaled[band], 45), "%s near 45 of 300 at the scale: %s" % [band, scaled])


func test_at_one_or_on_real_kinds_the_scale_changes_nothing() -> void:
	_stand_in({"wolf": _table(LADDER)})
	var unset := _drops_by_seed("wolf")
	CombatTable.set_drop_rate_scale(1.0)
	assert_eq(_drops_by_seed("wolf"), unset, "a scale of 1 is the game's odds")
	CombatTable.clear_stand_ins()
	for kind in ["ice_troll", "bandit_captain", "frostbound_knight"]:
		var before := _drops_by_seed(kind)
		CombatTable.set_drop_rate_scale(50.0)
		var after := _drops_by_seed(kind)
		CombatTable.clear_stand_ins()
		assert_eq(after, before, "%s rolls only its uncommon band, which the scale leaves alone" % kind)


func test_two_runs_with_the_same_seed_give_the_same_drops() -> void:
	_stand_in({"wolf": _table(LADDER)})
	CombatTable.set_drop_rate_scale(SCALE)
	var first := _drops_by_seed("wolf")
	var second := _drops_by_seed("wolf")
	CombatTable.clear_stand_ins()
	assert_eq(second, first)
	assert_true(first.any(func(line: String) -> bool: return line.contains("stand_in_")), "rare drops among them: %s" % [first])


func test_the_scale_is_never_written_into_a_save_code_nor_restored_from_one() -> void:
	var sim := _arena("wolf", 7)
	var code := sim.export_code()
	var test_mode := FieldKit.code()
	CombatTable.set_drop_rate_scale(9.0)
	assert_eq(sim.export_code(), code, "the same code at any scale")
	assert_eq(FieldKit.code(), test_mode, "test mode's code too")
	CombatTable.clear_stand_ins()
	var raised := sim.snapshot()
	raised["drop_rate_scale"] = 9.0
	assert_true(sim.restore(raised), "a save naming a scale still loads")
	assert_eq(CombatTable.drop_rate_scale(), 1.0, "and leaves the scale at 1")
	CombatTable.set_drop_rate_scale(9.0)
	assert_true(sim.command(Vocab.IMPORT_SAVE, {"code": code})["ok"])
	assert_true(sim.command(Vocab.IMPORT_SAVE, {"code": test_mode})["ok"])
	assert_eq(CombatTable.drop_rate_scale(), 9.0, "a load never puts it back to 1 either")
	CombatTable.clear_stand_ins()
	assert_eq(CombatTable.drop_rate_scale(), 1.0, "clearing the stand-ins does")


## Adds the stand-in items and bands, with `tables` keyed by enemy kind.
static func _stand_in(tables: Dictionary) -> void:
	CombatTable.add_stand_in_loot(tables, BANDS, ITEMS)


## A loot table of three logs every kill and `rare_roll`.
static func _table(rare_roll: Dictionary) -> Dictionary:
	return {"loot": [{"item": "logs", "count": 3}], "boss_loot": [], "rare_roll": rare_roll}


## Whether `count` is within half of `expected`, either way: what SEEDS kills tell apart.
static func _near(count: int, expected: int) -> bool:
	return absi(count - expected) * 2 <= expected


## How many of SEEDS wolf kills gave a rare drop of each band.
static func _counts() -> Dictionary:
	var out := {}
	for rarity in ItemTable.RARITIES:
		out[rarity] = 0
	for rng in range(1, SEEDS + 1):
		for drop in H.of_kind(_kill_events(_arena("wolf", rng), "first"), Vocab.EV_LOOT_DROPPED):
			if drop["rarity"] != "":
				out[drop["rarity"]] += 1
	return out


## Two kills in a row of `kind` for each seed from 1 to 30, one line each.
static func _drops_by_seed(kind: String) -> Array[String]:
	var out: Array[String] = []
	for rng in range(1, 31):
		var sim := _arena(kind, rng)
		out.append("%d: %s | %s" % [rng, ", ".join(_kill(sim, "first")), ", ".join(_kill(sim, "second"))])
	return out


## Two foes of `kind` either side of the player, armed, from generator seed `rng`.
## Each kind's arena is built once and put back to its start for every seed.
static func _arena(kind: String, rng: int) -> Sim:
	if not _arenas.has(kind):
		var built := H.arena({"first": {"kind": kind, "home": FIRST_HOME}, "second": {"kind": kind, "home": SECOND_HOME}})
		H.place(built, BETWEEN)
		H.arm(built, "iron_sword")
		_arenas[kind] = {"sim": built, "start": built.snapshot()}
	var sim: Sim = _arenas[kind]["sim"]
	var start: Dictionary = _arenas[kind]["start"].duplicate(true)
	start["rng"] = rng
	sim.restore(start)
	sim.drain_events()
	return sim


## Kills foe `id` at one health with a single blow, and answers the events.
static func _kill_events(sim: Sim, id: String) -> Array[Dictionary]:
	H.patch_enemy(sim, id, {"health": 1})
	sim.command(Vocab.ATTACK, {"enemy_id": id})
	return H.run(sim, 3)


## Kills foe `id` and answers its piles as "item xcount".
static func _kill(sim: Sim, id: String) -> Array[String]:
	var out: Array[String] = []
	for drop in H.of_kind(_kill_events(sim, id), Vocab.EV_LOOT_DROPPED):
		out.append("%s x%d" % [drop["item"], drop["count"]])
	return out
