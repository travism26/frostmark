## The in-game HUD: warmth and health gauges, the eight-skill panel behind its Skills
## button, the pack and equipment, the stash, workbench and upgrades panels, the field-fire
## button, the save-code panel, the buttons that open the help and sound panels and the
## banner for big moments.
##
## Glue only. It reads `sim.state` to draw and turns button presses into commands through
## `command_requested`; whether a command is allowed is always the simulation's answer.
## Every widget takes its look from UiTheme; nothing here sets a colour of its own.
extends Control

signal command_requested(kind: String, args: Dictionary)
signal export_requested
signal help_requested
signal sound_requested

## The skills panel lists all eight, gathering, crafting, combat.
const READOUT_SKILLS: Array[String] = SkillTable.NAMES

const PANEL_NONE := ""
const PANEL_STASH := "stash"
const PANEL_CRAFT := "craft"
const PANEL_UPGRADES := "upgrades"
## Side panels open to the right of the vitals and skills.
const PANEL_POSITION := Vector2(350, 60)
const BANNER_SECONDS := 3.0
const BANNER_MAX_WIDTH := 580.0
const SLOT_SIZE := Vector2(68, 52)
const SKILL_COLUMNS := 4

## How each skill is drawn in its cell: a Kenney icon where one fits, a coloured letter
## badge for the rest.
const SKILL_ICONS := {
	SkillTable.WOODCUTTING: {"letter": "W", "colour": Color(0.45, 0.72, 0.42)},
	SkillTable.MINING: {"letter": "M", "colour": Color(0.80, 0.58, 0.40)},
	SkillTable.FISHING: {"letter": "F", "colour": Color(0.50, 0.76, 0.95)},
	SkillTable.COOKING: {"icon": "flame", "colour": UiTheme.EMBER},
	SkillTable.SMITHING: {"icon": "wrench", "colour": Color(0.85, 0.88, 0.92)},
	SkillTable.MELEE: {"icon": "cross", "colour": Color(0.95, 0.42, 0.42)},
	SkillTable.RANGED: {"icon": "target", "colour": Color(0.95, 0.80, 0.45)},
}

var sim: Sim
var _panel := PANEL_NONE
var _warmth_bar: ProgressBar
var _warmth_value: Label
var _health_bar: ProgressBar
var _health_value: Label
var _skills_panel: PanelContainer
var _skills_button: Button
var _skill_rows := {}  # skill name -> {label, bar, cell}
var _skill_total: Label
var _pack_buttons: Array[Button] = []
var _equip_buttons := {}  # slot -> Button
var _weight_label: Label
var _style_label: Label
var _stash_panel: PanelContainer
var _stash_title: Label
var _stash_grid: GridContainer
var _stash_buttons: Array[Button] = []
var _craft_panel: PanelContainer
var _craft_list: VBoxContainer
var _craft_rows := {}  # recipe id -> {text, button}
var _upgrade_panel: PanelContainer
var _upgrade_list: VBoxContainer
var _upgrade_rows := {}  # upgrade id -> {text, button}
var _upgrade_note: Label
var _fire_button: Button
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
	_build_vitals()
	_build_pack()
	_build_stash()
	_build_craft()
	_build_upgrades()
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


func _process(delta: float) -> void:
	if _banner_left > 0.0:
		_banner_left -= delta
		_banner_box.modulate.a = clampf(_banner_left / 0.6, 0.0, 1.0)
	if _saved_label.modulate.a > 0.0:
		_saved_label.modulate.a = maxf(0.0, _saved_label.modulate.a - delta * 0.5)


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


func open_panel(which: String) -> void:
	_panel = which
	_stash_panel.visible = which == PANEL_STASH
	_craft_panel.visible = which == PANEL_CRAFT
	_upgrade_panel.visible = which == PANEL_UPGRADES
	refresh()


func close_panels() -> void:
	open_panel(PANEL_NONE)


func show_code(code: String) -> void:
	_save_text.text = code
	_save_note.text = "Copy this code and keep it somewhere safe. Import it on the title screen in any browser."
	_save_panel.visible = true


## The skills panel is its own toggle under the vitals, so walking (which closes the side
## panels) leaves it where it is.
func toggle_skills() -> void:
	_skills_panel.visible = not _skills_panel.visible
	refresh()


# --- Redraw from the state ------------------------------------------------------------

