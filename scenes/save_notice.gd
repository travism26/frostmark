## A small notice at the top of the screen about the save code: the reminder after a long
## stretch of play, or the warning that the browser is not keeping saves. It offers to copy
## the code, show it, or go away. It only shows text and emits the player's choice; GameRoot
## owns the SaveWatch that decides when it appears. Drawn in the HUD's panel style.
extends Control

signal copy_requested
signal show_requested
signal dismissed

const Hud := preload("res://scenes/hud.gd")

const REMINDER := "You have been playing a while. Copy your save code and keep it somewhere safe: it carries your character to any browser."
const UNSTORED := "This browser is not keeping your saves (its storage is full or blocked, as in some private browsing). The game carries on, but copy your save code now and again: it is your save."

var _text: Label
var _note: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_CENTER_TOP)
	offset_left = -280
	offset_right = 280
	offset_top = 16
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := Hud._panel_box()
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	_text = Hud._text("", 14)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_text)
	_note = Hud._text("", 13)
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_note)
	var buttons := HBoxContainer.new()
	box.add_child(buttons)
	buttons.add_child(_button("Copy save code", func() -> void: copy_requested.emit()))
	buttons.add_child(_button("Show code", func() -> void: show_requested.emit()))
	buttons.add_child(_button("Dismiss", func() -> void:
		visible = false
		dismissed.emit()))
	visible = false


func show_reminder() -> void:
	_show(REMINDER)


func show_unstored() -> void:
	_show(UNSTORED)


## A line under the message: whether the copy worked.
func set_note(text: String) -> void:
	_note.text = text


func _show(text: String) -> void:
	_text.text = text
	_note.text = ""
	visible = true


static func _button(text: String, pressed: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(pressed)
	return b
