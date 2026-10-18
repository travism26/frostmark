## The in-game HUD: one fixed side panel with tabs for Pack, Equipment, Skills, Upgrades and
## Settings, the warmth and health orbs and the Light fire button beside it, the stash and
## workbench panels that open when those are used, the save-code panel and the banner for big
## moments.
##
## Glue only. It reads `sim.state` to draw and turns button presses into commands through
## `command_requested`; whether a command is allowed is always the simulation's answer. The
## Settings tab emits `sound_changed` and `ui_changed`; GameRoot applies and keeps them.
## Every widget takes its look from UiTheme and its glyphs from IconTable; nothing here sets
## a colour or a path of its own.
extends Control

signal command_requested(kind: String, args: Dictionary)
signal export_requested
signal help_requested
signal sound_changed(volume: float, music: float, muted: bool)
signal ui_changed(settings: UiSettings)

## The skills tab lists all eight, gathering, crafting, combat.
const READOUT_SKILLS: Array[String] = SkillTable.NAMES
const TABS: Array[String] = IconTable.TABS
const TAB_LABELS := {
	IconTable.TAB_PACK: "Pack", IconTable.TAB_EQUIPMENT: "Equipment", IconTable.TAB_SKILLS: "Skills",
	IconTable.TAB_UPGRADES: "Upgrades", IconTable.TAB_SETTINGS: "Settings",
}
## Hotkeys, in the usual MMO way: B for the bag, C for the character, K for skills, U for
## upgrades, O for options. Q and E stay the camera's; Escape folds the panel to its tabs.
const TAB_KEYS := {
	KEY_B: IconTable.TAB_PACK, KEY_C: IconTable.TAB_EQUIPMENT, KEY_K: IconTable.TAB_SKILLS,
	KEY_U: IconTable.TAB_UPGRADES, KEY_O: IconTable.TAB_SETTINGS,
}

const PANEL_NONE := ""
const PANEL_STASH := "stash"
const PANEL_CRAFT := "craft"
## The stash and workbench panels open top-left, clear of the orbs and the side panel.
const PANEL_POSITION := Vector2(24, 24)
const SIDE_WIDTH := 292.0
## Every tab's page is at least this tall, so the frame keeps one height as tabs change.
const PAGE_HEIGHT := 430.0
const MARGIN := 14.0
const ORB_PX := 76
const SLOT_PX := 56
const BADGE_PX := 36
const BANNER_SECONDS := 3.0
const BANNER_MAX_WIDTH := 580.0

var sim: Sim
var _panel := PANEL_NONE
var _tab := ""  # the tab shown; set by the first show_tab in _ready
var _folded := false  # the panel shows only its tab strip
var _warmth: Orb
var _health: Orb
var _fire_button: Button
var _side: PanelContainer
var _tab_buttons := {}  # tab -> Button
var _pages := {}  # tab -> Control
var _skill_rows := {}  # skill name -> {level, bar, cell}
var _skill_total: Label
var _pack_buttons: Array[UiTooltip.Host] = []
var _equip_buttons := {}  # slot -> {button, name}
var _weight_label: Label
var _style_badge: Control
var _style_label: Label
var _stash_panel: PanelContainer
var _stash_title: Label
var _stash_grid: GridContainer
var _stash_buttons: Array[UiTooltip.Host] = []
var _craft_panel: PanelContainer
var _craft_list: VBoxContainer
var _craft_rows := {}  # recipe id -> {text, button}
var _upgrade_list: VBoxContainer
var _upgrade_rows := {}  # upgrade id -> {title, text, button, style, state}
var _upgrade_note: Label
var _flash_upgrade := ""  # the upgrade whose row is flashing, "" for none
var _flash_left := 0.0
var _scale_buttons := {}  # scale -> Button
var _motion: CheckBox
var _retaliate: CheckBox
var _volume: HSlider
var _music: HSlider
var _mute: CheckBox
var _save_panel: PanelContainer
var _save_text: TextEdit
var _save_note: Label
var _saved_label: Label
var _banner: Label
var _banner_box: PanelContainer
var _banner_left := 0.0


func _ready() -> void:
	theme = UiTheme.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_side()
	_build_orbs()
	_build_stash()
	_build_craft()
	_build_save()
	_banner_box = PanelContainer.new()
	_banner_box.add_theme_stylebox_override("panel", UiTheme.theme().get_stylebox("normal", "Banner"))
	_banner_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner_box.offset_top = 84
	_banner_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner_box.modulate.a = 0.0
	add_child(_banner_box)
	_banner = Label.new()
	_banner.theme_type_variation = "Banner"
	_banner.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner_box.add_child(_banner)
	show_tab(IconTable.TAB_PACK)


func _process(delta: float) -> void:
	# The panel hugs its open page: its parent is no container, so shrink it by hand once the
	# page change has settled into the minimum size.
	var wanted := _side.get_combined_minimum_size()
	if not is_equal_approx(_side.size.y, wanted.y):
		_side.size = Vector2(_side.size.x, wanted.y)
	if _banner_left > 0.0:
		_banner_left -= delta
		_banner_box.modulate.a = clampf(_banner_left / 0.6, 0.0, 1.0)
	if _saved_label.modulate.a > 0.0:
		_saved_label.modulate.a = maxf(0.0, _saved_label.modulate.a - delta * 0.5)
	if _flash_upgrade != "":
		_flash_left -= delta
		var id := _flash_upgrade
		if _flash_left <= 0.0:
			_flash_upgrade = ""
		_paint_upgrade_row(id)


