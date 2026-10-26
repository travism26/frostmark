## The ring-one dungeon's death chest: a death inside the dungeon keeps what a death anywhere
## else keeps and puts everything else in the chest just inside the mouth instead of destroying
## it. A second death there replaces what the chest holds, a death outside leaves it alone, and
## taking from it moves what fits into the pack. The chest is kept by a save and a save code.
extends "res://tests/run.gd".TestCase

const H := preload("res://tests/sim_helpers.gd")
const SimScript := preload("res://sim/sim.gd")
const Vocab := preload("res://sim/vocab.gd")
const WorldDefScript := preload("res://sim/world_def.gd")

const DUNGEON := "ring_one_dungeon"
const CHEST := "ring_one_dungeon_chest"
## Out of the fire's reach and every fight's sight, inside the dungeon and in ring one.
const IN_DUNGEON := [72.5, -56.5]
const IN_RING_ONE := [40.5, -50.5]
## Ten things: the worn club and nine pack stacks, so three are lost.
const HAUL := [
	{"item": "iron_sword", "count": 1},     # 80
	{"item": "logs", "count": 3},           # 6
	{"item": "arrows", "count": 30},        # 30
	{"item": "cooked_fish", "count": 2},    # 12, ties with the worn club
	{"item": "bronze_bar", "count": 2},     # 16
	{"item": "troll_hide", "count": 1},     # 20
	{"item": "copper_ore", "count": 5},     # 15
	{"item": "tin_ore", "count": 4},        # 12
	{"item": "wolf_pelt", "count": 1},      # 8
]


## Dies of the cold at `pos` carrying HAUL and wearing a club, and returns the `died` event.
func _die_at(sim: Sim, pos: Array, pack: Array = HAUL) -> Dictionary:
	H.place(sim, pos)
	H.arm(sim, "wooden_club", pack)
	H.patch(sim, {"warmth": 0, "health": 1})
	var died := H.of_kind(H.run(sim, 2), Vocab.EV_DIED)
	assert_eq(died.size(), 1, "the cold takes the player at %s" % [pos])
	return died[0] if died.size() == 1 else {"kept": [], "lost": [], "chest": "?"}


func _chest(sim: Sim) -> Array:
	return sim.state["death_chests"][DUNGEON]


## Walks to the chest from just beside it and returns the events of the visit.
func _visit_chest(sim: Sim) -> Array[Dictionary]:
	H.place(sim, [69.0, -50.5])
	sim.drain_events()
	var result := sim.command(Vocab.INTERACT, {"object_id": CHEST})
	assert_true(result["ok"], result["reason"])
	return H.run_until_idle(sim, 40)


# --- The chest ----------------------------------------------------------------------------

func test_the_dungeon_table_names_a_death_chest_on_its_reserved_spot() -> void:
	var w := WorldDefScript.outpost()
	assert_eq(WorldDef.DUNGEONS[DUNGEON]["chest"], CHEST)
	assert_eq(WorldDef.dungeon_of_chest(CHEST), DUNGEON)
	assert_eq(WorldDef.dungeon_of_chest(""), "")
	assert_eq(WorldDef.dungeon_of_chest("stash"), "")
	assert_eq(w.objects[CHEST]["kind"], WorldDef.KIND_DEATH_CHEST)
	var at: Array = WorldDef.DUNGEONS[DUNGEON]["reserved"]["chest"]
	assert_eq(w.object_center(CHEST), Vector2(at[0], at[1]), "on the spot #205 reserved")
	assert_eq(w.region_at(w.object_center(CHEST)), WorldDef.REGION_RING_ONE_DUNGEON)


func test_a_new_character_has_every_gentle_dungeons_chest_empty() -> void:
	var sim := SimScript.new()
	assert_eq(sim.state["death_chests"], {DUNGEON: []})


# --- Death --------------------------------------------------------------------------------

