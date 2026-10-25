## Selftest fixture: refused by lint, it starts a process.
extends "res://tools/verify/probe_base.gd"


func run() -> void:
	var out := []
	grade("AC1", OS.execute("true", [], out) == 0, out)
