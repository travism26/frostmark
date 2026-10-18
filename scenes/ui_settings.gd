## The player's interface settings: UI scale, reduced motion and auto-retaliate. They live in the same
## browser-local file as the sound settings (`user://frostmark_settings.cfg`, IndexedDB in the
## browser) under their own section, so they survive a reload and never travel inside a save
## code: they are browser preferences, not progress. `apply()` scales the window's content.
##
## `reduced_motion` is the one key the atmosphere (snowfall density, the frost vignette's
## pulse, the pines' sway) reads through AudioSettings as well, so it lives in that section
## and both stores see the same value. Presentation-side on purpose: the simulation never
## hears about the first two. `auto_retaliate` is a play preference rather than progress, so
## it is stored here too and handed to each sim with `set_auto_retaliate`, never saved in it.
class_name UiSettings
extends RefCounted

const PATH := AudioSettings.PATH
const SECTION := "ui"
const KEY_SCALE := "ui_scale"
const KEY_REDUCED_MOTION := "reduced_motion"
const KEY_AUTO_RETALIATE := "auto_retaliate"

## The three scales the Settings tab offers: 90%, 100% and 125%.
const SCALES: Array[float] = [0.9, 1.0, 1.25]
const DEFAULT_SCALE := 1.0

var ui_scale := DEFAULT_SCALE
var reduced_motion := false
var auto_retaliate := true  # fight back when hit while standing still


## The settings stored at `path`, or the defaults when there are none or they are unreadable.
## A scale that is not one of SCALES snaps to the nearest.
static func load_from(path := PATH) -> UiSettings:
	var settings := UiSettings.new()
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return settings
	settings.ui_scale = nearest_scale(float(cfg.get_value(SECTION, KEY_SCALE, DEFAULT_SCALE)))
	settings.reduced_motion = bool(cfg.get_value(AudioSettings.SECTION, KEY_REDUCED_MOTION, false))
	settings.auto_retaliate = bool(cfg.get_value(SECTION, KEY_AUTO_RETALIATE, true))
	return settings


## Writes these settings, keeping whatever else the file holds (the sound section).
func save_to(path := PATH) -> bool:
	var cfg := ConfigFile.new()
	cfg.load(path)  # a missing or unreadable file starts fresh
	cfg.set_value(SECTION, KEY_SCALE, ui_scale)
	cfg.set_value(AudioSettings.SECTION, KEY_REDUCED_MOTION, reduced_motion)
	cfg.set_value(SECTION, KEY_AUTO_RETALIATE, auto_retaliate)
	return cfg.save(path) == OK


## Whether the player asked for reduced motion: the one call the snowfall, the screen shake
## and the frost vignette make.
static func reduced_motion_on(path := PATH) -> bool:
	return load_from(path).reduced_motion


## The offered scale nearest to `value`.
static func nearest_scale(value: float) -> float:
	var best := DEFAULT_SCALE
	for s in SCALES:
		if absf(s - value) < absf(best - value):
			best = s
	return best


## Scales every canvas item in the window; the 3D view is unaffected.
func apply(window: Window) -> void:
	window.content_scale_factor = ui_scale
