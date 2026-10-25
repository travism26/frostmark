## Selftest fixture: a probe that never returns, for drive's alarm to kill.
extends "res://tools/verify/probe_base.gd"


func run() -> void:
	var ticks := 0
	while true:
		ticks += 1
