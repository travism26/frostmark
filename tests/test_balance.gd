## Balance run (#26): a first-time player, scripted, from a new character to engaging the
## bandit captain, timed phase by phase. The pacing test plays a planner's route; this one plays
## the way someone new would: it follows the guide, turns home when the cold tip shows, gathers
## whole stacks rather than exact costs, makes a wooden set before its first fight, cooks every
## fish it catches and tops up its food before each trip into ring one. It uses every skill.
##
## Sim time is only what the character does. A person also spends time choosing where to click,
## reading panels and planning each trip, so the run adds an allowance per click, per outing and
## per thing done for the first time (see the constants), and the total is what is held near the
## brief's thirty minutes. `godot --headless -s tests/run.gd -- balance` prints the phase table
## that docs/balance.md records.
extends "res://tests/run.gd".TestCase

const H := preload("res://tests/sim_helpers.gd")
const PlayBot := preload("res://tests/play_bot.gd")
const Vocab := preload("res://sim/vocab.gd")

## The human allowance, in seconds.
const WORLD_CLICK_SECONDS := 2.0   # spotting the next node, enemy or door and clicking it
const PANEL_CLICK_SECONDS := 3.0   # finding the item or recipe in a panel and clicking it
const OUTING_SECONDS := 20.0       # deciding where to go, turning the camera, reading the cold
const FIRST_SECONDS := 15.0        # reading a recipe or upgrade the first time it is made

## The estimate to engaging the captain must land near thirty minutes.
const TARGET_MINUTES := 30.0
const TOLERANCE_MINUTES := 4.0

const SOUTH_TREES := ["tree_1", "tree_2", "tree_3", "tree_4", "tree_5", "tree_6"]
const NORTH_TREES := ["tree_7", "tree_8", "tree_9", "tree_10"]
const COPPER := ["copper_4", "copper_5", "copper_6", "copper_7"]
const TIN := ["tin_6", "tin_5", "tin_4", "tin_7"]
const IRON := ["iron_1", "iron_2", "iron_4", "iron_5"]
const CRYSTALS := ["ice_crystal_2", "ice_crystal_1"]
const STACK := 10
const WOLF_PACKS := [["wolf_1", "wolf_2"], ["wolf_3", "wolf_4", "wolf_5"], ["wolf_6", "wolf_7"], ["wolf_8", "wolf_9", "wolf_10"]]

var bot: PlayBot
var sim: Sim


func test_a_first_time_player_engages_the_captain_in_about_thirty_minutes() -> void:
	_play()
	var report := report_lines()
	for line in report:
		print("balance: " + line)
	var total := 0.0
	for p in bot.phases:
		if p["name"] != "captain fight":
			total += human_seconds(p)
	var minutes := total / 60.0
	assert_true(absf(minutes - TARGET_MINUTES) <= TOLERANCE_MINUTES,
		"the captain is engaged in about thirty minutes (%.1f)" % minutes)
	for skill in SkillTable.NAMES:
		assert_true(int(sim.state["skills"][skill]["xp"]) > 0, "%s was used along the way" % skill)
	assert_eq(bot.deaths, 0, "a careful first-timer needs no deaths")
	assert_true("captain" in sim.state["bosses_defeated"], "and the kit is enough to beat him")


