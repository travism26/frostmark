## Board-only, not shipped: writes tools/test_codes.local.md, the map of every test code
## (docs/testing.md). For each test character it gives the short code and link where it has
## them, what it loads, read back from its save, and the full save code.
##   godot --headless -s tools/test_codes.gd
## The repo keeps only the hashes of the short codes and links (scenes/field_kit.gd), so the
## plaintext comes from tools/test_codes.local.cfg, one `name = code` line each. An entry that
## does not match its hash, or names nothing, is refused by name and no map is written; a code
## missing from the seed is written as not known on this machine. Neither file is committed
## (.gitignore): run this again after any pull or merge.
extends SceneTree

const RingCodes := preload("res://tools/ring_codes.gd")
const SEED_PATH := "res://tools/test_codes.local.cfg"
const MAP_PATH := "res://tools/test_codes.local.md"
const SITE := "https://travism26.github.io/frostmark/"

## Each seed name and the hash in scenes/field_kit.gd it must match. A short code is checked
## as FieldKit.normalise leaves it, a query pair as it stands.
const HASHES := {
	"test_mode_short": FieldKit.SHORT_HASH, "test_mode_query": FieldKit.QUERY_HASH,
	"bare_short": FieldKit.BARE_SHORT_HASH, "bare_query": FieldKit.BARE_QUERY_HASH,
	"gear_short": FieldKit.GEAR_SHORT_HASH, "gear_query": FieldKit.GEAR_QUERY_HASH,
}


func _init() -> void:
	var known := _seed()
	if known.has("refused"):
		quit(1)
		return
	var ring_two: Array = FieldKit.RING_SPOTS["two"]
	var entries := [
		{"title": "Test mode", "short": "test_mode_short", "query": "test_mode_query", "code": FieldKit.code()},
		{
			"title": "Test mode in ring two", "query": "test_mode_query", "query_tail": "&ring=two",
			"code": FieldKit.code(null, ring_two),
		},
		{"title": "Build from scratch", "short": "bare_short", "query": "bare_query", "code": FieldKit.bare_code()},
		{"title": "All gear", "short": "gear_short", "query": "gear_query", "code": FieldKit.gear_code()},
	]
	var rings := RingCodes.codes()
	for name in rings:
		entries.append({"title": "Ring code `%s`" % name, "code": rings[name]})
	var lines := PackedStringArray([
		"# Test codes",
		"",
		"Written by `godot --headless -s tools/test_codes.gd` from `scenes/field_kit.gd`,",
		"`tools/ring_codes.gd` and the seed in `tools/test_codes.local.cfg`. Never commit it, and",
		"run the command again after any pull or merge: a stale save code can miss what changed.",
	])
	for entry in entries:
		if (entry["code"] as String).is_empty():
			printerr("%s did not restore in this version" % entry["title"])
			quit(1)
			return
		lines.append_array(_entry(entry, known))
		print("MAP %s" % entry["title"])
	var file := FileAccess.open(MAP_PATH, FileAccess.WRITE)
	file.store_string("\n".join(lines) + "\n")
	file.close()
	print("wrote %s" % ProjectSettings.globalize_path(MAP_PATH))
	quit(0)


## The seed's codes by name, each checked against its hash. Holds `refused` when any entry was.
func _seed() -> Dictionary:
	var known := {}
	if not FileAccess.file_exists(SEED_PATH):
		return known
	var text := FileAccess.get_file_as_string(SEED_PATH)
	for raw in text.split("\n"):
		var line := raw.strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		var cut := line.find("=")
		var name := line.left(cut).strip_edges() if cut > 0 else line
		var value := line.substr(cut + 1).strip_edges() if cut > 0 else ""
		if not HASHES.has(name):
			printerr("refused %s: no test code has that name" % name)
			known["refused"] = true
			continue
		var typed := FieldKit.normalise(value) if name.ends_with("_short") else value
		if typed.sha256_text() != HASHES[name]:
			printerr("refused %s: it does not match its hash in scenes/field_kit.gd" % name)
			known["refused"] = true
			continue
		known[name] = value
	return known