## A big line across the top of the screen that fades out: banking, level-ups, crafting.
func banner(text: String) -> void:
	_banner.text = text
	_banner_left = BANNER_SECONDS
	# Size the backing strip to the text so it never hangs past short lines.
	var font: Font = UiTheme.theme().get_font("font", "Banner")
	var size := UiTheme.theme().get_font_size("font_size", "Banner")
	var width := minf(BANNER_MAX_WIDTH, font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, size).x + 44.0)
	_banner_box.offset_left = -width / 2.0
	_banner_box.offset_right = width / 2.0
	_banner_box.modulate.a = 1.0


func flash_saved() -> void:
	_saved_label.modulate.a = 1.0


## Opens the stash or workbench panel (PANEL_STASH, PANEL_CRAFT) or neither (PANEL_NONE).
func open_panel(which: String) -> void:
	_panel = which
	_stash_panel.visible = which == PANEL_STASH
	_craft_panel.visible = which == PANEL_CRAFT
	refresh()


func close_panels() -> void:
	open_panel(PANEL_NONE)


## Brings one of the side panel's tabs to the front. The open tab's button (or its key) a
## second time folds the panel to its tab strip, so the world has the screen back.
func show_tab(tab: String) -> void:
	_folded = tab == _tab and not _folded
	_tab = tab
	for t in _pages:
		(_pages[t] as Control).visible = t == tab and not _folded
		(_tab_buttons[t] as Button).set_pressed_no_signal(t == tab and not _folded)
	refresh()


## Folds the panel to its tab strip.
func fold() -> void:
	if not _folded:
		show_tab(_tab)


func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key: Key = (event as InputEventKey).keycode
	if TAB_KEYS.has(key):
		show_tab(TAB_KEYS[key])
		get_viewport().set_input_as_handled()
	elif key == KEY_ESCAPE and not _folded:
		fold()
		get_viewport().set_input_as_handled()


func show_code(code: String) -> void:
	_save_text.text = code
	_save_note.text = "Copy this code and keep it somewhere safe. Import it on the title screen in any browser."
	_save_panel.visible = true


## Sets the Settings tab's widgets to the stored settings, without echoing them as a change.
func set_settings(audio: AudioSettings, ui: UiSettings) -> void:
	_volume.set_value_no_signal(audio.volume)
	_music.set_value_no_signal(audio.music)
	_mute.set_pressed_no_signal(audio.muted)
	_motion.set_pressed_no_signal(ui.reduced_motion)
	_retaliate.set_pressed_no_signal(ui.auto_retaliate)
	for s in _scale_buttons:
		(_scale_buttons[s] as Button).set_pressed_no_signal(is_equal_approx(float(s), ui.ui_scale))


# --- Redraw from the state ------------------------------------------------------------

func refresh() -> void:
	if sim == null:
		return
	var s := sim.state
	_warmth.set_level(float(s["warmth"]) / Sim.WARMTH_MAX, "%d" % int(s["warmth"]))
	_health.set_level(float(s["health"]) / Sim.HEALTH_MAX, "%d" % int(s["health"]))
	var fire_why := sim.check(SimVocab.LIGHT_FIRE, {})
	_fire_button.disabled = fire_why != ""
	_fire_button.tooltip_text = "Burn %d logs from your pack into a fire where you stand. It warms you and cooks for a minute." % Sim.FIELD_FIRE_LOGS
	if fire_why == SimVocab.REASON_IN_OUTPOST:
		_fire_button.tooltip_text = "The outpost has its own fire."
	elif fire_why == SimVocab.REASON_MISSING_INPUTS:
		_fire_button.tooltip_text = "Needs %d logs in your pack." % Sim.FIELD_FIRE_LOGS
	match _tab:
		IconTable.TAB_PACK:
			_refresh_pack()
		IconTable.TAB_EQUIPMENT:
			_refresh_equipment()
		IconTable.TAB_SKILLS:
			_refresh_skills()
		IconTable.TAB_UPGRADES:
			_refresh_upgrades()
	if _panel == PANEL_STASH:
		_refresh_pack()
		_refresh_stash()
	elif _panel == PANEL_CRAFT:
		_refresh_craft()


func _refresh_pack() -> void:
	var pack: Array = sim.state["inventory"]["pack"]
	for i in _pack_buttons.size():
		_set_slot(_pack_buttons[i], pack[i])
		if pack[i] != null:
			var kind: String = pack[i]["item"]
			var verb := _pack_verb(kind)
			_pack_buttons[i].set_tip(func() -> Control: return UiTooltip.item(kind, verb))
	_weight_label.text = "Carrying %d / %d kg%s" % [
		sim.carry_weight(), Sim.CARRY_LIMIT, "  (slowed)" if sim.is_overweight() else "",
	]
	_weight_label.add_theme_color_override("font_color", UiTheme.BLOOD if sim.is_overweight() else UiTheme.TEXT_DIM)
	_refresh_style()