func test_a_death_inside_keeps_what_ring_one_keeps_and_chests_the_rest() -> void:
	var outside := SimScript.new()
	var there := _die_at(outside, IN_RING_ONE)
	var sim := SimScript.new()
	var died := _die_at(sim, IN_DUNGEON)
	assert_eq(died["kept"], there["kept"], "the same things are kept")
	assert_eq(died["lost"], there["lost"], "and the same things are not")
	assert_eq(died["lost"], [
		{"item": "tin_ore", "count": 4}, {"item": "wolf_pelt", "count": 1}, {"item": "logs", "count": 3},
		{"item": "wooden_axe", "count": 1},
	])
	assert_eq(_chest(sim), died["lost"], "everything not kept waits in the chest")
	assert_eq(died["chest"], CHEST, "and the died event says so")
	assert_eq(there["chest"], "", "a death in ring one names no chest")
	assert_eq(_chest(outside), [], "and destroys what it loses")
	assert_true(sim.in_outpost(), "the player still wakes by the outpost fire")
	assert_eq(died["spare"], "wooden_axe", "with a spare axe, as anywhere")
	assert_eq(sim.state["inventory"]["equipment"]["tool"], "wooden_axe")


func test_nothing_lost_inside_is_destroyed() -> void:
	var sim := SimScript.new()
	H.place(sim, IN_DUNGEON)
	H.arm(sim, "wooden_club", HAUL)
	var before := {}
	for slot in ItemTable.EQUIPMENT_SLOTS:
		var item: String = sim.state["inventory"]["equipment"][slot]
		if item != "":
			before[item] = int(before.get(item, 0)) + 1
	for s in HAUL:
		before[s["item"]] = int(before.get(s["item"], 0)) + int(s["count"])
	H.patch(sim, {"warmth": 0, "health": 1})
	var died := H.of_kind(H.run(sim, 2), Vocab.EV_DIED)
	assert_eq(died.size(), 1)
	var after := {}
	for slot in ItemTable.EQUIPMENT_SLOTS:
		var item: String = sim.state["inventory"]["equipment"][slot]
		if item != "":
			after[item] = int(after.get(item, 0)) + 1
	for s in sim.state["inventory"]["pack"] + _chest(sim):
		if s != null:
			after[s["item"]] = int(after.get(s["item"], 0)) + int(s["count"])
	# The spare axe is the only thing that was not there before: the lost axe is in the chest.
	after["wooden_axe"] = int(after["wooden_axe"]) - 1
	assert_eq(after, before, "everything carried or worn is kept or in the chest")


func test_a_second_death_inside_replaces_what_the_chest_holds() -> void:
	var sim := SimScript.new()
	_die_at(sim, IN_DUNGEON)
	var second := [
		{"item": "iron_sword", "count": 1}, {"item": "iron_bar", "count": 2}, {"item": "coal", "count": 4},
		{"item": "cooked_trout", "count": 3}, {"item": "troll_hide", "count": 2}, {"item": "iron_ore", "count": 10},
		{"item": "wolf_pelt", "count": 2}, {"item": "logs", "count": 1},
	]
	var died := _die_at(sim, IN_DUNGEON, second)
	assert_eq(died["chest"], CHEST)
	assert_eq(_chest(sim), died["lost"], "the second death's lost things, and only those")
	assert_false(_chest(sim).has({"item": "tin_ore", "count": 4}), "the first death's are gone")


func test_a_death_outside_the_dungeon_leaves_the_chest_alone() -> void:
	for pos in [IN_RING_ONE, H.OUTSIDE, [-40.0, 120.0]]:
		var sim := SimScript.new()
		_die_at(sim, IN_DUNGEON)
		var held := _chest(sim).duplicate(true)
		var died := _die_at(sim, pos)
		assert_eq(died["chest"], "", "a death at %s names no chest" % [pos])
		assert_eq(_chest(sim), held, "and leaves the chest as it was")
		for kind in ["tin_ore", "wolf_pelt", "logs"]:
			assert_eq(H.pack_count(sim, kind), 0, "what it lost at %s is gone" % [pos])


