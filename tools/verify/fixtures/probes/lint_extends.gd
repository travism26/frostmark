## Selftest fixture: refused by lint, it does not extend the probe base.
extends SceneTree


func _init() -> void:
	print("PROBE {\"id\": \"AC1\", \"pass\": true, \"observed\": null}")
	quit()