func _refresh_equipment() -> void:
	var equipment: Dictionary = sim.state["inventory"]["equipment"]
	for slot in _equip_buttons:
		var item: String = equipment[slot]
		var row: Dictionary = _equip_buttons[slot]
		var b: UiTooltip.Host = row["button"]
		_set_badge(b, item, IconTable.SLOT_KEYS[slot] if item == "" else "")
		(row["name"] as Label).text = ItemTable.label(item) if item != "" else "Nothing"
		if item != "":
			b.set_tip(func() -> Control: return UiTooltip.item(item, "Click to unequip into the pack", ""))
		else:
			b.set_tip(Callable())
	_refresh_style()


func _refresh_skills() -> void:
	var total := 0
	for name in READOUT_SKILLS:
		var p := sim.skill_progress(name)
		total += int(p["level"])
		var row: Dictionary = _skill_rows[name]
		(row["level"] as Label).text = "%d" % p["level"]
		(row["bar"] as ProgressBar).max_value = maxi(1, int(p["span"]))
		(row["bar"] as ProgressBar).value = int(p["into"])
	_skill_total.text = "Total level %d" % total


## The current style and its ammunition, shown under the pack and the equipment.
func _refresh_style() -> void:
	var weapon := CombatTable.weapon(sim.player_weapon())
	var style: String = weapon["style"]
	var text := "%s (%s)" % [style.capitalize(), str(weapon["label"]).to_lower()]
	if weapon["ammo"] != "":
		var ammo := Inventory.count_of(sim.state["inventory"]["pack"], weapon["ammo"])
		text += ", %d %s" % [ammo, ItemTable.label(weapon["ammo"]).to_lower()]
	_style_label.text = text
	var key := IconTable.style_key(style)
	if _style_badge.get_meta("key", "") != key:
		for c in _style_badge.get_children():
			c.queue_free()
		_style_badge.add_child(UiTheme.badge(key, 24))
		_style_badge.set_meta("key", key)


func _refresh_stash() -> void:
	var stash: Dictionary = sim.state["stash"]
	var slots: Array = stash["slots"]
	var used := 0
	for s in slots:
		if s != null:
			used += 1
	_stash_title.text = "Stash  %d / %d" % [used, int(stash["capacity"])]
	while _stash_buttons.size() < slots.size():
		var i := _stash_buttons.size()
		var b := _slot_button()
		b.pressed.connect(func() -> void: command_requested.emit(SimVocab.WITHDRAW, {"index": i}))
		_stash_grid.add_child(b)
		_stash_buttons.append(b)
	for i in _stash_buttons.size():
		var b := _stash_buttons[i]
		b.visible = i < slots.size()
		if b.visible:
			_set_slot(b, slots[i])
			if slots[i] != null:
				var kind: String = slots[i]["item"]
				b.set_tip(func() -> Control: return UiTooltip.item(kind, "Click to withdraw", ""))


## Recipe rows are built once and updated in place, so a Craft button is never freed
## between the press and the release of a click.
func _refresh_craft() -> void:
	var pack: Array = sim.state["inventory"]["pack"]
	for id in RecipeTable.ids():
		if not _craft_rows.has(id):
			_add_craft_row(id)
		var r := RecipeTable.get_recipe(id)
		var inputs: PackedStringArray = []
		for kind in r["inputs"]:
			inputs.append("%d %s (%d)" % [r["inputs"][kind], ItemTable.label(kind), Inventory.count_of(pack, kind)])
		var row: Dictionary = _craft_rows[id]
		var out: Dictionary = r["output"]
		var made: String = r["label"] if int(out["count"]) <= 1 else "%d %s" % [out["count"], r["label"]]
		var needs := "Smithing %d" % r["level"]
		if r["upgrade"] != "":
			needs += ", %s" % UpgradeTable.get_upgrade(r["upgrade"])["label"]
		(row["text"] as Label).text = "%s  <-  %s   [%s]" % [made, ", ".join(inputs), needs]
		var why := sim.check(SimVocab.SMITH, {"recipe": id})
		(row["button"] as Button).disabled = why != ""
		(row["button"] as Button).tooltip_text = _why_text(why)
		if why == SimVocab.REASON_TIER_CAPPED:
			(row["text"] as Label).text = "%s  -  needs the blast furnace: smithing stops at bronze until then" % r["label"]


