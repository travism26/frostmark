## Save codes and save migrations: the text a player copies to carry a character between
## browsers, and the forward migrations that let an older snapshot load after an update.
##
## A code is base64 of `FM|<version>|<checksum>|<snapshot JSON>`. The snapshot is compact
## JSON with sorted keys. The checksum is the first 16 hex digits of SHA-256 over
## `<version>|<snapshot JSON>`: it catches typos, truncation and hand edits, and is not
## meant to stop a determined cheat in a single-player game. Decoding never throws and never
## logs an engine error; a bad code is a result with a reason. Engine-free like sim/.
class_name SaveCode
extends RefCounted

const PREFIX := "FM"
const CHECKSUM_DIGITS := 16

static var _base64 := RegEx.create_from_string("^[A-Za-z0-9+/]+={0,2}$")


## Encodes a snapshot (which carries its own `version`) as a save code.
static func encode(snapshot: Dictionary) -> String:
	var version := int(snapshot.get("version", 0))
	var payload := JSON.stringify(snapshot)
	return Marshalls.utf8_to_base64("%s|%d|%s|%s" % [PREFIX, version, checksum(version, payload), payload])


static func checksum(version: int, payload: String) -> String:
	return ("%d|%s" % [version, payload]).sha256_text().substr(0, CHECKSUM_DIGITS)


## Decodes a save code. Returns {ok, reason, snapshot}. `current_version` is the newest
## version this build can read; a code from a newer build is `unsupported_version`.
## Whitespace (from line-wrapped pastes) is ignored. The snapshot is not migrated here.
static func decode(code: String, current_version: int) -> Dictionary:
	var text := ""
	for c in code:
		if c != " " and c != "\n" and c != "\r" and c != "\t":
			text += c
	if text.length() % 4 != 0 or _base64.search(text) == null:
		return _fail(SimVocab.REASON_BAD_CODE)
	var raw := Marshalls.base64_to_raw(text)
	# Only the canonical encoding of these bytes is accepted, so every changed character
	# is caught, including the padding bits the decoder would otherwise ignore.
	if raw.is_empty() or Marshalls.raw_to_base64(raw) != text:
		return _fail(SimVocab.REASON_BAD_CODE)
	for b in raw:
		if b >= 128:
			return _fail(SimVocab.REASON_BAD_CODE)
	var parts := raw.get_string_from_ascii().split("|", true, 3)
	if parts.size() != 4 or parts[0] != PREFIX or not parts[1].is_valid_int():
		return _fail(SimVocab.REASON_BAD_CODE)
	var version := parts[1].to_int()
	if checksum(version, parts[3]) != parts[2]:
		return _fail(SimVocab.REASON_BAD_CHECKSUM)
	if version > current_version:
		return _fail(SimVocab.REASON_UNSUPPORTED_VERSION)
	var json := JSON.new()
	if json.parse(parts[3]) != OK or not (json.data is Dictionary):
		return _fail(SimVocab.REASON_BAD_CODE)
	var snapshot: Dictionary = json.data
	if int(snapshot.get("version", -1)) != version:
		return _fail(SimVocab.REASON_BAD_CODE)
	return {"ok": true, "reason": "", "snapshot": snapshot}


static func _fail(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason, "snapshot": {}}


# --- Migrations -----------------------------------------------------------------------

## Brings a snapshot of any known version up to `target` by applying each step in turn.
## Returns the migrated deep copy, or null when the version is missing, unknown or newer
## than `target`. Each step hard-codes the defaults of its own version on purpose, so
## retuning a constant later never changes what an old save migrates into.
static func migrate(snapshot: Dictionary, target: int) -> Variant:
	if not snapshot.has("version"):
		return null
	var v: Variant = snapshot["version"]
	if not (v is int or v is float) or int(v) < 1 or int(v) > target:
		return null
	var snap := snapshot.duplicate(true)
	var version := int(v)
	while version < target:
		match version:
			1:
				snap = _v1_to_v2(snap)
			2:
				snap = _v2_to_v3(snap)
			3:
				snap = _v3_to_v4(snap)
			4:
				snap = _v4_to_v5(snap)
			5:
				snap = _v5_to_v6(snap)
			6:
				snap = _v6_to_v7(snap)
			7:
				snap = _v7_to_v8(snap)
			8:
				snap = _v8_to_v9(snap)
			9:
				snap = _v9_to_v10(snap)
			10:
				snap = _v10_to_v11(snap)
			11:
				snap = _v11_to_v12(snap)
			_:
				return null
		version = int(snap["version"])
	return snap


