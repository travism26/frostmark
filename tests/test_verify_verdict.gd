## The verify step's verdict rules (spec #144, Testing Decisions 1), on canned tickets, grades
## and drive output: no PASS without evidence, FAIL beats INCONCLUSIVE beats PASS, flags only
## with one of the four reasons, a new criterion's probe must fail on base, the residue, the doc
## quote, the ticket lint, the fix-cycle cap, the test guard, a sudden PASS and SCRIPT ERROR.
extends "res://tests/run.gd".TestCase

const Verdict := preload("res://tools/verify/verdict.gd")

const TICKET := """## What to build
The gate brings you home safe.

## Acceptance criteria
- [ ] Walking through the gate returns you home.
- [x] The pack is saved on return.
- [ ] docs/simulation.md lists the returned event.
- [ ] The balance test passes.

## Blocked by
- [ ] not a criterion
"""


func _probe(id: String, ok: bool, observed: String = "") -> String:
	return "PROBE " + JSON.stringify({"id": id, "pass": ok, "observed": observed})


func _grade(id: String, kind: String, grade: String, evidence: String, observed: String = "", is_new := false) -> Dictionary:
	return {"id": id, "kind": kind, "new": is_new, "grade": grade, "evidence": evidence, "observed": observed}


## Every criterion of TICKET passing on its evidence; tests break one thing at a time.
func _passing() -> Dictionary:
	return {
		"ticket": TICKET,
		"grades": {"criteria": [
			_grade("AC1", "sim", "PASS", "gate.gd:AC1", "", true),
			_grade("AC2", "sim", "PASS", "gate.gd:AC2"),
			_grade("AC3", "doc", "PASS", "docs/simulation.md:2", "`returned` fires on the way home"),
			_grade("AC4", "gate", "PASS", "ci"),
		], "flags": [], "notes": []},
		"drive": {"gate.gd": {
			"head": "Godot Engine\n%s\n%s\n" % [_probe("AC1", true, "home at tick 40"), _probe("AC2", true, "saved")],
			"base": "%s\n%s\n" % [_probe("AC1", false, "still outside"), _probe("AC2", true, "saved")],
		}},
		"docs": {"docs/simulation.md": "# Simulation\n- `returned` fires on the way home, with the pack.\n"},
		"ci": "success",
		"earlier": [],
		"binding": {"head_sha": "aaa", "base_sha": "bbb", "ticket": 107},
	}


func _row(result: Dictionary, id: String) -> Dictionary:
	for r in result.criteria:
		if r.id == id:
			return r
	return {}


func test_criteria_are_numbered_in_ticket_order_from_the_checklist_only() -> void:
	var c := Verdict.parse_criteria(TICKET)
	assert_eq(c.size(), 4, "items outside ## Acceptance criteria are not criteria")
	assert_eq(c[0].id, "AC1")
	assert_eq(c[1].text, "The pack is saved on return.")
	assert_eq(c[3].id, "AC4")


func test_ticking_a_box_does_not_change_the_criteria_hash() -> void:
	var ticked := Verdict.criteria_hash(Verdict.parse_criteria(TICKET.replace("- [ ] Walking", "- [x] Walking")))
	assert_eq(ticked, Verdict.criteria_hash(Verdict.parse_criteria(TICKET)))
	var edited := Verdict.criteria_hash(Verdict.parse_criteria(TICKET.replace("returns you home", "returns you")))
	assert_ne(edited, Verdict.criteria_hash(Verdict.parse_criteria(TICKET)), "editing a criterion does")


func test_everything_on_its_evidence_is_pass() -> void:
	var r := Verdict.decide(_passing())
	assert_eq(r.verdict, Verdict.PASS, str(r.criteria))
	assert_eq(_row(r, "AC1").observed, "home at tick 40", "observed comes from the probe")
	assert_eq(r.binding.criteria_hash, Verdict.criteria_hash(Verdict.parse_criteria(TICKET)))
	assert_eq(r.binding.head_sha, "aaa")


func test_a_pass_grade_with_no_matching_probe_line_is_inconclusive() -> void:
	var inputs := _passing()
	inputs.drive["gate.gd"].head = _probe("AC2", true)
	var r := Verdict.decide(inputs)
	assert_eq(_row(r, "AC1").grade, Verdict.INCONCLUSIVE)
	assert_eq(r.verdict, Verdict.INCONCLUSIVE)


