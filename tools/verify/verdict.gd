## The verify step's verdict (spec #144): a pure function from the ticket, the verifier's
## grades.json, the drive outputs, CI's conclusion and the ticket's earlier runs to the run's
## verdict, per-criterion grades, flags, notes and residue. Nothing here touches a file;
## tools/verify/write_verdict.gd gathers the inputs from a record and writes what this returns.
##
## The model's word alone never passes a criterion: a PASS needs a PROBE line, a quote found at
## its path:line, or CI's success for the head SHA.
extends RefCounted

const PASS := "PASS"
const FAIL := "FAIL"
const INCONCLUSIVE := "INCONCLUSIVE"
const FLAG := "FLAG"

## The only reasons a verifier flag may carry; any other flag becomes a note.
const FLAG_REASONS := ["ticket_contradiction", "uninterpretable", "gaming_suspected", "oracle_dispute"]
## The reasons of the flags this script raises itself.
const FIX_CYCLE_CAP := "fix_cycle_cap"
const TEST_GUARD := "test_guard"
const SUDDEN_PASS := "sudden_pass"
## A third non-PASS run for the ticket is FLAG.
const MAX_NON_PASS_RUNS := 3

const RESIDUE_TAGS := ["look", "playtest"]
const PROBE_KINDS := ["sim", "data"]
const KINDS := ["sim", "data", "doc", "gate", "look", "playtest"]
## Worst first: the run's grade is the worst of its criteria.
const RANK := {PASS: 0, INCONCLUSIVE: 1, FAIL: 2}


