## What tools/verify/run.sh reads through tools/verify/record.gd: the ticket lint's criteria
## count and hash, the test guard from a diff of tests/, the probes a frozen grades.json cites,
## and the grades a re-drive of those probes is judged by.
extends "res://tests/run.gd".TestCase

const Record := preload("res://tools/verify/record.gd")
const Verdict := preload("res://tools/verify/verdict.gd")

const TICKET := """## What to build
A warning when the pack is heavy.

## Acceptance criteria
- [ ] The warning shows over the carry limit.
- [x] It reads well. (look)
- [ ] It is worth playing. (playtest)
"""

const DIFF := """diff --git a/tests/test_gate.gd b/tests/test_gate.gd
deleted file mode 100644
--- a/tests/test_gate.gd
+++ /dev/null
@@ -1,2 +0,0 @@
-	assert_eq(a, b)
-	assert_true(c)
diff --git a/tests/test_gate.gd.uid b/tests/test_gate.gd.uid
deleted file mode 100644
--- a/tests/test_gate.gd.uid
+++ /dev/null
@@ -1 +0,0 @@
-uid://abc
diff --git a/tests/test_pack.gd b/tests/test_pack.gd
--- a/tests/test_pack.gd
+++ b/tests/test_pack.gd
@@ -3 +3,2 @@
-	assert_eq(pack, 3)
+	assert_eq(pack, 4)
+	var assert_count := 0
"""


func test_criteria_info_counts_what_a_verifier_would_grade() -> void:
	var info := Record.criteria_info(TICKET)
	assert_eq(info.count, 3)
	assert_eq(info.graded, 1, "(look) and (playtest) are not graded")
	assert_eq(info.hash, Verdict.criteria_hash(Verdict.parse_criteria(TICKET)))
	assert_eq(Record.criteria_info(TICKET.replace("- [ ] The", "- [x] The")).hash, info.hash, "ticking a box is not an edit")
	assert_eq(Record.criteria_info("## What to build\nNothing.\n").count, 0)


func test_the_guard_names_deleted_test_files_but_not_their_uid() -> void:
	assert_eq(Record.test_guard(DIFF).deleted_tests, ["tests/test_gate.gd"])


func test_the_guard_counts_assert_lines_both_ways() -> void:
	var g := Record.test_guard(DIFF)
	assert_eq(g.asserts_removed, 3)
	assert_eq(g.asserts_added, 2)


func test_a_guard_on_a_change_that_weakens_the_tests_is_flagged() -> void:
	var weakened := """diff --git a/tests/test_pack.gd b/tests/test_pack.gd
--- a/tests/test_pack.gd
+++ b/tests/test_pack.gd
@@ -3,2 +3 @@
-	assert_eq(pack, 3)
-	assert_true(saved)
+	assert_eq(pack, 3)
"""
	var inputs := {
		"ticket": TICKET,
		"grades": {"criteria": [{"id": "AC1", "kind": "gate", "grade": "PASS", "evidence": "ci"}]},
		"ci": "success",
		"test_guard": Record.test_guard(weakened),
	}
	var r := Verdict.decide(inputs)
	assert_eq(r.verdict, Verdict.FLAG, str(r.flags))
	assert_eq(r.flags[0].reason, Verdict.TEST_GUARD)
	inputs.test_guard = Record.test_guard(DIFF.substr(DIFF.find("diff --git a/tests/test_pack.gd")))
	assert_eq(Verdict.decide(inputs).verdict, Verdict.PASS, "an edited assert is not a removed one")


func test_a_rename_is_not_a_deletion() -> void:
	var renamed := "diff --git a/tests/test_a.gd b/tests/test_b.gd\nsimilarity index 100%\nrename from tests/test_a.gd\nrename to tests/test_b.gd\n"
	assert_eq(Record.test_guard(renamed).deleted_tests, [])


func test_cited_probes_are_the_sim_and_data_evidence_once_each() -> void:
	var grades := {"criteria": [
		{"id": "AC1", "kind": "sim", "evidence": "gate:AC1"},
		{"id": "AC2", "kind": "data", "evidence": "gate.gd:AC2"},
		{"id": "AC3", "kind": "doc", "evidence": "docs/simulation.md:12"},
		{"id": "AC4", "kind": "sim", "evidence": "pack.gd:AC4"},
	]}
	assert_eq(Record.cited_probes(grades), PackedStringArray(["gate.gd", "pack.gd"]))
	grades.criteria.append({"id": "AC5", "kind": "sim", "evidence": "probe:AC5"})
	assert_true("*" in Record.cited_probes(grades), "a bare probe: cites every probe")


func test_a_redrive_lets_the_new_probe_lines_decide() -> void:
	var grades := {"criteria": [
		{"id": "AC1", "kind": "sim", "grade": "FAIL", "evidence": "gate.gd:AC1"},
		{"id": "AC2", "kind": "sim", "grade": "INCONCLUSIVE", "evidence": "gate.gd:AC2"},
		{"id": "AC3", "kind": "gate", "grade": "FAIL", "evidence": "ci"},
	], "notes": ["kept"]}
	var redrive := Record.redrive_grades(grades)
	assert_eq(redrive.criteria[0].grade, Verdict.PASS, "a FAIL claim is left to the new head line")
	assert_eq(redrive.criteria[1].grade, Verdict.INCONCLUSIVE, "the verifier's doubt stays")
	assert_eq(redrive.criteria[2].grade, Verdict.FAIL, "only probe claims change")
	assert_eq(grades.criteria[0].grade, "FAIL", "the frozen grades are not touched")
	var ticket := "## Acceptance criteria\n- [ ] A.\n- [ ] B.\n- [ ] C.\n"
	var inputs := {"ticket": ticket, "grades": redrive, "ci": "success",
		"drive": {"gate.gd": {"head": "PROBE {\"id\":\"AC1\",\"pass\":true,\"observed\":\"fixed\"}\n", "base": ""}}}
	assert_eq(Verdict.decide(inputs).criteria[0].grade, Verdict.PASS, "the fix passes on its probe")
	inputs.drive["gate.gd"].head = "PROBE {\"id\":\"AC1\",\"pass\":false,\"observed\":\"still broken\"}\n"
	assert_eq(Verdict.decide(inputs).criteria[0].grade, Verdict.FAIL, "and a probe still failing fails")
