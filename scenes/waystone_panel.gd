## The waystone prompt: shown while the player stands by a waystone, with a button that starts
## travel home and a line saying how the channel is going or why it cannot start. Bottom centre,
## above the status lines.
##
## Glue only. Whether travel would start is the simulation's answer (`Sim.travel_check`); the
## button emits `travel_requested` and GameRoot sends the `travel` command.
extends Control

signal travel_requested(object_id: String)

const WIDTH := 320.0

## What a refusal means at the stone.
const WHY_TEXT := {
	SimVocab.REASON_UPGRADE_MISSING: "The stone sleeps. Build Waystones at the outpost to wake it.",
	SimVocab.REASON_NOT_ATTUNED: "Walk up to the stone to attune it.",
}

var _panel: PanelContainer
var _note: Label
var _travel: Button
var _stone := ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UiTheme.panel_style(UiTheme.PANEL_ICE))
	_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_panel.offset_left = -WIDTH * 0.5
	_panel.offset_right = WIDTH * 0.5
	_panel.offset_bottom = -124  # clear of the status and controls lines along the bottom
	add_child(_panel)
	var box := VBoxContainer.new()
	_panel.add_child(box)
	box.add_child(UiTheme.heading("Waystone", 14, UiTheme.ICE))
	_note = UiTheme.wrapped("", WIDTH - 20, 13)
	box.add_child(_note)
	_travel = Button.new()
	_travel.text = "Travel to the outpost"
	_travel.theme_type_variation = "PrimaryButton"
	_travel.icon = UiTheme.icon("home", 16)
	_travel.pressed.connect(func() -> void: travel_requested.emit(_stone))
	box.add_child(_travel)
	_panel.visible = false


## Shows the prompt for the waystone the player stands by, or hides it when there is none.
func show_sim(sim: Sim) -> void:
	_stone = ""
	for id in sim.world.objects_of_kind(WorldDef.KIND_WAYSTONE):
		if sim.world.distance_to_object(id, sim.player_pos()) <= Sim.USE_REACH:
			_stone = id
	_panel.visible = _stone != ""
	if _stone == "":
		return
	var activity: Dictionary = sim.state["player"]["activity"]
	if sim.is_travelling():
		_note.text = "Travelling home... %d / %d. A blow will break it." % [int(activity["progress"]), Sim.TRAVEL_TICKS]
		_travel.disabled = true
	else:
		var why := sim.travel_check(_stone)
		_note.text = WHY_TEXT.get(why, "Takes you and your pack to the outpost gate. Walk through it to be home safe.")
		_travel.disabled = why != ""
	_panel.offset_top = _panel.offset_bottom - _panel.get_combined_minimum_size().y
