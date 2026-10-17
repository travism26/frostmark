## Frostmark's one look for every screen: frosted dark-slate panels with an ice-blue edge,
## Cinzel headings, Inter body text, an ember accent for warmth and fire and a cold red for
## health and danger. Everything is built in code from the CC0 Kenney border art and the
## two OFL fonts under assets/, so there is no .tres to keep in step.
##
## `theme()` returns the one cached Theme; each root Control sets it in `_ready`. The rest
## are small helpers for widgets the Theme cannot express on its own: framed panels in a
## colour key, headings and body labels, icons scaled to a size, and the three labels that
## live in main.tscn (`style_hud_label`).
class_name UiTheme
extends RefCounted

# --- Palette --------------------------------------------------------------------------

## Panel fill: frosted slate that still lets a little of the snow through.
const SLATE := Color(0.07, 0.10, 0.15, 0.88)
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

const FONT_CINZEL := "res://assets/fonts/Cinzel[wght].ttf"
const FONT_INTER := "res://assets/fonts/Inter[opsz,wght].ttf"
const FRAME_ART := "res://assets/ui/kenney_fantasy_ui_borders/panel-border-014.png"
const ICON_DIR := "res://assets/ui/kenney_game_icons/"
## The frame art is 48 px with its corner detail inside 12 px.
const FRAME_MARGIN := 12

