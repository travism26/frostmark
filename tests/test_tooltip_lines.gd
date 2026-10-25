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


func test_a_troll_hide_builds_the_blast_furnace_and_crafts_the_steel_body() -> void:
	var lines := UiTooltip.item_lines("troll_hide")
	assert_eq(_builds_line(lines), "Builds Blast furnace.")
	var crafts := ""
	for line in lines:
		if line.begins_with("Crafts into "):
			crafts = line
	assert_true(crafts.contains("steel body"), crafts)


func test_logs_list_their_upgrades_in_table_order() -> void:
	assert_eq(_builds_line(UiTooltip.item_lines("logs")),
		"Builds Stash shelves, Forge, Stash cellar, Armoury, Pack frame, Bloomery, Ring-two gate winch, Blast furnace, Waystones, Stash vault.")


func test_the_builds_line_comes_straight_after_crafts_into() -> void:
	var lines := UiTooltip.item_lines("troll_hide", "Click to deposit")
	var at := lines.find("Builds Blast furnace.")
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
