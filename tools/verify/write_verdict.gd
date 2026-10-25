## Writes a verify record's verdict.json and report.md from the inputs the run left in it.
##
##   godot --headless -s tools/verify/write_verdict.gd -- <record>
##
## The record (`$FROSTMARK_VERIFY_HOME/<ticket>/<sha>-<stamp>/`) holds:
##   ticket.md                    the ticket text as fetched (required)
##   grades.json                  the verifier's grades (absent: every criterion is ungraded)
##   inputs.json                  head_sha, base_sha, ticket, ci, harness_version, verifier_model,
##                                head_copy (the head export's folder, for doc quotes),
##                                test_guard, changed_since_fail and earlier, and head_patch
##                                when the head copy was patched
##   drive/<probe>.head.log       raw head output of each probe, and .base.log for base;
##   drive/<probe>.head.rc        optionally the exit code of each side
## The ticket's earlier runs are the verdict.json files of the records inputs.json names in
## `earlier` (folder names beside this one), or when it has no `earlier`, of every other record
## beside this one.
## Prints the verdict and exits 0, or exits 1 when the record can't be read.
extends SceneTree

const Verdict := preload("res://tools/verify/verdict.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1 or not DirAccess.dir_exists_absolute(args[0]):
		printerr("usage: godot --headless -s tools/verify/write_verdict.gd -- <record>")
		quit(1)
		return
	var record: String = args[0].trim_suffix("/")
	if not FileAccess.file_exists(record + "/ticket.md"):
		printerr("verdict: %s has no ticket.md" % record)
		quit(1)
		return
	var given: Dictionary = _json(record + "/inputs.json")
	var grades: Dictionary = _json(record + "/grades.json")
	var binding := {"godot_version": Engine.get_version_info().string}
	for k in ["head_sha", "base_sha", "ticket", "harness_version", "verifier_model"]:
		var v = given.get(k, "")
		# JSON reads every number as a float; the ticket number stays a whole number.
		binding[k] = int(v) if v is float and v == floorf(v) else v
	# A head copy with a patch on it (tools/verify/prove.sh's planted bug) is not the commit.
	if given.has("head_patch"):
		binding["head_patch"] = given["head_patch"]
	var result := Verdict.decide({
		"ticket": FileAccess.get_file_as_string(record + "/ticket.md"),
		"grades": grades,
		"drive": _drive(record + "/drive"),
		"docs": _docs(grades, str(given.get("head_copy", ""))),
		"ci": given.get("ci", ""),
		"earlier": _earlier(record, given.get("earlier", null)),
		"test_guard": given.get("test_guard", {}),
		"changed_since_fail": given.get("changed_since_fail", []),
		"binding": binding,
	})
	_write(record + "/verdict.json", JSON.stringify(result, "  ") + "\n")
	_write(record + "/report.md", Verdict.report_md(result))
	print("verdict: %s (%s)" % [result.verdict, record])
	quit(0)


func _json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


func _drive(dir: String) -> Dictionary:
	var out := {}
	if not DirAccess.dir_exists_absolute(dir):
		return out
	for f in DirAccess.get_files_at(dir):
		for side in ["head", "base"]:
			var suffix := ".%s.log" % side
			if not f.ends_with(suffix):
				continue
			var probe := f.trim_suffix(suffix)
			if not out.has(probe):
				out[probe] = {}
			out[probe][side] = FileAccess.get_file_as_string(dir + "/" + f)
			var rc := "%s/%s.%s.rc" % [dir, probe, side]
			if FileAccess.file_exists(rc):
				out[probe][side + "_rc"] = FileAccess.get_file_as_string(rc).strip_edges().to_int()
	return out


## The head copy's text of each file a doc grade quotes, kept inside the copy.
func _docs(grades: Dictionary, head_copy: String) -> Dictionary:
	var out := {}
	if head_copy == "":
		return out
	for g in grades.get("criteria", []):
		if not (g is Dictionary) or g.get("kind") != "doc":
			continue
		var evidence := str(g.get("evidence", ""))
		var path := evidence.substr(0, evidence.rfind(":"))
		if path == "" or path.is_absolute_path() or ".." in path.split("/"):
			continue
		var full := head_copy.path_join(path)
		if FileAccess.file_exists(full):
			out[path] = FileAccess.get_file_as_string(full)
	return out


func _earlier(record: String, named: Variant) -> Array:
	var out := []
	var parent := record.get_base_dir()
	var dirs: Array = named if named is Array else Array(DirAccess.get_directories_at(parent))
	for d in dirs:
		var other := parent.path_join(str(d))
		if other != record:
			var v := _json(other + "/verdict.json")
			if not v.is_empty():
				out.append(v)
	return out


func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()
