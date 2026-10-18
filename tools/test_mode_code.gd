## Board-only, not shipped: writes the test-mode save code (docs/testing.md), the maxed
## character scenes/field_kit.gd builds, to tools/test_mode_code.txt.
##   godot --headless -s tools/test_mode_code.gd > /dev/null && cat tools/test_mode_code.txt
## Regenerate it whenever the save version changes; tests/test_test_mode.gd imports the file.
extends SceneTree

const CODE_PATH := "res://tools/test_mode_code.txt"


func _init() -> void:
	var code := FieldKit.code()
	if code.is_empty():
		push_error("the maxed snapshot did not restore")
		quit(1)
		return
	var file := FileAccess.open(CODE_PATH, FileAccess.WRITE)
	file.store_string(code + "\n")
	file.close()
	print("CODE test_mode %s" % code)
	quit(0)