## Panel colour keys for `panel_style(kind)`.
const PANEL_SLATE := "panel"
const PANEL_DANGER := "danger"
const PANEL_ICE := "ice"
const PANEL_EMBER := "ember"

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
	t.set_type_variation("OnBar", "Label")  # text printed over a gauge
	t.set_font("font", "OnBar", font_inter(600))
	t.set_font_size("font_size", "OnBar", 12)
	t.set_color("font_color", "OnBar", TEXT)
	t.set_color("font_outline_color", "OnBar", Color(INK, 0.9))
	t.set_constant("outline_size", "OnBar", 4)
	t.set_type_variation("Banner", "Label")
	t.set_font("font", "Banner", font_cinzel(700, 2))
	t.set_font_size("font_size", "Banner", 26)
	t.set_color("font_color", "Banner", TEXT)
	t.set_color("font_outline_color", "Banner", Color(INK, 0.85))
	t.set_constant("outline_size", "Banner", 4)
	t.set_stylebox("normal", "Banner", _flat(Color(INK, 0.62), Color(ICE, 0.35), 1, 8, Vector2(18, 8)))
	t.set_type_variation("LevelBadge", "Label")
	t.set_font("font", "LevelBadge", font_cinzel(800, 0))
	t.set_font_size("font_size", "LevelBadge", 12)
	t.set_color("font_color", "LevelBadge", INK)
	t.set_stylebox("normal", "LevelBadge", _flat(ICE, Color(1, 1, 1, 0.5), 1, 9, Vector2(6, 0)))
	t.set_type_variation("CountBadge", "Label")
	t.set_font("font", "CountBadge", font_inter(700))
	t.set_font_size("font_size", "CountBadge", 11)
	t.set_color("font_color", "CountBadge", TEXT)
	t.set_stylebox("normal", "CountBadge", _flat(Color(INK, 0.85), Color(ICE, 0.45), 1, 6, Vector2(5, 0)))
	t.set_type_variation("Flash", "Label")  # the "Saved" flash
	t.set_font("font", "Flash", font_cinzel(700, 1))
	t.set_font_size("font_size", "Flash", 14)
	t.set_color("font_color", "Flash", ICE)
	t.set_stylebox("normal", "Flash", _flat(Color(INK, 0.7), Color(ICE, 0.5), 1, 6, Vector2(12, 4)))

	# Buttons: Cinzel labels, four clear states, disabled visibly dimmer.
	t.set_font("font", "Button", font_cinzel(600, 1))
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
	t.set_stylebox("normal", "Button", _flat(SLATE_RAISED, Color(ICE, 0.55), 1, 5, Vector2(14, 7)))
	t.set_stylebox("hover", "Button", _glow(_flat(Color(0.19, 0.28, 0.40, 0.98), Color(ICE, 0.95), 1, 5, Vector2(14, 7)), Color(ICE, 0.35), 4))
	t.set_stylebox("pressed", "Button", _flat(Color(0.06, 0.10, 0.16, 0.98), ICE, 1, 5, Vector2(14, 7)))
	t.set_stylebox("hover_pressed", "Button", _flat(Color(0.06, 0.10, 0.16, 0.98), ICE, 1, 5, Vector2(14, 7)))
	t.set_stylebox("disabled", "Button", _flat(Color(0.07, 0.09, 0.13, 0.55), Color(ICE_DIM, 0.22), 1, 5, Vector2(14, 7)))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())

	t.set_type_variation("PrimaryButton", "Button")
	t.set_font_size("font_size", "PrimaryButton", 17)
	t.set_stylebox("normal", "PrimaryButton", _flat(Color(0.17, 0.32, 0.48, 0.98), Color(ICE, 0.85), 1, 6, Vector2(20, 10)))
	t.set_stylebox("hover", "PrimaryButton", _glow(_flat(Color(0.24, 0.42, 0.62, 1.0), Color(1, 1, 1, 0.9), 1, 6, Vector2(20, 10)), Color(ICE, 0.45), 6))
	t.set_stylebox("pressed", "PrimaryButton", _flat(Color(0.10, 0.20, 0.32, 1.0), ICE, 1, 6, Vector2(20, 10)))
	t.set_stylebox("hover_pressed", "PrimaryButton", _flat(Color(0.10, 0.20, 0.32, 1.0), ICE, 1, 6, Vector2(20, 10)))
	t.set_stylebox("disabled", "PrimaryButton", _flat(Color(0.07, 0.09, 0.13, 0.55), Color(ICE_DIM, 0.22), 1, 6, Vector2(20, 10)))

	t.set_type_variation("DangerButton", "Button")
	t.set_font_size("font_size", "DangerButton", 17)
	t.set_stylebox("normal", "DangerButton", _flat(Color(0.36, 0.11, 0.14, 0.98), Color(1.0, 0.55, 0.5, 0.8), 1, 6, Vector2(20, 10)))
	t.set_stylebox("hover", "DangerButton", _glow(_flat(Color(0.50, 0.16, 0.20, 1.0), Color(1.0, 0.75, 0.7), 1, 6, Vector2(20, 10)), Color(1.0, 0.4, 0.4, 0.4), 6))
	t.set_stylebox("pressed", "DangerButton", _flat(Color(0.22, 0.07, 0.09, 1.0), Color(1.0, 0.6, 0.55), 1, 6, Vector2(20, 10)))
	t.set_stylebox("hover_pressed", "DangerButton", _flat(Color(0.22, 0.07, 0.09, 1.0), Color(1.0, 0.6, 0.55), 1, 6, Vector2(20, 10)))
	t.set_color("font_pressed_color", "DangerButton", Color(1.0, 0.7, 0.65))
	t.set_color("font_hover_pressed_color", "DangerButton", Color(1.0, 0.7, 0.65))

	# The Light fire button: its flame glows ember while a fire can be lit.
	t.set_type_variation("FireButton", "Button")
	t.set_color("icon_normal_color", "FireButton", EMBER)
	t.set_color("icon_hover_color", "FireButton", Color(1.0, 0.78, 0.4))
	t.set_color("icon_pressed_color", "FireButton", Color(1.0, 0.5, 0.15))
	t.set_color("icon_hover_pressed_color", "FireButton", Color(1.0, 0.5, 0.15))
	t.set_color("icon_focus_color", "FireButton", EMBER)
	t.set_color("icon_disabled_color", "FireButton", Color(0.55, 0.42, 0.32, 0.5))

	# Inventory cells: a dark inset with a light border, a glow on hover.
	t.set_type_variation("SlotButton", "Button")
	t.set_font("font", "SlotButton", font_inter(500))
	t.set_font_size("font_size", "SlotButton", 12)
	t.set_color("font_disabled_color", "SlotButton", TEXT_DIM)
	t.set_stylebox("normal", "SlotButton", _flat(SLATE_DEEP, Color(ICE, 0.38), 1, 4, Vector2(4, 4)))
	t.set_stylebox("hover", "SlotButton", _glow(_flat(Color(0.09, 0.14, 0.21, 0.96), Color(ICE, 0.95), 1, 4, Vector2(4, 4)), Color(ICE, 0.4), 4))
	t.set_stylebox("pressed", "SlotButton", _flat(Color(0.16, 0.26, 0.38, 0.98), ICE, 1, 4, Vector2(4, 4)))
	t.set_stylebox("hover_pressed", "SlotButton", _flat(Color(0.16, 0.26, 0.38, 0.98), ICE, 1, 4, Vector2(4, 4)))
	t.set_stylebox("disabled", "SlotButton", _flat(Color(0.035, 0.055, 0.09, 0.6), Color(ICE, 0.18), 1, 4, Vector2(4, 4)))

	# The close cross in a panel's header bar.
	t.set_type_variation("CloseButton", "Button")
	t.set_stylebox("normal", "CloseButton", _flat(Color(0, 0, 0, 0), Color(ICE, 0.3), 1, 4, Vector2(5, 5)))
	t.set_stylebox("hover", "CloseButton", _flat(Color(0.55, 0.16, 0.2, 0.9), Color(1.0, 0.6, 0.55), 1, 4, Vector2(5, 5)))
	t.set_stylebox("pressed", "CloseButton", _flat(Color(0.35, 0.08, 0.1, 0.95), Color(1.0, 0.6, 0.55), 1, 4, Vector2(5, 5)))
	t.set_stylebox("hover_pressed", "CloseButton", _flat(Color(0.35, 0.08, 0.1, 0.95), Color(1.0, 0.6, 0.55), 1, 4, Vector2(5, 5)))
	t.set_color("icon_normal_color", "CloseButton", TEXT_DIM)
	t.set_color("icon_hover_color", "CloseButton", Color(1, 1, 1))

	# Panels: the framed slate by default, a flat tinted strip for header bars.
	t.set_stylebox("panel", "PanelContainer", panel_style(PANEL_SLATE))
	t.set_type_variation("HeaderBar", "PanelContainer")
	var header := _flat(Color(ICE, 0.10), Color(ICE, 0.45), 0, 4, Vector2(10, 6))
	header.border_width_bottom = 1
	t.set_stylebox("panel", "HeaderBar", header)
	t.set_type_variation("Inset", "PanelContainer")
	t.set_stylebox("panel", "Inset", _flat(SLATE_DEEP, Color(ICE, 0.22), 1, 5, Vector2(10, 8)))

	# Gauges: a dark rounded track, a rounded fill with a highlight along its top edge.
	t.set_stylebox("background", "ProgressBar", _track(6))
	t.set_stylebox("fill", "ProgressBar", _fill(ICE, 6))
	t.set_type_variation("WarmthBar", "ProgressBar")
	t.set_stylebox("background", "WarmthBar", _track(7))
	t.set_stylebox("fill", "WarmthBar", _fill(EMBER, 7))
	t.set_type_variation("HealthBar", "ProgressBar")
	t.set_stylebox("background", "HealthBar", _track(7))
	t.set_stylebox("fill", "HealthBar", _fill(BLOOD, 7))
	t.set_type_variation("XpBar", "ProgressBar")
	t.set_stylebox("background", "XpBar", _track(3))
	t.set_stylebox("fill", "XpBar", _fill(XP, 3))

	# Text fields (the save code).
	var field := _flat(SLATE_DEEP, Color(ICE, 0.35), 1, 5, Vector2(8, 6))
	t.set_stylebox("normal", "TextEdit", field)
	t.set_stylebox("read_only", "TextEdit", field)
	t.set_stylebox("focus", "TextEdit", _glow(_flat(SLATE_DEEP, Color(ICE, 0.9), 1, 5, Vector2(8, 6)), Color(ICE, 0.3), 3))
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
	rule.color = Color(ICE, 0.22)
	rule.thickness = 1
	rule.grow_begin = 0
	rule.grow_end = 0
	t.set_stylebox("separator", "HSeparator", rule)
	t.set_constant("separation", "HSeparator", 10)
	var vrule := StyleBoxLine.new()
	vrule.color = Color(ICE, 0.22)
	vrule.thickness = 1
	vrule.vertical = true
	t.set_stylebox("separator", "VSeparator", vrule)
	t.set_stylebox("panel", "TooltipPanel", _flat(Color(0.04, 0.06, 0.10, 0.96), Color(ICE, 0.6), 1, 5, Vector2(10, 6)))
	t.set_color("font_color", "TooltipLabel", TEXT)
	t.set_font_size("font_size", "TooltipLabel", 13)
	t.set_constant("separation", "VBoxContainer", 6)
	t.set_constant("separation", "HBoxContainer", 6)
	t.set_constant("h_separation", "GridContainer", 5)
	t.set_constant("v_separation", "GridContainer", 5)
	return t


