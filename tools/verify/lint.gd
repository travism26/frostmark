## Probe lint, run by tools/verify/drive.sh before each drive, inside the head copy:
##
##   godot --headless --path <copy> -s res://tools/verify/lint.gd -- res://tools/verify/probes/<probe>.gd
##
## Prints `LINT ok`, or one `LINT <problem>` line per problem and exits 1. A probe must parse,
## extend the probe base, load only from the allowed paths, and never touch the file system or
## start a process. `problems()` is the text half, a pure function the unit suite covers.
extends SceneTree

const BASE := "res://tools/verify/probe_base.gd"
## What a probe may load: the simulation, the scenes' pure functions, the test helpers and
## the save fixtures. Entries ending in `/` are folders.
const ALLOWED := [
	"res://sim/",
	"res://scenes/",
	"res://tests/sim_helpers.gd",
	"res://tests/play_bot.gd",
	"res://tests/fixtures/",
]
## Identifiers a probe must not use. `OS.execute` also covers `OS.execute_with_pipe`; the
## others are the remaining ways round the same rules (reading files, loading by a built
## path, starting a process).
const FORBIDDEN := ["FileAccess", "DirAccess", "OS.execute", "OS.create_process", "OS.create_instance", "OS.shell_open", "ResourceLoader"]


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1:
		printerr("usage: godot --headless -s res://tools/verify/lint.gd -- <probe path>")
		quit(2)
		return
	var source := FileAccess.get_file_as_string(args[0])
	var found := problems(source)
	if found.is_empty():
		var script := GDScript.new()
		script.source_code = source
		script.resource_path = args[0]
		if script.reload() != OK:
			found.append("the probe does not parse")
	for p in found:
		print("LINT " + p)
	if found.is_empty():
		print("LINT ok")
	quit(1 if found.size() > 0 else 0)


## The text rules, on the probe's source. Returns one line per problem; empty means clean.
static func problems(source: String) -> Array[String]:
	var out: Array[String] = []
	var scan := _scan(source)
	var code: String = scan["code"]
	var strings: Array = scan["strings"]

	var head := RegEx.create_from_string("^\\s*(?:@\\w+\\s*)*extends\\s+\\$S(\\d+)\\$\\s*(?:\\n|$)")
	var m := head.search(code)
	if m == null or strings[int(m.get_string(1))] != BASE:
		out.append("the probe must start with: extends \"%s\"" % BASE)

	for word in FORBIDDEN:
		if RegEx.create_from_string("\\b" + word.replace(".", "\\s*\\.\\s*")).search(code) != null:
			out.append("uses %s" % word)

	var loads := RegEx.create_from_string("\\b(?:pre)?load\\s*\\(([^)]*)\\)")
	var literal := RegEx.create_from_string("^\\s*\\$S(\\d+)\\$\\s*$")
	for call in loads.search_all(code):
		var arg := literal.search(call.get_string(1))
		if arg == null:
			out.append("loads a path that is not a plain string: %s" % call.get_string(0).strip_edges())
		elif not _allowed(strings[int(arg.get_string(1))]):
			out.append("loads a path off the allowed list: %s" % strings[int(arg.get_string(1))])

	# A path kept in a string and loaded elsewhere is caught here instead.
	for i in strings.size():
		var s: String = strings[i]
		if s.contains(":/") and s != BASE and not _allowed(s):
			out.append("names a path off the allowed list: %s" % s)
	return _unique(out)


static func _allowed(path: String) -> bool:
	for a: String in ALLOWED:
		if a.ends_with("/"):
			if path.begins_with(a) and path.length() > a.length():
				return true
		elif path == a:
			return true
	return false


## Splits GDScript source into its code, with comments dropped and each string literal
## replaced by `$S<n>$`, and the literals' contents. Covers '...', "...", the triple-quoted
## forms and the r / & / ^ prefixes (the prefix stays in the code, harmlessly).
static func _scan(source: String) -> Dictionary:
	var code := ""
	var strings: Array[String] = []
	var i := 0
	var n := source.length()
	while i < n:
		var c := source[i]
		if c == "#":
			while i < n and source[i] != "\n":
				i += 1
			continue
		if c == "\"" or c == "'":
			var raw := i > 0 and source[i - 1] == "r"
			var quote := c.repeat(3) if source.substr(i, 3) == c.repeat(3) else c
			i += quote.length()
			var text := ""
			while i < n and source.substr(i, quote.length()) != quote:
				if source[i] == "\\" and not raw and i + 1 < n:
					text += source.substr(i, 2)
					i += 2
					continue
				text += source[i]
				i += 1
			i += quote.length()
			code += "$S%d$" % strings.size()
			strings.append(text)
			continue
		code += c
		i += 1
	return {"code": code, "strings": strings}


static func _unique(lines: Array[String]) -> Array[String]:
	var out: Array[String] = []
	for l in lines:
		if not out.has(l):
			out.append(l)
	return out