func _add_craft_row(id: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var out: String = RecipeTable.get_recipe(id)["output"]["item"]
	var badge := UiTheme.badge(out, 30)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(badge)
	var text := UiTheme.body("", 13)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(text)
	var craft := Button.new()
	craft.text = "Craft"
	craft.custom_minimum_size = Vector2(76, 0)
	craft.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	craft.pressed.connect(func() -> void: command_requested.emit(SimVocab.SMITH, {"recipe": id}))
	row.add_child(craft)
	row.add_child(_gap(14))  # clear of the scrollbar
	_craft_list.add_child(row)
	_craft_list.add_child(HSeparator.new())
	_craft_rows[id] = {"text": text, "button": craft}


## Upgrade rows are built once with the page and updated in place, like the recipe rows.
## Status comes from the sim's upgrade_status() query; UpgradeRows words it.
func _refresh_upgrades() -> void:
	var statuses := sim.upgrade_status()
	for id in statuses:
		var s: Dictionary = statuses[id]
		var v := UpgradeRows.view(id, s)
		var row: Dictionary = _upgrade_rows[id]
		row["state"] = v["state"]
		(row["text"] as Label).text = "\n".join(v["lines"])
		var why: String = s["reason"]
		var button := row["button"] as Button
		button.disabled = why != ""
		button.text = v["button"]
		button.icon = UiTheme.icon(v["icon"], 14) if v["icon"] != "" else null
		button.tooltip_text = _why_text(why)
		_paint_upgrade_row(id)
	_upgrade_note.text = "Build from what is in the stash, inside the outpost." if sim.in_outpost() else "Upgrades are built inside the outpost."


## The row just built flashes once, then rests in its built state.
func flash_upgrade(id: String) -> void:
	if not _upgrade_rows.has(id):
		return
	var was := _flash_upgrade
	_flash_upgrade = id
	_flash_left = UpgradeRows.FLASH_SECONDS
	if was != "" and was != id:
		_paint_upgrade_row(was)


## Colours a row for its state: a can-build-now row stands out in ember on timber, rows not
## buildable yet are greyed, and the flashing row glows ember over whichever it is.
func _paint_upgrade_row(id: String) -> void:
	var row: Dictionary = _upgrade_rows[id]
	var state: String = row["state"]
	var fill := Color(UiTheme.TIMBER, 0.0)
	var edge := Color(UiTheme.IRON_DARK, 0.0)
	var title_colour := UiTheme.TEXT
	var unmet := state == UpgradeRows.NOT_YET or state == UpgradeRows.LOCKED
	if state == UpgradeRows.CAN_BUILD:
		fill = Color(UiTheme.TIMBER, 0.6)
		edge = UiTheme.EMBER
		title_colour = UiTheme.EMBER
	elif unmet:
		title_colour = UiTheme.TEXT_DISABLED
	if id == _flash_upgrade:
		var glow := UpgradeRows.flash(UpgradeRows.FLASH_SECONDS - _flash_left)
		fill = fill.lerp(Color(UiTheme.EMBER_DEEP, 0.7), glow)
		edge = edge.lerp(UiTheme.EMBER, glow)
	var style := row["style"] as StyleBoxFlat
	style.bg_color = fill
	style.border_color = edge
	(row["title"] as Label).add_theme_color_override("font_color", title_colour)
	(row["text"] as Label).modulate = Color(1, 1, 1, 0.6 if unmet else 1.0)


func _add_upgrade_group(title: String) -> void:
	var heading := UiTheme.heading(title, 12, UiTheme.TEXT_DIM)
	_upgrade_list.add_child(heading)


func _add_upgrade_row(id: String) -> void:
	var style := UiTheme.row_style()
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	frame.add_child(box)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	var title := UiTheme.heading(UpgradeTable.get_upgrade(id)["label"], 13)
	title.clip_text = true
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(title)
	var build := Button.new()
	build.text = "Build"
	build.custom_minimum_size = Vector2(84, 0)
	build.pressed.connect(func() -> void: command_requested.emit(SimVocab.BUILD, {"upgrade": id}))
	head.add_child(build)
	head.add_child(_gap(10))  # clear of the scrollbar
	box.add_child(head)
	var text := UiTheme.muted("", 12)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(text)
	_upgrade_list.add_child(frame)
	_upgrade_rows[id] = {"title": title, "text": text, "button": build, "style": style, "state": UpgradeRows.NOT_YET}


## What a refusal means, for a disabled button's tooltip.
static func _why_text(reason: String) -> String:
	match reason:
		"":
			return ""
		SimVocab.REASON_MISSING_INPUTS:
			return "Not enough materials."
		SimVocab.REASON_LEVEL_TOO_LOW:
			return "Your smithing level is too low."
		SimVocab.REASON_UPGRADE_MISSING:
			return "Build the upgrade it needs first."
		SimVocab.REASON_NOT_AT_WORKBENCH:
			return "Stand at the workbench."
		SimVocab.REASON_NOT_IN_OUTPOST:
			return "Only inside the outpost."
		SimVocab.REASON_TIER_CAPPED:
			return "Smithing stops at bronze until the blast furnace is built."
		SimVocab.REASON_PACK_FULL:
			return "Your pack is full."
	return reason.replace("_", " ").capitalize()


## Fills an inventory cell: the item's badge, and a count in the corner for stacks.
func _set_slot(b: UiTooltip.Host, slot: Variant) -> void:
	var badge: Label = b.get_meta("count")
	if slot == null:
		_set_badge(b, "", "")
		badge.visible = false
		b.set_tip(Callable())
		return
	var count := int(slot["count"])
	_set_badge(b, slot["item"], "")
	badge.text = "%d" % count
	badge.visible = count > 1


## Puts `key`'s badge in a slot button, or `ghost`'s dimmed glyph for an empty slot.
static func _set_badge(b: Control, key: String, ghost: String) -> void:
	var want := key if key != "" else ("ghost:" + ghost if ghost != "" else "")
	if b.get_meta("badge_key", "") == want:
		return
	var holder: Control = b.get_meta("badge_holder")
	for c in holder.get_children():
		c.queue_free()
	if key != "":
		holder.add_child(UiTheme.badge(key, BADGE_PX))
	elif ghost != "":
		var g := UiTheme.badge(ghost, BADGE_PX, Color(UiTheme.IRON_DARK, 0.6))
		g.modulate.a = 0.45
		holder.add_child(g)
	b.set_meta("badge_key", want)


## What a click on a pack item does here, for its tooltip.
func _pack_verb(kind: String) -> String:
	if _panel == PANEL_STASH:
		return "Click to deposit"
	if RecipeTable.is_cookable(kind) and sim.near_fire():
		return "Click to cook the lot at this fire"
	if RecipeTable.is_cookable(kind):
		return "Click to eat raw (heals %d). Stand by a fire to cook it instead" % ItemTable.heal(kind)
	if ItemTable.slot(kind) != "":
		return "Click to equip (lands next tick)"
	if ItemTable.heal(kind) > 0:
		return "Click to eat (heals %d, costs a tick)" % ItemTable.heal(kind)
	return ""


func _on_pack_pressed(index: int) -> void:
	var slot: Variant = sim.state["inventory"]["pack"][index]
	if slot == null:
		return
	if _panel == PANEL_STASH:
		command_requested.emit(SimVocab.DEPOSIT, {"index": index})
	elif RecipeTable.is_cookable(slot["item"]) and sim.near_fire():
		command_requested.emit(SimVocab.COOK, {"index": index})
	elif ItemTable.slot(slot["item"]) != "":
		command_requested.emit(SimVocab.EQUIP, {"index": index})
	elif ItemTable.heal(slot["item"]) > 0:
		command_requested.emit(SimVocab.EAT, {"index": index})


func _on_pack_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if sim.state["inventory"]["pack"][index] != null:
			command_requested.emit(SimVocab.DROP, {"index": index})
		get_viewport().set_input_as_handled()


# --- Building the widgets -------------------------------------------------------------

## The side panel: a strip of icon tabs over the page each one opens.
func _build_side() -> void:
	_side = PanelContainer.new()
	_side.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_side.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_side.grow_vertical = Control.GROW_DIRECTION_END
	_side.offset_left = -(SIDE_WIDTH + MARGIN)
	_side.offset_right = -MARGIN
	_side.offset_top = MARGIN
	add_child(_side)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	_side.add_child(column)
	var strip := HBoxContainer.new()
	strip.add_theme_constant_override("separation", 2)
	strip.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(strip)
	var group := ButtonGroup.new()
	for tab in TABS:
		var b := Button.new()
		b.theme_type_variation = "TabButton"
		b.toggle_mode = true
		b.button_group = group
		b.tooltip_text = "%s  (%s; again to fold the panel)" % [TAB_LABELS[tab], OS.get_keycode_string(TAB_KEYS.find_key(tab))]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_child(_centered(UiTheme.badge(tab, 30)))
		b.custom_minimum_size = Vector2(44, 44)
		b.pressed.connect(show_tab.bind(tab))
		strip.add_child(b)
		_tab_buttons[tab] = b
	column.add_child(HSeparator.new())
	_pages[IconTable.TAB_PACK] = _build_pack_page()
	_pages[IconTable.TAB_EQUIPMENT] = _build_equipment_page()
	_pages[IconTable.TAB_SKILLS] = _build_skills_page()
	_pages[IconTable.TAB_UPGRADES] = _build_upgrades_page()
	_pages[IconTable.TAB_SETTINGS] = _build_settings_page()
	for tab in TABS:
		var page: Control = _pages[tab]
		page.custom_minimum_size = Vector2(SIDE_WIDTH - 32, PAGE_HEIGHT)
		column.add_child(page)


func _build_pack_page() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.add_child(_page_title("Pack", "Click an item to equip or eat it, or by a fire to cook it. Right-click drops it."))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	box.add_child(_centered(grid))
	for i in Sim.PACK_SLOTS:
		var b := _slot_button()
		b.pressed.connect(_on_pack_pressed.bind(i))
		b.gui_input.connect(_on_pack_input.bind(i))
		grid.add_child(b)
		_pack_buttons.append(b)
	_weight_label = UiTheme.muted("", 13)
	_weight_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_weight_label)
	box.add_child(_style_row())
	return box


