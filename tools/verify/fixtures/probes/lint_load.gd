## Selftest fixture: refused by lint, it loads a script off the allowed list.
extends "res://tools/verify/probe_base.gd"


func run() -> void:
	var tool = load("res://tools/test_mode_code.gd")
	grade("AC1", tool != null, "loaded")
