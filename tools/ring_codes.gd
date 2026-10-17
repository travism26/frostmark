## Board-only, not shipped: prints a save code that puts a fresh character in each ring, for
## importing into a browser build to screenshot it.
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
	quit(0)
