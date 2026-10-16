## Browser-local persistence for the save code. `user://` is IndexedDB in a web export and
## the user data folder on desktop. The stored text is the same checksummed save code the
## player can export, so a damaged local save is caught exactly like a bad pasted code.
## Presentation-side on purpose: the simulation never touches the filesystem.
class_name SaveStore
extends RefCounted

const PATH := "user://frostmark.save"


static func has_save() -> bool:
	return FileAccess.file_exists(PATH)


static func read() -> String:
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return ""
	var text := f.get_as_text()
	f.close()
	return text


static func write(code: String) -> bool:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(code)
	f.close()
	return true
