## The help panel: the controls and the first-outing loop, reachable from the title screen
## and the HUD. In a game it also holds the switch that turns hints back on after they were
## hidden. It only shows text and emits; GameRoot holds the simulation still while it is open
## and sends the `set_hints` command.
extends Control

signal hints_toggled(on: bool)

const COLOR_BACKDROP := Color(0.08, 0.11, 0.16, 0.8)
const Hud := preload("res://scenes/hud.gd")

const CONTROLS := [
	["Walk", "Click the ground."],
	["Use", "Click a tree, rock or fishing hole to gather it, the gate to cross it, the stash, workbench or a fire to use it, loot to pick it up."],
	["Fight", "Click an enemy. Read the cue over its head: a blade up close beats a bow, a bow at range beats a blade."],
	["Pack", "Click an item to equip or eat it, or by a fire to cook it. Right-click to drop it."],
	["Camera", "Q and E, or a middle-mouse drag, turn the camera. The mouse wheel zooms."],
]

const LOOP := [
	"Walk out through the gate and cut a pine.",
	"Walk back in: crossing the gate banks your pack in the stash. Nothing you carry is safe until then.",
	"Take logs from the stash and make a pickaxe or a rod at the workbench.",
	"Warmth drains outside. Get home, or to a fire, before it runs out.",
	"Once built, a waystone you have visited takes you to the outpost gate. It does not bank: walk through the gate for that.",
	"If you die you keep your three most valuable things. The stash is never touched.",
]

var _hints: CheckBox


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
	var panel := Hud._panel_box()
	centre.add_child(panel)
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(620, 0)
	column.add_theme_constant_override("separation", 6)
	panel.add_child(column)

	column.add_child(Hud._text("Controls", 22))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	column.add_child(grid)
	for row in CONTROLS:
		grid.add_child(Hud._text(row[0], 15))
		grid.add_child(_wrapped(row[1], 520))
	column.add_child(Hud._text("The loop", 22))
	for line in LOOP:
		column.add_child(_wrapped("- " + line, 620))

	_hints = CheckBox.new()
	_hints.text = "Show hints"
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		_hints.add_theme_color_override(state, Hud.COLOR_TEXT)
	_hints.toggled.connect(func(on: bool) -> void: hints_toggled.emit(on))
	column.add_child(_hints)
	var close := Button.new()
	close.text = "Close"
	close.custom_minimum_size = Vector2(0, 36)
	close.pressed.connect(func() -> void: visible = false)
	column.add_child(close)
	visible = false


## Opens the panel. The hints switch shows only in a game, set to `hints_on`.
func open(in_game: bool, hints_on := false) -> void:
	_hints.visible = in_game
	_hints.set_pressed_no_signal(hints_on)
	visible = true


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		visible = false
		get_viewport().set_input_as_handled()


static func _wrapped(text: String, width: float) -> Label:
	var l := Hud._text(text, 14)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(width, 0)
	return l
