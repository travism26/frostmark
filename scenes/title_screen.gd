## The title screen: the one-line hook, New character, Continue (when a browser save exists)
## and Import code. It only collects the player's choice and emits it; GameRoot does the
## loading, so every save code still goes through the simulation's `import_save`.
##
## A dark-ice gradient and light snowfall sit behind a narrow column of themed widgets.
extends Control

signal new_character
signal continue_requested
signal import_requested(code: String)
signal help_requested

const HOOK := "You keep the fire at Frostmark, the last trading post on the ice, for a caravan three winters late."
const CREDIT := "3D models by Kenney (kenney.nl), KayKit (kaylousberg.com) and Quaternius (quaternius.com), CC0. Fonts Cinzel and Inter (OFL)."
const COLOR_ERROR := Color(1.0, 0.55, 0.5)
const COLUMN_WIDTH := 460.0
const SNOW_TEXTURE := "res://assets/particles/kenney_particle_pack/circle_05.png"
const SNOW_COUNT := 120

## The backdrop: deep ice at the top into slate at the bottom, with a soft glow behind the
## title and a band of ground fog low down.
const BACKDROP_SHADER := """
shader_type canvas_item;
uniform vec4 top_colour : source_color = vec4(0.025, 0.045, 0.085, 1.0);
uniform vec4 bottom_colour : source_color = vec4(0.10, 0.16, 0.24, 1.0);
uniform vec4 glow_colour : source_color = vec4(0.45, 0.65, 0.90, 1.0);
uniform float opacity = 0.94;
void fragment() {
	vec3 c = mix(top_colour.rgb, bottom_colour.rgb, pow(UV.y, 1.4));
	float d = distance(UV * vec2(1.0, 0.5625), vec2(0.5, 0.17));
	c += glow_colour.rgb * 0.20 * smoothstep(0.42, 0.0, d);
	c += vec3(0.60, 0.75, 0.90) * 0.07 * smoothstep(1.0, 0.0, abs(UV.y - 0.86) * 5.0);
	COLOR = vec4(c, opacity);
}
"""

var _new_button: Button
var _continue_button: Button
var _code: TextEdit
var _message: Label
var _confirm_new := false


func _ready() -> void:
	theme = UiTheme.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_backdrop())
	add_child(_snowfall())

	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(COLUMN_WIDTH, 0)
	column.add_theme_constant_override("separation", 12)
	centre.add_child(column)

	var title := UiTheme.heading("Frostmark", 64)
	title.add_theme_font_override("font", UiTheme.font_cinzel(700, 6))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_outline_color", Color(UiTheme.INK, 0.6))
	title.add_theme_constant_override("outline_size", 3)
	title.add_theme_color_override("font_shadow_color", Color(UiTheme.ICE, 0.35))
	title.add_theme_constant_override("shadow_outline_size", 14)
	title.add_theme_constant_override("shadow_offset_x", 0)
	title.add_theme_constant_override("shadow_offset_y", 0)
	column.add_child(title)
	var hook := UiTheme.body(HOOK, 16, Color(0.78, 0.86, 0.96))
	hook.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hook.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(hook)
	column.add_child(_spacer(10))

	_continue_button = _button("Continue", _on_continue, "PrimaryButton")
	_continue_button.icon = UiTheme.icon("star", 16)
	column.add_child(_continue_button)
	_new_button = _button("New character", _on_new, "PrimaryButton")
	_new_button.icon = UiTheme.icon("plus", 16)
	_new_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_new_button)
	var controls := _button("Controls", func() -> void: help_requested.emit(), "")
	controls.icon = UiTheme.icon("question", 16)
	column.add_child(controls)
	column.add_child(_spacer(6))

	var import_panel := PanelContainer.new()
	import_panel.theme_type_variation = "Inset"
	column.add_child(import_panel)
	var import_box := VBoxContainer.new()
	import_box.add_theme_constant_override("separation", 8)
	import_panel.add_child(import_box)
	var import_title := UiTheme.heading("Import a save code", 14)
	import_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	import_box.add_child(import_title)
	_code = TextEdit.new()
	_code.custom_minimum_size = Vector2(0, 84)
	_code.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_code.placeholder_text = "Paste a save code exported from Frostmark"
	import_box.add_child(_code)
	var import_button := _button("Import code", _on_import, "")
	import_button.icon = UiTheme.icon("import", 15)
	import_box.add_child(import_button)

	_message = UiTheme.body("", 15, COLOR_ERROR)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_message)
	column.add_child(_spacer(4))
	var credit := UiTheme.muted(CREDIT, 12)
	credit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	credit.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	credit.modulate.a = 0.8
	column.add_child(credit)
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


static func _backdrop() -> ColorRect:
	var rect := ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = BACKDROP_SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	rect.material = material
	return rect


## Light snow drifting down the whole screen, started mid-fall so the screen never opens empty.
static func _snowfall() -> CPUParticles2D:
	var snow := CPUParticles2D.new()
	snow.amount = SNOW_COUNT
	snow.lifetime = 10.0
	snow.preprocess = 10.0
	snow.texture = load(SNOW_TEXTURE)
	snow.position = Vector2(640, -24)
	snow.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	snow.emission_rect_extents = Vector2(760, 8)
	snow.direction = Vector2(0.15, 1.0)
	snow.spread = 12.0
	snow.gravity = Vector2(6.0, 14.0)
	snow.initial_velocity_min = 30.0
	snow.initial_velocity_max = 70.0
	snow.scale_amount_min = 0.006
	snow.scale_amount_max = 0.02
	snow.color = Color(0.92, 0.96, 1.0, 0.7)
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0.0))
	ramp.set_color(1, Color(1, 1, 1, 1.0))
	ramp.add_point(0.12, Color(1, 1, 1, 1.0))
	ramp.add_point(0.85, Color(1, 1, 1, 1.0))
	snow.color_ramp = ramp
	return snow


func _button(text: String, pressed: Callable, variation: String) -> Button:
	var b := Button.new()
	b.text = text
	if variation != "":
		b.theme_type_variation = variation
	b.custom_minimum_size = Vector2(0, 42)
	b.pressed.connect(pressed)
	return b


static func _spacer(height: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, height)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c
