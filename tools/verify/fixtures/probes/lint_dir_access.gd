## Selftest fixture: refused by lint, it lists a folder.
extends "res://tools/verify/probe_base.gd"


func run() -> void:
	grade("AC1", DirAccess.dir_exists_absolute("res://sim"), "listed")
