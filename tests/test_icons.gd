## The interface pass's data: every skill, item kind, panel tab, combat style and interface
## action resolves to a glyph that exists and loads, every shipped glyph is used by some key,
## every game-icons.net icon and author in use is credited, and the interface settings
## persist beside the sound settings without either wiping the other.
extends "res://tests/run.gd".TestCase

const CREDITS_PATH := "res://docs/assets/CREDITS.md"
const SETTINGS_PATH := "user://test_ui_settings.cfg"


func test_every_skill_item_tab_style_and_action_has_an_icon() -> void:
	var expected: Array[String] = []
	expected.append_array(SkillTable.NAMES)
	for kind in ItemTable.ITEMS:
		expected.append(kind)
	expected.append_array(IconTable.TABS)
	for style in [CombatTable.STYLE_MELEE, CombatTable.STYLE_RANGED, CombatTable.STYLE_MAGIC]:
		var key := IconTable.style_key(style)
		assert_ne(key, "", "%s has an icon key" % style)
		expected.append(key)
	expected.append_array(IconTable.UI_ACTIONS)
	for slot in ItemTable.EQUIPMENT_SLOTS:
		assert_true(IconTable.SLOT_KEYS.has(slot), "empty %s slot has a glyph" % slot)
		expected.append(IconTable.SLOT_KEYS[slot])
	for key in expected:
		assert_true(IconTable.has(key), "%s is in the icon table" % key)


func test_every_key_resolves_to_a_glyph_that_loads_with_a_tint() -> void:
	for key in IconTable.all_keys():
		var p := IconTable.path(key)
		assert_true(p.begins_with(IconTable.DIR) and p.ends_with(".svg"), "%s: %s is an svg under the icon folder" % [key, p])
		assert_true(ResourceLoader.exists(p), "%s: %s exists" % [key, p])
		assert_true(load(p) is Texture2D, "%s: %s loads as a texture" % [key, p])
		assert_true(IconTable.AUTHORS.has(IconTable.author(key)), "%s: author %s is named" % [key, IconTable.author(key)])
		assert_true(IconTable.tint(key).a > 0.99, "%s has an opaque badge tint" % key)


func test_every_shipped_glyph_is_used() -> void:
	var used := {}
	for key in IconTable.all_keys():
		used[IconTable.path(key)] = true
	var shipped := 0
	for folder in DirAccess.get_directories_at(IconTable.DIR):
		for file in DirAccess.get_files_at(IconTable.DIR + folder):
			if file.ends_with(".svg"):
				shipped += 1
				assert_true(used.has(IconTable.DIR + folder + "/" + file), "%s/%s is referenced by a key (prune it otherwise)" % [folder, file])
	assert_true(shipped > 0, "the icon folder ships glyphs")


func test_every_icon_and_author_in_use_is_credited() -> void:
	var credits := FileAccess.get_file_as_string(CREDITS_PATH)
	assert_true(credits.length() > 0, "the credits file reads")
	var in_use := IconTable.authors_in_use()
	assert_false(in_use.is_empty(), "some author is in use")
	for folder in in_use:
		var line := "Icons made by %s. Available on %s" % [IconTable.AUTHORS[folder], IconTable.SITE]
		assert_true(credits.contains(line), "credits carry the line for %s" % folder)
	for key in IconTable.all_keys():
		var icon := str(IconTable.ICONS[key]["icon"])
		assert_true(credits.contains("`%s`" % icon.get_slice("/", 1)), "credits name the %s glyph" % icon)
	for line in IconTable.credits():
		assert_true(credits.contains(line), "the in-game credit line is in the file: %s" % line)


func test_tiered_gear_takes_its_tier_colour_and_styles_share_the_telegraph_colours() -> void:
	assert_eq(IconTable.tint("steel_sword"), IconTable.TIER_TINTS[ItemTable.TIER_STEEL], "steel gear wears the steel tint")
	assert_eq(IconTable.tint("steel_axe"), IconTable.tint("steel_armour"), "all steel gear matches")
	assert_ne(IconTable.tint("bronze_sword"), IconTable.tint("iron_sword"), "tiers differ")
	for style in IconTable.STYLE_COLOURS:
		assert_eq(IconTable.tint(IconTable.style_key(style)), IconTable.STYLE_COLOURS[style], "%s badge is the telegraph colour" % style)


func test_ui_settings_persist_and_keep_the_sound_section() -> void:
	DirAccess.remove_absolute(SETTINGS_PATH)
	var fresh := UiSettings.load_from(SETTINGS_PATH)
	assert_almost_eq(fresh.ui_scale, UiSettings.DEFAULT_SCALE, 0.0001, "no file: 100% scale")
	assert_false(fresh.reduced_motion, "no file: full motion")
	assert_false(UiSettings.reduced_motion_on(SETTINGS_PATH), "the accessor reads the default")
	var sound := AudioSettings.new()
	sound.volume = 0.35
	assert_true(sound.save_to(SETTINGS_PATH), "sound settings write")
	var ui := UiSettings.new()
	ui.ui_scale = 1.25
	ui.reduced_motion = true
	assert_true(ui.save_to(SETTINGS_PATH), "interface settings write")
	var back := UiSettings.load_from(SETTINGS_PATH)
	assert_almost_eq(back.ui_scale, 1.25, 0.0001, "scale persists")
	assert_true(back.reduced_motion, "reduced motion persists")
	assert_true(UiSettings.reduced_motion_on(SETTINGS_PATH), "the accessor sees it")
	assert_almost_eq(AudioSettings.load_from(SETTINGS_PATH).volume, 0.35, 0.0001, "the sound section survives the interface write")
	sound.volume = 0.5
	sound.reduced_motion = true  # the director's copy, kept in step by GameRoot
	sound.save_to(SETTINGS_PATH)
	assert_almost_eq(UiSettings.load_from(SETTINGS_PATH).ui_scale, 1.25, 0.0001, "the interface section survives the sound write")
	assert_true(UiSettings.load_from(SETTINGS_PATH).reduced_motion, "reduced motion is one key both stores read")
	assert_true(AudioSettings.load_from(SETTINGS_PATH).reduced_motion, "the sound store sees the same key")
	DirAccess.remove_absolute(SETTINGS_PATH)


func test_odd_scales_snap_to_an_offered_one() -> void:
	assert_almost_eq(UiSettings.nearest_scale(0.5), 0.9, 0.0001, "too small snaps to 90%")
	assert_almost_eq(UiSettings.nearest_scale(1.1), 1.0, 0.0001, "near 100% snaps to it")
	assert_almost_eq(UiSettings.nearest_scale(3.0), 1.25, 0.0001, "too big snaps to 125%")
	var cfg := ConfigFile.new()
	cfg.set_value(UiSettings.SECTION, UiSettings.KEY_SCALE, 7.0)
	cfg.save(SETTINGS_PATH)
	assert_almost_eq(UiSettings.load_from(SETTINGS_PATH).ui_scale, 1.25, 0.0001, "a stored odd scale snaps on load")
	DirAccess.remove_absolute(SETTINGS_PATH)