func test_a_pass_grade_naming_a_probe_that_was_not_driven_is_inconclusive() -> void:
	var inputs := _passing()
	inputs.grades.criteria[1].evidence = "other.gd:AC2"
	assert_eq(_row(Verdict.decide(inputs), "AC2").grade, Verdict.INCONCLUSIVE)


func test_evidence_naming_the_probe_file_reads_its_output_under_the_stem() -> void:
	var inputs := _passing()
	inputs.drive = {"gate": inputs.drive["gate.gd"]}
	assert_eq(Verdict.decide(inputs).verdict, Verdict.PASS, "drive.sh saves gate.gd's output as drive/gate.head.log")
	inputs.grades.criteria[0].evidence = "gate:AC1"
	assert_eq(_row(Verdict.decide(inputs), "AC1").grade, Verdict.PASS)


func test_a_bare_probe_evidence_reads_every_probe() -> void:
	var inputs := _passing()
	inputs.grades.criteria[1].evidence = "probe:AC2"
	assert_eq(_row(Verdict.decide(inputs), "AC2").grade, Verdict.PASS)


func test_a_failing_head_line_is_fail_whatever_the_verifier_claimed() -> void:
	var inputs := _passing()
	inputs.drive["gate.gd"].head = "%s\n%s\n" % [_probe("AC1", true, "home"), _probe("AC2", false, "pack empty, nothing saved")]
	var r := Verdict.decide(inputs)
	assert_eq(_row(r, "AC2").grade, Verdict.FAIL)
	assert_eq(_row(r, "AC2").observed, "pack empty, nothing saved", "a FAIL names what the probe saw")
	assert_eq(r.verdict, Verdict.FAIL)


func test_one_failing_line_among_passes_fails_the_criterion() -> void:
	var inputs := _passing()
	inputs.drive["gate.gd"].head += _probe("AC2", false, "second case") + "\n"
	assert_eq(_row(Verdict.decide(inputs), "AC2").grade, Verdict.FAIL)


func test_fail_beats_inconclusive_beats_pass() -> void:
	var inputs := _passing()
	inputs.ci = "pending"
	assert_eq(Verdict.decide(inputs).verdict, Verdict.INCONCLUSIVE, "INCONCLUSIVE beats PASS")
	inputs.drive["gate.gd"].head = "%s\n%s\n" % [_probe("AC1", true), _probe("AC2", false)]
	assert_eq(Verdict.decide(inputs).verdict, Verdict.FAIL, "FAIL beats INCONCLUSIVE")


func test_the_model_cannot_pass_a_criterion_its_evidence_does_not() -> void:
	var inputs := _passing()
	inputs.grades.criteria[1].grade = "FAIL"
	var row := _row(Verdict.decide(inputs), "AC2")
	assert_eq(row.grade, Verdict.INCONCLUSIVE, "a passing probe the verifier doubts is not a PASS")


func test_a_flag_with_one_of_the_four_reasons_is_flag() -> void:
	for reason in Verdict.FLAG_REASONS:
		var inputs := _passing()
		inputs.grades.flags = [{"reason": reason, "detail": "AC2 says saved and AC1 says discarded"}]
		var r := Verdict.decide(inputs)
		assert_eq(r.verdict, Verdict.FLAG, reason)
		assert_eq(r.flags[0].reason, reason)
		assert_eq(r.flags[0].by, "verifier")


func test_any_other_flag_becomes_a_note_and_leaves_the_verdict_alone() -> void:
	var inputs := _passing()
	inputs.drive["gate.gd"].head = "%s\n%s\n" % [_probe("AC1", true), _probe("AC2", false)]
	inputs.grades.flags = [{"reason": "diagnosis", "detail": "the cause is in _return()"}, "no reason at all"]
	var r := Verdict.decide(inputs)
	assert_eq(r.verdict, Verdict.FAIL, "the verifier's diagnosis does not turn a FAIL into a FLAG")
	assert_true(r.flags.is_empty())
	assert_true(r.notes.any(func(n): return n.contains("the cause is in _return()")), str(r.notes))
	assert_true(r.notes.any(func(n): return n.contains("no reason at all")), str(r.notes))


func test_a_new_criterion_whose_probe_passes_on_base_is_inconclusive() -> void:
	var inputs := _passing()
	inputs.drive["gate.gd"].base = "%s\n%s\n" % [_probe("AC1", true), _probe("AC2", true)]
	var r := Verdict.decide(inputs)
	assert_eq(_row(r, "AC1").grade, Verdict.INCONCLUSIVE)
	assert_true(_row(r, "AC1").why.contains("does not test the change"))
	assert_eq(_row(r, "AC2").grade, Verdict.PASS, "a kept criterion may pass on base")


