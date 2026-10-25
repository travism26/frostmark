## Selftest fixture: one grade under a criterion's id and one under an id the verdict never reads.
extends "res://tools/verify/probe_base.gd"


func run() -> void:
	grade("AC1", true, "a criterion id")
	grade("AC1.part", true, "a part's own id")
