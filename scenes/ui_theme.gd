## Frostmark's one look for every screen: rounded frosted timber-and-iron frames with a soft
## inner glow, Cinzel headings, Inter body text and buttons, white glyphs on tinted round
## badges (IconTable), an ember accent for warmth and fire and a cold red for health and
## danger. Everything is built in code from the icon table and the two OFL fonts under
## assets/, so there is no .tres to keep in step.
##
## `theme()` returns the one cached Theme; each root Control sets it in `_ready`. The rest
## are small helpers for widgets the Theme cannot express on its own: framed panels in a
## colour key, headings and body labels, badges, Kenney icons scaled to a size, and the
## status label that lives in main.tscn (`style_hud_label`).
class_name UiTheme
extends RefCounted

# --- Palette --------------------------------------------------------------------------

## Panel fill: frosted slate that still lets a little of the snow through.
const SLATE := Color(0.07, 0.10, 0.15, 0.90)
## Insets: slot cells, gauge tracks, text fields.
const SLATE_DEEP := Color(0.035, 0.055, 0.09, 0.92)
## Raised surfaces: buttons and header strips.
const SLATE_RAISED := Color(0.13, 0.19, 0.27, 0.96)
const ICE := Color(0.62, 0.80, 1.0)
const ICE_DIM := Color(0.40, 0.55, 0.72)
const ICE_FAINT := Color(0.62, 0.80, 1.0, 0.22)
const TEXT := Color(0.88, 0.93, 1.0)
const TEXT_DIM := Color(0.62, 0.70, 0.80)
const TEXT_DISABLED := Color(0.52, 0.58, 0.66, 0.85)
const INK := Color(0.03, 0.05, 0.08)
const EMBER := Color(1.0, 0.62, 0.22)
const EMBER_DEEP := Color(0.78, 0.36, 0.10)
const BLOOD := Color(0.85, 0.22, 0.25)
const BLOOD_DEEP := Color(0.45, 0.10, 0.13)
const XP := Color(0.45, 0.82, 0.74)
## The frame's timber band and iron line.
const TIMBER := Color(0.30, 0.19, 0.11)
const TIMBER_LIGHT := Color(0.42, 0.28, 0.16)
const IRON := Color(0.46, 0.50, 0.56)
const IRON_DARK := Color(0.22, 0.25, 0.30)

const FONT_CINZEL := "res://assets/fonts/Cinzel[wght].ttf"
const FONT_INTER := "res://assets/fonts/Inter[opsz,wght].ttf"
const ICON_DIR := "res://assets/ui/kenney_game_icons/"

## Panel colour keys for `panel_style(kind)`.
const PANEL_SLATE := "panel"
const PANEL_DANGER := "danger"
const PANEL_ICE := "ice"
const PANEL_EMBER := "ember"

## The frame texture is this big, with its band and glow inside the 9-slice margin.
const FRAME_PX := 72
const FRAME_MARGIN := 24

static var _theme: Theme
static var _fonts := {}  # "cinzel:700:2" -> FontVariation
static var _frames := {}  # kind -> StyleBoxTexture
static var _icons := {}  # "name:px" -> Texture2D


# --- The theme ------------------------------------------------------------------------

## The shared Theme, built once.
static func theme() -> Theme:
	if _theme == null:
		_theme = _build()
	return _theme