func _play() -> void:
	bot = PlayBot.new(self)
	sim = bot.sim
	bot.turn_back_warmth = GuideTable.COLD_WARMTH
	# 1. The guide's path: cut pines, walk the logs home, craft at the workbench from the pack.
	bot.phase("first tools")
	bot.head_out()
	bot.gather(SOUTH_TREES, "logs", STACK)
	bot.home(false)
	bot.smith("wooden_pickaxe")
	bot.smith("fishing_rod")
	# 2. The inner ring: ore, fish, crystals and wood, until the shelves and the forge are up.
	bot.phase("inner ring")
	bot.kit(["wooden_pickaxe", "fishing_rod"])
	bot.head_out()
	bot.gather(["fishing_hole"], "raw_fish", 6)
	bot.gather(COPPER, "copper_ore", STACK)
	bot.gather(TIN, "tin_ore", STACK)
	bot.home()
	bot.withdraw("raw_fish")
	bot.cook_all()
	bot.kit(["wooden_pickaxe"])
	bot.head_out()
	bot.gather(CRYSTALS, "ice_crystal", 3)
	bot.gather(NORTH_TREES, "logs", STACK)
	bot.gather(SOUTH_TREES, "logs", 2 * STACK)
	bot.home()
	bot.build("stash_shelves")
	bot.build("forge")
	# 3. Bronze, a staff, and a wooden set before the first fight.
	bot.phase("bronze and a wooden set")
	_logs_for(14)
	bot.withdraw("copper_ore")
	bot.withdraw("tin_ore")
	bot.withdraw("logs")
	for i in mini(H.pack_count(sim, "copper_ore"), H.pack_count(sim, "tin_ore")):
		bot.smith("bronze_bar")
	bot.smith("bronze_pickaxe")
	bot.smith("bronze_sword")
	bot.withdraw("ice_crystal")
	bot.smith("wooden_staff")
	bot.smith("frost_shards")
	bot.smith("frost_shards")
	for piece in ["wooden_helm", "wooden_body", "wooden_legs"]:
		bot.smith(piece)
		bot.equip(piece)
	# 4. Ring one: the bow on the near archer, the sword and the staff on the wolf packs.
	bot.phase("first fights")
	_kit_for_ring_one()
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
	# 5. Iron by the archer camp, more bronze, the armoury, a bronze set and the winch, each
	# gathered for as the Upgrades tab's costs say.
	bot.phase("iron, armour and the winch")
	var cellar: Dictionary = UpgradeTable.get_upgrade("stash_cellar")["cost"]
	var armoury: Dictionary = UpgradeTable.get_upgrade("armoury")["cost"]
	var winch: Dictionary = UpgradeTable.get_upgrade("ring_two_gate")["cost"]
	_pelts_for(int(armoury.get("wolf_pelt", 0)) + int(winch.get("wolf_pelt", 0)))
	bot.kit(["bronze_pickaxe", "fishing_rod"])
	bot.head_out()
	bot.gather(["fishing_hole"], "raw_fish", 6)
	bot.gather(COPPER, "copper_ore", STACK)
	bot.gather(TIN, "tin_ore", STACK)
	bot.home()
	bot.withdraw("raw_fish")
	bot.cook_all()
	bot.kit(["bronze_pickaxe"])
	bot.head_out()
	bot.gather(IRON, "iron_ore", int(winch.get("iron_ore", 0)))
	bot.gather(SOUTH_TREES, "logs", 2 * STACK)
	bot.home()
	_logs_for(int(cellar.get("logs", 0)) + int(armoury.get("logs", 0)) + int(winch.get("logs", 0)))
	var bars := int(cellar.get("bronze_bar", 0)) + int(armoury.get("bronze_bar", 0)) + int(winch.get("bronze_bar", 0))
	for piece in ["bronze_helm", "bronze_body", "bronze_legs"]:
		bars += int(RecipeTable.get_recipe(piece)["inputs"]["bronze_bar"])
	_ore_for_bars(bars)
	bot.withdraw("copper_ore")
	bot.withdraw("tin_ore")
	for i in mini(H.pack_count(sim, "copper_ore"), H.pack_count(sim, "tin_ore")):
		bot.smith("bronze_bar")
	# Twelve stash slots are cramped by now, and the return banner offers the cellar.
	bot.build("stash_cellar")
	bot.build("armoury")
	for piece in ["bronze_helm", "bronze_body", "bronze_legs"]:
		bot.smith(piece)
		bot.equip(piece)
	# The stash is full by now: the outgrown wooden gear goes, to make room for the winch's iron.
	_drop_from_pack(["wooden_helm", "wooden_body", "wooden_legs"])
	bot.discard(["wooden_pickaxe"])
	bot.build("ring_two_gate")
	assert_true((sim.state["upgrades"] as Array).has("ring_two_gate"), "the winch is built")
	# 6. Food and the road south, until the captain turns to fight.
	bot.phase("to the captain")
	_kit_for_ring_one()
	bot.head_out()
	bot.cmd(Vocab.ATTACK, {"enemy_id": "captain"})
	var guard := 0
	while sim.state["enemies"]["captain"]["mode"] != Sim.MODE_ENGAGED and guard < 400:
		bot.step()
		guard += 1
	assert_eq(sim.state["enemies"]["captain"]["mode"], Sim.MODE_ENGAGED, "the captain is engaged")
	# The fight itself is reported, not counted toward the thirty minutes.
	bot.phase("captain fight")
	bot.fight(["captain"])
	bot.end_phase()


