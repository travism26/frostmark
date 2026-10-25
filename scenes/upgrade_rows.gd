## How the Upgrades tab lays out and words its rows, as pure functions the HUD draws from: the
## groups (each upgrade line in step order, then the single upgrades), each row's state and
## text from one entry of the sim's `upgrade_status()`, and the one flash a row gives when it
## is built. No nodes and no sim: it reads only the status it is handed and the tables.
class_name UpgradeRows
extends RefCounted

## A row's state: built, can be built now, not yet (with what is missing), or locked in this
## version.
const BUILT := "built"
const CAN_BUILD := "can_build"
const NOT_YET := "not_yet"
const LOCKED := "locked"

## The heading over the upgrades that belong to no line.
const SINGLES := "Single upgrades"

## How long the row just built flashes, in seconds: one rise and fall, then it rests as built.
const FLASH_SECONDS := 0.9

## What readying each ring gate does, by the gate's object id.
const RING_GATE_TEXT := {
	"ring_two_gate": "works the gate to ring two once its captain falls",
	"ring_three_gate": "opens the gate to ring three, in ring two's southern cliffs",
}


## The tab's groups in order: `{title, ids}`. An upgrade line is a YardLook line with more
## than one step; its rows come in step order, and lines in the order the table first names
## them. Every other upgrade (a one-step line, or one with no look) goes under SINGLES, in
## table order, after the lines.
static func groups() -> Array[Dictionary]:
	var steps := {}  # line -> {step: id}
	var order: Array[String] = []
	for id in UpgradeTable.ids():
		var look: Dictionary = YardLook.LOOKS.get(id, {})
		if look.is_empty():
			continue
		if not steps.has(look["line"]):
			steps[look["line"]] = {}
			order.append(look["line"])
		steps[look["line"]][int(look["step"])] = id
	var out: Array[Dictionary] = []
	var in_line := {}
	for line in order:
		var by_step: Dictionary = steps[line]
		if by_step.size() < 2:
			continue
		var keys := by_step.keys()
		keys.sort()
		var ids: Array[String] = []
		for k in keys:
			ids.append(by_step[k])
			in_line[by_step[k]] = true
		out.append({"title": "%s line" % line.capitalize(), "ids": ids})
	var singles: Array[String] = []
	for id in UpgradeTable.ids():
		if not in_line.has(id):
			singles.append(id)
	if not singles.is_empty():
		out.append({"title": SINGLES, "ids": singles})
	return out


## One row from its `upgrade_status()` entry: `{state, lines, button, icon}`. `lines` are
## the text under the title (what the upgrade does first), `button` the Build button's text
## and `icon` the Kenney icon on it ("" for none). A row that can't be built yet says what is
## missing: the upgrades it needs first and how much more of each short cost item.
static func view(id: String, status: Dictionary) -> Dictionary:
	var state := NOT_YET
	if status["status"] == SimVocab.UPGRADE_BUILT:
		state = BUILT
	elif status["locked"] != "":
		state = LOCKED
	elif status["status"] == SimVocab.UPGRADE_CAN_BUILD:
		state = CAN_BUILD
	var lines: Array[String] = [effect_text(UpgradeTable.get_upgrade(id)["effects"])]
	match state:
		BUILT:
			lines.append("Built.")
		LOCKED:
			lines.append("Locked. %s" % status["locked"])
		_:
			var costs: PackedStringArray = []
			for c in status["cost"]:
				costs.append("%d %s (%d)" % [c["need"], ItemTable.label(c["item"]), c["have"]])
			lines.append("Costs %s from the stash and your pack." % ", ".join(costs))
			var missing: PackedStringArray = []
			for need in status["requires"]:
				missing.append(UpgradeTable.get_upgrade(need)["label"])
			if not missing.is_empty():
				lines.append("Needs the %s first." % " and the ".join(missing))
			var short: PackedStringArray = []
			for c in status["short"]:
				short.append("%d %s" % [int(c["need"]) - int(c["have"]), ItemTable.label(c["item"]).to_lower()])
			if not short.is_empty():
				lines.append("Short of %s." % _and_list(short))
	var button := "Build"
	var icon := ""
	match state:
		BUILT:
			button = "Built"
			icon = "checkmark"
		LOCKED:
			button = "Locked"
			icon = "locked"
		CAN_BUILD:
			icon = "unlocked"
	return {"state": state, "lines": lines, "button": button, "icon": icon}


## How strongly the row just built glows `t` seconds after the build: a single rise and fall
## from 0 to 1 and back over FLASH_SECONDS, and 0 before and after.
static func flash(t: float) -> float:
	if t <= 0.0 or t >= FLASH_SECONDS:
		return 0.0
	return sin(PI * t / FLASH_SECONDS)


## "a", "a and b", "a, b and c".
static func _and_list(parts: PackedStringArray) -> String:
	if parts.size() < 2:
		return "".join(parts)
	return "%s and %s" % [", ".join(parts.slice(0, -1)), parts[-1]]


## What an upgrade's effects do, as one sentence.
static func effect_text(effects: Dictionary) -> String:
	var parts: PackedStringArray = []
	if effects.has("stash"):
		parts.append("+%d stash slots" % effects["stash"])
	if effects.has("carry"):
		parts.append("+%d kg carry limit" % effects["carry"])
	if effects.has("recipes"):
		var names: PackedStringArray = []
		for r in effects["recipes"]:
			names.append(str(RecipeTable.get_recipe(r)["label"]).to_lower())
		parts.append("unlocks %s" % ", ".join(names))
	if effects.has("smithing_tier"):
		parts.append("smithing works up to %s" % effects["smithing_tier"])
	if effects.has("ring_gate"):
		parts.append(RING_GATE_TEXT.get(effects["ring_gate"], "opens a ring gate"))
	if effects.has("waystones"):
		parts.append("wakes the waystones in ring one and ring two: visit one, then travel home from it")
	var text := "; ".join(parts)
	return text.substr(0, 1).to_upper() + text.substr(1)
