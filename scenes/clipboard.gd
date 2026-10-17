## Copies text to the system clipboard and says whether it worked. In the web export it goes
## through the browser's `navigator.clipboard.writeText`, which only works from a click (a
## user gesture) on a secure page and can be refused, so the answer arrives later through
## `done`. On desktop it is the engine clipboard and always works.
class_name Clipboard
extends RefCounted

# The browser holds these callbacks only weakly: keep them alive until the promise settles.
static var _pending: Array[JavaScriptObject] = []


## Calls `done.call(ok: bool)` once the copy has worked or failed.
static func copy(text: String, done: Callable) -> void:
	if not OS.has_feature("web"):
		DisplayServer.clipboard_set(text)
		done.call(true)
		return
	var navigator: Variant = JavaScriptBridge.get_interface("navigator")
	var api: Variant = navigator.clipboard if navigator != null else null
	if api == null:
		done.call(false)  # an insecure (http://) page or an old browser
		return
	var settled := func(ok: bool) -> void:
		_pending.clear()
		done.call(ok)
	var on_ok := JavaScriptBridge.create_callback(func(_args: Array) -> void: settled.call(true))
	var on_fail := JavaScriptBridge.create_callback(func(_args: Array) -> void: settled.call(false))
	_pending = [on_ok, on_fail]
	api.writeText(text).then(on_ok, on_fail)