func _entry(entry: Dictionary, known: Dictionary) -> PackedStringArray:
	var lines := PackedStringArray(["", "## %s" % entry["title"], ""])
	if entry.has("short"):
		var name: String = entry["short"]
		if known.has(name):
			lines.append("- Short code: `%s` (any case, surrounding spaces ignored)" % known[name])
		else:
			lines.append("- Short code: not known on this machine (sha256 `%s`)" % HASHES[name])
	if entry.has("query"):
		var name: String = entry["query"]
		var tail: String = entry.get("query_tail", "")
		if known.has(name):
			var query: String = "?" + known[name] + tail
			lines.append("- Link: <%s%s> (local build: `%s`)" % [SITE, query, query])
		else:
			var then := ", then `%s`" % tail if tail != "" else ""
			lines.append("- Link: not known on this machine (query pair sha256 `%s`%s)" % [HASHES[name], then])
	if lines.size() > 3:
		lines.append("")
	lines.append("Loads:")
	lines.append("")
	for point in _summary(entry["code"]):
		lines.append("- " + point)
	lines.append_array(["", "Full save code:", "", "```", entry["code"], "```"])
	return lines


## What a save code loads, read back from the save it imports as.
func _summary(code: String) -> PackedStringArray:
	var sim := Sim.new()
	sim.command(SimVocab.IMPORT_SAVE, {"code": code})
	var state := sim.state
	var points := PackedStringArray()
	points.append("standing in %s at %s" % [state["player"]["region"], state["player"]["pos"]])
	var levels := {}
	for name in SkillTable.NAMES:
		levels[int(state["skills"][name]["level"])] = true
	if levels.size() == 1:
		points.append("every skill at level %d" % levels.keys()[0])
	else:
		points.append("skills at levels %d to %d" % [levels.keys().min(), levels.keys().max()])
	var worn := PackedStringArray()
	for slot in ItemTable.EQUIPMENT_SLOTS:
		var kind: String = state["inventory"]["equipment"].get(slot, "")
		if kind != "":
			worn.append(ItemTable.label(kind))
	points.append("worn: %s" % (", ".join(worn) if not worn.is_empty() else "nothing"))
	points.append("pack: %s" % _contents(state["inventory"]["pack"], false))
	var stash: Array = state["stash"]["slots"]
	var filled := stash.filter(func(slot: Variant) -> bool: return slot != null).size()
	points.append("stash: %d of %d slots filled: %s" % [filled, state["stash"]["capacity"], _contents(stash, true)])
	var built := (state["upgrades"] as Array).size()
	points.append("%d of %d upgrades built" % [built, UpgradeTable.ids().size()])
	var captain := "down" if (state["bosses_defeated"] as Array).has("captain") else "standing"
	points.append("the captain %s; rings reached: %s" % [captain, _list(state["rings_reached"])])
	points.append("waystones attuned: %s" % _list(state["waystones"]))
	var hints := "on" if state["guide"]["on"] else "off"
	points.append("warmth %s of %s, health %s of %s, hints %s" % [
		state["warmth"], Sim.WARMTH_MAX, state["health"], Sim.HEALTH_MAX, hints,
	])
	return points


## Slots summed by kind in table order, by label; with `by_set`, gear is counted by its set
## (or tier) instead.
func _contents(slots: Array, by_set: bool) -> String:
	var gear := 0
	var sets := {}
	var rest := {}
	for kind in ItemTable.ITEMS:
		var count := Inventory.count_of(slots, kind)
		if count == 0:
			continue
		if not by_set or ItemTable.slot(kind) == "":
			rest[ItemTable.label(kind)] = count
			continue
		gear += count
		var group: String = ItemTable.ITEMS[kind].get("set", ItemTable.tier(kind))
		group = group if group != "" else "no tier"
		sets[group] = int(sets.get(group, 0)) + count
	var parts := PackedStringArray()
	if gear > 0:
		var groups := PackedStringArray()
		for group in sets:
			groups.append("%s %d" % [group, sets[group]])
		parts.append("%d gear %s (%s)" % [gear, "item" if gear == 1 else "items", ", ".join(groups)])
	for label in rest:
		parts.append("%s %d" % [label, rest[label]])
	return ", ".join(parts) if not parts.is_empty() else "empty"


func _list(names: Array) -> String:
	return ", ".join(PackedStringArray(names)) if not names.is_empty() else "none"
