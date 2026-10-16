## FROSTMARK headless unit-test runner (no framework).
##
##   godot --headless -s tests/run.gd            # run everything under tests/test_*.gd
##   godot --headless -s tests/run.gd -- sim     # only files whose name contains "sim"
##
## Discovers tests/test_*.gd; each `extends "res://tests/run.gd".TestCase` (a RefCounted)
## and its `test_*` methods run in declaration order.
## Assertions record failures instead of crashing; the run prints `PASS n / FAIL m`
## plus every failing assertion with file + method, and exits 1 on any failure.
##
## Tests drive the simulation through its command interface only: no scenes, nodes,
## rendering or input. The runner strips the project's autoloads in memory
## (project.godot is untouched) so nothing boots behind the tests.
## Presentation is covered by the headless smoke run of the main scene instead.
extends SceneTree

const TESTS_DIR := "res://tests"


## Base class for a test file. Subclasses declare `func test_<name>() -> void`.
class TestCase:
	extends RefCounted

	var _failures: Array[String] = []  # messages for the current method
	var _asserts := 0

	func _begin() -> void:
		_failures = []
		_asserts = 0

	func assert_true(cond: bool, msg: String = "") -> void:
		_asserts += 1
		if not cond:
			_failures.append("expected true" + (": " + msg if msg != "" else ""))

	func assert_false(cond: bool, msg: String = "") -> void:
		_asserts += 1
		if cond:
			_failures.append("expected false" + (": " + msg if msg != "" else ""))

	func assert_eq(a: Variant, b: Variant, msg: String = "") -> void:
		_asserts += 1
		if not is_same(a, b) and a != b:
			_failures.append("expected %s == %s" % [_repr(a), _repr(b)] + (": " + msg if msg != "" else ""))

	func assert_ne(a: Variant, b: Variant, msg: String = "") -> void:
		_asserts += 1
		if is_same(a, b) or a == b:
			_failures.append("expected %s != %s" % [_repr(a), _repr(b)] + (": " + msg if msg != "" else ""))

	func assert_almost_eq(a: float, b: float, eps: float = 0.0001, msg: String = "") -> void:
		_asserts += 1
		if absf(a - b) > eps:
			_failures.append("expected %s ≈ %s (±%s)" % [a, b, eps] + (": " + msg if msg != "" else ""))

	func _repr(v: Variant) -> String:
		return var_to_str(v) if v is String else str(v)


func _init() -> void:
	_strip_autoloads()
	var filter := ""
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		filter = args[0]
	var files := _discover(filter)
	if files.is_empty():
		printerr("[unit] no tests/test_*.gd files found" + (" matching '%s'" % filter if filter != "" else ""))
		quit(1)
		return

	var passed := 0
	var failed := 0
	var asserts := 0
	var report: Array[String] = []
	var t0 := Time.get_ticks_msec()

	for path in files:
		var script: Script = load(path)
		if script == null:
			failed += 1
			report.append("%s: failed to load" % path)
			continue
		var case = script.new()
		if not (case is TestCase):
			failed += 1
			report.append("%s: must extend the runner's TestCase" % path)
			continue
		for m in script.get_script_method_list():
			var name: String = m.name
			if not name.begins_with("test_"):
				continue
			case._begin()
			case.call(name)
			asserts += case._asserts
			if case._asserts == 0:
				case._failures.append("no assertions recorded (the method may have aborted on a runtime script error)")
			if case._failures.is_empty():
				passed += 1
			else:
				failed += 1
				for f in case._failures:
					report.append("%s %s: %s" % [path.trim_prefix("res://"), name, f])

	var ms := Time.get_ticks_msec() - t0
	print("== FROSTMARK UNIT ==")
	for line in report:
		print("FAIL  " + line)
	print("PASS %d / FAIL %d  (%d assertions, %d files, %d ms)" % [passed, failed, asserts, files.size(), ms])
	quit(1 if failed > 0 else 0)


## Autoloads are instantiated right after this script's _init; dropping them from
## the in-memory ProjectSettings keeps the run pure (nothing is saved to disk).
func _strip_autoloads() -> void:
	for p in ProjectSettings.get_property_list():
		var n: String = p.name
		if n.begins_with("autoload/"):
			ProjectSettings.set_setting(n, null)


func _discover(filter: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(TESTS_DIR)
	if dir == null:
		return out
	for f in dir.get_files():
		if f.begins_with("test_") and f.ends_with(".gd") and (filter == "" or f.contains(filter)):
			out.append(TESTS_DIR + "/" + f)
	out.sort()
	return out