func test_an_untagged_criterion_left_ungraded_is_inconclusive() -> void:
	var inputs := _passing()
	inputs.grades.criteria.remove_at(3)
	var r := Verdict.decide(inputs)
	assert_eq(_row(r, "AC4").grade, Verdict.INCONCLUSIVE)
	assert_eq(r.verdict, Verdict.INCONCLUSIVE)


func test_a_look_grade_on_an_untagged_criterion_is_inconclusive() -> void:
	var inputs := _passing()
	inputs.grades.criteria[3] = _grade("AC4", "look", "PASS", "")
	assert_eq(_row(Verdict.decide(inputs), "AC4").grade, Verdict.INCONCLUSIVE)


func test_a_look_criterion_is_excluded_and_listed() -> void:
	var inputs := _passing()
	inputs.ticket = TICKET.replace("The balance test passes.", "The gate glows at night (look)")
	inputs.grades.criteria.remove_at(3)
	var r := Verdict.decide(inputs)
	assert_eq(r.verdict, Verdict.PASS)
	assert_eq(r.residue.size(), 1)
	assert_eq(r.residue[0].id, "AC4")
	assert_eq(r.residue[0].kind, "look")
	assert_true(_row(r, "AC4").is_empty(), "residue is not graded")


func test_a_doc_grade_whose_quote_is_not_at_its_line_is_inconclusive() -> void:
	var inputs := _passing()
	inputs.grades.criteria[2].evidence = "docs/simulation.md:1"
	assert_eq(_row(Verdict.decide(inputs), "AC3").grade, Verdict.INCONCLUSIVE, "wrong line")
	inputs = _passing()
	inputs.grades.criteria[2].observed = "`returned` fires when you die"
	assert_eq(_row(Verdict.decide(inputs), "AC3").grade, Verdict.INCONCLUSIVE, "a quote the doc does not make")
	inputs = _passing()
	inputs.docs = {}
	assert_eq(_row(Verdict.decide(inputs), "AC3").grade, Verdict.INCONCLUSIVE, "a file not in the head copy")


func test_a_gate_grade_follows_ci() -> void:
	var inputs := _passing()
	inputs.ci = "failure"
	var r := Verdict.decide(inputs)
	assert_eq(_row(r, "AC4").grade, Verdict.FAIL)
	assert_eq(r.verdict, Verdict.FAIL)


func test_a_ticket_with_no_criteria_is_inconclusive() -> void:
	var inputs := _passing()
	inputs.ticket = "## What to build\nSomething.\n"
	var r := Verdict.decide(inputs)
	assert_eq(r.verdict, Verdict.INCONCLUSIVE)
	assert_true(r.criteria.is_empty())


func test_a_ticket_with_only_look_criteria_is_a_no_op_pass() -> void:
	var r := Verdict.decide({"ticket": "## Acceptance criteria\n- [ ] The mine reads as a mine (look)\n- [ ] It feels heavy (playtest).\n"})
	assert_eq(r.verdict, Verdict.PASS)
	assert_eq(r.residue.map(func(x): return x.kind), ["look", "playtest"])


func test_the_third_non_pass_run_is_flag() -> void:
	var inputs := _passing()
	inputs.drive["gate.gd"].head = "%s\n%s\n" % [_probe("AC1", true), _probe("AC2", false)]
	var failed := {"verdict": Verdict.FAIL, "criteria": [], "binding": {"head_sha": "x1"}}
	inputs.earlier = [failed]
	assert_eq(Verdict.decide(inputs).verdict, Verdict.FAIL, "the second non-PASS run is still a FAIL")
	inputs.earlier = [failed, {"verdict": Verdict.FAIL, "criteria": [], "binding": {"head_sha": "x1"}}]
	assert_eq(Verdict.decide(inputs).verdict, Verdict.FAIL, "a re-run of the same SHA is not another cycle")
	inputs.earlier = [failed, {"verdict": Verdict.INCONCLUSIVE, "criteria": [], "binding": {"head_sha": "x2"}}]
	var r := Verdict.decide(inputs)
	assert_eq(r.verdict, Verdict.FLAG)
	assert_eq(r.flags[0].reason, Verdict.FIX_CYCLE_CAP)
	assert_eq(_row(r, "AC2").grade, Verdict.FAIL, "the criterion keeps its own grade")