func test_a_death_inside_is_a_save_point_and_disengages_as_anywhere() -> void:
	var sim := SimScript.new()
	H.place(sim, IN_DUNGEON)
	H.arm(sim, "wooden_club", HAUL)
	H.patch(sim, {"warmth": 0, "health": 1})
	var events := H.run(sim, 2)
	assert_eq(H.of_kind(events, Vocab.EV_SAVED)[-1]["reason"], "death")


# --- Taking from the chest ----------------------------------------------------------------

func test_taking_from_the_chest_fills_the_pack_and_leaves_the_rest_for_later() -> void:
	var sim := SimScript.new()
	H.patch(sim, {"death_chests": {DUNGEON: [
		{"item": "iron_bar", "count": 2}, {"item": "logs", "count": 3}, {"item": "copper_ore", "count": 5},
	]}})
	# A pack with room for two more stacks only.
	var full: Array = []
	for i in Sim.PACK_SLOTS - 2:
		full.append({"item": "iron_sword", "count": 1})
	H.set_pack(sim, full)
	var events := _visit_chest(sim)
	var took := H.of_kind(events, Vocab.EV_TOOK_FROM_CHEST)
	assert_eq(took.size(), 1)
	assert_eq(took[0]["object_id"], CHEST)
	assert_eq(took[0]["dungeon_id"], DUNGEON)
	assert_eq(took[0]["items"], [{"item": "iron_bar", "count": 2}, {"item": "logs", "count": 3}], "in order, while there is room")
	assert_eq(took[0]["left"], [{"item": "copper_ore", "count": 5}])
	assert_eq(_chest(sim), [{"item": "copper_ore", "count": 5}], "the rest stays in the chest")
	assert_eq(H.pack_count(sim, "iron_bar"), 2)
	assert_eq(H.pack_count(sim, "logs"), 3)
	assert_eq(H.of_kind(events, Vocab.EV_SAVED)[-1]["reason"], "death_chest", "a save point")

	var again := _visit_chest(sim)
	assert_eq(H.of_kind(again, Vocab.EV_TOOK_FROM_CHEST).size(), 0, "nothing fits a full pack")
	var refused := H.of_kind(again, Vocab.EV_COMMAND_REJECTED)
	assert_eq(refused.size(), 1)
	assert_eq(refused[0]["reason"], Vocab.REASON_PACK_FULL)
	assert_eq(_chest(sim), [{"item": "copper_ore", "count": 5}])

	var pack: Array = sim.state["inventory"]["pack"].duplicate(true)
	pack[0] = null
	H.set_pack(sim, pack.filter(func(s: Variant) -> bool: return s != null))
	var last := H.of_kind(_visit_chest(sim), Vocab.EV_TOOK_FROM_CHEST)
	assert_eq(last.size(), 1, "made room, the rest comes")
	assert_eq(last[0]["items"], [{"item": "copper_ore", "count": 5}])
	assert_eq(_chest(sim), [], "and the chest is empty")


func test_a_stack_tops_up_what_the_pack_already_carries() -> void:
	var sim := SimScript.new()
	H.patch(sim, {"death_chests": {DUNGEON: [{"item": "arrows", "count": 30}]}})
	var full: Array = []
	for i in Sim.PACK_SLOTS - 1:
		full.append({"item": "iron_sword", "count": 1})
	full.append({"item": "arrows", "count": ItemTable.stack_size("arrows") - 10})
	H.set_pack(sim, full)
	var took := H.of_kind(_visit_chest(sim), Vocab.EV_TOOK_FROM_CHEST)
	assert_eq(took.size(), 1)
	assert_eq(took[0]["items"], [{"item": "arrows", "count": 10}], "as many as fit")
	assert_eq(_chest(sim), [{"item": "arrows", "count": 20}])


