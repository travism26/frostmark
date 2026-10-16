## Placeholder scene for the walking skeleton: a snow plane, a light, a fixed camera
## and a title label, so a loaded page is unmistakable.
extends Node3D

@onready var _title: Label = $HUD/Title


func _ready() -> void:
	_title.text = "Frostmark v%s" % ProjectSettings.get_setting("application/config/version")
