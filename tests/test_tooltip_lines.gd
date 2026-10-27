## An item tooltip's body lines, from the pure function the tooltip builds them with: a material
## names what it crafts into and, on a "Builds" line straight after, every outpost upgrade whose
## cost includes it, in upgrade-table order. Items that build nothing get no "Builds" line.
extends "res://tests/run.gd".TestCase


func _builds_line(lines: Array[String]) -> String:
	for line in lines:
		if line.begins_with("Builds "):
			return line
	return ""


func test_a_wolf_pelt_builds_the_armoury_frame_and_winch() -> void:
	var lines := UiTooltip.item_lines("wolf_pelt")
	assert_true(lines.has("Builds Armoury, Pack frame, Ring-two gate winch."), str(lines))


func test_a_troll_hide_builds_the_blast_furnace_and_the_hoist_and_crafts_the_steel_body() -> void:
	var lines := UiTooltip.item_lines("troll_hide")
	assert_eq(_builds_line(lines), "Builds Blast furnace, Ring-three gate hoist.")
	var crafts := ""
	for line in lines:
		if line.begins_with("Crafts into "):
			crafts = line
	assert_true(crafts.contains("steel body"), crafts)


func test_logs_list_their_upgrades_in_table_order() -> void:
	assert_eq(_builds_line(UiTooltip.item_lines("logs")),
		"Builds Stash shelves, Forge, Stash cellar, Armoury, Pack frame, Bloomery, Ring-two gate winch, Blast furnace, Ring-three gate hoist, Waystones, Stash vault.")


func test_the_builds_line_comes_straight_after_crafts_into() -> void:
	var lines := UiTooltip.item_lines("troll_hide", "Click to deposit")
	var at := lines.find("Builds Blast furnace, Ring-three gate hoist.")
	assert_true(at > 0 and lines[at - 1].begins_with("Crafts into "), str(lines))
	assert_eq(lines[lines.size() - 1], "Click to deposit.")


func test_an_item_that_builds_nothing_has_no_builds_line() -> void:
	assert_eq(_builds_line(UiTooltip.item_lines("cooked_trout")), "")
	assert_eq(_builds_line(UiTooltip.item_lines("bronze_sword")), "")


func test_a_wolf_pelt_crafts_into_the_fur_pieces() -> void:
	assert_true(UiTooltip.item_lines("wolf_pelt").has("Crafts into fur hood, fur coat, fur leggings."), str(UiTooltip.item_lines("wolf_pelt")))


func test_a_fur_piece_shows_no_tier_and_takes_nothing_off_a_hit() -> void:
	for kind in ["fur_hood", "fur_coat", "fur_legs"]:
		var lines := UiTooltip.item_lines(kind)
		assert_true(lines.has("Takes nothing off a hit on its own."), "%s: %s" % [kind, lines])
		assert_false("\n".join(lines).contains("tier"), "%s shows no tier: %s" % [kind, lines])
	assert_true(UiTooltip.item_lines("bronze_helm")[0].begins_with("Bronze tier"), "metal still shows its tier")


func test_a_fur_piece_says_it_makes_warmth_last_longer() -> void:
	for kind in ["fur_hood", "fur_coat", "fur_legs"]:
		assert_true(UiTooltip.item_lines(kind).has("Makes warmth last longer while worn."), "%s: %s" % [kind, UiTooltip.item_lines(kind)])
	for kind in ["bronze_helm", "wolf_pelt", "logs"]:
		assert_false("\n".join(UiTooltip.item_lines(kind)).contains("warmth"), "%s keeps no cold out" % kind)


func test_a_set_piece_shows_its_set_and_level_first() -> void:
	var expected := {
		"hearthguard_helm": "Hearthguard · mid (beside bronze)",
		"trapper_bow": "Trapper's Leathers · mid (beside bronze)",
		"wolfstalker_quiver": "Wolfstalker · mid-high (beside iron)",
		"rimecaller_cape": "Rimecaller · mid-high (beside iron)",
		"steelpoint_body": "Steelpoint Ranger · high (beside steel)",
		"glacier_warden_staff": "Glacier Warden · high (beside steel)",
		"emberheart_hammer": "Emberheart · top (above steel)",
		"ruinwarden_mage_cape": "Ruinwarden · top (above steel)",
	}
	for kind in expected:
		assert_eq(UiTooltip.item_lines(kind)[0], expected[kind], "%s: %s" % [kind, UiTooltip.item_lines(kind)])


func test_every_set_piece_names_its_set_and_level_and_no_tier() -> void:
	for kind in ItemTable.ITEMS:
		var set_key := ItemTable.set_of(kind)
		if set_key == "":
			continue
		var lines := UiTooltip.item_lines(kind)
		assert_eq(lines[0], UiTooltip.set_line(set_key), "%s: %s" % [kind, lines])
		assert_true(lines[0].begins_with(ItemTable.set_label(set_key) + " · " + ItemTable.set_level(set_key) + " ("), lines[0])
		assert_false(lines[1].contains("tier"), "%s shows no tier: %s" % [kind, lines])