static func _build() -> Theme:
	var t := Theme.new()
	t.default_font = font_inter(400)
	t.default_font_size = 14

	# Labels.
	t.set_color("font_color", "Label", TEXT)
	t.set_type_variation("Heading", "Label")
	t.set_font("font", "Heading", font_cinzel(700, 2))
	t.set_font_size("font_size", "Heading", 16)
	t.set_color("font_color", "Heading", TEXT)
	t.set_type_variation("Muted", "Label")
	t.set_color("font_color", "Muted", TEXT_DIM)
	t.set_font_size("font_size", "Muted", 13)
	t.set_type_variation("OnBar", "Label")  # text printed over a gauge or an orb
	t.set_font("font", "OnBar", font_inter(700))
	t.set_font_size("font_size", "OnBar", 13)
	t.set_color("font_color", "OnBar", TEXT)
	t.set_color("font_outline_color", "OnBar", Color(INK, 0.9))
	t.set_constant("outline_size", "OnBar", 4)
	t.set_type_variation("Banner", "Label")
	t.set_font("font", "Banner", font_cinzel(700, 2))
	t.set_font_size("font_size", "Banner", 26)
	t.set_color("font_color", "Banner", TEXT)
	t.set_color("font_outline_color", "Banner", Color(INK, 0.85))
	t.set_constant("outline_size", "Banner", 4)
	t.set_stylebox("normal", "Banner", _flat(Color(INK, 0.62), Color(ICE, 0.35), 1, 10, Vector2(18, 8)))
	t.set_type_variation("CountBadge", "Label")
	t.set_font("font", "CountBadge", font_inter(700))
	t.set_font_size("font_size", "CountBadge", 11)
	t.set_color("font_color", "CountBadge", TEXT)
	t.set_stylebox("normal", "CountBadge", _flat(Color(INK, 0.85), Color(ICE, 0.45), 1, 6, Vector2(5, 0)))
	t.set_type_variation("Flash", "Label")  # the "Saved" flash
	t.set_font("font", "Flash", font_cinzel(700, 1))
	t.set_font_size("font_size", "Flash", 14)
	t.set_color("font_color", "Flash", ICE)
	t.set_stylebox("normal", "Flash", _flat(Color(INK, 0.7), Color(ICE, 0.5), 1, 8, Vector2(12, 4)))

	# Buttons: Inter labels (Cinzel is a capitals face and shouts on a button), four clear
	# states, disabled dimmer but still opaque so it never reads as a ghost over the world.
	t.set_font("font", "Button", font_inter(600))
	t.set_font_size("font_size", "Button", 14)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color(1, 1, 1))
	t.set_color("font_pressed_color", "Button", ICE)
	t.set_color("font_hover_pressed_color", "Button", ICE)
	t.set_color("font_focus_color", "Button", TEXT)
	t.set_color("font_disabled_color", "Button", TEXT_DISABLED)
	t.set_color("icon_normal_color", "Button", TEXT)
	t.set_color("icon_hover_color", "Button", Color(1, 1, 1))
	t.set_color("icon_pressed_color", "Button", ICE)
	t.set_color("icon_hover_pressed_color", "Button", ICE)
	t.set_color("icon_focus_color", "Button", TEXT)
	t.set_color("icon_disabled_color", "Button", TEXT_DISABLED)
	t.set_constant("h_separation", "Button", 7)
	t.set_stylebox("normal", "Button", _flat(SLATE_RAISED, Color(IRON, 0.8), 1, 7, Vector2(14, 7)))
	t.set_stylebox("hover", "Button", _glow(_flat(Color(0.19, 0.28, 0.40, 0.98), Color(ICE, 0.95), 1, 7, Vector2(14, 7)), Color(ICE, 0.35), 4))
	t.set_stylebox("pressed", "Button", _flat(Color(0.06, 0.10, 0.16, 0.98), ICE, 1, 7, Vector2(14, 7)))
	t.set_stylebox("hover_pressed", "Button", _flat(Color(0.06, 0.10, 0.16, 0.98), ICE, 1, 7, Vector2(14, 7)))
	t.set_stylebox("disabled", "Button", _flat(Color(0.09, 0.12, 0.17, 0.96), Color(IRON_DARK, 0.9), 1, 7, Vector2(14, 7)))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())

	t.set_type_variation("PrimaryButton", "Button")
	t.set_font_size("font_size", "PrimaryButton", 16)
	t.set_stylebox("normal", "PrimaryButton", _flat(Color(0.17, 0.32, 0.48, 0.98), Color(ICE, 0.85), 1, 8, Vector2(20, 10)))
	t.set_stylebox("hover", "PrimaryButton", _glow(_flat(Color(0.24, 0.42, 0.62, 1.0), Color(1, 1, 1, 0.9), 1, 8, Vector2(20, 10)), Color(ICE, 0.45), 6))
	t.set_stylebox("pressed", "PrimaryButton", _flat(Color(0.10, 0.20, 0.32, 1.0), ICE, 1, 8, Vector2(20, 10)))
	t.set_stylebox("hover_pressed", "PrimaryButton", _flat(Color(0.10, 0.20, 0.32, 1.0), ICE, 1, 8, Vector2(20, 10)))
	t.set_stylebox("disabled", "PrimaryButton", _flat(Color(0.09, 0.12, 0.17, 0.96), Color(IRON_DARK, 0.9), 1, 8, Vector2(20, 10)))

	t.set_type_variation("DangerButton", "Button")
	t.set_font_size("font_size", "DangerButton", 16)
	t.set_stylebox("normal", "DangerButton", _flat(Color(0.36, 0.11, 0.14, 0.98), Color(1.0, 0.55, 0.5, 0.8), 1, 8, Vector2(20, 10)))
	t.set_stylebox("hover", "DangerButton", _glow(_flat(Color(0.50, 0.16, 0.20, 1.0), Color(1.0, 0.75, 0.7), 1, 8, Vector2(20, 10)), Color(1.0, 0.4, 0.4, 0.4), 6))
	t.set_stylebox("pressed", "DangerButton", _flat(Color(0.22, 0.07, 0.09, 1.0), Color(1.0, 0.6, 0.55), 1, 8, Vector2(20, 10)))
	t.set_stylebox("hover_pressed", "DangerButton", _flat(Color(0.22, 0.07, 0.09, 1.0), Color(1.0, 0.6, 0.55), 1, 8, Vector2(20, 10)))
	t.set_color("font_pressed_color", "DangerButton", Color(1.0, 0.7, 0.65))
	t.set_color("font_hover_pressed_color", "DangerButton", Color(1.0, 0.7, 0.65))

	# The Light fire button: ember-rimmed, and still solid while a fire cannot be lit.
	t.set_type_variation("FireButton", "Button")
	t.set_stylebox("normal", "FireButton", _flat(Color(0.20, 0.12, 0.07, 0.97), Color(EMBER, 0.85), 1, 7, Vector2(12, 7)))
	t.set_stylebox("hover", "FireButton", _glow(_flat(Color(0.30, 0.17, 0.09, 1.0), Color(1.0, 0.78, 0.4), 1, 7, Vector2(12, 7)), Color(EMBER, 0.4), 5))
	t.set_stylebox("pressed", "FireButton", _flat(Color(0.12, 0.07, 0.04, 1.0), EMBER, 1, 7, Vector2(12, 7)))
	t.set_stylebox("hover_pressed", "FireButton", _flat(Color(0.12, 0.07, 0.04, 1.0), EMBER, 1, 7, Vector2(12, 7)))
	t.set_stylebox("disabled", "FireButton", _flat(Color(0.12, 0.10, 0.09, 0.96), Color(0.45, 0.32, 0.22), 1, 7, Vector2(12, 7)))
	t.set_color("font_disabled_color", "FireButton", Color(0.70, 0.62, 0.55))

	# Inventory cells: a dark inset with an iron border, a glow on hover.
	t.set_type_variation("SlotButton", "Button")
	t.set_font("font", "SlotButton", font_inter(500))
	t.set_font_size("font_size", "SlotButton", 12)
	t.set_color("font_disabled_color", "SlotButton", TEXT_DIM)
	t.set_stylebox("normal", "SlotButton", _flat(SLATE_DEEP, Color(IRON, 0.55), 1, 8, Vector2(3, 3)))
	t.set_stylebox("hover", "SlotButton", _glow(_flat(Color(0.09, 0.14, 0.21, 0.96), Color(ICE, 0.95), 1, 8, Vector2(3, 3)), Color(ICE, 0.4), 4))
	t.set_stylebox("pressed", "SlotButton", _flat(Color(0.16, 0.26, 0.38, 0.98), ICE, 1, 8, Vector2(3, 3)))
	t.set_stylebox("hover_pressed", "SlotButton", _flat(Color(0.16, 0.26, 0.38, 0.98), ICE, 1, 8, Vector2(3, 3)))
	t.set_stylebox("disabled", "SlotButton", _flat(Color(0.035, 0.055, 0.09, 0.6), Color(IRON, 0.25), 1, 8, Vector2(3, 3)))

	# The side panel's tabs: icon only, the open one lit from beneath.
	t.set_type_variation("TabButton", "Button")
	t.set_stylebox("normal", "TabButton", _flat(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 8, Vector2(6, 6)))
	t.set_stylebox("hover", "TabButton", _flat(Color(ICE, 0.10), Color(0, 0, 0, 0), 0, 8, Vector2(6, 6)))
	var lit := _flat(Color(ICE, 0.16), Color(0, 0, 0, 0), 0, 8, Vector2(6, 6))
	lit.border_width_bottom = 2
	lit.border_color = ICE
	t.set_stylebox("pressed", "TabButton", lit)
	t.set_stylebox("hover_pressed", "TabButton", lit)

	# A setting's choice (90 / 100 / 125): a small toggle, lit when chosen.
	t.set_type_variation("ChoiceButton", "Button")
	t.set_font_size("font_size", "ChoiceButton", 13)
	t.set_stylebox("normal", "ChoiceButton", _flat(SLATE_DEEP, Color(IRON, 0.6), 1, 6, Vector2(10, 4)))
	t.set_stylebox("hover", "ChoiceButton", _flat(Color(0.09, 0.14, 0.21, 0.96), Color(ICE, 0.9), 1, 6, Vector2(10, 4)))
	t.set_stylebox("pressed", "ChoiceButton", _flat(Color(0.17, 0.32, 0.48, 0.98), ICE, 1, 6, Vector2(10, 4)))
	t.set_stylebox("hover_pressed", "ChoiceButton", _flat(Color(0.17, 0.32, 0.48, 0.98), ICE, 1, 6, Vector2(10, 4)))

	# The close cross in a panel's header bar.
	t.set_type_variation("CloseButton", "Button")
	t.set_stylebox("normal", "CloseButton", _flat(Color(0, 0, 0, 0), Color(IRON, 0.5), 1, 6, Vector2(5, 5)))
	t.set_stylebox("hover", "CloseButton", _flat(Color(0.55, 0.16, 0.2, 0.9), Color(1.0, 0.6, 0.55), 1, 6, Vector2(5, 5)))
	t.set_stylebox("pressed", "CloseButton", _flat(Color(0.35, 0.08, 0.1, 0.95), Color(1.0, 0.6, 0.55), 1, 6, Vector2(5, 5)))
	t.set_stylebox("hover_pressed", "CloseButton", _flat(Color(0.35, 0.08, 0.1, 0.95), Color(1.0, 0.6, 0.55), 1, 6, Vector2(5, 5)))
	t.set_color("icon_normal_color", "CloseButton", TEXT_DIM)
	t.set_color("icon_hover_color", "CloseButton", Color(1, 1, 1))

	# Panels: the framed slate by default, a flat tinted strip for header bars.
	t.set_stylebox("panel", "PanelContainer", panel_style(PANEL_SLATE))
	t.set_type_variation("HeaderBar", "PanelContainer")
	var header := _flat(Color(ICE, 0.08), Color(IRON, 0.7), 0, 6, Vector2(10, 6))
	header.border_width_bottom = 1
	t.set_stylebox("panel", "HeaderBar", header)
	t.set_type_variation("Inset", "PanelContainer")
	t.set_stylebox("panel", "Inset", _flat(SLATE_DEEP, Color(IRON, 0.4), 1, 8, Vector2(10, 8)))
	t.set_type_variation("Plain", "PanelContainer")
	t.set_stylebox("panel", "Plain", StyleBoxEmpty.new())

	# Gauges: a dark rounded track, a rounded fill with a highlight along its top edge.
	t.set_stylebox("background", "ProgressBar", _track(6))
	t.set_stylebox("fill", "ProgressBar", _fill(ICE, 6))
	t.set_type_variation("XpBar", "ProgressBar")
	t.set_stylebox("background", "XpBar", _track(3))
	t.set_stylebox("fill", "XpBar", _fill(XP, 3))

	# Text fields (the save code).
	var field := _flat(SLATE_DEEP, Color(IRON, 0.5), 1, 7, Vector2(8, 6))
	t.set_stylebox("normal", "TextEdit", field)
	t.set_stylebox("read_only", "TextEdit", field)
	t.set_stylebox("focus", "TextEdit", _glow(_flat(SLATE_DEEP, Color(ICE, 0.9), 1, 7, Vector2(8, 6)), Color(ICE, 0.3), 3))
	t.set_font_size("font_size", "TextEdit", 13)
	t.set_color("font_color", "TextEdit", TEXT)
	t.set_color("font_readonly_color", "TextEdit", Color(0.78, 0.86, 0.96))
	t.set_color("font_placeholder_color", "TextEdit", Color(TEXT_DIM, 0.6))
	t.set_color("caret_color", "TextEdit", ICE)
	t.set_color("selection_color", "TextEdit", Color(ICE, 0.35))
	t.set_color("background_color", "TextEdit", Color(0, 0, 0, 0))
	t.set_constant("line_spacing", "TextEdit", 3)

	# Scrollbars, separators, tooltips.
	t.set_stylebox("scroll", "VScrollBar", _flat(Color(INK, 0.35), Color(0, 0, 0, 0), 0, 4, Vector2(0, 0)))
	t.set_stylebox("grabber", "VScrollBar", _flat(Color(ICE_DIM, 0.6), Color(0, 0, 0, 0), 0, 4, Vector2(2, 2)))
	t.set_stylebox("grabber_highlight", "VScrollBar", _flat(Color(ICE, 0.85), Color(0, 0, 0, 0), 0, 4, Vector2(2, 2)))
	t.set_stylebox("grabber_pressed", "VScrollBar", _flat(ICE, Color(0, 0, 0, 0), 0, 4, Vector2(2, 2)))
	t.set_stylebox("scroll", "HScrollBar", _flat(Color(INK, 0.35), Color(0, 0, 0, 0), 0, 4, Vector2(0, 0)))
	t.set_stylebox("grabber", "HScrollBar", _flat(Color(ICE_DIM, 0.6), Color(0, 0, 0, 0), 0, 4, Vector2(2, 2)))
	t.set_stylebox("grabber_highlight", "HScrollBar", _flat(Color(ICE, 0.85), Color(0, 0, 0, 0), 0, 4, Vector2(2, 2)))
	t.set_stylebox("grabber_pressed", "HScrollBar", _flat(ICE, Color(0, 0, 0, 0), 0, 4, Vector2(2, 2)))
	t.set_stylebox("panel", "ScrollContainer", StyleBoxEmpty.new())
	var rule := StyleBoxLine.new()
	rule.color = Color(IRON, 0.45)
	rule.thickness = 1
	rule.grow_begin = 0
	rule.grow_end = 0
	t.set_stylebox("separator", "HSeparator", rule)
	t.set_constant("separation", "HSeparator", 10)
	var vrule := StyleBoxLine.new()
	vrule.color = Color(IRON, 0.45)
	vrule.thickness = 1
	vrule.vertical = true
	t.set_stylebox("separator", "VSeparator", vrule)
	t.set_stylebox("panel", "TooltipPanel", _glow(_flat(Color(0.05, 0.07, 0.11, 0.97), Color(IRON, 0.9), 1, 9, Vector2(12, 9)), Color(INK, 0.5), 6))
	t.set_color("font_color", "TooltipLabel", TEXT)
	t.set_font_size("font_size", "TooltipLabel", 13)
	# Check boxes and sliders (the help panel and the Settings tab).
	t.set_font_size("font_size", "CheckBox", 14)
	t.set_color("font_color", "CheckBox", TEXT)
	t.set_color("font_hover_color", "CheckBox", Color(1, 1, 1))
	t.set_color("font_pressed_color", "CheckBox", TEXT)
	t.set_color("font_hover_pressed_color", "CheckBox", Color(1, 1, 1))
	t.set_color("font_focus_color", "CheckBox", TEXT)
	t.set_constant("h_separation", "CheckBox", 8)
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		t.set_stylebox(state, "CheckBox", _flat(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0, Vector2(4, 4)))
	var unchecked := _check_icon(false)
	var checked := _check_icon(true)
	for name in ["unchecked", "radio_unchecked", "unchecked_disabled", "radio_unchecked_disabled"]:
		t.set_icon(name, "CheckBox", unchecked)
	for name in ["checked", "radio_checked", "checked_disabled", "radio_checked_disabled"]:
		t.set_icon(name, "CheckBox", checked)
	t.set_stylebox("slider", "HSlider", _track(4))
	t.set_stylebox("grabber_area", "HSlider", _fill(ICE_DIM, 4))
	t.set_stylebox("grabber_area_highlight", "HSlider", _fill(ICE, 4))
	t.set_constant("center_grabber", "HSlider", 0)
	t.set_constant("grabber_offset", "HSlider", 0)

	t.set_constant("separation", "VBoxContainer", 6)
	t.set_constant("separation", "HBoxContainer", 6)
	t.set_constant("h_separation", "GridContainer", 5)
	t.set_constant("v_separation", "GridContainer", 5)
	return t


