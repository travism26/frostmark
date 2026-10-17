## Browser-local persistence for the save code. `user://` is IndexedDB in a web export and
## the user data folder on desktop. The stored text is the same checksummed save code the
## player can export, so a damaged local save is caught exactly like a bad pasted code.
## Presentation-side on purpose: the simulation never touches the filesystem.
class_name SaveStore
extends RefCounted

const PATH := "user://frostmark.save"


static func has_save() -> bool:
	return FileAccess.file_exists(PATH)


## False when this browser will not keep `user://` past the page: IndexedDB is blocked (some
## private browsing) or unavailable. Writes still succeed in memory then, and vanish on reload.
static func persistent() -> bool:
	return OS.is_userfs_persistent()


static func read() -> String:
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return ""
	var text := f.get_as_text()
	f.close()
	return text


## True only when the code was written in full to storage that outlives the page. A full
## disk or quota shows up as a failed open or a short write.
static func write(code: String) -> bool:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		return false
	var ok := f.store_string(code) and f.get_error() == OK
	f.close()
	return ok and persistent()