func _build_equipment_page() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.add_child(_page_title("Equipment", "What you are wearing. Click a piece to take it off into the pack."))
	for slot in ItemTable.EQUIPMENT_SLOTS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var b := _slot_button()
		b.pressed.connect(func() -> void:
			if sim.state["inventory"]["equipment"][slot] != "":
				command_requested.emit(SimVocab.EQUIP, {"unequip": slot}))
		row.add_child(b)
		var text := VBoxContainer.new()
		text.add_theme_constant_override("separation", 2)
		text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.add_child(UiTheme.heading(slot.capitalize(), 13))
		var name := UiTheme.muted("Nothing", 13)
		text.add_child(name)
		row.add_child(text)
		box.add_child(row)
		_equip_buttons[slot] = {"button": b, "name": name}
	box.add_child(HSeparator.new())
	box.add_child(_style_row())
	return box


## The style badge and line shown under the pack and the equipment. The second call
## reparents nothing: each page gets its own pair and both are refreshed together.
func _style_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var badge := Control.new()
	badge.custom_minimum_size = Vector2(24, 24)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(badge)
	var label := UiTheme.body("", 13)
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(label)
	if _style_badge == null:
		_style_badge = badge
		_style_label = label
	else:
		# The equipment page's copy mirrors the pack page's.
		var first_badge := _style_badge
		var first_label := _style_label
		row.set_meta("mirror", true)
		row.visibility_changed.connect(func() -> void:
			if row.is_visible_in_tree():
				label.text = first_label.text
				for c in badge.get_children():
					c.queue_free()
				var key: String = first_badge.get_meta("key", "")
				if key != "":
					badge.add_child(UiTheme.badge(key, 24)))
	return row


