## Board-only, not shipped: prints a save code that puts a fresh character in each ring, for
## importing into a browser build to screenshot it. `ring_one_cold` is ring one with the
## warmth run low, for the frost vignette. tools/test_codes.gd lists the same codes.
##   godot --headless -s tools/ring_codes.gd
extends SceneTree

const H := preload("res://tests/sim_helpers.gd")
const SPOTS := {
	"outpost": [0.5, 4.5], "inner_ring": [-1.5, 16.5], "ring_one": [-11.5, 36.5], "ring_two": [2.5, 71.5],
	"ring_three": [-33.5, 136.5],
}
## The warmth `ring_one_cold` is left with.
const COLD_WARMTH := 70


func _init() -> void:
	var all := codes()
	for name in all:
		print("CODE %s %s" % [name, all[name]])
	quit(0)


## Every ring code by name, in the order printed.
static func codes() -> Dictionary:
	var all := {}
	for ring in SPOTS:
		all[ring] = _placed(SPOTS[ring])
	all["ring_one_cold"] = _placed(SPOTS["ring_one"], COLD_WARMTH)
	return all


static func _placed(spot: Array, warmth: int = -1) -> String:
	var sim := Sim.new()
	sim.command(SimVocab.NEW_CHARACTER, {"previous": ""})
	H.place(sim, spot)
	if warmth >= 0:
		sim.state["warmth"] = warmth
	return sim.export_code()
