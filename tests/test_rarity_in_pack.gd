## Rarity in the pack and the stash, from the screen's own functions: a slot holding a rare,
## super rare or ultra rare item is tinted blue, purple or gold, and its tooltip names it in
## that colour. Uncommon iron pieces and band-less items stay plain. No real item is rare or
## better yet (#138), so stand-in items carry those bands, and they reach the stash the way a
## player puts them there: a deposit through the sim.
extends "res://tests/run.gd".TestCase

const SimScript := preload("res://sim/sim.gd")
const H := preload("res://tests/sim_helpers.gd")
const HudScript := preload("res://scenes/hud.gd")

const STAND_IN_ITEMS := {
	"stand_in_rare_charm": {
		"label": "Stand-in rare charm", "stack": 1, "weight": 1, "value": 200, "slot": "",
		"rarity": ItemTable.RARITY_RARE,
	},
	"stand_in_super_rare_charm": {
		"label": "Stand-in super rare charm", "stack": 1, "weight": 1, "value": 400, "slot": "",
		"rarity": ItemTable.RARITY_SUPER_RARE,
	},
	"stand_in_ultra_rare_charm": {
		"label": "Stand-in ultra rare charm", "stack": 1, "weight": 1, "value": 800, "slot": "",
		"rarity": ItemTable.RARITY_ULTRA_RARE,
	},
}
## Each stand-in's colour, read from the one table of band colours.
var BAND_COLOURS := {
	"stand_in_rare_charm": RarityLook.colour(ItemTable.RARITY_RARE),
	"stand_in_super_rare_charm": RarityLook.colour(ItemTable.RARITY_SUPER_RARE),
	"stand_in_ultra_rare_charm": RarityLook.colour(ItemTable.RARITY_ULTRA_RARE),
}
const PLAIN := ["iron_sword", "iron_helm", "iron_pickaxe", "bronze_sword", "steel_body", "hearthguard_helm", "logs", "wolf_pelt", "cooked_trout"]


## A slot cell as the pack and stash build it, filled with `slot` the way they fill it.
func _cell(slot: Variant) -> Button:
	var b := Button.new()
	HudScript.tint_slot(b, slot)
	return b


func _rim(b: Button) -> Variant:
	if not b.has_theme_stylebox_override("normal"):
		return null
	return Color((b.get_theme_stylebox("normal") as StyleBoxFlat).border_color, 1.0)


## The colour the tooltip's title is drawn in, or null when it is the theme's plain heading.
func _title_colour(kind: String) -> Variant:
	var tip := UiTooltip.item(kind, "Click to deposit")
	var heading: Label = null
	for node in tip.find_children("*", "Label", true, false):
		if (node as Label).text == ItemTable.label(kind):
			heading = node
	assert_true(heading != null, "%s's tooltip has its name as its title" % kind)
	var colour: Variant = null
	if heading != null and heading.has_theme_color_override("font_color"):
		colour = heading.get_theme_color("font_color")
	tip.free()
	return colour


func test_the_band_colours_are_blue_purple_and_gold_and_uncommon_has_none() -> void:
	var c: Color = RarityLook.colour(ItemTable.RARITY_RARE)
	assert_true(c.b > c.r and c.b > c.g, "rare is blue: %s" % c)
	c = RarityLook.colour(ItemTable.RARITY_SUPER_RARE)
	assert_true(c.r > c.g and c.b > c.g and c.b > 0.8, "super rare is purple: %s" % c)
	c = RarityLook.colour(ItemTable.RARITY_ULTRA_RARE)
	assert_true(c.r > c.b and c.g > c.b and c.r > 0.8, "ultra rare is gold: %s" % c)
	assert_eq(RarityLook.colour(ItemTable.RARITY_UNCOMMON), null, "uncommon has no colour")
	assert_eq(RarityLook.colour(""), null, "no band, no colour")
	assert_eq(RarityLook.COLOURS.size(), 3, "one colour for each band rarer than uncommon")


