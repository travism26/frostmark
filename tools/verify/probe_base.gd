## The base every verify probe extends. A probe is a headless script that plays the simulation
## through its command and query interface, the way the play bot does, and grades one or more
## acceptance criteria by what it saw:
##
##   extends "res://tools/verify/probe_base.gd"
##   func run() -> void:
##       var sim := Sim.new()
##       ...
##       grade("AC1", ok, {"warmth": sim.snapshot()["survival"]["warmth"]})
##
## `tools/verify/drive.sh <record> <probe>` runs it on the head and base copies. Like
## tests/run.gd, the base strips the project's autoloads in memory so nothing boots behind the
## probe. `run()` is synchronous: the base quits as soon as it returns, and a run() that never
## returns is killed by drive's alarm.
extends SceneTree


func _init() -> void:
	_strip_autoloads()
	run()
	quit()


## Overridden by the probe.
func run() -> void:
	pass


## Prints one `PROBE {json}` line, the only output the verdict reads. `observed` is what the
## probe saw, in whatever shape explains the grade (a number, a list of events, a dictionary).
## `id` is a criterion's own id; the verdict reads no other, so any other id is an error.
func grade(id: String, ok: bool, observed: Variant) -> void:
	if not RegEx.create_from_string("^AC[1-9][0-9]*$").search(id):
		push_error("grade: '%s' is not a criterion id (AC1, AC2, ...): to grade one in parts, call grade() with its id once per part" % id)
		return
	print("PROBE " + JSON.stringify({"id": id, "pass": ok, "observed": observed}))


## Autoloads are instantiated right after this script's _init; dropping them from
## the in-memory ProjectSettings keeps the run pure (nothing is saved to disk).
func _strip_autoloads() -> void:
	for p in ProjectSettings.get_property_list():
		var n: String = p.name
		if n.begins_with("autoload/"):
			ProjectSettings.set_setting(n, null)