## Version 1 (slice 2) held only the tick and the player's position. Version 2 adds the
## inventory, stash, skills, warmth, health, nodes and upgrades of a new character.
static func _v1_to_v2(snap: Dictionary) -> Dictionary:
	var pack: Array = []
	pack.resize(12)
	var stash: Array = []
	stash.resize(8)
	var skills := {}
	for name in ["woodcutting", "mining", "fishing", "cooking", "smithing", "melee", "ranged"]:
		skills[name] = {"xp": 0, "level": 1}
	snap["version"] = 2
	snap["rng"] = 1
	snap["warmth"] = 360
	snap["health"] = 100
	snap["inventory"] = {
		"pack": pack,
		"equipment": {"weapon": "", "armour": "", "tool": "wooden_axe"},
	}
	snap["stash"] = {"capacity": 8, "slots": stash}
	snap["skills"] = skills
	snap["nodes"] = {}
	snap["upgrades"] = []
	snap["pending"] = []
	if snap.get("player") is Dictionary:
		snap["player"]["activity"] = {}
	return snap


## Version 2 (slice 3) had no combat. Version 3 adds the player's swing timer, food healing in
## progress, the enemies (empty here, so every enemy loads at home, unhurt and idle), ground
## loot, and the slice-4 starter kit (a wooden bow, 30 arrows, 5 cooked fish) placed in empty
## stash slots so a slice-3 character can fight too. What does not fit is not added.
static func _v2_to_v3(snap: Dictionary) -> Dictionary:
	snap["version"] = 3
	snap["healing"] = []
	snap["enemies"] = {}
	snap["loot"] = {}
	snap["loot_seq"] = 0
	if snap.get("player") is Dictionary:
		snap["player"]["ready_tick"] = 0
	var stash: Variant = snap.get("stash")
	if stash is Dictionary and stash.get("slots") is Array:
		var slots: Array = stash["slots"]
		var kit := [
			{"item": "wooden_bow", "count": 1}, {"item": "arrows", "count": 30}, {"item": "cooked_fish", "count": 5},
		]
		for i in slots.size():
			if kit.is_empty():
				break
			if slots[i] == null:
				slots[i] = kit.pop_front()
	return snap


## Version 3 (slice 4) had one patch of ring one and no field fires, cooking or upgrades to
## build. Version 4 adds field fires (none burning), the guardians defeated so far (none), and
## leaves everything else as it was: the new nodes and enemies (the rest of ring one and the
## captain) load full and at home, and the stash keeps its capacity.
static func _v3_to_v4(snap: Dictionary) -> Dictionary:
	snap["version"] = 4
	snap["fires"] = {}
	snap["fire_seq"] = 0
	snap["bosses_defeated"] = []
	return snap


## Version 4 (slice 5) had no first-outing guide. Every version-4 character has already been
## played, so version 5 gives it the guide switched off with its four hint steps behind it.
static func _v4_to_v5(snap: Dictionary) -> Dictionary:
	snap["version"] = 5
	snap["guide"] = {"on": false, "step": 4, "tips": {}}
	return snap


## Version 5 had seven skills and a two-way style edge. Version 6 adds the eighth
## skill, magic, at level 1 with no experience, keeping a magic entry already there. Nothing
## else changes: the ice crystals and the frost witches load full and at home, and the
## captain's longer cycle carries on from the step he was on.
static func _v5_to_v6(snap: Dictionary) -> Dictionary:
	snap["version"] = 6
	var skills: Variant = snap.get("skills")
	if skills is Dictionary and not skills.has("magic"):
		skills["magic"] = {"xp": 0, "level": 1}
	return snap


