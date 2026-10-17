## The in-game HUD: warmth and health gauges, the seven-skill panel, the pack and equipment,
## the stash, workbench and upgrades panels, the field-fire button, the save-code panel and
## the banner for big moments.
##
## Glue only. It reads `sim.state` to draw and turns button presses into commands through
## `command_requested`; whether a command is allowed is always the simulation's answer.
extends Control

signal command_requested(kind: String, args: Dictionary)
signal export_requested
signal help_requested

## The skills panel lists all seven, gathering, crafting, combat.
const READOUT_SKILLS: Array[String] = SkillTable.NAMES

const PANEL_NONE := ""
const PANEL_STASH := "stash"
const PANEL_CRAFT := "craft"
const PANEL_UPGRADES := "upgrades"
## Side panels open to the right of the gauges and skills.
const PANEL_POSITION := Vector2(330, 60)

const COLOR_TEXT := Color(0.1, 0.14, 0.2)
const COLOR_WARMTH := Color(1.0, 0.62, 0.2)
const COLOR_HEALTH := Color(0.85, 0.22, 0.25)
const COLOR_XP := Color(0.35, 0.7, 0.4)
const BANNER_SECONDS := 3.0

var sim: Sim
var _panel := PANEL_NONE
var _warmth_bar: ProgressBar
var _health_bar: ProgressBar
var _skill_rows := {}  # skill name -> {label, bar}
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
var _banner_left := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_vitals()
	_build_pack()
	_build_stash()
	_build_craft()
	_build_upgrades()
	_build_save()
	_banner = Label.new()
	_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner.offset_left = -400
	_banner.offset_right = 400
	_banner.offset_top = 90
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_banner.add_theme_font_size_override("font_size", 30)
	_banner.add_theme_color_override("font_color", Color(1, 1, 1))
	_banner.add_theme_color_override("font_outline_color", Color(0.1, 0.14, 0.2))
	_banner.add_theme_constant_override("outline_size", 10)
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_banner)


func _process(delta: float) -> void:
	if _banner_left > 0.0:
		_banner_left -= delta
		_banner.modulate.a = clampf(_banner_left / 0.6, 0.0, 1.0)
	if _saved_label.modulate.a > 0.0:
		_saved_label.modulate.a = maxf(0.0, _saved_label.modulate.a - delta * 0.5)


## A big line across the top of the screen that fades out: banking, level-ups, crafting.
func banner(text: String) -> void:
	_banner.text = text
	_banner_left = BANNER_SECONDS
	_banner.modulate.a = 1.0


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


# --- Redraw from the state ------------------------------------------------------------

func refresh() -> void:
	if sim == null:
		return
	var s := sim.state
	_warmth_bar.max_value = Sim.WARMTH_MAX
	_warmth_bar.value = int(s["warmth"])
	_health_bar.max_value = Sim.HEALTH_MAX
	_health_bar.value = int(s["health"])
	for name in READOUT_SKILLS:
		var p := sim.skill_progress(name)
		var row: Dictionary = _skill_rows[name]
		(row["label"] as Label).text = "%s %d" % [name.capitalize(), p["level"]]
		(row["bar"] as ProgressBar).max_value = maxi(1, int(p["span"]))
		(row["bar"] as ProgressBar).value = int(p["into"])
		(row["bar"] as ProgressBar).tooltip_text = "%d / %d xp to level %d" % [p["into"], p["span"], int(p["level"]) + 1]
	var fire_why := sim.check(SimVocab.LIGHT_FIRE, {})
	_fire_button.disabled = fire_why != ""
	_fire_button.tooltip_text = "Burn %d logs from your pack into a fire where you stand. It warms you and cooks for a minute." % Sim.FIELD_FIRE_LOGS
	if fire_why == SimVocab.REASON_IN_OUTPOST:
		_fire_button.tooltip_text = "The outpost has its own fire."
	elif fire_why == SimVocab.REASON_MISSING_INPUTS:
		_fire_button.tooltip_text = "Needs %d logs in your pack." % Sim.FIELD_FIRE_LOGS

	var pack: Array = s["inventory"]["pack"]
	for i in _pack_buttons.size():
		_pack_buttons[i].text = _slot_text(pack[i])
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
	_weight_label.add_theme_color_override("font_color", COLOR_HEALTH if sim.is_overweight() else COLOR_TEXT)
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
	_stash_title.text = "Stash  %d / %d slots" % [used, int(stash["capacity"])]
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
			b.text = _slot_text(slots[i])
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
			(row["text"] as Label).text = "%s  -  iron is found in ring one, never smithed" % r["label"]


