## Selftest fixture: a probe whose run() hits a script error before it grades anything.
extends "res://tools/verify/probe_base.gd"


func run() -> void:
	var missing = null
	missing.walk()
	grade("AC1", true, "never reached")