## The ticket's `## Acceptance criteria` checklist, AC1..ACn in ticket order. `tag` is "look" or
## "playtest" when the item ends with `(look)` or `(playtest)`, else "".
static func parse_criteria(ticket: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var inside := false
	var item := RegEx.create_from_string("^[-*] \\[[ xX]\\]\\s+(.+)$")
	for raw in ticket.split("\n"):
		var line := raw.strip_edges()
		if line.begins_with("#"):
			inside = line.to_lower() == "## acceptance criteria"
			continue
		if not inside:
			continue
		var m := item.search(line)
		if m == null:
			continue
		var text := m.get_string(1).strip_edges()
		var tag := ""
		var bare := text.trim_suffix(".").strip_edges()
		for t in RESIDUE_TAGS:
			if bare.ends_with("(%s)" % t):
				tag = t
		out.append({"id": "AC%d" % (out.size() + 1), "text": text, "tag": tag})
	return out


## A hash of the criteria's text in order, blind to whether their boxes are ticked.
static func criteria_hash(criteria: Array[Dictionary]) -> String:
	var texts := PackedStringArray()
	for c in criteria:
		texts.append(c.text)
	return "\n".join(texts).sha256_text()


## Every `PROBE {json}` line in a probe's raw output, parsed; lines that aren't JSON objects
## are skipped.
static func probe_lines(output: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for raw in output.split("\n"):
		var line := raw.strip_edges()
		if not line.begins_with("PROBE "):
			continue
		var parsed = JSON.parse_string(line.trim_prefix("PROBE "))
		if parsed is Dictionary:
			out.append(parsed)
	return out


## The verdict for one run. `inputs` holds:
##   ticket: String, the ticket text as fetched (What to build and Acceptance criteria)
##   grades: Dictionary, grades.json ({criteria: [...], flags: [...], notes: [...]})
##   drive: {probe: {head: String, base: String, head_rc?: int, base_rc?: int}}, raw drive output
##   docs: {path: String}, the head copy's text of every file a doc grade quotes
##   ci: String, CI's conclusion for the head SHA ("success", "failure", or anything else)
##   earlier: Array of the ticket's earlier verdict.json dictionaries
##   test_guard: {deleted_tests: Array, asserts_added: int, asserts_removed: int}, from the diff
##   changed_since_fail: Array of paths changed since the last run that failed a criterion
##   binding: head_sha, base_sha, ticket, harness_version, verifier_model, godot_version
static func decide(inputs: Dictionary) -> Dictionary:
	var criteria := parse_criteria(str(inputs.get("ticket", "")))
	var binding: Dictionary = inputs.get("binding", {}).duplicate()
	binding["criteria_hash"] = criteria_hash(criteria)
	var result := {
		"verdict": INCONCLUSIVE,
		"criteria": [],
		"residue": [],
		"flags": [],
		"notes": [],
		"binding": binding,
	}
	if criteria.is_empty():
		result.notes.append("the ticket has no acceptance criteria")
		return result

	var graded: Array = []
	for c in criteria:
		if c.tag != "":
			result.residue.append({"id": c.id, "kind": c.tag, "text": c.text})
		else:
			graded.append(c)
	if graded.is_empty():
		result.verdict = PASS
		result.notes.append("every criterion is (look) or (playtest): nothing to verify")
		return result

	var grades: Dictionary = inputs.get("grades", {})
	var by_id := {}
	for g in grades.get("criteria", []):
		if g is Dictionary and g.has("id"):
			by_id[str(g.id)] = g
	for id in by_id:
		if not criteria.any(func(c): return c.id == id):
			result.notes.append("grades.json grades %s, which the ticket does not have" % id)
	for n in grades.get("notes", []):
		result.notes.append(str(n))

	var worst := PASS
	for c in graded:
		var row := _grade(c, by_id.get(c.id, {}), inputs)
		result.criteria.append(row)
		if RANK[row.grade] > RANK[worst]:
			worst = row.grade

	for f in grades.get("flags", []):
		var reason := str(f.get("reason", "")) if f is Dictionary else ""
		var detail := str(f.get("detail", "")) if f is Dictionary else str(f)
		if reason in FLAG_REASONS:
			result.flags.append({"reason": reason, "detail": detail, "by": "verifier"})
		else:
			result.notes.append("flag without a valid reason (%s): %s" % [reason if reason != "" else "none", detail])

	_guard_flags(result, inputs)
	_sudden_pass_flags(result, inputs)
	result.verdict = FLAG if not result.flags.is_empty() else worst
	_fix_cycle_flag(result, inputs)
	if not result.flags.is_empty():
		result.verdict = FLAG
	return result


## One criterion's row: the verifier's claim checked against its evidence.
static func _grade(c: Dictionary, g: Dictionary, inputs: Dictionary) -> Dictionary:
	var row := {
		"id": c.id,
		"text": c.text,
		"kind": str(g.get("kind", "")),
		"new": g.get("new", false) == true,
		"claimed": str(g.get("grade", "")),
		"evidence": str(g.get("evidence", "")),
		"observed": str(g.get("observed", "")),
		"note": str(g.get("note", "")),
		"grade": INCONCLUSIVE,
		"why": "",
	}
	if g.is_empty():
		row.why = "not graded"
		return row
	match row.kind:
		"sim", "data":
			_grade_probe(row, inputs.get("drive", {}))
		"doc":
			_grade_doc(row, inputs.get("docs", {}))
		"gate":
			match str(inputs.get("ci", "")):
				"success":
					row.grade = PASS
					row.observed = "CI succeeded for the head SHA"
				"failure":
					row.grade = FAIL
					row.observed = "CI failed for the head SHA"
				var other:
					row.why = "no CI conclusion for the head SHA (%s)" % other
		"look", "playtest":
			row.why = "kind %s, but the ticket does not mark it so" % row.kind
		_:
			row.why = "unknown kind '%s'" % row.kind
	# The model can call its own evidence into doubt, never past it.
	if row.grade == PASS and row.claimed != PASS:
		row.grade = INCONCLUSIVE
		row.why = "the evidence passes but the verifier graded it %s" % row.claimed
	return row


static func _grade_probe(row: Dictionary, drive: Dictionary) -> void:
	var probe := _evidence_probe(row.evidence)
	var probes: Array = drive.keys() if probe == "probe" else [probe, probe + ".gd"].filter(func(p): return drive.has(p))
	if probes.is_empty():
		row.why = "no drive output for evidence '%s'" % row.evidence
		return
	var head := _probe_result(row.id, probes, drive, "head")
	if head.is_empty():
		row.why = "no PROBE line for %s on head" % row.id
		return
	row.observed = head.observed
	if not head.pass:
		row.grade = FAIL
		return
	if head.errored:
		row.why = "the head run logged a SCRIPT ERROR or did not exit cleanly"
		return
	if row.new:
		var base := _probe_result(row.id, probes, drive, "base")
		if not base.is_empty() and base.pass:
			row.why = "probe does not test the change: it also passes on base"
			return
	row.grade = PASS


## `<probe>:<id>` names the probe whose output holds the criterion's lines; a bare `probe:<id>`
## means any probe the run drove.
static func _evidence_probe(evidence: String) -> String:
	var at := evidence.rfind(":")
	return evidence.substr(0, at).strip_edges() if at > 0 else evidence.strip_edges()


## The criterion's lines on one side, folded: pass only if every line for the id passed.
## Empty when no probe printed a line for it.
static func _probe_result(id: String, probes: Array, drive: Dictionary, side: String) -> Dictionary:
	var found := false
	var ok := true
	var observed := PackedStringArray()
	var errored := false
	for p in probes:
		var out: Dictionary = drive[p]
		var text := str(out.get(side, ""))
		var lines := probe_lines(text).filter(func(l): return str(l.get("id", "")) == id)
		if lines.is_empty():
			continue
		found = true
		errored = errored or text.contains("SCRIPT ERROR") or int(out.get(side + "_rc", 0)) != 0
		for l in lines:
			ok = ok and l.get("pass") == true
			observed.append(str(l.get("observed", "")))
	if not found:
		return {}
	return {"pass": ok, "observed": "; ".join(observed), "errored": errored}


static func _grade_doc(row: Dictionary, docs: Dictionary) -> void:
	var evidence: String = row.evidence
	var at := evidence.rfind(":")
	var path := evidence.substr(0, at) if at > 0 else ""
	var line_no := evidence.substr(at + 1).to_int() if at > 0 else 0
	var quote: String = row.observed.strip_edges()
	if path == "" or line_no < 1 or quote == "":
		row.why = "a doc grade needs path:line evidence and the quote in observed"
		return
	if not docs.has(path):
		row.why = "%s is not in the head copy" % path
		return
	var lines := str(docs[path]).split("\n")
	if line_no > lines.size() or not _squash(lines[line_no - 1]).contains(_squash(quote)):
		row.why = "the quote is not at %s" % row.evidence
		return
	row.grade = PASS


static func _squash(s: String) -> String:
	return " ".join(s.split(" ", false)).replace("\t", " ").strip_edges()


## The test guard: the change deletes a test file, or removes more `assert_` lines than it adds
## under tests/.
static func _guard_flags(result: Dictionary, inputs: Dictionary) -> void:
	var guard: Dictionary = inputs.get("test_guard", {})
	var deleted: Array = guard.get("deleted_tests", [])
	if not deleted.is_empty():
		result.flags.append({"reason": TEST_GUARD, "detail": "the change deletes %s" % ", ".join(deleted), "by": "script"})
	var added := int(guard.get("asserts_added", 0))
	var removed := int(guard.get("asserts_removed", 0))
	if removed > added:
		result.flags.append({"reason": TEST_GUARD,
			"detail": "the change removes %d assert_ lines under tests/ and adds %d" % [removed, added], "by": "script"})


## A frozen probe that failed in an earlier run passing now, with nothing changed under sim/ or
## scenes/ since.
static func _sudden_pass_flags(result: Dictionary, inputs: Dictionary) -> void:
	var failed_before := {}
	for run in inputs.get("earlier", []):
		for g in run.get("criteria", []):
			if g.get("grade") == FAIL:
				failed_before[str(g.get("id"))] = true
	if failed_before.is_empty():
		return
	var game_changed: bool = inputs.get("changed_since_fail", []).any(
		func(p): return str(p).begins_with("sim/") or str(p).begins_with("scenes/"))
	if game_changed:
		return
	for row in result.criteria:
		if row.grade == PASS and failed_before.has(row.id) and row.kind in PROBE_KINDS:
			result.flags.append({"reason": SUDDEN_PASS,
				"detail": "%s failed before and passes now with nothing changed under sim/ or scenes/" % row.id, "by": "script"})


## The fix-cycle cap: the ticket's third non-PASS run, counting each head SHA once, is FLAG.
static func _fix_cycle_flag(result: Dictionary, inputs: Dictionary) -> void:
	if result.verdict == PASS:
		return
	var shas := {str(result.binding.get("head_sha", "this run")): true}
	var earlier: Array = inputs.get("earlier", [])
	for i in earlier.size():
		if earlier[i].get("verdict") != PASS:
			shas[str(earlier[i].get("binding", {}).get("head_sha", "earlier run %d" % i))] = true
	if shas.size() >= MAX_NON_PASS_RUNS:
		result.flags.append({"reason": FIX_CYCLE_CAP,
			"detail": "non-PASS run %d for this ticket" % shas.size(), "by": "script"})


## The record's short report: one row per criterion, then the residue, flags, notes and the
## binding fields.
static func report_md(result: Dictionary) -> String:
	var b: Dictionary = result.binding
	var out := PackedStringArray()
	out.append("# Verify: %s" % result.verdict)
	out.append("")
	out.append("| id | kind | grade | observed |")
	out.append("|---|---|---|---|")
	for row in result.criteria:
		var seen: String = row.observed
		if row.why != "":
			seen = row.why if seen == "" else "%s (%s)" % [seen, row.why]
		out.append("| %s | %s | %s | %s |" % [row.id, row.kind, row.grade, _cell(seen)])
	out.append("")
	out.append("## Residue")
	out.append_array(_bullets(result.residue.map(func(r): return "%s (%s): %s" % [r.id, r.kind, r.text])))
	out.append("")
	out.append("## Flags")
	out.append_array(_bullets(result.flags.map(func(f): return "%s (%s): %s" % [f.reason, f.by, f.detail])))
	out.append("")
	out.append("## Notes")
	out.append_array(_bullets(result.notes))
	out.append("")
	out.append("## Binding")
	for k in ["head_sha", "base_sha", "ticket", "criteria_hash", "harness_version", "verifier_model", "godot_version"]:
		out.append("- %s: %s" % [k, str(b.get(k, ""))])
	return "\n".join(out) + "\n"


static func _bullets(items: Array) -> PackedStringArray:
	var out := PackedStringArray()
	if items.is_empty():
		out.append("- none")
	for i in items:
		out.append("- " + str(i))
	return out


static func _cell(s: String) -> String:
	return s.replace("|", "\\|").replace("\n", " ")
