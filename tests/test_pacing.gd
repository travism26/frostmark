## Pacing: a scripted new character plays the whole first playable through the command
## interface, from an empty pack to the bandit captain and through the ring-two gate, using
## all eight skills. It plays a plain, sensible route, not a perfect one; a person reading the
## world and clicking takes longer, so the bot's time is held well under thirty minutes.
## Then it plays on through ring two to a smithed steel kit, which a person should manage in
## one or two evening sessions (thirty to forty-five minutes). The balance run
## (test_balance.gd) plays a first-timer instead and adds a person's time to the bot's.
extends "res://tests/run.gd".TestCase

const H := preload("res://tests/sim_helpers.gd")
const PlayBot := preload("res://tests/play_bot.gd")
const Vocab := preload("res://sim/vocab.gd")

## The bot must reach the captain inside this window (ticks are half a second).
const MIN_TICKS := 1200   # 10 minutes: the route must not be trivial
const MAX_TICKS := 2700   # 22.5 minutes of perfect clicking: about thirty for a person
## Ring two, from the first step through its gate to a steel sword, armour and pickaxe made.
## The same reading as ring one's window: the bot's time scaled for a person's 30 to 45 minutes.
const RING_TWO_MIN_TICKS := 1500   # 12.5 minutes: steel must be worked for
const RING_TWO_MAX_TICKS := 4050   # 33.75 minutes of perfect clicking: about forty-five for a person

const SOUTH_TREES := ["tree_1", "tree_2", "tree_3", "tree_4", "tree_5", "tree_6"]
const NORTH_TREES := ["tree_7", "tree_8", "tree_9", "tree_10"]
const COPPER := ["copper_4", "copper_5", "copper_6", "copper_7"]
const TIN := ["tin_6", "tin_5", "tin_4", "tin_7"]
const IRON := ["iron_1", "iron_2", "iron_4", "iron_5"]
const CRYSTALS := ["ice_crystal_2", "ice_crystal_1"]
const COAL_EAST := ["coal_1", "coal_2", "coal_3", "coal_4"]
const RICH_IRON := ["rich_iron_1", "rich_iron_2", "rich_iron_3"]
const MELEE := PlayBot.MELEE
const RANGED := PlayBot.RANGED

var bot: PlayBot
var sim: Sim


func test_a_new_character_reaches_and_beats_the_captain_in_time() -> void:
	var reached := _play_to_the_captain()
	print("pacing: %s" % " | ".join(bot.log_lines))
	print("pacing: the captain fell at tick %d (%.1f minutes), %d deaths" % [reached, reached * Sim.TICK_SECONDS / 60.0, bot.deaths])
	assert_true(reached >= MIN_TICKS, "the route takes a while (%d ticks)" % reached)
	assert_true(reached <= MAX_TICKS, "the captain is reached in time (%d ticks)" % reached)
	for skill in SkillTable.NAMES:
		assert_true(int(sim.state["skills"][skill]["xp"]) > 0, "%s was used along the way" % skill)
	assert_eq(bot.deaths, 0, "a sensible route needs no deaths")


