## The first-outing guide on screen: the current hint step, the latest contextual tip, and a
## button to hide hints for good. Bottom left, under the skills and clear of the side panels.
##
## Glue only. The text comes from GuideTable; which hint is current and when a tip fires is
## the simulation's answer (`hint`, `tip` and `hints_set` events). Hiding emits `dismissed`
## and GameRoot turns the guide off through the `set_hints` command.
extends Control

signal dismissed

## How long a tip, and the line that closes the hint path, stay up.
const TIP_SECONDS := 10.0

var _panel: PanelContainer
var _hint: Label
var _tip: Label
var _tip_left := 0.0
var _hint_left := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UiTheme.panel_style(UiTheme.PANEL_EMBER))
	_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_panel.offset_left = 24
	_panel.offset_right = 324
	_panel.offset_bottom = -132
	add_child(_panel)
	var box := VBoxContainer.new()
	_panel.add_child(box)
	var head := HBoxContainer.new()
	box.add_child(head)
	var title := UiTheme.heading("Next", 14, UiTheme.EMBER)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(title)
	var hide := Button.new()
	hide.text = "Hide hints"
	hide.tooltip_text = "Turn hints off. Help can turn them back on."
	hide.add_theme_font_size_override("font_size", 12)
	hide.pressed.connect(func() -> void: dismissed.emit())
	head.add_child(hide)
	_hint = _wrapped(14)
	box.add_child(_hint)
	_tip = _wrapped(13)
	_tip.add_theme_color_override("font_color", Color(1.0, 0.78, 0.45))
	box.add_child(_tip)
	_panel.visible = false


func _process(delta: float) -> void:
	if _tip_left > 0.0:
		_tip_left -= delta
		if _tip_left <= 0.0:
			_tip.visible = false
			_relayout()
	if _hint_left > 0.0:
		_hint_left -= delta
		if _hint_left <= 0.0:
			_hint.visible = false
			_relayout()


## Redraws from the simulation: the current hint, or nothing when the guide is off.
func show_sim(sim: Sim) -> void:
	_tip.visible = false
	_tip_left = 0.0
	_hint_left = 0.0
	_hint.text = GuideTable.hint_text(sim.hint())
	_hint.visible = sim.hint() != ""
	_relayout(sim.hints_on())


## A `hint` event: the next step, or "" for the closing line, which fades like a tip.
func show_hint(id: String) -> void:
	_hint.text = GuideTable.hint_text(id)
	_hint.visible = true
	_hint_left = TIP_SECONDS if id == "" else 0.0
	_relayout()


## A `tip` event.
func show_tip(id: String) -> void:
	_tip.text = GuideTable.tip_text(id)
	_tip.visible = true
	_tip_left = TIP_SECONDS
	_relayout()


## The panel shows while the guide is on and has something to say.
func _relayout(on := true) -> void:
	_panel.visible = on and (_hint.visible or _tip.visible)
	# Grow upward from the fixed bottom edge, clear of the status lines below.
	_panel.offset_top = _panel.offset_bottom - _panel.get_combined_minimum_size().y


static func _wrapped(size: int) -> Label:
	var l := UiTheme.wrapped("", 276, size)
	l.visible = false
	return l