func _build_skills_page() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.add_child(_page_title("Skills", "Each levels by use. Hover one for the xp to go and what the next level unlocks."))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	box.add_child(grid)
	for name in READOUT_SKILLS:
		grid.add_child(_skill_cell(name))
	_skill_total = UiTheme.muted("Total level", 13)
	_skill_total.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_skill_total)
	return box


## One cell of the skills grid, in the Old School RuneScape way: the skill's badge and its
## level side by side, the name beneath, and a thin xp bar along the bottom.
func _skill_cell(name: String) -> Control:
	var cell := UiTooltip.Host.new()
	cell.theme_type_variation = "SlotButton"
	cell.custom_minimum_size = Vector2(126, 54)
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.set_tip(func() -> Control: return UiTooltip.skill(name, sim))
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 6
	box.offset_right = -6
	box.offset_top = 5
	box.offset_bottom = -5
	box.add_theme_constant_override("separation", 2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(box)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(top)
	top.add_child(UiTheme.badge(name, 26))
	var label := UiTheme.muted(name.capitalize(), 11)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.clip_text = true
	top.add_child(label)
	var level := UiTheme.heading("1", 16)
	level.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(level)
	var bar := ProgressBar.new()
	bar.theme_type_variation = "XpBar"
	bar.custom_minimum_size = Vector2(0, 5)
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(bar)
	_skill_rows[name] = {"level": level, "bar": bar, "cell": cell}
	return cell


func _build_upgrades_page() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.add_child(_page_title("Outpost upgrades", ""))
	_upgrade_note = UiTheme.muted("", 12)
	_upgrade_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_upgrade_note)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_upgrade_list = VBoxContainer.new()
	_upgrade_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_upgrade_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_upgrade_list)
	for group in UpgradeRows.groups():
		_add_upgrade_group(group["title"])
		for id in group["ids"]:
			_add_upgrade_row(id)
	return box


func _build_settings_page() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.add_child(_page_title("Settings", "Kept in this browser, not in your save code."))
	var scale_row := HBoxContainer.new()
	scale_row.add_theme_constant_override("separation", 6)
	var scale_label := UiTheme.body("Interface size", 13)
	scale_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scale_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	scale_row.add_child(scale_label)
	var group := ButtonGroup.new()
	for s in UiSettings.SCALES:
		var b := Button.new()
		b.theme_type_variation = "ChoiceButton"
		b.toggle_mode = true
		b.button_group = group
		b.text = "%d%%" % roundi(s * 100.0)
		b.pressed.connect(_emit_ui)
		scale_row.add_child(b)
		_scale_buttons[s] = b
	box.add_child(scale_row)
	_motion = CheckBox.new()
	_motion.text = "Reduced motion"
	_motion.tooltip_text = "No screen shake, no frost pulse at the edges of the screen, and lighter snowfall."
	_motion.toggled.connect(func(_on: bool) -> void: _emit_ui())
	box.add_child(_motion)
	_retaliate = CheckBox.new()
	_retaliate.text = "Auto-retaliate"
	_retaliate.tooltip_text = "Fight back with the weapon in hand when hit while standing still. A move click always wins, and it never switches style for you."
	_retaliate.button_pressed = true
	_retaliate.toggled.connect(func(_on: bool) -> void: _emit_ui())
	box.add_child(_retaliate)
	box.add_child(HSeparator.new())
	_volume = _slider(box, "Volume")
	_music = _slider(box, "Music")
	_mute = CheckBox.new()
	_mute.text = "Mute"
	_mute.toggled.connect(func(_on: bool) -> void: _emit_sound())
	box.add_child(_mute)
	box.add_child(HSeparator.new())
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	var help := Button.new()
	help.text = "Controls"
	help.icon = IconTable.texture(IconTable.UI_HELP)
	help.add_theme_constant_override("icon_max_width", 16)
	help.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	help.pressed.connect(func() -> void: help_requested.emit())
	buttons.add_child(help)
	var code := Button.new()
	code.text = "Save code"
	code.icon = IconTable.texture(IconTable.UI_SAVE)
	code.add_theme_constant_override("icon_max_width", 16)
	code.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	code.pressed.connect(func() -> void: export_requested.emit())
	buttons.add_child(code)
	box.add_child(buttons)
	box.add_child(HSeparator.new())
	box.add_child(UiTheme.heading("Credits", 12))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var lines: Array[String] = []
	lines.append_array(IconTable.credits())
	lines.append_array(AudioCues.CREDITS)
	var credits := UiTheme.muted("\n\n".join(lines), 11)
	credits.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	credits.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	credits.custom_minimum_size = Vector2(SIDE_WIDTH - 48, 0)
	scroll.add_child(credits)
	return box


