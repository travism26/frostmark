## Feature probe: save codes (features/save-codes.md). A played character's code carries it to
## another game; a damaged code is refused and changes nothing.
##   AC1 export: export_save returns a code and changes nothing
##   AC2 import: the code loads the same character into a new game, and saves as import_save
##   AC3 damaged code: one changed character is refused as save_rejected, the state untouched
##   AC4 test code: the test-mode code loads every skill at 99 and every upgrade built
extends "res://tools/verify/probe_base.gd"

const H := preload("res://tests/sim_helpers.gd")
const Vocab := preload("res://sim/vocab.gd")


func run() -> void:
	var played := Sim.new()
	played.command(Vocab.CROSS_GATE, {})
	H.run_until_idle(played, 200)
	played.command(Vocab.GATHER, {"object_id": "tree_1"})
	H.run_until_idle(played, 400)
	var before := played.snapshot()
	var exported := played.command(Vocab.EXPORT_SAVE, {})
	var code := String(exported.get("code", ""))
	grade("AC1", exported["ok"] and code != "" and played.snapshot() == before,
		{"ok": exported["ok"], "code_length": code.length(), "unchanged": played.snapshot() == before})

	var other := Sim.new()
	var imported := other.command(Vocab.IMPORT_SAVE, {"code": code})
	var events := other.drain_events()
	grade("AC2", imported["ok"] and other.snapshot() == before
		and H.where(events, Vocab.EV_SAVED, "reason", "import_save").size() == 1,
		{"command": imported, "same": other.snapshot() == before,
		"logs": H.pack_count(other, "logs"), "saved": H.of_kind(events, Vocab.EV_SAVED)})

	var damaged := code.substr(0, 20) + ("A" if code[20] != "A" else "B") + code.substr(21)
	var target := Sim.new()
	var pristine := target.snapshot()
	var refused := target.command(Vocab.IMPORT_SAVE, {"code": damaged})
	var rejects := H.of_kind(target.drain_events(), Vocab.EV_SAVE_REJECTED)
	grade("AC3", not refused["ok"] and rejects.size() == 1 and target.snapshot() == pristine,
		{"command": refused, "save_rejected": rejects})

	var kit := Sim.new()
	var loaded := kit.command(Vocab.IMPORT_SAVE, {"code": FieldKit.code()})
	var levels := []
	for s in kit.state["skills"]:
		levels.append(int(kit.state["skills"][s]["level"]))
	grade("AC4", loaded["ok"] and levels.min() == 99
		and kit.state["upgrades"].size() == UpgradeTable.UPGRADES.size(),
		{"command": loaded, "levels": levels, "upgrades": kit.state["upgrades"].size(),
		"table": UpgradeTable.UPGRADES.size()})