## Version 6 ended at the gate to ring two: walking through it sent the character home with
## the ending screen. Version 7 opens ring two and adds the rings the character has walked
## into (none recorded yet, so the first walk through the gate is still announced). Everything
## else is as it was: ring two's nodes and monsters load full and at home, and a character who
## saw the old ending simply finds the gate open.
static func _v6_to_v7(snap: Dictionary) -> Dictionary:
	snap["version"] = 7
	snap["rings_reached"] = []
	return snap


## Version 7 had waystones listed but locked. Version 8 wakes them and records the waystones the
## character has visited: none yet, so each must be walked to once. Nothing else changes: the
## upgrade could not be built before, so no old character has it.
static func _v7_to_v8(snap: Dictionary) -> Dictionary:
	snap["version"] = 8
	snap["waystones"] = []
	return snap


## Version 8 had no Stash vault. Version 9 adds it to the tree; a version-8 save cannot hold it,
## so only the version number changes: the upgrades and the stash stay exactly as they were.
static func _v8_to_v9(snap: Dictionary) -> Dictionary:
	snap["version"] = 9
	return snap


## Version 9 had one armour slot. Version 10 splits it into helm, body and legs, and each tier's
## single armour becomes that tier's body piece wherever it is: worn, in the pack, in the stash,
## lying as loot or named by a queued command. The helm and legs slots start empty.
static func _v9_to_v10(snap: Dictionary) -> Dictionary:
	snap["version"] = 10
	var inventory: Variant = snap.get("inventory")
	if inventory is Dictionary:
		var worn: Variant = inventory.get("equipment")
		if worn is Dictionary:
			var armour := _as_body(str(worn.get("armour", "")))
			worn.erase("armour")
			worn["helm"] = ""
			worn["body"] = armour
			worn["legs"] = ""
		_bodies_in(inventory.get("pack"))
	var stash: Variant = snap.get("stash")
	if stash is Dictionary:
		_bodies_in(stash.get("slots"))
	var loot: Variant = snap.get("loot")
	if loot is Dictionary:
		_bodies_in(loot.values())
	var pending: Variant = snap.get("pending")
	if pending is Array:
		for p in pending:
			var args: Variant = p.get("args") if p is Dictionary else null
			if args is Dictionary:
				if args.has("item"):
					args["item"] = _as_body(str(args["item"]))
				if str(args.get("unequip", "")) == "armour":
					args["unequip"] = "body"
	return snap


## Version 10 had five equipment slots. Version 11 adds the quiver and the cape, both empty:
## nothing could go in them before, so everything else stays exactly as it was.
static func _v10_to_v11(snap: Dictionary) -> Dictionary:
	snap["version"] = 11
	var inventory: Variant = snap.get("inventory")
	if inventory is Dictionary:
		var worn: Variant = inventory.get("equipment")
		if worn is Dictionary:
			worn["quiver"] = ""
			worn["cape"] = ""
	return snap


## Version 11 had no fight phases. Version 12 records the phase each enemy fights in, and every
## enemy saved before then was on its kind's own cycle: phase 0, everything else as it was.
static func _v11_to_v12(snap: Dictionary) -> Dictionary:
	snap["version"] = 12
	var enemies: Variant = snap.get("enemies")
	if enemies is Dictionary:
		for e in enemies.values():
			if e is Dictionary:
				e["phase"] = 0
	return snap


## `<tier>_armour` as `<tier>_body`; any other kind unchanged.
static func _as_body(kind: String) -> String:
	return kind.trim_suffix("_armour") + "_body" if kind.ends_with("_armour") else kind


## Renames every `<tier>_armour` among `entries` (slot or loot dictionaries) to its body piece.
static func _bodies_in(entries: Variant) -> void:
	if not (entries is Array):
		return
	for e in entries:
		if e is Dictionary and e.has("item"):
			e["item"] = _as_body(str(e["item"]))
