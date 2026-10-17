## The save-code reminder after long play and the warning when the browser stops keeping saves.
extends "res://tests/run.gd".TestCase


func _advance(watch: SaveWatch, ticks: int) -> int:
	var due := 0
	for i in ticks:
		if watch.advance():
			due += 1
	return due


func test_the_reminder_falls_due_after_45_minutes_of_play() -> void:
	assert_eq(SaveWatch.REMINDER_TICKS * Sim.TICK_SECONDS, 45.0 * 60.0)
	var watch := SaveWatch.new()
	assert_eq(_advance(watch, SaveWatch.REMINDER_TICKS - 1), 0, "not before")
	assert_true(watch.advance(), "due on the tick 45 minutes are reached")
	assert_eq(watch.ticks_left(), SaveWatch.REMINDER_TICKS, "the count starts again")


func test_an_ignored_reminder_comes_back() -> void:
	var watch := SaveWatch.new()
	assert_eq(_advance(watch, SaveWatch.REMINDER_TICKS * 3), 3, "once every 45 minutes")


func test_seeing_the_code_or_dismissing_restarts_the_count() -> void:
	var watch := SaveWatch.new()
	_advance(watch, SaveWatch.REMINDER_TICKS - 10)
	watch.code_seen()
	assert_eq(_advance(watch, SaveWatch.REMINDER_TICKS - 1), 0, "a full interval after the code was seen")
	assert_true(watch.advance())


func test_a_failed_write_warns_once() -> void:
	var watch := SaveWatch.new()
	assert_true(watch.storage_ok)
	assert_false(watch.stored(true), "a good write says nothing")
	assert_true(watch.stored(false), "the first failure warns")
	assert_false(watch.storage_ok)
	assert_false(watch.stored(false), "later failures do not warn again")
	assert_false(watch.stored(true), "a write that holds clears it quietly")
	assert_true(watch.storage_ok)
	assert_true(watch.stored(false), "failing again after recovering warns again")


func test_storage_failing_from_the_first_write_warns() -> void:
	assert_true(SaveWatch.new().stored(false), "private browsing fails the very first save")


func test_reminders_come_sooner_while_saves_are_not_kept() -> void:
	var watch := SaveWatch.new()
	watch.stored(false)
	assert_eq(watch.interval(), SaveWatch.REMINDER_TICKS_UNSTORED)
	assert_eq(SaveWatch.REMINDER_TICKS_UNSTORED * Sim.TICK_SECONDS, 15.0 * 60.0)
	assert_eq(_advance(watch, SaveWatch.REMINDER_TICKS_UNSTORED - 1), 0)
	assert_true(watch.advance(), "due after 15 minutes")
	watch.stored(true)
	assert_eq(watch.interval(), SaveWatch.REMINDER_TICKS, "back to 45 once saves hold again")
