## Selftest fixture: refused by lint, it reads a file.
extends "res://tools/verify/probe_base.gd"


func run() -> void:
	grade("AC1", FileAccess.file_exists("res://project.godot"), "read")