func _add_craft_row(id: String) -> void:
	var row := HBoxContainer.new()
	var text := _text("", 13)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(text)
	var craft := Button.new()
	craft.text = "Craft"
	craft.pressed.connect(func() -> void: command_requested.emit(SimVocab.SMITH, {"recipe": id}))
	row.add_child(craft)
	row.add_child(_gap(14))  # clear of the scrollbar
	_craft_list.add_child(row)
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
		button.tooltip_text = _why_text(why)
	_upgrade_note.text = "Build from what is in the stash, inside the outpost." if sim.in_outpost() else "Upgrades are built inside the outpost."


func _add_upgrade_row(id: String) -> void:
	var row := HBoxContainer.new()
	var text := _text("", 13)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(text)
	var build := Button.new()
	build.text = "Build"
	build.custom_minimum_size = Vector2(70, 0)
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
	if effects.has("ring_gate"):
		parts.append("works the gate to ring two once its captain falls")
	if effects.has("waystone"):
		parts.append("a waystone home from ring one")
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
			return "Smithing stops at bronze."
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


static func _slot_text(slot: Variant) -> String:
	if slot == null:
		return ""
	var count := int(slot["count"])
	var name := ItemTable.label(slot["item"])
	return name if count <= 1 else "%s\nx%d" % [name, count]


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

func _build_vitals() -> void:
	var box := VBoxContainer.new()
	box.position = Vector2(24, 60)
	box.custom_minimum_size = Vector2(280, 0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	box.add_child(_text("Warmth", 14))
	_warmth_bar = _bar(COLOR_WARMTH)
	box.add_child(_warmth_bar)
	box.add_child(_text("Health", 14))
	_health_bar = _bar(COLOR_HEALTH)
	box.add_child(_health_bar)
	box.add_child(_text("Skills", 14))
	for name in READOUT_SKILLS:
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(row)
		var label := _text("", 13)
		label.custom_minimum_size = Vector2(140, 0)
		row.add_child(label)
		var bar := _bar(COLOR_XP)
		bar.custom_minimum_size = Vector2(136, 10)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.mouse_filter = Control.MOUSE_FILTER_PASS
		row.add_child(bar)
		_skill_rows[name] = {"label": label, "bar": bar}


func _build_pack() -> void:
	var panel := _panel_box()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.offset_right = -16
	panel.offset_bottom = -16
	add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	box.add_child(_text("Pack", 16))
	var grid := GridContainer.new()
	grid.columns = 4
	box.add_child(grid)
	for i in Sim.PACK_SLOTS:
		var b := _slot_button()
		b.pressed.connect(_on_pack_pressed.bind(i))
		b.gui_input.connect(_on_pack_input.bind(i))
		grid.add_child(b)
		_pack_buttons.append(b)
	_weight_label = _text("", 13)
	box.add_child(_weight_label)
	_style_label = _text("", 13)
	box.add_child(_style_label)
	var worn := HBoxContainer.new()
	box.add_child(worn)
	for slot in ItemTable.EQUIPMENT_SLOTS:
		var b := _slot_button()
		b.custom_minimum_size = Vector2(102, 44)
		b.pressed.connect(func() -> void:
			if sim.state["inventory"]["equipment"][slot] != "":
				command_requested.emit(SimVocab.EQUIP, {"unequip": slot}))
		worn.add_child(b)
		_equip_buttons[slot] = b


func _build_stash() -> void:
	_stash_panel = _panel_box()
	_stash_panel.position = PANEL_POSITION
	_stash_panel.visible = false
	add_child(_stash_panel)
	var box := VBoxContainer.new()
	_stash_panel.add_child(box)
	var head := HBoxContainer.new()
	box.add_child(head)
	_stash_title = _text("Stash", 16)
	_stash_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_stash_title)
	head.add_child(_close_button())
	box.add_child(_text("Click a stash slot to withdraw it, or a pack slot to deposit.", 13))
	_stash_grid = GridContainer.new()
	_stash_grid.columns = 4
	box.add_child(_stash_grid)