## Plays a new character from nothing to the captain's fall and through the ring-two gate.
## Returns the tick the captain fell.
func _play_to_the_captain() -> int:
	bot = PlayBot.new(self)
	sim = bot.sim
	# 1. Wood for the first tools and the shelves.
	bot.head_out()
	bot.gather(SOUTH_TREES, "logs", 20)
	bot.home()
	bot.smith("wooden_pickaxe")
	bot.smith("fishing_rod")
	bot.build("stash_shelves")
	bot.note("tools and shelves")
	# 2. Ore, fish and more wood in the inner ring. Tools stay in the pack through the gate,
	# so taking them is only for the first trip after they were made.
	bot.kit(["wooden_pickaxe", "fishing_rod"])
	bot.head_out()
	bot.gather(NORTH_TREES, "logs", 10)
	bot.gather(["fishing_hole"], "raw_fish", 8)
	bot.gather(COPPER, "copper_ore", 10)
	bot.home()
	bot.kit(["wooden_pickaxe"])
	bot.head_out()
	bot.gather(TIN, "tin_ore", 10)
	bot.gather(CRYSTALS, "ice_crystal", 3)
	bot.gather(SOUTH_TREES, "logs", 20)
	bot.home()
	bot.build("forge")
	bot.withdraw("raw_fish")
	bot.cook_all()
	for i in 7:
		bot.smith("bronze_bar")
	bot.smith("bronze_pickaxe")
	bot.smith("bronze_sword")
	bot.smith("wooden_staff")
	bot.smith("frost_shards")
	bot.smith("frost_shards")
	bot.note("forge, food, bronze and a staff")
	# 3. Ring one: the bow against the archer, the sword and then the staff against the wolves.
	bot.withdraw("wooden_bow", 1)
	bot.withdraw("arrows", 30)
	bot.withdraw("wooden_staff", 1)
	bot.withdraw("frost_shards", 20)
	bot.withdraw("cooked_fish")
	bot.equip("wooden_bow")
	bot.head_out()
	bot.fight(["archer_1"])
	bot.equip("bronze_sword")
	bot.fight(["wolf_1", "wolf_2"])
	bot.fight(["wolf_3", "wolf_4", "wolf_5"])
	bot.equip("wooden_staff")
	bot.fight(["wolf_6", "wolf_7"])
	bot.equip("bronze_sword")
	bot.home()
	bot.note("first fights")
	# 4. More ore, iron from ring one and the north pack's pelts, then the armoury, armour and
	# the gate winch. The iron's south-west spot lies past the packs fought on the last trip,
	# back by now, so the bot takes food.
	bot.kit(["bronze_pickaxe"])
	bot.withdraw("cooked_fish")
	bot.head_out()
	bot.gather(COPPER, "copper_ore", 9)
	bot.gather(IRON, "iron_ore", 12)
	bot.home()
	bot.kit(["bronze_pickaxe", "fishing_rod"])
	bot.withdraw("cooked_fish")
	bot.head_out()
	bot.gather(TIN, "tin_ore", 9)
	bot.gather(NORTH_TREES, "logs", 10)
	bot.gather(["fishing_hole"], "raw_fish", 6)
	bot.fight(["wolf_8", "wolf_9", "wolf_10"])
	bot.home()
	for i in 9:
		bot.smith("bronze_bar")
	bot.build("armoury")
	for piece in ["bronze_helm", "bronze_body", "bronze_legs"]:
		bot.smith(piece)
		bot.equip(piece)
	bot.build("ring_two_gate")
	bot.withdraw("raw_fish")
	bot.cook_all()
	bot.withdraw("cooked_fish")
	bot.note("armour and the winch")
	assert_true((sim.state["upgrades"] as Array).has("ring_two_gate"), "the winch is built")
	# 5. The captain, then through the gate.
	bot.head_out()
	var start := int(sim.state["tick"])
	bot.fight(["captain"])
	var reached := int(sim.state["tick"])
	assert_true(sim.ring_gate_open("ring_two_gate"), "the gate stands open")
	sim.command(Vocab.INTERACT, {"object_id": "ring_two_gate"})
	var events := bot.run_idle(60)
	assert_eq(H.of_kind(events, Vocab.EV_RING_TWO_REACHED).size(), 1, "walked through to ring two")
	bot.note("captain down after a %d-tick fight" % (reached - start))
	return reached