func refresh() -> void:
	if sim == null:
		return
	var s := sim.state
	_warmth_bar.max_value = Sim.WARMTH_MAX
	_warmth_bar.value = int(s["warmth"])
	_warmth_value.text = "%d / %d" % [int(s["warmth"]), Sim.WARMTH_MAX]
	_health_bar.max_value = Sim.HEALTH_MAX
	_health_bar.value = int(s["health"])
	_health_value.text = "%d / %d" % [int(s["health"]), Sim.HEALTH_MAX]
	var total := 0
	for name in READOUT_SKILLS:
		var p := sim.skill_progress(name)
		total += int(p["level"])
		var row: Dictionary = _skill_rows[name]
		(row["label"] as Label).text = "%d" % p["level"]
		(row["bar"] as ProgressBar).max_value = maxi(1, int(p["span"]))
		(row["bar"] as ProgressBar).value = int(p["into"])
		var tip := "%s %d\n%d / %d xp to level %d" % [name.capitalize(), p["level"], p["into"], p["span"], int(p["level"]) + 1]
		(row["bar"] as ProgressBar).tooltip_text = tip
		(row["cell"] as Control).tooltip_text = tip
	_skill_total.text = "Total level %d" % total
	_skills_button.text = "Skills  %d" % total
	var fire_why := sim.check(SimVocab.LIGHT_FIRE, {})
	_fire_button.disabled = fire_why != ""
	_fire_button.tooltip_text = "Burn %d logs from your pack into a fire where you stand. It warms you and cooks for a minute." % Sim.FIELD_FIRE_LOGS
	if fire_why == SimVocab.REASON_IN_OUTPOST:
		_fire_button.tooltip_text = "The outpost has its own fire."
	elif fire_why == SimVocab.REASON_MISSING_INPUTS:
		_fire_button.tooltip_text = "Needs %d logs in your pack." % Sim.FIELD_FIRE_LOGS

	var pack: Array = s["inventory"]["pack"]
	for i in _pack_buttons.size():
		_set_slot(_pack_buttons[i], pack[i])
		_pack_buttons[i].tooltip_text = _pack_tooltip(pack[i])
	var equipment: Dictionary = s["inventory"]["equipment"]
	for slot in _equip_buttons:
		var item: String = equipment[slot]
		var b: Button = _equip_buttons[slot]
		b.text = "%s\n%s" % [slot.capitalize(), ItemTable.label(item) if item != "" else "-"]
		b.tooltip_text = "Click to unequip into the pack" if item != "" else ""
	_weight_label.text = "Carrying %d / %d kg%s" % [
		sim.carry_weight(), Sim.CARRY_LIMIT, "  (slowed)" if sim.is_overweight() else "",
	]
	_weight_label.add_theme_color_override("font_color", UiTheme.BLOOD if sim.is_overweight() else UiTheme.TEXT_DIM)
	_style_label.text = _style_text()

	if _panel == PANEL_STASH:
		_refresh_stash()
	elif _panel == PANEL_CRAFT:
		_refresh_craft()
	elif _panel == PANEL_UPGRADES:
		_refresh_upgrades()


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
			b.tooltip_text = "Click to withdraw" if slots[i] != null else ""


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


## Upgrade rows are built once and updated in place, like the recipe rows.
func _refresh_upgrades() -> void:
	var stash: Array = sim.state["stash"]["slots"]
	var built: Array = sim.state["upgrades"]
	for id in UpgradeTable.ids():
		if not _upgrade_rows.has(id):
			_add_upgrade_row(id)
		var u := UpgradeTable.get_upgrade(id)
		var costs: PackedStringArray = []
		for kind in u["cost"]:
			costs.append("%d %s (%d)" % [u["cost"][kind], ItemTable.label(kind), Inventory.count_of(stash, kind)])
		var lines: PackedStringArray = ["%s: %s" % [u["label"], _effect_text(u["effects"])]]
		if built.has(id):
			lines.append("Built.")
		elif u["locked"] != "":
			lines.append("Locked. %s" % u["locked"])
		else:
			lines.append("Costs %s from the stash." % ", ".join(costs))
			var missing: PackedStringArray = []
			for need in u["requires"]:
				if not built.has(need):
					missing.append(UpgradeTable.get_upgrade(need)["label"])
			if not missing.is_empty():
				lines.append("Needs the %s first." % " and the ".join(missing))
		var row: Dictionary = _upgrade_rows[id]
		(row["text"] as Label).text = "\n".join(lines)
		var why := sim.check(SimVocab.BUILD, {"upgrade": id})
		var button := row["button"] as Button
		button.disabled = why != ""
		button.text = "Built" if built.has(id) else "Locked" if u["locked"] != "" else "Build"
		button.icon = UiTheme.icon("checkmark", 14) if built.has(id) else UiTheme.icon("locked", 14) if u["locked"] != "" else null
		button.tooltip_text = _why_text(why)
	_upgrade_note.text = "Build from what is in the stash, inside the outpost." if sim.in_outpost() else "Upgrades are built inside the outpost."