func test_a_pass_after_two_failures_is_not_capped() -> void:
	var inputs := _passing()
	var failed := {"verdict": Verdict.FAIL, "criteria": [], "binding": {"head_sha": "x1"}}
	inputs.earlier = [failed, {"verdict": Verdict.FAIL, "criteria": [], "binding": {"head_sha": "x2"}}]
	assert_eq(Verdict.decide(inputs).verdict, Verdict.PASS)


func test_the_test_guard_flags_a_deleted_test_or_lost_asserts() -> void:
	var inputs := _passing()
	inputs.test_guard = {"deleted_tests": ["tests/test_sim_gate.gd"], "asserts_added": 0, "asserts_removed": 0}
	var r := Verdict.decide(inputs)
	assert_eq(r.verdict, Verdict.FLAG)
	assert_eq(r.flags[0].reason, Verdict.TEST_GUARD)
	inputs.test_guard = {"deleted_tests": [], "asserts_added": 2, "asserts_removed": 3}
	assert_eq(Verdict.decide(inputs).verdict, Verdict.FLAG, "more assert_ lines removed than added")
	inputs.test_guard = {"deleted_tests": [], "asserts_added": 3, "asserts_removed": 3}
	assert_eq(Verdict.decide(inputs).verdict, Verdict.PASS, "a test reworded line for line is fine")


func test_a_sudden_pass_with_no_game_change_is_flag() -> void:
	var inputs := _passing()
	inputs.earlier = [{"verdict": Verdict.FAIL, "criteria": [{"id": "AC2", "grade": Verdict.FAIL}], "binding": {"head_sha": "x1"}}]
	inputs.changed_since_fail = ["tests/test_sim_gate.gd"]
	var r := Verdict.decide(inputs)
	assert_eq(r.verdict, Verdict.FLAG)
	assert_eq(r.flags[0].reason, Verdict.SUDDEN_PASS)
	inputs.changed_since_fail = ["tests/test_sim_gate.gd", "sim/gate.gd"]
	assert_eq(Verdict.decide(inputs).verdict, Verdict.PASS, "a fix under sim/ explains the pass")


func test_output_containing_script_error_never_passes() -> void:
	var inputs := _passing()
	inputs.drive["gate.gd"].head += "SCRIPT ERROR: Invalid call. Nonexistent function 'foo'.\n"
	var r := Verdict.decide(inputs)
	assert_eq(_row(r, "AC1").grade, Verdict.INCONCLUSIVE)
	assert_eq(_row(r, "AC2").grade, Verdict.INCONCLUSIVE)
	assert_ne(r.verdict, Verdict.PASS)


func test_a_head_run_that_did_not_exit_cleanly_never_passes() -> void:
	var inputs := _passing()
	inputs.drive["gate.gd"].head_rc = 142
	assert_eq(_row(Verdict.decide(inputs), "AC1").grade, Verdict.INCONCLUSIVE, "a timeout is not a PASS")


func test_the_report_has_a_row_per_criterion_then_residue_flags_notes_and_binding() -> void:
	var inputs := _passing()
	inputs.ticket = TICKET.replace("The balance test passes.", "The gate glows at night (look)")
	inputs.grades.criteria.remove_at(3)
	inputs.grades.notes = ["AC2 also holds with a full stash"]
	var md := Verdict.report_md(Verdict.decide(inputs))
	assert_true(md.begins_with("# Verify: PASS\n"), md)
	assert_true(md.contains("| id | kind | grade | observed |"), md)
	assert_true(md.contains("| AC1 | sim | PASS | home at tick 40 |"), md)
	assert_true(md.contains("| AC3 | doc | PASS |"), md)
	var order := ["## Residue", "AC4 (look)", "## Flags", "## Notes", "AC2 also holds", "## Binding", "- head_sha: aaa", "- criteria_hash: "]
	var at := 0
	for s in order:
		var i := md.find(s, at)
		assert_true(i >= 0, "%s after offset %d in\n%s" % [s, at, md])
		at = maxi(i, at)


func test_the_report_names_a_patched_head_copy() -> void:
	var inputs := _passing()
	assert_false(Verdict.report_md(Verdict.decide(inputs)).contains("head_patch"), "an unpatched copy says nothing")
	inputs.binding["head_patch"] = "f00d"
	var result := Verdict.decide(inputs)
	assert_eq(result.binding.get("head_patch"), "f00d", "the patch stays in the binding")
	assert_true(Verdict.report_md(result).contains("- head_patch: f00d (the head copy was patched"), Verdict.report_md(result))