# --- Fonts ------------------------------------------------------------------------------

## Cinzel at a weight (400-900) with extra letter spacing, for display text.
static func font_cinzel(weight: int, spacing: int = 1) -> FontVariation:
	return _font("cinzel", FONT_CINZEL, weight, spacing)


## Inter at a weight (100-900), for body text and numbers.
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


## A framed, frosted panel in a colour key: PANEL_SLATE, PANEL_DANGER, PANEL_ICE or
## PANEL_EMBER. The Kenney border art is composed over the fill at build time.
static func panel_style(kind: String = PANEL_SLATE) -> StyleBoxTexture:
	if not _frames.has(kind):
		var fill := SLATE
		var edge := Color(ICE, 0.92)
		match kind:
			PANEL_DANGER:
				fill = Color(0.13, 0.05, 0.07, 0.90)
				edge = Color(1.0, 0.5, 0.45, 0.92)
			PANEL_ICE:
				fill = Color(0.05, 0.09, 0.15, 0.90)
				edge = Color(0.78, 0.90, 1.0, 0.95)
			PANEL_EMBER:
				fill = Color(0.12, 0.08, 0.06, 0.90)
				edge = Color(EMBER, 0.92)
		var sb := StyleBoxTexture.new()
		sb.texture = _framed_texture(fill, edge)
		sb.texture_margin_left = FRAME_MARGIN
		sb.texture_margin_top = FRAME_MARGIN
		sb.texture_margin_right = FRAME_MARGIN
		sb.texture_margin_bottom = FRAME_MARGIN
		sb.content_margin_left = 16
		sb.content_margin_right = 16
		sb.content_margin_top = 14
		sb.content_margin_bottom = 14
		sb.modulate_color = Color(1, 1, 1)
		_frames[kind] = sb
	return _frames[kind]


