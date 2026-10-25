## The JSON half of tools/verify/run.sh: what it reads out of a ticket, a diff and a frozen
## grades.json. Each subcommand prints its answer on stdout and exits 0, or exits 1 when it
## can't read its input:
##
##   godot --headless -s tools/verify/record.gd -- criteria <ticket.md>
##       {"hash", "count", "graded", "criteria": [{id, text, tag}]}
##   godot --headless -s tools/verify/record.gd -- guard <diff>
##       the test guard ({deleted_tests, asserts_added, asserts_removed}) of a
##       `git diff -M -U0 <base> <head> -- tests/`
##   godot --headless -s tools/verify/record.gd -- probes <grades.json>
##       the probes the sim and data grades cite, one file name a line; `*` for a bare `probe:`
##   godot --headless -s tools/verify/record.gd -- redrive <grades.json>
##       the grades a re-drive of the frozen probes is judged by
##
## The static functions are the pure half, which the unit suite covers.
extends SceneTree

const Verdict := preload("res://tools/verify/verdict.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2 or not args[0] in ["criteria", "guard", "probes", "redrive"]:
		printerr("usage: godot --headless -s tools/verify/record.gd -- criteria|guard|probes|redrive <file>")
		quit(1)
		return
	if not FileAccess.file_exists(args[1]):
		printerr("record: no file at %s" % args[1])
		quit(1)
		return
	var text := FileAccess.get_file_as_string(args[1])
	match args[0]:
		"criteria":
			print(JSON.stringify(criteria_info(text)))
		"guard":
			print(JSON.stringify(test_guard(text)))
		"probes":
			print("\n".join(cited_probes(_grades(text))))
		"redrive":
			print(JSON.stringify(redrive_grades(_grades(text)), "  "))
	quit(0)


func _grades(text: String) -> Dictionary:
	var parsed = JSON.parse_string(text)
	return parsed if parsed is Dictionary else {}


## The ticket's criteria, the hash `--replay` and the frozen probes are bound to, and how many
## criteria a verifier would grade (those not marked `(look)` or `(playtest)`).
static func criteria_info(ticket: String) -> Dictionary:
	var criteria := Verdict.parse_criteria(ticket)
	return {
		"hash": Verdict.criteria_hash(criteria),
		"count": criteria.size(),
		"graded": criteria.filter(func(c): return c.tag == "").size(),
		"criteria": criteria,
	}


## The test guard's inputs from a diff of tests/: the .gd files it deletes, and the `assert_`
## lines it adds and removes. A rename is not a deletion; the asserts it moves count both ways.
static func test_guard(diff: String) -> Dictionary:
	var deleted: Array = []
	var added := 0
	var removed := 0
	var file := ""
	for line in diff.split("\n"):
		if line.begins_with("diff --git "):
			file = line.substr(line.find(" a/") + 3).split(" b/")[0]
		elif line.begins_with("deleted file mode") and file.ends_with(".gd"):
			deleted.append(file)
		elif line.begins_with("+++ ") or line.begins_with("--- "):
			continue
		elif line.begins_with("+") and line.contains("assert_"):
			added += 1
		elif line.begins_with("-") and line.contains("assert_"):
			removed += 1
	return {"deleted_tests": deleted, "asserts_added": added, "asserts_removed": removed}


## The probe files the sim and data grades cite as `<probe>:<id>` evidence, each once, in
## grades order; `*` when one cites a bare `probe:<id>` (any probe the run drove).
static func cited_probes(grades: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	for g in grades.get("criteria", []):
		if not (g is Dictionary) or not str(g.get("kind", "")) in Verdict.PROBE_KINDS:
			continue
		var probe := Verdict._evidence_probe(str(g.get("evidence", "")))
		if probe == "":
			continue
		var file := "*" if probe == "probe" else (probe if probe.ends_with(".gd") else probe + ".gd")
		if not file in out:
			out.append(file)
	return out


## The frozen grades with each sim and data claim of PASS or FAIL set to PASS, so the re-drive's
## own PROBE lines decide them: verdict.gd fails a criterion on its head line whatever the claim,
## and passes one only when the claim is PASS. A claim the verifier left INCONCLUSIVE stays.
static func redrive_grades(grades: Dictionary) -> Dictionary:
	var out := grades.duplicate(true)
	for g in out.get("criteria", []):
		if g is Dictionary and str(g.get("kind", "")) in Verdict.PROBE_KINDS and str(g.get("grade", "")) in [Verdict.PASS, Verdict.FAIL]:
			g["grade"] = Verdict.PASS
	return out
