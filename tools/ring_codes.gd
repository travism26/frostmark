## Board-only, not shipped: prints a save code that puts a fresh character in each ring, for
## importing into a browser build to screenshot it. `ring_one_cold` is ring one with the
## warmth run low, for the frost vignette.
##   godot --headless -s tools/ring_codes.gd
extends SceneTree

const H := preload("res://tests/sim_helpers.gd")
const SPOTS := {
	"outpost": [0.5, 4.5], "inner_ring": [-1.5, 16.5], "ring_one": [-11.5, 36.5], "ring_two": [2.5, 71.5],
}

func _init() -> void:
	for ring in SPOTS:
		var sim := Sim.new()
		sim.command(SimVocab.NEW_CHARACTER, {"previous": ""})
		H.place(sim, SPOTS[ring])
		print("CODE %s %s" % [ring, sim.export_code()])
	var cold := Sim.new()
	cold.command(SimVocab.NEW_CHARACTER, {"previous": ""})
	H.place(cold, SPOTS["ring_one"])
	cold.state["warmth"] = 70
	print("CODE ring_one_cold %s" % cold.export_code())
	quit(0)