## A round coloured badge with one letter in it, for skills the icon pack has no glyph for.
static func letter_badge(letter: String, colour: Color, px: int = 22) -> Label:
	var l := Label.new()
	l.text = letter
	l.theme_type_variation = "LevelBadge"
	l.custom_minimum_size = Vector2(px, px)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", int(px * 0.55))
	l.add_theme_stylebox_override("normal", _flat(colour, Color(1, 1, 1, 0.55), 1, px / 2, Vector2(0, 0)))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## A Kenney game icon (white, 2x) scaled down to `px` for a button or badge.
static func icon(name: String, px: int = 16) -> Texture2D:
	var key := "%s:%d" % [name, px]
	if not _icons.has(key):
		var img: Image
		if name == "flame":
			img = _flame_image(px * 2)
		else:
			var tex: Texture2D = load(ICON_DIR + name + ".png")
			img = tex.get_image()
			img.convert(Image.FORMAT_RGBA8)
		img.resize(px, px, Image.INTERPOLATE_LANCZOS)
		_icons[key] = ImageTexture.create_from_image(img)
	return _icons[key]


## Restyles one of the three labels main.tscn keeps under the HUD layer. Roles: "title"
## (Cinzel with a soft ice glow), "status" and "hint" (Inter with a dark outline so they
## read over snow). GameRoot calls this once per label.
static func style_hud_label(label: Label, role: String) -> void:
	label.theme = theme()
	match role:
		"title":
			label.add_theme_font_override("font", font_cinzel(700, 3))
			label.add_theme_font_size_override("font_size", 26)
			label.add_theme_color_override("font_color", TEXT)
			label.add_theme_color_override("font_outline_color", Color(INK, 0.85))
			label.add_theme_constant_override("outline_size", 5)
			label.add_theme_color_override("font_shadow_color", Color(ICE, 0.45))
			label.add_theme_constant_override("shadow_outline_size", 10)
			label.add_theme_constant_override("shadow_offset_x", 0)
			label.add_theme_constant_override("shadow_offset_y", 0)
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
	var s := _flat(SLATE_DEEP, Color(ICE, 0.28), 1, radius, Vector2(1, 1))
	return s