## When the stash and pack hold fewer than `need` logs, a trip out to chop a stack more.
func _logs_for(need: int) -> void:
	while H.stash_count(sim, "logs") + H.pack_count(sim, "logs") < need:
		bot.head_out()
		bot.gather(SOUTH_TREES + NORTH_TREES, "logs", H.pack_count(sim, "logs") + STACK)
		bot.home()


## Until the stash holds `need` wolf pelts, trips into ring one with the sword, each clearing the
## next wolf pack still standing.
func _pelts_for(need: int) -> void:
	var guard := 0
	while _have("wolf_pelt") < need and guard < 6:
		guard += 1
		_kit_for_ring_one()
		bot.head_out()
		if sim.state["inventory"]["equipment"]["weapon"] != "bronze_sword":
			bot.equip("bronze_sword")
		for pack in WOLF_PACKS:
			if pack.any(func(id: String) -> bool: return sim.state["enemies"][id]["mode"] != Sim.MODE_DEAD):
				bot.fight(pack)
				break
		bot.home()
	assert_true(_have("wolf_pelt") >= need, "%d wolf pelts" % need)


## Mines copper and tin a stack at a time until the bars stashed plus the bars the ore makes
## reach `bars`.
func _ore_for_bars(bars: int) -> void:
	var guard := 0
	while _have("bronze_bar") + mini(_have("copper_ore"), _have("tin_ore")) < bars and guard < 4:
		guard += 1
		bot.kit(["bronze_pickaxe"])
		bot.head_out()
		bot.gather(COPPER, "copper_ore", STACK)
		bot.gather(TIN, "tin_ore", STACK)
		bot.home()


func _have(kind: String) -> int:
	return H.stash_count(sim, kind) + H.pack_count(sim, kind)


func _drop_from_pack(kinds: Array) -> void:
	for kind in kinds:
		var pack: Array = sim.state["inventory"]["pack"]
		for i in pack.size():
			if pack[i] != null and pack[i]["item"] == kind:
				assert_true(bot.cmd(Vocab.DROP, {"index": i})["ok"], "drop %s" % kind)
				bot.step()
				break


## Food from the stash and the bow's arrows, before each trip into ring one.
func _kit_for_ring_one() -> void:
	bot.withdraw_food()
	if H.stash_count(sim, "arrows") > 0:
		bot.withdraw("arrows")
	for kind in ["wooden_bow", "wooden_staff", "frost_shards"]:
		if H.stash_count(sim, kind) > 0:
			bot.withdraw(kind)


## A phase's estimated time for a person, in seconds: the sim time plus the allowance.
static func human_seconds(p: Dictionary) -> float:
	return int(p["ticks"]) * Sim.TICK_SECONDS + overhead_seconds(p)


static func overhead_seconds(p: Dictionary) -> float:
	return int(p["world"]) * WORLD_CLICK_SECONDS + int(p["panel"]) * PANEL_CLICK_SECONDS \
		+ int(p["outings"]) * OUTING_SECONDS + int(p["firsts"]) * FIRST_SECONDS


## The phase table as Markdown rows, then the totals to the captain.
func report_lines() -> Array[String]:
	var out: Array[String] = []
	out.append("| Phase | Sim time | World clicks | Panel clicks | Outings | Firsts | Allowance | Estimate |")
	out.append("|-------|----------|--------------|--------------|---------|--------|-----------|----------|")
	var sim_total := 0.0
	var human_total := 0.0
	for p in bot.phases:
		var sim_s := int(p["ticks"]) * Sim.TICK_SECONDS
		out.append("| %s | %s | %d | %d | %d | %d | %s | %s |" % [p["name"], _clock(sim_s), p["world"],
			p["panel"], p["outings"], p["firsts"], _clock(overhead_seconds(p)), _clock(human_seconds(p))])
		if p["name"] != "captain fight":
			sim_total += sim_s
			human_total += human_seconds(p)
	out.append("| **to the captain** | **%s** | | | | | **%s** | **%s** |" % [_clock(sim_total),
		_clock(human_total - sim_total), _clock(human_total)])
	out.append("with half the allowance %s, with half as much again %s" % [
		_clock(sim_total + 0.5 * (human_total - sim_total)), _clock(sim_total + 1.5 * (human_total - sim_total))])
	return out


static func _clock(seconds: float) -> String:
	var s := int(round(seconds))
	return "%d:%02d" % [s / 60, s % 60]
