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
