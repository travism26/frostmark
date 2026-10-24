## The HUD's weight line, from the pure function the pack page shows it with: dim with room
## to spare, amber within 5 kg of the carry limit, red with "(slowed)" once overweight, and
## the same thresholds whatever the limit, so the warning follows the Pack frame.
extends "res://tests/run.gd".TestCase

const HudScript := preload("res://scenes/hud.gd")


func test_text_under_at_and_over_the_limit() -> void:
	assert_eq(HudScript._weight_line(30, 45)["text"], "Carrying 30 / 45 kg")
	assert_eq(HudScript._weight_line(45, 45)["text"], "Carrying 45 / 45 kg", "at the limit is not slowed")
	assert_eq(HudScript._weight_line(46, 45)["text"], "Carrying 46 / 45 kg  (slowed)")


func _assert_tones(limit: int) -> void:
	assert_eq(HudScript._weight_line(limit - 6, limit)["tone"], HudScript.TONE_DIM, "L - 6 at L = %d" % limit)
	assert_eq(HudScript._weight_line(limit - 5, limit)["tone"], HudScript.TONE_AMBER, "L - 5 at L = %d" % limit)
	assert_eq(HudScript._weight_line(limit, limit)["tone"], HudScript.TONE_AMBER, "L at L = %d" % limit)
	assert_eq(HudScript._weight_line(limit + 1, limit)["tone"], HudScript.TONE_RED, "L + 1 at L = %d" % limit)


func test_tones_at_the_base_carry_limit() -> void:
	_assert_tones(45)


func test_tones_follow_the_pack_frame_limit() -> void:
	_assert_tones(60)
	assert_eq(HudScript._weight_line(56, 60)["text"], "Carrying 56 / 60 kg")
	assert_eq(HudScript._weight_line(61, 60)["text"], "Carrying 61 / 60 kg  (slowed)")


func test_each_tone_has_its_theme_colour() -> void:
	assert_eq(HudScript.WEIGHT_TONE_COLOURS[HudScript.TONE_DIM], UiTheme.TEXT_DIM)
	assert_eq(HudScript.WEIGHT_TONE_COLOURS[HudScript.TONE_AMBER], UiTheme.EMBER)
	assert_eq(HudScript.WEIGHT_TONE_COLOURS[HudScript.TONE_RED], UiTheme.BLOOD)
