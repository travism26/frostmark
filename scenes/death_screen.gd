## The death screen: what killed the player, exactly what they kept and what they lost, and
## one button to wake by the fire. It only shows the `died` event and emits `dismissed`;
## GameRoot holds the simulation still until then.
extends Control

signal dismissed

const COLOR_BACKDROP := Color(0.12, 0.05, 0.06, 0.92)
const COLOR_TEXT := Color(0.94, 0.92, 0.92)
const COLOR_KEPT := Color(0.6, 0.9, 0.65)
const COLOR_LOST := Color(1.0, 0.6, 0.55)

var _cause: Label
var _kept: Label
var _lost: Label
var _spare: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var backdrop := ColorRect.new()
	backdrop.color = COLOR_BACKDROP
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(560, 0)
	column.add_theme_constant_override("separation", 12)
	centre.add_child(column)

	column.add_child(_label("You died", 48, COLOR_TEXT))
	_cause = _label("", 18, COLOR_TEXT)
	column.add_child(_cause)
	column.add_child(_label("Kept", 20, COLOR_KEPT))
	_kept = _label("", 16, COLOR_KEPT)
	column.add_child(_kept)
	column.add_child(_label("Lost for good", 20, COLOR_LOST))
	_lost = _label("", 16, COLOR_LOST)
	column.add_child(_lost)
	_spare = _label("", 16, COLOR_TEXT)
	column.add_child(_spare)
	column.add_child(_label("Your stash and skills are untouched.", 16, COLOR_TEXT))
	var wake := Button.new()
	wake.text = "Wake by the fire"
	wake.custom_minimum_size = Vector2(0, 44)
	wake.add_theme_font_size_override("font_size", 20)
	wake.pressed.connect(func() -> void: dismissed.emit())
	column.add_child(wake)


## Fills the screen from a `died` event.
func show_death(e: Dictionary) -> void:
	var cause: String = e["cause"]
	if CombatTable.is_enemy_kind(cause):
		_cause.text = "Killed by a %s." % str(CombatTable.enemy(cause)["label"]).to_lower()
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


static func _label(text: String, size: int, colour: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	return l
