## The Upgrades tab's rows: grouped by line in step order with the single upgrades after,
## each row's state and what it says taken from the sim's status query, and the one flash
## the row just built gives. How the rows look is judged from screenshots; this checks what
## they are drawn from.
extends "res://tests/run.gd".TestCase

const H := preload("res://tests/sim_helpers.gd")
const SimScript := preload("res://sim/sim.gd")
const Vocab := preload("res://sim/vocab.gd")
const UpgradeRowsScript := preload("res://scenes/upgrade_rows.gd")


## A sim whose stash holds `entries`, with `upgrades` built (the same arrangement as the
## upgrade sim tests).
func _sim_with_stash(entries: Array, upgrades: Array = [], capacity := Sim.STASH_START_SLOTS + 4) -> Sim:
	var sim := SimScript.new()
	var slots: Array = []
	slots.resize(capacity)
	for i in entries.size():
		slots[i] = entries[i]
	H.patch(sim, {"stash": {"capacity": capacity, "slots": slots}, "upgrades": upgrades})
	sim.drain_events()
	return sim


func test_lines_come_first_in_step_order_then_the_singles() -> void:
	var groups := UpgradeRowsScript.groups()
	assert_eq(groups.size(), 3)
	assert_eq(groups[0], {"title": "Stash line", "ids": ["stash_shelves", "stash_cellar", "stash_vault"]})
	assert_eq(groups[1], {"title": "Smithing line", "ids": ["forge", "bloomery", "blast_furnace"]})
	assert_eq(groups[2], {"title": UpgradeRowsScript.SINGLES, "ids": ["armoury", "ring_two_gate", "waystone"]})


func test_every_upgrade_has_exactly_one_row() -> void:
	var ids: Array = []
	for g in UpgradeRowsScript.groups():
		ids.append_array(g["ids"])
	assert_eq(ids.size(), UpgradeTable.ids().size())
	for id in UpgradeTable.ids():
		assert_true(ids.has(id), "%s has a row" % id)


func test_a_row_that_can_be_built_now_shows_the_unlocked_icon() -> void:
	var sim := _sim_with_stash([{"item": "logs", "count": 9}])
	var v := UpgradeRowsScript.view("stash_shelves", sim.upgrade_status()["stash_shelves"])
	assert_eq(v["state"], UpgradeRowsScript.CAN_BUILD)
	assert_eq(v["icon"], "unlocked")
	assert_eq(v["button"], "Build")
	assert_true(ResourceLoader.exists(UiTheme.ICON_DIR + "unlocked.png"), "the unlocked icon ships")


func test_can_build_now_holds_outside_the_outpost_too() -> void:
	var sim := _sim_with_stash([{"item": "logs", "count": 8}])
	H.place(sim, H.OUTSIDE)
	var v := UpgradeRowsScript.view("stash_shelves", sim.upgrade_status()["stash_shelves"])
	assert_eq(v["state"], UpgradeRowsScript.CAN_BUILD, "the state follows the sim's status, not where you stand")


func test_an_unmet_row_says_what_is_missing() -> void:
	var sim := _sim_with_stash([{"item": "logs", "count": 10}, {"item": "copper_ore", "count": 1}])
	var forge := UpgradeRowsScript.view("forge", sim.upgrade_status()["forge"])
	assert_eq(forge["state"], UpgradeRowsScript.NOT_YET)
	assert_eq(forge["icon"], "")
	assert_true(forge["lines"].has("Short of 2 copper ore and 3 tin ore."), "how much more of each short item")
	var winch := UpgradeRowsScript.view("ring_two_gate", sim.upgrade_status()["ring_two_gate"])
	assert_true(winch["lines"].has("Needs the Armoury first."), "the prerequisite by name")
	assert_true(winch["lines"].has("Short of 2 logs, 12 iron ore, 3 bronze bar and 5 wolf pelt."), "and the short items beside it")


func test_a_row_whose_cost_is_met_but_needs_an_upgrade_names_only_that() -> void:
	var lots := [{"item": "logs", "count": 10}, {"item": "logs", "count": 10}, {"item": "bronze_bar", "count": 10}]
	var v := UpgradeRowsScript.view("stash_cellar", _sim_with_stash(lots).upgrade_status()["stash_cellar"])
	assert_eq(v["state"], UpgradeRowsScript.NOT_YET)
	assert_true(v["lines"].has("Needs the Stash shelves first."))
	for line in v["lines"]:
		assert_true(not str(line).begins_with("Short of"), "nothing is short")


func test_a_built_row_says_built_with_the_checkmark() -> void:
	var sim := _sim_with_stash([], ["stash_shelves"])
	var v := UpgradeRowsScript.view("stash_shelves", sim.upgrade_status()["stash_shelves"])
	assert_eq(v["state"], UpgradeRowsScript.BUILT)
	assert_eq(v["button"], "Built")
	assert_eq(v["icon"], "checkmark")
	assert_eq(v["lines"][-1], "Built.")


func test_a_locked_upgrade_reads_locked() -> void:
	var status := {"status": Vocab.UPGRADE_NOT_YET, "locked": "Not in this version.", "requires": [], "cost": [], "short": [], "reason": ""}
	var v := UpgradeRowsScript.view("waystone", status)
	assert_eq(v["state"], UpgradeRowsScript.LOCKED)
	assert_eq(v["icon"], "locked")
	assert_eq(v["lines"][-1], "Locked. Not in this version.")


func test_the_row_just_built_flashes_once_then_settles() -> void:
	var f := UpgradeRowsScript.FLASH_SECONDS
	assert_eq(UpgradeRowsScript.flash(0.0), 0.0, "starts from rest")
	assert_true(UpgradeRowsScript.flash(f * 0.5) > 0.99, "peaks once at the middle")
	var rising := true
	var turns := 0
	var last := 0.0
	for i in range(1, 60):
		var g := UpgradeRowsScript.flash(f * i / 60.0)
		if rising and g < last:
			rising = false
			turns += 1
		elif not rising and g > last:
			turns += 1
		last = g
	assert_eq(turns, 1, "one rise and one fall")
	assert_eq(UpgradeRowsScript.flash(f), 0.0, "back at rest when it ends")
	assert_eq(UpgradeRowsScript.flash(f + 5.0), 0.0, "and stays there")
