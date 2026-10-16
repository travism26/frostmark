## Project settings the build and the deploy rely on.
extends "res://tests/run.gd".TestCase


func test_version_is_semver() -> void:
	var version: String = ProjectSettings.get_setting("application/config/version", "")
	var semver := RegEx.create_from_string("^\\d+\\.\\d+\\.\\d+$")
	assert_true(semver.search(version) != null, "application/config/version %s is not MAJOR.MINOR.PATCH" % version)


func test_renderer_is_gl_compatibility() -> void:
	assert_eq(ProjectSettings.get_setting("rendering/renderer/rendering_method"), "gl_compatibility")
	assert_eq(ProjectSettings.get_setting("rendering/renderer/rendering_method.mobile"), "gl_compatibility")