func test_ring_two_to_a_steel_kit_takes_an_evening() -> void:
	_play_to_the_captain()
	var start := int(sim.state["tick"])
	bot.log_lines = []
	assert_eq(sim.state["player"]["region"], WorldDef.REGION_RING_TWO, "starts just through the gate")
	# 6. Home first, to store the captain's iron and clear out the gear it outgrew, then fish
	# and bronze bars for the furnace.
	bot.home()
	# The wooden bow goes only when the captain's iron gear was a better bow.
	bot.discard(["wooden_pickaxe", "wolf_pelt"] + (["wooden_bow"] if bot.best_weapon(RANGED) != "wooden_bow" else []))
	bot.kit(["fishing_rod", "bronze_pickaxe"])
	bot.head_out()
	bot.gather(["fishing_hole"], "raw_fish", 10)
	bot.gather(COPPER, "copper_ore", 4)
	bot.gather(TIN, "tin_ore", 4)
	bot.gather(SOUTH_TREES, "logs", 20)
	bot.home()
	bot.withdraw("raw_fish")
	bot.cook_all()
	for i in 4:
		bot.smith("bronze_bar")
	bot.build("stash_cellar")
	bot.note("fish, bronze and the cellar")
	# 7. East: the stalkers with a bow, then coal; the lake's troll with a blade, for a hide.
	bot.ready_for_ring_two(["bronze_pickaxe"])
	bot.fight_with(RANGED, ["stalker_2"])
	bot.fight_with(RANGED, ["stalker_3", "stalker_4"])
	bot.gather(COAL_EAST, "coal", 10)
	bot.rest_at_the_brazier()
	bot.fight_with(MELEE, ["troll_1"])
	bot.home()
	bot.note("coal and a hide")
	bot.ready_for_ring_two(["bronze_pickaxe"])
	bot.fight_with(RANGED, ["stalker_2"])
	bot.gather(COAL_EAST, "coal", 10)
	bot.rest_at_the_brazier()
	bot.fight_with(MELEE, ["troll_4"])
	bot.home()
	bot.build("blast_furnace")
	bot.note("the blast furnace")
	# 8. The keep's trolls for the armour's hide, rich iron behind them, and coal for seven bars.
	# The food left the stash with the last trips and none comes back through the gate, so
	# fish and cook for the keep first.
	bot.head_out()
	bot.gather(["fishing_hole"], "raw_fish", 6)
	bot.home(false)
	bot.cook_all()
	bot.ready_for_ring_two(["bronze_pickaxe"])
	bot.fight_with(RANGED, ["stalker_2"])
	bot.rest_at_the_brazier()
	bot.fight_with(MELEE, ["troll_2", "troll_3"])
	bot.gather(RICH_IRON, "iron_ore", 7)
	bot.fight_with(RANGED, ["stalker_3", "stalker_4"])
	bot.gather(COAL_EAST, "coal", 6)
	bot.home()
	bot.note("the keep, iron and coal")
	# Kit stays in the pack through the gate, so the tools, spare armour and outgrown bronze no
	# steel recipe uses go to the stash to make room for the smithing.
	bot.put_away(["fishing_rod", "wooden_staff", "frost_shards", "bronze_body", "bronze_sword", "bronze_pickaxe"])
	for i in 7:
		bot.smith("steel_bar")
	bot.smith("steel_pickaxe")
	bot.smith("steel_axe")
	bot.smith("steel_sword")
	for piece in ["steel_helm", "steel_body", "steel_legs"]:
		bot.smith(piece)
	bot.equip("steel_sword")
	for piece in ["steel_helm", "steel_body", "steel_legs"]:
		bot.equip(piece)
	var done := int(sim.state["tick"])
	bot.note("a steel kit")
	print("pacing: %s" % " | ".join(bot.log_lines))
	print("pacing: ring two to steel took %d ticks (%.1f minutes), %d deaths" % [done - start, (done - start) * Sim.TICK_SECONDS / 60.0, bot.deaths])
	assert_true(done - start >= RING_TWO_MIN_TICKS, "steel takes a while (%d ticks)" % (done - start))
	assert_true(done - start <= RING_TWO_MAX_TICKS, "steel within an evening or two (%d ticks)" % (done - start))
	assert_eq(sim.state["inventory"]["equipment"]["weapon"], "steel_sword")
	assert_eq(bot.deaths, 0, "a sensible route needs no deaths")