func test_a_tier_piece_shows_no_set_line() -> void:
	for kind in ["bronze_helm", "iron_sword", "steel_body", "wooden_axe", "fur_coat", "logs"]:
		var lines := UiTooltip.item_lines(kind)
		assert_false("\n".join(lines).contains("·"), "%s: %s" % [kind, lines])
	assert_eq(UiTooltip.item_lines("bronze_helm")[0], "Bronze tier, 1 kg, worth 10 each")
	assert_eq(UiTooltip.item_lines("steel_sword", "Click to equip"),
		["Steel tier, 4 kg, worth 160 each", "Melee, power 11, reach 1.5 m.", "Click to equip."] as Array[String])


func test_a_set_piece_shows_how_many_of_its_set_are_worn() -> void:
	var worn := {"weapon": "hearthguard_broadsword", "helm": "hearthguard_helm", "body": "steel_body", "legs": ""}
	assert_true(UiTooltip.item_lines("hearthguard_legs", "", worn).has("Hearthguard 2/4 worn"), "%s" % [UiTooltip.item_lines("hearthguard_legs", "", worn)])
	assert_true(UiTooltip.item_lines("hearthguard_helm", "", worn).has("Hearthguard 2/4 worn"), "the same count on a worn piece")
	assert_true(UiTooltip.item_lines("wolfstalker_quiver", "", worn).has("Wolfstalker 0/5 worn"), "another set counts its own")
	assert_true(UiTooltip.item_lines("auroral_warden_cape").has("Auroral Warden 0/6 worn"), "nothing worn")
	for kind in ["steel_body", "bronze_helm", "fur_coat", "logs"]:
		for line in UiTooltip.item_lines(kind, "", worn):
			assert_false(line.ends_with(" worn") or line.contains(" pieces"), "%s is in no set: %s" % [kind, line])


func test_a_set_piece_lists_its_steps_with_the_reached_ones_apart() -> void:
	ItemTable.clear_stand_in_steps()
	ItemTable.add_stand_in_steps({"hearthguard": [
		{"pieces": 2, "power": 2, "defence": 1}, {"pieces": 4, "power": 0, "defence": 2},
	]})
	var two := {"weapon": "hearthguard_broadsword", "helm": "hearthguard_helm", "body": "steel_body"}
	var lines := UiTooltip.item_lines("hearthguard_body", "Click to equip", two)
	var at := lines.find("Hearthguard 2/4 worn")
	assert_true(at >= 0, "%s" % [lines])
	assert_eq(lines.slice(at, at + 3), ["Hearthguard 2/4 worn", "2 pieces (reached): +2 melee power, +1 defence.", "4 pieces: +2 defence."] as Array[String])
	assert_eq(lines[-1], "Click to equip.", "the click stays last")
	var four := {"weapon": "hearthguard_broadsword", "helm": "hearthguard_helm", "body": "hearthguard_body", "legs": "hearthguard_legs"}
	assert_eq(UiTooltip.set_bonus_lines("hearthguard", four), ["Hearthguard 4/4 worn", "2 pieces (reached): +2 melee power, +1 defence.", "4 pieces (reached): +2 defence."] as Array[String])
	assert_eq(UiTooltip.set_bonus_lines("hearthguard", {}), ["Hearthguard 0/4 worn", "2 pieces: +2 melee power, +1 defence.", "4 pieces: +2 defence."] as Array[String])
	ItemTable.clear_stand_in_steps()


func test_the_placeholder_steps_say_there_is_no_bonus_yet() -> void:
	ItemTable.clear_stand_in_steps()
	var worn := {"weapon": "wolfstalker_bow", "helm": "wolfstalker_helm", "body": "wolfstalker_body", "legs": "wolfstalker_legs"}
	assert_eq(UiTooltip.set_bonus_lines("wolfstalker", worn), [
		"Wolfstalker 4/5 worn", "2 pieces (reached): no bonus yet.", "4 pieces (reached): no bonus yet.", "5 pieces: no bonus yet.",
	] as Array[String])


func test_every_set_piece_lists_one_line_per_step() -> void:
	ItemTable.clear_stand_in_steps()
	for kind in ItemTable.ITEMS:
		var set_key := ItemTable.set_of(kind)
		if set_key == "":
			continue
		var lines := UiTooltip.item_lines(kind)
		var at := lines.find("%s 0/%d worn" % [ItemTable.set_label(set_key), ItemTable.set_size(set_key)])
		assert_true(at > 0, "%s: %s" % [kind, lines])
		for i in ItemTable.set_steps(set_key).size():
			assert_true(lines[at + 1 + i].begins_with("%d pieces: " % ItemTable.set_steps(set_key)[i]["pieces"]), "%s: %s" % [kind, lines])