# --- Fonts ------------------------------------------------------------------------------

## Cinzel at a weight (400-900) with extra letter spacing, for display text.
static func font_cinzel(weight: int, spacing: int = 1) -> FontVariation:
	return _font("cinzel", FONT_CINZEL, weight, spacing)


## Inter at a weight (100-900), for body text, buttons and numbers.
static func font_inter(weight: int) -> FontVariation:
	return _font("inter", FONT_INTER, weight, 0)


static func _font(family: String, path: String, weight: int, spacing: int) -> FontVariation:
	var key := "%s:%d:%d" % [family, weight, spacing]
	if not _fonts.has(key):
		var fv := FontVariation.new()
		fv.base_font = load(path)
		var tag := TextServerManager.get_primary_interface().name_to_tag("weight")
		fv.variation_opentype = {tag: weight}
		fv.spacing_glyph = spacing
		_fonts[key] = fv
	return _fonts[key]


# --- Widgets --------------------------------------------------------------------------

## A Cinzel heading label.
static func heading(text: String, size: int = 16, colour: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = "Heading"
	l.add_theme_font_size_override("font_size", size)
	if colour != TEXT:
		l.add_theme_color_override("font_color", colour)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## An Inter body label.
static func body(text: String, size: int = 14, colour: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	if colour != TEXT:
		l.add_theme_color_override("font_color", colour)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## A quieter body label for notes and secondary lines.
static func muted(text: String, size: int = 13) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = "Muted"
	l.add_theme_font_size_override("font_size", size)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## A body label that wraps at `width` pixels.
static func wrapped(text: String, width: float, size: int = 14, colour: Color = TEXT) -> Label:
	var l := body(text, size, colour)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(width, 0)
	return l


## A framed, frosted panel in a colour key: PANEL_SLATE, PANEL_DANGER, PANEL_ICE or
## PANEL_EMBER. The frame (timber and iron, the UI board's pick) is drawn in code.
static func panel_style(kind: String = PANEL_SLATE) -> StyleBoxTexture:
	if not _frames.has(kind):
		var fill := SLATE
		var glow := ICE
		match kind:
			PANEL_DANGER:
				fill = Color(0.13, 0.05, 0.07, 0.92)
				glow = Color(1.0, 0.5, 0.45)
			PANEL_ICE:
				fill = Color(0.05, 0.09, 0.15, 0.92)
				glow = Color(0.78, 0.90, 1.0)
			PANEL_EMBER:
				fill = Color(0.12, 0.08, 0.06, 0.92)
				glow = EMBER
		var sb := StyleBoxTexture.new()
		sb.texture = ImageTexture.create_from_image(_frame_image(fill, glow))
		sb.texture_margin_left = FRAME_MARGIN
		sb.texture_margin_top = FRAME_MARGIN
		sb.texture_margin_right = FRAME_MARGIN
		sb.texture_margin_bottom = FRAME_MARGIN
		sb.content_margin_left = 16
		sb.content_margin_right = 16
		sb.content_margin_top = 14
		sb.content_margin_bottom = 14
		_frames[kind] = sb
	return _frames[kind]


## A panel's title strip: the heading on the left and, when `on_close` is given, a close
## cross on the right. The title Label is kept in the "title" metadata for retitling.
static func header(title: String, on_close: Callable = Callable()) -> PanelContainer:
	var bar := PanelContainer.new()
	bar.theme_type_variation = "HeaderBar"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	bar.add_child(row)
	var label := heading(title, 15)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(label)
	bar.set_meta("title", label)
	if on_close.is_valid():
		var b := Button.new()
		b.theme_type_variation = "CloseButton"
		b.icon = icon("cross", 11)
		b.tooltip_text = "Close"
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.pressed.connect(on_close)
		row.add_child(b)
	return bar


## A round tinted badge with an icon-table glyph on it, `px` wide. The glyph is white and
## fills about two thirds of the badge, so every badge reads as one family.
static func badge(key: String, px: int = 28, tint: Variant = null) -> Control:
	var colour: Color = tint if tint != null else IconTable.tint(key)
	var b := PanelContainer.new()
	b.custom_minimum_size = Vector2(px, px)
	b.add_theme_stylebox_override("panel", badge_style(colour, px))
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pic := TextureRect.new()
	pic.texture = IconTable.texture(key)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(pic)
	return b


## The round badge behind a glyph: the tint with a lighter rim and a dark shadow beneath.
static func badge_style(colour: Color, px: int) -> StyleBoxFlat:
	var inset := maxi(3, px / 6)
	var s := _flat(colour, Color(colour.lightened(0.35), 0.9), 1, px / 2, Vector2(inset, inset))
	s.shadow_color = Color(INK, 0.45)
	s.shadow_size = 2
	s.shadow_offset = Vector2(0, 1)
	return s


## A list row's own backing, clear until the caller colours its `bg_color` and
## `border_color` (the Upgrades tab's can-build-now highlight and its flash). A fresh box per
## row, so recolouring one row leaves the rest alone.
static func row_style() -> StyleBoxFlat:
	return _flat(Color(TIMBER, 0.0), Color(IRON_DARK, 0.0), 1, 6, Vector2(8, 6))


## A Kenney game icon (white, 2x) scaled down to `px` for a button.
static func icon(name: String, px: int = 16) -> Texture2D:
	var key := "%s:%d" % [name, px]
	if not _icons.has(key):
		var tex: Texture2D = load(ICON_DIR + name + ".png")
		var img := tex.get_image()
		img.convert(Image.FORMAT_RGBA8)
		img.resize(px, px, Image.INTERPOLATE_LANCZOS)
		_icons[key] = ImageTexture.create_from_image(img)
	return _icons[key]


## Restyles the status label main.tscn keeps under the HUD layer: Inter with a dark outline
## so it reads over snow. GameRoot calls this once.
static func style_hud_label(label: Label, role: String) -> void:
	label.theme = theme()
	match role:
		"status":
			label.add_theme_font_override("font", font_inter(600))
			label.add_theme_font_size_override("font_size", 15)
			label.add_theme_color_override("font_color", TEXT)
			label.add_theme_color_override("font_outline_color", Color(INK, 0.9))
			label.add_theme_constant_override("outline_size", 5)
		_:
			label.add_theme_font_override("font", font_inter(500))
			label.add_theme_font_size_override("font_size", 13)
			label.add_theme_color_override("font_color", Color(0.82, 0.88, 0.96))
			label.add_theme_color_override("font_outline_color", Color(INK, 0.85))
			label.add_theme_constant_override("outline_size", 4)


# --- Style builders ---------------------------------------------------------------------

static func _flat(bg: Color, border: Color, width: int, radius: int, margin: Vector2) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(radius)
	s.content_margin_left = margin.x
	s.content_margin_right = margin.x
	s.content_margin_top = margin.y
	s.content_margin_bottom = margin.y
	s.anti_aliasing = true
	return s


static func _glow(s: StyleBoxFlat, colour: Color, size: int) -> StyleBoxFlat:
	s.shadow_color = colour
	s.shadow_size = size
	s.shadow_offset = Vector2.ZERO
	return s


## A gauge's inner track.
static func _track(radius: int) -> StyleBoxFlat:
	return _flat(SLATE_DEEP, Color(IRON, 0.5), 1, radius, Vector2(1, 1))


## A gauge's fill, with a lighter line along the top as a highlight.
static func _fill(colour: Color, radius: int) -> StyleBoxFlat:
	var s := _flat(colour, colour.lightened(0.35), 0, radius, Vector2(0, 0))
	s.border_width_top = 1
	s.border_blend = true
	s.shadow_color = Color(colour, 0.25)
	s.shadow_size = 2
	s.shadow_offset = Vector2.ZERO
	return s


## A check box's square: an iron-rimmed well, filled with ice when checked.
static func _check_icon(on: bool) -> Texture2D:
	var n := 18
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var edge := x == 0 or y == 0 or x == n - 1 or y == n - 1
			var corner := (x == 0 or x == n - 1) and (y == 0 or y == n - 1)
			var c := Color(0, 0, 0, 0)
			if corner:
				c = Color(0, 0, 0, 0)
			elif edge:
				c = IRON
			elif on and x >= 4 and x < n - 4 and y >= 4 and y < n - 4:
				c = ICE
			else:
				c = SLATE_DEEP
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


# --- The frame --------------------------------------------------------------------------

## The 9-slice frame art, drawn from a signed distance to a rounded box: a timber band along
## the edge with iron rivets in its corners, an iron line inside it, and the frosted fill
## with a soft glow fading inward from the band.
static func _frame_image(fill: Color, glow: Color) -> Image:
	var n := FRAME_PX
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var radius := 12.0
	var band := 6.0
	var line := 2.0
	var glow_len := 14.0
	var glow_strength := 0.34
	var band_colour := TIMBER
	var band_edge := TIMBER_LIGHT
	var half := n * 0.5
	for y in n:
		for x in n:
			var p := Vector2(x + 0.5 - half, y + 0.5 - half)
			var q := Vector2(absf(p.x), absf(p.y)) - Vector2(half - radius, half - radius)
			var d := Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - radius
			var coverage := clampf(0.5 - d, 0.0, 1.0)  # antialiased outer edge
			if coverage <= 0.0:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var depth := -d  # pixels inside the outer edge
			var c: Color
			if depth < band:
				# The band: lighter toward its outer edge, with a faint grain.
				var t := clampf(depth / band, 0.0, 1.0)
				c = band_edge.lerp(band_colour, t)
				c = c.darkened(0.08 * (0.5 + 0.5 * sin((x + y) * 1.7)))
				c.a = 1.0
			elif depth < band + line:
				c = IRON
			else:
				var inside := depth - band - line
				var g := exp(-inside / glow_len) * glow_strength
				c = fill.lerp(Color(glow, fill.a), g)
				c.a = fill.a + (1.0 - fill.a) * g * 0.5
			if depth < band + 1.0:
				# Iron rivets in the corners of the band.
				var corner := Vector2(absf(p.x), absf(p.y)) - Vector2(half - radius * 0.9, half - radius * 0.9)
				if corner.length() < 2.6:
					c = IRON.lightened(0.2)
			c.a *= coverage
			img.set_pixel(x, y, c)
	return img
