## The ring-two ending screen: the first playable's finish line. Shown when the player walks
## through the open gate to ring two; one button takes them home to the outpost, character
## intact. It only shows the `ring_two_reached` moment and emits `dismissed`; GameRoot holds
## the simulation still until then.
extends Control

signal dismissed

const COLOR_BACKDROP := Color(0.06, 0.09, 0.14, 0.94)
const COLOR_TEXT := Color(0.9, 0.94, 1.0)
const COLOR_ACCENT := Color(0.62, 0.8, 1.0)
const LINES := [
	"The winch groans, and the gate to ring two swings open.",
	"Beyond it the snow lies over broken walls older than the outpost, and the tracks in it are not wolves'.",
	"The caravan came this way, three winters ago.",
]

var _summary: Label


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
	column.custom_minimum_size = Vector2(620, 0)
	column.add_theme_constant_override("separation", 14)
	centre.add_child(column)

	column.add_child(_label("Ring two", 56, COLOR_ACCENT))
	for line in LINES:
		column.add_child(_label(line, 18, COLOR_TEXT))
	_summary = _label("", 16, COLOR_ACCENT)
	column.add_child(_summary)
	column.add_child(_label("This is where the first playable of Frostmark ends. Your character, stash and skills are kept; the wilds stay open for more.", 15, COLOR_TEXT))
	var home := Button.new()
	home.text = "Return to the outpost"
	home.custom_minimum_size = Vector2(0, 44)
	home.add_theme_font_size_override("font_size", 20)
	home.pressed.connect(func() -> void: dismissed.emit())
	column.add_child(home)


## Fills in the character's levels and shows the screen.
func show_ending(sim: Sim) -> void:
	var parts: PackedStringArray = []
	var total := 0
	for skill in SkillTable.NAMES:
		var level := sim.skill_level(skill)
		total += level
		parts.append("%s %d" % [skill.capitalize(), level])
	_summary.text = "Total level %d: %s." % [total, ", ".join(parts)]
	visible = true


static func _label(text: String, size: int, colour: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	return l