func _slider(box: VBoxContainer, text: String) -> HSlider:
	var row := HBoxContainer.new()
	box.add_child(row)
	var label := UiTheme.body(text, 13)
	label.custom_minimum_size = Vector2(70, 0)
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.value_changed.connect(func(_v: float) -> void: _emit_sound())
	row.add_child(slider)
	return slider


func _emit_sound() -> void:
	sound_changed.emit(_volume.value, _music.value, _mute.button_pressed)


func _emit_ui() -> void:
	var settings := UiSettings.new()
	for s in _scale_buttons:
		if (_scale_buttons[s] as Button).button_pressed:
			settings.ui_scale = float(s)
	settings.reduced_motion = _motion.button_pressed
	settings.auto_retaliate = _retaliate.button_pressed
	ui_changed.emit(settings)


## The warmth and health orbs and the Light fire button, in a column beside the panel.
func _build_orbs() -> void:
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	column.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	column.offset_right = -(SIDE_WIDTH + MARGIN + 10)
	column.offset_top = MARGIN
	column.add_theme_constant_override("separation", 8)
	column.alignment = BoxContainer.ALIGNMENT_BEGIN
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)
	_warmth = Orb.new(UiTheme.EMBER, UiTheme.EMBER_DEEP, "Warmth")
	_warmth.tooltip_text = "Warmth. It drains outside the outpost; only a fire restores it, and at zero your health drains instead."
	column.add_child(_warmth)
	_health = Orb.new(UiTheme.BLOOD, UiTheme.BLOOD_DEEP, "Health")
	_health.tooltip_text = "Health. Food heals it. At zero you wake by the outpost fire with your three most valuable things."
	column.add_child(_health)
	_fire_button = Button.new()
	_fire_button.text = "Light fire"
	_fire_button.theme_type_variation = "FireButton"
	_fire_button.icon = IconTable.texture(IconTable.UI_FIRE)
	_fire_button.add_theme_constant_override("icon_max_width", 16)
	_fire_button.add_theme_color_override("icon_normal_color", UiTheme.EMBER)
	_fire_button.add_theme_color_override("icon_hover_color", Color(1.0, 0.8, 0.45))
	_fire_button.add_theme_color_override("icon_disabled_color", Color(0.70, 0.55, 0.40))
	_fire_button.pressed.connect(func() -> void: command_requested.emit(SimVocab.LIGHT_FIRE, {}))
	column.add_child(_fire_button)


