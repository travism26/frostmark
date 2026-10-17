## The help panel: the controls and the first-outing loop, reachable from the title screen
## and the HUD. In a game it also holds the switch that turns hints back on after they were
## hidden. It only shows text and emits; GameRoot holds the simulation still while it is open
## and sends the `set_hints` command.
extends Control

signal hints_toggled(on: bool)

const COLOR_BACKDROP := Color(0.02, 0.04, 0.07, 0.72)

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
	theme = UiTheme.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var backdrop := ColorRect.new()
	backdrop.color = COLOR_BACKDROP
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.panel_style(UiTheme.PANEL_ICE))
	centre.add_child(panel)
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(620, 0)
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)

	column.add_child(UiTheme.header("Controls", func() -> void: visible = false))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 6)
	column.add_child(grid)
	for row in CONTROLS:
		var key := UiTheme.heading(row[0], 13, UiTheme.ICE)
		key.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		grid.add_child(key)
		grid.add_child(UiTheme.wrapped(row[1], 520))
	column.add_child(HSeparator.new())
	column.add_child(UiTheme.heading("The loop", 15))
	for line in LOOP:
		column.add_child(UiTheme.wrapped("- " + line, 620, 14, Color(0.78, 0.86, 0.96)))
	column.add_child(HSeparator.new())

	var foot := HBoxContainer.new()
	column.add_child(foot)
	_hints = CheckBox.new()
	_hints.text = "Show hints"
	_hints.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hints.toggled.connect(func(on: bool) -> void: hints_toggled.emit(on))
	foot.add_child(_hints)
	var close := Button.new()
	close.text = "Close"
	close.theme_type_variation = "PrimaryButton"
	close.custom_minimum_size = Vector2(140, 36)
	close.pressed.connect(func() -> void: visible = false)
	foot.add_child(close)
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
