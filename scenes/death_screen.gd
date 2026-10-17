## The death screen: what killed the player, exactly what they kept and what they lost, and
## one button to wake by the fire. It only shows the `died` event and emits `dismissed`;
## GameRoot holds the simulation still until then.
##
## The shared theme in its cold red key: a danger-framed panel over a dark red backdrop.
extends Control

signal dismissed

const COLOR_BACKDROP := Color(0.10, 0.03, 0.05, 0.90)
const COLOR_TITLE := Color(1.0, 0.62, 0.58)
const COLOR_KEPT := Color(0.62, 0.90, 0.68)
const COLOR_LOST := Color(1.0, 0.60, 0.55)

var _cause: Label
var _kept: Label
var _lost: Label
var _spare: Label


func _ready() -> void:
	theme = UiTheme.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var backdrop := ColorRect.new()
	backdrop.color = COLOR_BACKDROP
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.panel_style(UiTheme.PANEL_DANGER))
	panel.custom_minimum_size = Vector2(560, 0)
	centre.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)

	var title := _heading("You died", 44, COLOR_TITLE)
	title.add_theme_font_override("font", UiTheme.font_cinzel(700, 4))
	title.add_theme_color_override("font_shadow_color", Color(1.0, 0.3, 0.3, 0.3))
	title.add_theme_constant_override("shadow_outline_size", 10)
	title.add_theme_constant_override("shadow_offset_x", 0)
	title.add_theme_constant_override("shadow_offset_y", 0)
	column.add_child(title)
	_cause = _label("", 16, UiTheme.TEXT)
	column.add_child(_cause)
	column.add_child(_rule())

	var ledger := HBoxContainer.new()
	ledger.add_theme_constant_override("separation", 12)
	column.add_child(ledger)
	var kept_box := _column(ledger)
	kept_box.add_child(_heading("Kept", 15, COLOR_KEPT))
	_kept = _label("", 14, COLOR_KEPT)
	kept_box.add_child(_kept)
	ledger.add_child(VSeparator.new())
	var lost_box := _column(ledger)
	lost_box.add_child(_heading("Lost for good", 15, COLOR_LOST))
	_lost = _label("", 14, COLOR_LOST)
	lost_box.add_child(_lost)

	_spare = _label("", 14, UiTheme.TEXT)
	column.add_child(_spare)
	column.add_child(_rule())
	column.add_child(_label("Your stash and skills are untouched.", 14, UiTheme.TEXT_DIM))
	var wake := Button.new()
	wake.text = "Wake by the fire"
	wake.theme_type_variation = "DangerButton"
	wake.icon = UiTheme.icon("flame", 16)
	wake.custom_minimum_size = Vector2(0, 46)
	wake.pressed.connect(func() -> void: dismissed.emit())
	column.add_child(wake)


## Fills the screen from a `died` event.
func show_death(e: Dictionary) -> void:
	var cause: String = e["cause"]
	if CombatTable.is_enemy_kind(cause):
		var killer := str(CombatTable.enemy(cause)["label"]).to_lower()
		_cause.text = "Killed by %s %s." % ["an" if killer.left(1) in ["a", "e", "i", "o", "u"] else "a", killer]
	else:
		_cause.text = "The cold took you."
	_kept.text = _list(e["kept"])
	_lost.text = _list(e["lost"])
	var spare: String = e.get("spare", "")
	_spare.text = "A spare %s waits by the fire." % ItemTable.label(spare).to_lower() if spare != "" else ""
	_spare.visible = spare != ""
	visible = true


static func _list(entries: Array) -> String:
	if entries.is_empty():
		return "Nothing"
	var lines: PackedStringArray = []
	for entry in entries:
		var count := int(entry["count"])
		var name := ItemTable.label(entry["item"])
		lines.append(name if count <= 1 else "%d %s" % [count, name])
	return "\n".join(lines)


static func _column(parent: Control) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 4)
	parent.add_child(box)
	return box


static func _rule() -> HSeparator:
	return HSeparator.new()


static func _heading(text: String, size: int, colour: Color) -> Label:
	var l := UiTheme.heading(text, size, colour)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func _label(text: String, size: int, colour: Color) -> Label:
	var l := UiTheme.body(text, size, colour)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l