## A gauge's fill, with a lighter line along the top as a highlight.
static func _fill(colour: Color, radius: int) -> StyleBoxFlat:
	var s := _flat(colour, colour.lightened(0.35), 0, radius, Vector2(0, 0))
	s.border_width_top = 1
	s.border_blend = true
	s.shadow_color = Color(colour, 0.25)
	s.shadow_size = 2
	s.shadow_offset = Vector2.ZERO
	return s


## The border art composed over a fill: border pixels take the edge colour, pixels inside
## the frame take the fill, the seam between the two lines a thinner fill, and pixels
## outside the frame stay clear so the corners keep their notches.
static func _framed_texture(fill: Color, edge: Color) -> ImageTexture:
	var art: Texture2D = load(FRAME_ART)
	var src := art.get_image()
	src.convert(Image.FORMAT_RGBA8)
	var w := src.get_width()
	var h := src.get_height()
	var cls := PackedByteArray()  # 0 gap, 1 line, 2 outside, 3 inside
	cls.resize(w * h)
	for y in h:
		for x in w:
			cls[y * w + x] = 1 if src.get_pixel(x, y).a > 0.5 else 0
	for x in w:
		_flood(cls, w, h, x, 0, 2)
		_flood(cls, w, h, x, h - 1, 2)
	for y in h:
		_flood(cls, w, h, 0, y, 2)
		_flood(cls, w, h, w - 1, y, 2)
	_flood(cls, w, h, w / 2, h / 2, 3)
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var seam := Color(fill, fill.a * 0.6)
	for y in h:
		for x in w:
			match cls[y * w + x]:
				1:
					out.set_pixel(x, y, Color(edge, edge.a * src.get_pixel(x, y).a))
				2:
					out.set_pixel(x, y, Color(0, 0, 0, 0))
				3:
					out.set_pixel(x, y, fill)
				_:
					out.set_pixel(x, y, seam)
	return ImageTexture.create_from_image(out)


static func _flood(cls: PackedByteArray, w: int, h: int, sx: int, sy: int, mark: int) -> void:
	if cls[sy * w + sx] != 0:
		return
	var stack := PackedInt32Array([sy * w + sx])
	cls[sy * w + sx] = mark
	while not stack.is_empty():
		var i := stack[stack.size() - 1]
		stack.resize(stack.size() - 1)
		var x := i % w
		var y := i / w
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx: int = x + d.x
			var ny: int = y + d.y
			if nx < 0 or ny < 0 or nx >= w or ny >= h:
				continue
			var j := ny * w + nx
			if cls[j] == 0:
				cls[j] = mark
				stack.append(j)


## A small white flame glyph, drawn in code because the icon pack has none. Supersampled
## so its edge is smooth at button size.
static func _flame_image(size: int) -> Image:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var ss := 3
	for y in size:
		for x in size:
			var hits := 0
			for sy in ss:
				for sx in ss:
					var u := (x + (sx + 0.5) / ss) / size
					var v := (y + (sy + 0.5) / ss) / size
					if _in_flame(u, v):
						hits += 1
			var a := float(hits) / float(ss * ss)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return img


## The flame in unit space: a round base with a tip that leans right, hollowed by a
## smaller flame so it reads as fire rather than a drop.
static func _in_flame(u: float, v: float) -> bool:
	var outer := _tongue(u, v, 0.5, 0.70, 0.27, 0.05, 0.17)
	var inner := _tongue(u, v, 0.5, 0.76, 0.12, 0.44, -0.06)
	return outer and not inner


## A circle of radius r at (cx, cy) with a tapered tongue rising from it to `top`.
static func _tongue(u: float, v: float, cx: float, cy: float, r: float, top: float, lean: float) -> bool:
	if Vector2(u - cx, v - cy).length() <= r:
		return true
	if v < top or v > cy:
		return false
	var t := (v - top) / (cy - top)  # 0 at the tip, 1 at the circle's centre line
	var half := r * pow(t, 0.75)
	var centre := cx + lean * (1.0 - t) * (1.0 - t)
	return absf(u - centre) <= half
