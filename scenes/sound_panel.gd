## The sound panel: overall volume, music volume, mute, and the credit for every sound the
## game plays. Plain and functional in the HUD's own panel style; it emits `changed` and
## GameRoot hands the settings to the audio director, which applies and keeps them.
extends PanelContainer

signal changed(volume: float, music: float, muted: bool)

const Hud := preload("res://scenes/hud.gd")

var _volume: HSlider
var _music: HSlider
var _mute: CheckBox


func _ready() -> void:
	var look := Hud._panel_box()
	add_theme_stylebox_override("panel", look.get_theme_stylebox("panel"))
	look.free()
	set_anchors_preset(Control.PRESET_CENTER)
	custom_minimum_size = Vector2(560, 0)
	offset_left = -280
	offset_top = -200
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	add_child(box)
	var head := HBoxContainer.new()
	box.add_child(head)
	var title := Hud._text("Sound", 16)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var close := Button.new()
	close.text = "x"
	close.pressed.connect(func() -> void: visible = false)
	head.add_child(close)
	_volume = _slider(box, "Volume")
	_music = _slider(box, "Music")
	_mute = CheckBox.new()
	_mute.text = "Mute"
	_mute.add_theme_color_override("font_color", Hud.COLOR_TEXT)
	_mute.toggled.connect(func(_on: bool) -> void: _emit())
	box.add_child(_mute)
	box.add_child(Hud._text("Credits", 14))
	var credits := Hud._text("\n".join(AudioCues.CREDITS), 12)
	credits.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	credits.custom_minimum_size = Vector2(540, 0)
	box.add_child(credits)


## Shows the panel with the current settings, without echoing them back as a change.
func open(settings: AudioSettings) -> void:
	_volume.set_value_no_signal(settings.volume)
	_music.set_value_no_signal(settings.music)
	_mute.set_pressed_no_signal(settings.muted)
	visible = true


func _slider(box: VBoxContainer, text: String) -> HSlider:
	var row := HBoxContainer.new()
	box.add_child(row)
	var label := Hud._text(text, 13)
	label.custom_minimum_size = Vector2(80, 0)
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(func(_v: float) -> void: _emit())
	row.add_child(slider)
	return slider


func _emit() -> void:
	changed.emit(_volume.value, _music.value, _mute.button_pressed)