func _build_stash() -> void:
	_stash_panel = PanelContainer.new()
	_stash_panel.position = PANEL_POSITION
	_stash_panel.visible = false
	add_child(_stash_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_stash_panel.add_child(box)
	var head := _header("Stash", close_panels)
	_stash_title = head.get_meta("title")
	box.add_child(head)
	box.add_child(UiTheme.muted("Click a stash slot to withdraw it, or a pack slot to deposit.", 13))
	_stash_grid = GridContainer.new()
	_stash_grid.columns = 4
	_stash_grid.add_theme_constant_override("h_separation", 6)
	_stash_grid.add_theme_constant_override("v_separation", 6)
	box.add_child(_stash_grid)


func _build_craft() -> void:
	_craft_panel = PanelContainer.new()
	_craft_panel.position = PANEL_POSITION
	_craft_panel.custom_minimum_size = Vector2(580, 0)
	_craft_panel.visible = false
	add_child(_craft_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_craft_panel.add_child(box)
	box.add_child(_header("Workbench", close_panels))
	box.add_child(UiTheme.muted("Smithing: crafts from what is in your pack.", 13))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(548, 380)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_craft_list = VBoxContainer.new()
	_craft_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_craft_list)


func _build_save() -> void:
	_saved_label = Label.new()
	_saved_label.text = "Saved"
	_saved_label.theme_type_variation = "Flash"
	_saved_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_saved_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_saved_label.offset_right = -(SIDE_WIDTH + MARGIN + 10)
	_saved_label.offset_top = MARGIN + ORB_PX * 2 + 16 + 44
	_saved_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_saved_label.modulate.a = 0.0
	add_child(_saved_label)

	_save_panel = PanelContainer.new()
	_save_panel.set_anchors_preset(Control.PRESET_CENTER)
	_save_panel.custom_minimum_size = Vector2(660, 0)
	_save_panel.offset_left = -330
	_save_panel.offset_top = -150
	_save_panel.visible = false
	add_child(_save_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_save_panel.add_child(box)
	box.add_child(_header("Your save code", func() -> void: _save_panel.visible = false))
	_save_note = UiTheme.body("", 13)
	_save_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_save_note)
	_save_text = TextEdit.new()
	_save_text.editable = false
	_save_text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_save_text.custom_minimum_size = Vector2(620, 140)
	box.add_child(_save_text)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	box.add_child(buttons)
	var copy := Button.new()
	copy.text = "Copy to clipboard"
	copy.icon = UiTheme.icon("export", 14)
	copy.pressed.connect(func() -> void:
		Clipboard.copy(_save_text.text, func(ok: bool) -> void:
			_save_note.text = "Copied." if ok else "Your browser would not copy it. Select all, then copy it by hand (Ctrl+C or Cmd+C)."))
	buttons.add_child(copy)
	var select := Button.new()
	select.text = "Select all"
	select.pressed.connect(func() -> void:
		_save_text.grab_focus()
		_save_text.select_all())
	buttons.add_child(select)
	buttons.add_child(_gap(0, true))
	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(func() -> void: _save_panel.visible = false)
	buttons.add_child(close)


## A page's heading and, when given, one quiet line of guidance under it.
static func _page_title(title: String, note: String) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	var h := UiTheme.heading(title, 15)
	box.add_child(h)
	if note != "":
		var n := UiTheme.muted(note, 12)
		n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(n)
	return box


## A panel's title strip (UiTheme.header): the title Label is in the "title" metadata.
static func _header(title: String, on_close: Callable = Callable()) -> PanelContainer:
	return UiTheme.header(title, on_close)


static func _gap(width: float, expand: bool = false) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(width, 0)
	if expand:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func _centered(inner: Control) -> Control:
	var c := CenterContainer.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(inner)
	return c


## An inventory cell: a dark inset button holding a badge, with a count in its corner.
static func _slot_button() -> UiTooltip.Host:
	var b := UiTooltip.Host.new()
	b.theme_type_variation = "SlotButton"
	b.custom_minimum_size = Vector2(SLOT_PX, SLOT_PX)
	var holder := CenterContainer.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(holder)
	b.set_meta("badge_holder", holder)
	b.set_meta("badge_key", "")
	var count := Label.new()
	count.theme_type_variation = "CountBadge"
	count.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	count.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	count.grow_vertical = Control.GROW_DIRECTION_BEGIN
	count.offset_right = -3
	count.offset_bottom = -3
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	count.visible = false
	b.add_child(count)
	b.set_meta("count", count)
	return b


## A gauge orb: an iron rim around a dark well that fills from the bottom with the vital's
## colour, the number printed over it. Drawn in code; the fill is a chord of the circle.
class Orb:
	extends Control

	var _fraction := 1.0
	var _colour: Color
	var _deep: Color
	var _value: Label

	func _init(colour: Color, deep: Color, name_text: String) -> void:
		_colour = colour
		_deep = deep
		custom_minimum_size = Vector2(ORB_PX, ORB_PX)
		mouse_filter = Control.MOUSE_FILTER_STOP
		_value = Label.new()
		_value.theme_type_variation = "OnBar"
		_value.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_value.add_theme_font_size_override("font_size", 17)
		_value.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_value)
		name = name_text

	func set_level(fraction: float, text: String) -> void:
		var f := clampf(fraction, 0.0, 1.0)
		if not is_equal_approx(f, _fraction):
			_fraction = f
			queue_redraw()
		_value.text = text

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5 - 2.0
		draw_circle(c, r + 2.0, Color(UiTheme.INK, 0.55))  # a soft shadow behind the rim
		draw_circle(c, r, UiTheme.SLATE_DEEP)
		# The liquid: every point of the circle below the level line.
		var inner := r - 3.0
		var cut := inner - 2.0 * inner * _fraction  # y of the surface, down from the centre
		if _fraction > 0.001:
			var points := PackedVector2Array()
			var a0 := asin(clampf(cut / inner, -1.0, 1.0))
			var steps := 40
			for i in steps + 1:
				var a := lerpf(a0, PI - a0, float(i) / steps)
				points.append(c + Vector2(cos(a), sin(a)) * inner)
			if points.size() >= 3:
				draw_colored_polygon(points, _deep.lerp(_colour, 0.65))
				# Lighter toward the surface, so the liquid has depth.
				var top := c.y + cut
				var glow := PackedVector2Array()
				var a1 := asin(clampf((cut + inner * 0.35) / inner, -1.0, 1.0))
				for i in steps + 1:
					var a := lerpf(a0, PI - a0, float(i) / steps)
					var p := c + Vector2(cos(a), sin(a)) * inner
					if p.y <= c.y + cut + inner * 0.35:
						glow.append(p)
				if glow.size() >= 3 and a1 > a0:
					draw_colored_polygon(glow, Color(_colour, 0.45))
				var half := sqrt(maxf(inner * inner - cut * cut, 0.0))
				draw_line(Vector2(c.x - half, top), Vector2(c.x + half, top), _colour.lightened(0.4), 1.5, true)
		# A glassy highlight on the upper left, then the iron rim.
		draw_arc(c + Vector2(-r * 0.18, -r * 0.18), r * 0.62, PI * 1.05, PI * 1.55, 18, Color(1, 1, 1, 0.16), 3.0, true)
		draw_arc(c, r, 0.0, TAU, 64, UiTheme.IRON_DARK, 4.0, true)
		draw_arc(c, r, 0.0, TAU, 64, UiTheme.IRON, 1.5, true)
		draw_arc(c, r - 3.0, 0.0, TAU, 64, Color(UiTheme.ICE, 0.18), 1.0, true)
