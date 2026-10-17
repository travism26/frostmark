## The player's sound settings: overall volume, music volume and mute, kept in their own
## file beside the save (`user://` is IndexedDB in the browser) so they survive a reload
## and never travel inside a save code. `apply()` sets the audio buses to match.
##
## Presentation-side on purpose: the simulation never hears about sound.
class_name AudioSettings
extends RefCounted

const PATH := "user://frostmark_settings.cfg"
const SECTION := "audio"

## The buses the director plays on. Music and Effects (with the beds) feed Master.
const BUS_MASTER := "Master"
const BUS_MUSIC := "Music"
const BUS_EFFECTS := "Effects"

const DEFAULT_VOLUME := 0.8
const DEFAULT_MUSIC := 0.6

var volume := DEFAULT_VOLUME  # 0..1, everything
var music := DEFAULT_MUSIC    # 0..1, the music under everything else
var muted := false


## The settings stored at `path`, or the defaults when there are none or they are unreadable.
static func load_from(path := PATH) -> AudioSettings:
	var settings := AudioSettings.new()
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return settings
	settings.volume = clampf(float(cfg.get_value(SECTION, "volume", DEFAULT_VOLUME)), 0.0, 1.0)
	settings.music = clampf(float(cfg.get_value(SECTION, "music", DEFAULT_MUSIC)), 0.0, 1.0)
	settings.muted = bool(cfg.get_value(SECTION, "muted", false))
	return settings


func save_to(path := PATH) -> bool:
	var cfg := ConfigFile.new()
	cfg.set_value(SECTION, "volume", volume)
	cfg.set_value(SECTION, "music", music)
	cfg.set_value(SECTION, "muted", muted)
	return cfg.save(path) == OK


## Sets the buses to these settings, making the Music and Effects buses if they are missing.
func apply() -> void:
	var master := AudioServer.get_bus_index(BUS_MASTER)
	AudioServer.set_bus_volume_db(master, linear_to_db(volume))
	AudioServer.set_bus_mute(master, muted or volume <= 0.0)
	var bus := ensure_bus(BUS_MUSIC)
	AudioServer.set_bus_volume_db(bus, linear_to_db(music))
	AudioServer.set_bus_mute(bus, music <= 0.0)
	ensure_bus(BUS_EFFECTS)


## The index of the named bus, added under Master when it does not exist yet.
static func ensure_bus(bus_name: String) -> int:
	var index := AudioServer.get_bus_index(bus_name)
	if index == -1:
		index = AudioServer.bus_count
		AudioServer.add_bus(index)
		AudioServer.set_bus_name(index, bus_name)
		AudioServer.set_bus_send(index, BUS_MASTER)
	return index
