## Selftest fixture: a well-formed probe that grades one sim and one data criterion.
extends "res://tools/verify/probe_base.gd"

const H := preload("res://tests/sim_helpers.gd")
const GameRootScript := preload("res://scenes/game_root.gd")


func run() -> void:
	var sim := Sim.new()
	var before: int = sim.snapshot()["warmth"]
	H.walk_to(sim, H.OUTSIDE)
	H.run(sim, 50)
	var after: int = sim.snapshot()["warmth"]
	grade("AC1", after < before, {"before": before, "after": after})
	var text := GameRootScript._returned_text({"kind": SimVocab.EV_RETURNED, "items": [], "newly_affordable": []})
	grade("AC2", text == "Home safe.", text)
