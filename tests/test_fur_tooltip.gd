## A fur piece's tooltip: no tier, and that it takes nothing off a hit.
extends "res://tests/run.gd".TestCase


## Every line of text the item tooltip for `kind` shows.
func _tooltip_text(kind: String) -> Array[String]:
	var tip := UiTooltip.item(kind)
	var out: Array[String] = []
	var queue: Array[Node] = [tip]
	while not queue.is_empty():
		var node: Node = queue.pop_front()
		if node is Label:
			out.append((node as Label).text)
		queue.append_array(node.get_children())
	tip.free()
	return out


func test_a_fur_piece_shows_no_tier_and_takes_nothing_off_a_hit() -> void:
	for kind in ["fur_hood", "fur_coat", "fur_legs"]:
		var text := "\n".join(_tooltip_text(kind))
		assert_true(text.contains(ItemTable.label(kind)), "%s is titled" % kind)
		assert_true(text.contains("Takes nothing off a hit"), "%s takes nothing off a hit: %s" % [kind, text])
		assert_false(text.contains("tier"), "%s shows no tier: %s" % [kind, text])
	assert_true("\n".join(_tooltip_text("bronze_helm")).contains("Bronze tier"), "metal still shows its tier")