func _add_upgrade_row(id: String) -> void:
	var row := HBoxContainer.new()
	var text := UiTheme.body("", 13)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(text)
	var build := Button.new()
	build.text = "Build"
	build.custom_minimum_size = Vector2(92, 0)
	build.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	build.pressed.connect(func() -> void: command_requested.emit(SimVocab.BUILD, {"upgrade": id}))
	row.add_child(build)
	row.add_child(_gap(14))  # clear of the scrollbar
	_upgrade_list.add_child(row)
	_upgrade_list.add_child(HSeparator.new())
	_upgrade_rows[id] = {"text": text, "button": build}


static func _effect_text(effects: Dictionary) -> String:
	var parts: PackedStringArray = []
	if effects.has("stash"):
		parts.append("+%d stash slots" % effects["stash"])
	if effects.has("recipes"):
		var names: PackedStringArray = []
		for r in effects["recipes"]:
			names.append(str(RecipeTable.get_recipe(r)["label"]).to_lower())
		parts.append("unlocks %s" % ", ".join(names))
	if effects.has("smithing_tier"):
		parts.append("smithing works up to %s" % effects["smithing_tier"])
	if effects.has("ring_gate"):
		parts.append("works the gate to ring two once its captain falls")
	if effects.has("waystones"):
		parts.append("wakes the waystones in ring one and ring two: visit one, then travel home from it")
	return "; ".join(parts)


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


## "Melee (wooden club)", or for a ranged weapon "Ranged (wooden bow), 12 arrows".
func _style_text() -> String:
	var weapon := CombatTable.weapon(sim.player_weapon())
	var text := "Style: %s (%s)" % [str(weapon["style"]).capitalize(), str(weapon["label"]).to_lower()]
	if weapon["ammo"] != "":
		var ammo := Inventory.count_of(sim.state["inventory"]["pack"], weapon["ammo"])
		text += ", %d %s" % [ammo, ItemTable.label(weapon["ammo"]).to_lower()]
	return text


## Fills an inventory cell: the item's name, and a count badge in the corner for stacks.
static func _set_slot(b: Button, slot: Variant) -> void:
	var badge: Label = b.get_meta("badge")
	if slot == null:
		b.text = ""
		badge.visible = false
		return
	var count := int(slot["count"])
	b.text = ItemTable.label(slot["item"])
	badge.text = "%d" % count
	badge.visible = count > 1


func _pack_tooltip(slot: Variant) -> String:
	if slot == null:
		return ""
	var kind: String = slot["item"]
	var verb := ""
	if _panel == PANEL_STASH:
		verb = "Click to deposit"
	elif RecipeTable.is_cookable(kind) and sim.near_fire():
		verb = "Click to cook the lot at this fire"
	elif RecipeTable.is_cookable(kind):
		verb = "Click to eat raw (heals %d). Stand by a fire to cook it instead" % ItemTable.heal(kind)
	elif ItemTable.slot(kind) != "":
		verb = "Click to equip (lands next tick)"
	elif ItemTable.heal(kind) > 0:
		verb = "Click to eat (heals %d, costs a tick)" % ItemTable.heal(kind)
	return "%s. %d kg, worth %d each. %sRight-click to drop." % [
		ItemTable.label(kind), ItemTable.weight(kind), ItemTable.value(kind),
		verb + ". " if verb != "" else "",
	]


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