func _build_craft() -> void:
	_craft_panel = _panel_box()
	_craft_panel.position = PANEL_POSITION
	_craft_panel.custom_minimum_size = Vector2(560, 0)
	_craft_panel.visible = false
	add_child(_craft_panel)
	var box := VBoxContainer.new()
	_craft_panel.add_child(box)
	var head := HBoxContainer.new()
	box.add_child(head)
	var title := _text("Workbench (smithing): crafts from what is in your pack", 16)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(_close_button())
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(540, 380)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_craft_list = VBoxContainer.new()
	_craft_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_craft_list)


func _build_upgrades() -> void:
	_upgrade_panel = _panel_box()
	_upgrade_panel.position = PANEL_POSITION
	_upgrade_panel.custom_minimum_size = Vector2(560, 0)
	_upgrade_panel.visible = false
	add_child(_upgrade_panel)
	var box := VBoxContainer.new()
	_upgrade_panel.add_child(box)
	var head := HBoxContainer.new()
	box.add_child(head)
	var title := _text("Outpost upgrades", 16)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(_close_button())
	_upgrade_note = _text("", 13)
	box.add_child(_upgrade_note)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(540, 400)
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
	add_child(buttons_row)
	_fire_button = Button.new()
	_fire_button.text = "Light fire"
	_fire_button.pressed.connect(func() -> void: command_requested.emit(SimVocab.LIGHT_FIRE, {}))
	buttons_row.add_child(_fire_button)
	var upgrades := Button.new()
	upgrades.text = "Upgrades"
	upgrades.pressed.connect(func() -> void: open_panel(PANEL_NONE if _panel == PANEL_UPGRADES else PANEL_UPGRADES))
	buttons_row.add_child(upgrades)
	var open := Button.new()
	open.text = "Save code"
	open.pressed.connect(func() -> void: export_requested.emit())
	buttons_row.add_child(open)
	var help := Button.new()
	help.text = "Help"
	help.pressed.connect(func() -> void: help_requested.emit())
	buttons_row.add_child(help)
	_saved_label = _text("Saved", 14)
	_saved_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_saved_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_saved_label.offset_right = -16
	_saved_label.offset_top = 56
	_saved_label.modulate.a = 0.0
	add_child(_saved_label)

	_save_panel = _panel_box()
	_save_panel.set_anchors_preset(Control.PRESET_CENTER)
	_save_panel.custom_minimum_size = Vector2(640, 0)
	_save_panel.offset_left = -320
	_save_panel.offset_top = -140
	_save_panel.visible = false
	add_child(_save_panel)
	var box := VBoxContainer.new()
	_save_panel.add_child(box)
	box.add_child(_text("Your save code", 16))
	_save_note = _text("", 13)
	_save_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_save_note)
	_save_text = TextEdit.new()
	_save_text.editable = false
	_save_text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_save_text.custom_minimum_size = Vector2(620, 140)
	box.add_child(_save_text)
	var buttons := HBoxContainer.new()
	box.add_child(buttons)
	var copy := Button.new()
	copy.text = "Copy to clipboard"
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
	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(func() -> void: _save_panel.visible = false)
	buttons.add_child(close)


func _close_button() -> Button:
	var b := Button.new()
	b.text = "x"
	b.pressed.connect(close_panels)
	return b


static func _gap(width: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(width, 0)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func _panel_box() -> PanelContainer:
	var p := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.93, 0.95, 0.98, 0.92)
	style.border_color = Color(0.4, 0.45, 0.55)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(10)
	p.add_theme_stylebox_override("panel", style)
	return p


static func _slot_button() -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(76, 50)
	b.clip_text = true
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_theme_font_size_override("font_size", 13)
	return b


static func _bar(colour: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(280, 16)
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := StyleBoxFlat.new()
	fill.bg_color = colour
	bar.add_theme_stylebox_override("fill", fill)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.2, 0.22, 0.26, 0.5)
	bar.add_theme_stylebox_override("background", bg)
	return bar


static func _text(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", COLOR_TEXT)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