func test_a_rare_super_rare_and_ultra_rare_item_tint_their_pack_slot() -> void:
	ItemTable.add_stand_ins(STAND_IN_ITEMS)
	var sim := SimScript.new()
	var entries: Array = []
	for kind in STAND_IN_ITEMS:
		entries.append({"item": kind, "count": 1})
	H.set_pack(sim, entries)
	var pack: Array = sim.state["inventory"]["pack"]
	for i in STAND_IN_ITEMS.size():
		var kind: String = pack[i]["item"]
		var b := _cell(pack[i])
		assert_eq(_rim(b), BAND_COLOURS[kind], "%s's pack slot" % kind)
		var hover := b.get_theme_stylebox("hover") as StyleBoxFlat
		assert_eq(Color(hover.shadow_color, 1.0), BAND_COLOURS[kind], "%s glows in its band on hover" % kind)
		b.free()
	ItemTable.clear_stand_ins()


func test_the_same_tint_shows_in_the_stash() -> void:
	ItemTable.add_stand_ins(STAND_IN_ITEMS)
	var sim := SimScript.new()
	H.patch(sim, {"stash": {"capacity": Sim.STASH_START_SLOTS, "slots": []}})  # without the starting kit
	var entries: Array = []
	for kind in STAND_IN_ITEMS:
		entries.append({"item": kind, "count": 1})
	H.set_pack(sim, entries)
	for i in STAND_IN_ITEMS.size():
		assert_true(sim.command(SimVocab.DEPOSIT, {"index": i})["ok"])
		H.run(sim, 1)
	var slots: Array = sim.state["stash"]["slots"]
	for kind in STAND_IN_ITEMS:
		var at := -1
		for i in slots.size():
			if slots[i] != null and slots[i]["item"] == kind:
				at = i
		assert_true(at >= 0, "%s is in the stash" % kind)
		if at >= 0:
			var b := _cell(slots[at])
			assert_eq(_rim(b), BAND_COLOURS[kind], "%s's stash slot" % kind)
			b.free()
	ItemTable.clear_stand_ins()


func test_each_ones_tooltip_shows_its_name_in_its_band_colour() -> void:
	ItemTable.add_stand_ins(STAND_IN_ITEMS)
	for kind in STAND_IN_ITEMS:
		assert_eq(_title_colour(kind), BAND_COLOURS[kind], kind)
	ItemTable.clear_stand_ins()


func test_iron_pieces_and_every_other_item_stay_plain() -> void:
	for kind in ItemTable.ITEMS:
		var b := _cell({"item": kind, "count": 1})
		assert_eq(_rim(b), null, "%s's slot is not tinted" % kind)
		b.free()
	for kind in PLAIN:
		assert_eq(_title_colour(kind), null, "%s's name is plain" % kind)
	assert_eq(ItemTable.rarity("iron_sword"), ItemTable.RARITY_UNCOMMON, "iron is uncommon")


func test_a_slot_loses_its_tint_when_a_plain_item_or_nothing_takes_its_place() -> void:
	ItemTable.add_stand_ins(STAND_IN_ITEMS)
	var b := _cell({"item": "stand_in_ultra_rare_charm", "count": 1})
	assert_eq(_rim(b), BAND_COLOURS["stand_in_ultra_rare_charm"])
	HudScript.tint_slot(b, {"item": "stand_in_rare_charm", "count": 1})
	assert_eq(_rim(b), BAND_COLOURS["stand_in_rare_charm"], "a new band, a new tint")
	HudScript.tint_slot(b, {"item": "iron_sword", "count": 1})
	assert_eq(_rim(b), null, "an iron piece leaves it plain")
	HudScript.tint_slot(b, {"item": "stand_in_super_rare_charm", "count": 1})
	HudScript.tint_slot(b, null)
	assert_eq(_rim(b), null, "an empty slot is plain")
	b.free()
	ItemTable.clear_stand_ins()