## The vitals panel top-left, with the skills panel docked beneath it when open.
func _build_vitals() -> void:
	var column := VBoxContainer.new()
	column.position = Vector2(24, 60)
	column.custom_minimum_size = Vector2(300, 0)
	column.add_theme_constant_override("separation", 8)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)

	var vitals := PanelContainer.new()
	column.add_child(vitals)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 7)
	vitals.add_child(box)
	var warmth := _gauge("Warmth", "WarmthBar")
	_warmth_bar = warmth["bar"]
	_warmth_value = warmth["value"]
	box.add_child(_warmth_bar)
	var health := _gauge("Health", "HealthBar")
	_health_bar = health["bar"]
	_health_value = health["value"]
	box.add_child(_health_bar)
	_skills_button = Button.new()
	_skills_button.text = "Skills"
	_skills_button.icon = UiTheme.icon("star", 15)
	_skills_button.tooltip_text = "Your eight skills, the level each has reached and the xp to the next."
	_skills_button.pressed.connect(toggle_skills)
	box.add_child(_skills_button)

	_skills_panel = PanelContainer.new()
	_skills_panel.visible = false
	column.add_child(_skills_panel)
	var skills := VBoxContainer.new()
	skills.add_theme_constant_override("separation", 8)
	_skills_panel.add_child(skills)
	skills.add_child(_header("Skills", toggle_skills))
	var grid := GridContainer.new()
	grid.columns = SKILL_COLUMNS
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	skills.add_child(grid)
	for name in READOUT_SKILLS:
		grid.add_child(_skill_cell(name))
	_skill_total = UiTheme.muted("Total level", 13)
	_skill_total.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skills.add_child(_skill_total)


## One cell of the skills grid, in the Old School RuneScape way: the skill's icon and its
## level side by side, the name beneath, and a thin xp bar along the bottom.
func _skill_cell(name: String) -> Control:
	var cell := PanelContainer.new()
	cell.theme_type_variation = "Inset"
	cell.add_theme_stylebox_override("panel", _cell_style())
	cell.custom_minimum_size = Vector2(70, 58)
	cell.mouse_filter = Control.MOUSE_FILTER_STOP
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(box)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 4)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(top)
	var look: Dictionary = SKILL_ICONS[name]
	if look.has("icon"):
		var pic := TextureRect.new()
		pic.texture = UiTheme.icon(look["icon"], 20)
		pic.modulate = look["colour"]
		pic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		pic.custom_minimum_size = Vector2(22, 22)
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		top.add_child(pic)
	else:
		top.add_child(UiTheme.letter_badge(look["letter"], look["colour"], 22))
	var level := UiTheme.heading("1", 17)
	level.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	level.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top.add_child(level)
	var label := UiTheme.muted(name.capitalize(), 10)
	label.clip_text = true
	box.add_child(label)
	var bar := ProgressBar.new()
	bar.theme_type_variation = "XpBar"
	bar.custom_minimum_size = Vector2(0, 5)
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(bar)
	_skill_rows[name] = {"label": level, "bar": bar, "cell": cell}
	return cell


static func _cell_style() -> StyleBoxFlat:
	var s: StyleBoxFlat = UiTheme.theme().get_stylebox("panel", "Inset").duplicate()
	s.content_margin_left = 4
	s.content_margin_right = 4
	s.content_margin_top = 5
	s.content_margin_bottom = 5
	return s


## A gauge with its name on the left and its number on the right, printed over the bar.
static func _gauge(name: String, variation: String) -> Dictionary:
	var bar := ProgressBar.new()
	bar.theme_type_variation = variation
	bar.custom_minimum_size = Vector2(258, 22)
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var overlay := HBoxContainer.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.offset_left = 9
	overlay.offset_right = -9
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(overlay)
	var title := Label.new()
	title.text = name
	title.theme_type_variation = "OnBar"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(title)
	var value := Label.new()
	value.theme_type_variation = "OnBar"
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(value)
	return {"bar": bar, "value": value}


func _build_pack() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.offset_right = -16
	panel.offset_bottom = -16
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	box.add_child(_header("Pack"))
	var grid := GridContainer.new()
	grid.columns = 4
	box.add_child(grid)
	for i in Sim.PACK_SLOTS:
		var b := _slot_button()
		b.pressed.connect(_on_pack_pressed.bind(i))
		b.gui_input.connect(_on_pack_input.bind(i))
		grid.add_child(b)
		_pack_buttons.append(b)
	_weight_label = UiTheme.muted("", 13)
	box.add_child(_weight_label)
	_style_label = UiTheme.body("", 13)
	box.add_child(_style_label)
	var worn := HBoxContainer.new()
	worn.add_theme_constant_override("separation", 5)
	box.add_child(worn)
	for slot in ItemTable.EQUIPMENT_SLOTS:
		var b := _slot_button()
		b.custom_minimum_size = Vector2(92, 44)
		b.pressed.connect(func() -> void:
			if sim.state["inventory"]["equipment"][slot] != "":
				command_requested.emit(SimVocab.EQUIP, {"unequip": slot}))
		worn.add_child(b)
		_equip_buttons[slot] = b


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