func test_an_empty_chest_gives_nothing_and_saves_nothing() -> void:
	var sim := SimScript.new()
	var events := _visit_chest(sim)
	var touched := H.of_kind(events, Vocab.EV_INTERACTED)
	assert_eq(touched.size(), 1)
	assert_eq(touched[0]["action"], Vocab.ACTION_DEATH_CHEST)
	assert_eq(H.of_kind(events, Vocab.EV_TOOK_FROM_CHEST).size(), 0)
	assert_eq(H.of_kind(events, Vocab.EV_SAVED).size(), 0)


func test_the_chest_waits_with_no_timer() -> void:
	var sim := SimScript.new()
	_die_at(sim, IN_DUNGEON)
	var held := _chest(sim).duplicate(true)
	H.run(sim, 5000)
	assert_eq(_chest(sim), held)


func test_the_chest_is_not_a_store() -> void:
	var sim := SimScript.new()
	_die_at(sim, IN_DUNGEON)
	var held := _chest(sim).duplicate(true)
	H.place(sim, [0.5, 4.5])
	H.set_pack(sim, [{"item": "logs", "count": 4}, {"item": "copper_ore", "count": 2}])
	sim.command(Vocab.DEPOSIT_HAUL)
	sim.command(Vocab.WITHDRAW, {"index": 0})
	H.run(sim, 2)
	assert_eq(_chest(sim), held, "deposit and withdraw never touch it")


# --- Saves --------------------------------------------------------------------------------

func test_the_chest_survives_a_restore_and_a_save_code() -> void:
	var sim := SimScript.new()
	_die_at(sim, IN_DUNGEON)
	var held := _chest(sim).duplicate(true)
	assert_false(held.is_empty())
	var other := SimScript.new()
	assert_true(other.restore(sim.snapshot()))
	assert_eq(other.state["death_chests"][DUNGEON], held, "restore keeps it")
	var imported := SimScript.new()
	assert_true(imported.command(Vocab.IMPORT_SAVE, {"code": sim.export_code()})["ok"])
	assert_eq(imported.state["death_chests"][DUNGEON], held, "and so does a save code")


func test_a_save_without_the_entry_or_with_a_bad_one_loads_empty() -> void:
	var bads: Array = [null, "chest", [], {DUNGEON: "logs"}, {"no_such_dungeon": [{"item": "logs", "count": 3}]}]
	for bad in bads:
		var sim := SimScript.new()
		var snap := sim.snapshot()
		if bad == null:
			snap.erase("death_chests")
		else:
			snap["death_chests"] = bad
		assert_true(sim.restore(snap), "%s loads" % [bad])
		assert_eq(sim.state["death_chests"], {DUNGEON: []}, "%s loads every chest empty" % [bad])
	var sim := SimScript.new()
	var snap := sim.snapshot()
	snap["death_chests"] = {DUNGEON: [
		{"item": "logs", "count": 3.0}, {"item": "no_such_item", "count": 1}, "junk", {"item": "coal"},
		{"item": "arrows", "count": 9999}, {"item": "tin_ore", "count": 0},
	]}
	assert_true(sim.restore(snap))
	assert_eq(sim.state["death_chests"][DUNGEON], [
		{"item": "logs", "count": 3}, {"item": "arrows", "count": ItemTable.stack_size("arrows")},
	], "known items only, counts clamped to a stack")


func test_every_save_fixture_loads_with_the_chest_empty() -> void:
	var dir := DirAccess.open("res://tests/fixtures")
	var count := 0
	for name in dir.get_files():
		if not name.ends_with(".txt"):
			continue
		var sim := SimScript.new()
		var code := FileAccess.get_file_as_string("res://tests/fixtures/" + name).strip_edges()
		assert_true(sim.command(Vocab.IMPORT_SAVE, {"code": code})["ok"], "%s loads" % name)
		assert_eq(sim.state["death_chests"], {DUNGEON: []}, "%s has an empty chest" % name)
		count += 1
	assert_true(count > 0, "some fixtures")
