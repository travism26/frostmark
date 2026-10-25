## The verify probe lint's text rules (tools/verify/lint.gd `problems()`): a probe must extend
## the probe base, load only the simulation, scenes, test helpers and save fixtures, and never
## touch files or start a process. tools/verify/selftest.sh covers the same rules through drive.
extends "res://tests/run.gd".TestCase

const Lint := preload("res://tools/verify/lint.gd")
const HEAD := "## A probe.\nextends \"res://tools/verify/probe_base.gd\"\n\n"


func _problems(body: String) -> Array[String]:
	return Lint.problems(HEAD + body)


func test_a_clean_probe_has_no_problems() -> void:
	var body := "const H := preload(\"res://tests/sim_helpers.gd\")\n" \
		+ "const Bot := preload(\"res://tests/play_bot.gd\")\n" \
		+ "const G := preload(\"res://scenes/game_root.gd\")\n" \
		+ "func run() -> void:\n\tvar code = load(\"res://tests/fixtures/save_v1.txt\")\n" \
		+ "\tvar s := load('res://sim/sim.gd')\n\tgrade(\"AC1\", true, \"#not a comment\")  # FileAccess in a comment\n"
	assert_eq(_problems(body), [] as Array[String])


func test_it_must_extend_the_base() -> void:
	assert_eq(Lint.problems("extends SceneTree\n").size(), 1)
	assert_true(Lint.problems("extends \"res://tests/run.gd\"\n")[0].begins_with("the probe must start with"))
	assert_eq(Lint.problems("# a comment\n@tool\nextends 'res://tools/verify/probe_base.gd'\n"), [] as Array[String])


func test_loads_off_the_allowed_list_are_refused() -> void:
	assert_true(_problems("var x = load(\"res://tools/test_mode_code.gd\")\n").has("loads a path off the allowed list: res://tools/test_mode_code.gd"))
	assert_true(_problems("const T := preload(\"res://tests/run.gd\")\n").has("loads a path off the allowed list: res://tests/run.gd"))
	assert_true(_problems("var x = load(\"res://simulation_notes.gd\")\n").size() > 0, "a prefix of sim/ is not sim/")
	assert_true(_problems("var x = load(\"res://sim/\")\n").size() > 0, "the folder itself is not a file in it")
	assert_true(_problems("var x = load(\"/etc/hosts\")\n").size() > 0, "an absolute path")


func test_a_built_path_is_refused() -> void:
	assert_true(_problems("var p := \"res://sim/sim.gd\"\nvar x = load(p)\n")[0].begins_with("loads a path that is not a plain string"))
	assert_true(_problems("var x = load(\"res://\" + \"tools/x.gd\")\n").size() > 0)


func test_a_stored_path_off_the_list_is_refused() -> void:
	assert_true(_problems("var p := \"user://save.txt\"\n").has("names a path off the allowed list: user://save.txt"))


func test_files_and_processes_are_refused() -> void:
	assert_true(_problems("var f = FileAccess.open(\"x\", FileAccess.READ)\n").has("uses FileAccess"))
	assert_true(_problems("var d = DirAccess.open(\"x\")\n").has("uses DirAccess"))
	assert_true(_problems("OS.execute(\"ls\", [])\n").has("uses OS.execute"))
	assert_true(_problems("OS . execute_with_pipe(\"ls\", [])\n").has("uses OS.execute"))
	assert_true(_problems("OS.create_process(\"ls\", [])\n").has("uses OS.create_process"))
	assert_true(_problems("var r = ResourceLoader.load(\"res://sim/sim.gd\")\n").has("uses ResourceLoader"))


func test_names_inside_strings_and_comments_do_not_count() -> void:
	assert_eq(_problems("# FileAccess OS.execute load(x)\nvar s := \"DirAccess and OS.execute\"\nvar t := \"\"\"FileAccess\"\"\"\n"), [] as Array[String])
