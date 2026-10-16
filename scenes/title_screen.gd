## The title screen: the one-line hook, New character, Continue (when a browser save exists)
## and Import code. It only collects the player's choice and emits it; GameRoot does the
## loading, so every save code still goes through the simulation's `import_save`.
extends Control

signal new_character
signal continue_requested
signal import_requested(code: String)

const HOOK := "You keep the fire at Frostmark, the last trading post on the ice, for a caravan three winters late."
const COLOR_BACKDROP := Color(0.08, 0.11, 0.16, 0.94)
const COLOR_TEXT := Color(0.9, 0.94, 1.0)
const COLOR_ERROR := Color(1.0, 0.55, 0.5)

var _new_button: Button
var _continue_button: Button
var _code: TextEdit
var _message: Label
var _confirm_new := false


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
	column.custom_minimum_size = Vector2(640, 0)
	column.add_theme_constant_override("separation", 14)
	centre.add_child(column)

	column.add_child(_label("Frostmark", 56))
	var hook := _label(HOOK, 18)
	hook.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(hook)
	column.add_child(_spacer(12))

	_continue_button = _button("Continue", _on_continue)
	column.add_child(_continue_button)
	_new_button = _button("New character", _on_new)
	column.add_child(_new_button)
	column.add_child(_spacer(12))

	column.add_child(_label("Import a save code", 16))
	_code = TextEdit.new()
	_code.custom_minimum_size = Vector2(640, 90)
	_code.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_code.placeholder_text = "Paste a save code exported from Frostmark"
	column.add_child(_code)
	column.add_child(_button("Import code", _on_import))
	_message = _label("", 16)
	_message.add_theme_color_override("font_color", COLOR_ERROR)
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_message)
	refresh()


## Shows Continue only when a browser save exists.
func refresh() -> void:
	_continue_button.visible = SaveStore.has_save()
	_confirm_new = false
	_new_button.text = "New character"


func show_error(text: String) -> void:
	_message.text = text


func _on_continue() -> void:
	_message.text = ""
	continue_requested.emit()


func _on_new() -> void:
	# Starting over replaces the browser save, so ask once more when there is one.
	if SaveStore.has_save() and not _confirm_new:
		_confirm_new = true
		_new_button.text = "Start over? Your saved character will be replaced. Click again."
		return
	_message.text = ""
	new_character.emit()


func _on_import() -> void:
	_message.text = ""
	import_requested.emit(_code.text)


func _label(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", COLOR_TEXT)
	return l


func _button(text: String, pressed: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 40)
	b.add_theme_font_size_override("font_size", 18)
	b.pressed.connect(pressed)
	return b


static func _spacer(height: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, height)
	return c