func _build_upgrades() -> void:
	_upgrade_panel = PanelContainer.new()
	_upgrade_panel.position = PANEL_POSITION
	_upgrade_panel.custom_minimum_size = Vector2(580, 0)
	_upgrade_panel.visible = false
	add_child(_upgrade_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_upgrade_panel.add_child(box)
	box.add_child(_header("Outpost upgrades", close_panels))
	_upgrade_note = UiTheme.muted("", 13)
	box.add_child(_upgrade_note)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(548, 400)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_upgrade_list = VBoxContainer.new()
	_upgrade_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_upgrade_list)


func _build_save() -> void:
	var buttons_row := HBoxContainer.new()
	buttons_row.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	buttons_row.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	buttons_row.offset_right = -16
	buttons_row.offset_top = 16
	buttons_row.add_theme_constant_override("separation", 8)
	add_child(buttons_row)
	_fire_button = Button.new()
	_fire_button.text = "Light fire"
	_fire_button.theme_type_variation = "FireButton"
	_fire_button.icon = UiTheme.icon("flame", 16)
	_fire_button.pressed.connect(func() -> void: command_requested.emit(SimVocab.LIGHT_FIRE, {}))
	buttons_row.add_child(_fire_button)
	var upgrades := Button.new()
	upgrades.text = "Upgrades"
	upgrades.icon = UiTheme.icon("home", 16)
	upgrades.pressed.connect(func() -> void: open_panel(PANEL_NONE if _panel == PANEL_UPGRADES else PANEL_UPGRADES))
	buttons_row.add_child(upgrades)
	var open := Button.new()
	open.text = "Save code"
	open.icon = UiTheme.icon("save", 16)
	open.pressed.connect(func() -> void: export_requested.emit())
	buttons_row.add_child(open)
	var help := Button.new()
	help.text = "Help"
	help.icon = UiTheme.icon("question", 16)
	help.pressed.connect(func() -> void: help_requested.emit())
	buttons_row.add_child(help)
	var sound := Button.new()
	sound.text = "Sound"
	sound.icon = UiTheme.icon("gear", 16)
	sound.pressed.connect(func() -> void: sound_requested.emit())
	buttons_row.add_child(sound)
	_saved_label = Label.new()
	_saved_label.text = "Saved"
	_saved_label.theme_type_variation = "Flash"
	_saved_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_saved_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_saved_label.offset_right = -16
	_saved_label.offset_top = 60
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


## A panel's title strip: the heading on the left and, when `on_close` is given, a close
## cross on the right. The title Label is kept in the "title" metadata for retitling.
static func _header(title: String, on_close: Callable = Callable()) -> PanelContainer:
	var bar := PanelContainer.new()
	bar.theme_type_variation = "HeaderBar"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	bar.add_child(row)
	var label := UiTheme.heading(title, 15)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(label)
	bar.set_meta("title", label)
	if on_close.is_valid():
		var b := Button.new()
		b.theme_type_variation = "CloseButton"
		b.icon = UiTheme.icon("cross", 11)
		b.tooltip_text = "Close"
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.pressed.connect(on_close)
		row.add_child(b)
	return bar


static func _gap(width: float, expand: bool = false) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(width, 0)
	if expand:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## An inventory cell: a dark inset button with a count badge in its corner.
static func _slot_button() -> Button:
	var b := Button.new()
	b.theme_type_variation = "SlotButton"
	b.custom_minimum_size = SLOT_SIZE
	b.clip_text = true
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var badge := Label.new()
	badge.theme_type_variation = "CountBadge"
	badge.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	badge.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	badge.grow_vertical = Control.GROW_DIRECTION_BEGIN
	badge.offset_right = -3
	badge.offset_bottom = -3
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.visible = false
	b.add_child(badge)
	b.set_meta("badge", badge)
	return b
