## Shared arrangement helpers for the simulation tests. Not a test file itself (the runner
## only discovers test_*.gd). Everything here goes through Sim's public interface:
## `command()`, `step()`, `drain_events()`, `snapshot()` and `restore()`.
extends RefCounted

const SimScript := preload("res://sim/sim.gd")
const Vocab := preload("res://sim/vocab.gd")

## A point on open ground in the inner ring, just south of the gate.
const OUTSIDE := [0.5, 12.5]
## A point on open floor inside the outpost, clear of the fire's warmth.
const INSIDE_COLD_CORNER := [-7.5, 7.5]


static func run(sim: Sim, ticks: int) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for i in ticks:
		sim.step()
		events.append_array(sim.drain_events())
	return events


## Steps until the player is idle (not walking, not gathering) or `max_ticks` pass.
static func run_until_idle(sim: Sim, max_ticks: int) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for i in max_ticks:
		sim.step()
		events.append_array(sim.drain_events())
		if not sim.is_moving() and not sim.is_gathering():
			break
	return events


static func of_kind(events: Array[Dictionary], kind: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e in events:
		if e["kind"] == kind:
			out.append(e)
	return out


## Walks to `pos` and returns the events of the walk.
static func walk_to(sim: Sim, pos: Array) -> Array[Dictionary]:
	sim.drain_events()
	var result := sim.command(Vocab.MOVE_TO, {"pos": pos})
	assert(result["ok"], "walk_to %s rejected: %s" % [pos, result["reason"]])
	return run_until_idle(sim, 200)


## Replaces the pack with `entries` ({item, count} in slot order) through restore().
static func set_pack(sim: Sim, entries: Array) -> void:
	var snap := sim.snapshot()
	var pack: Array = []
	pack.resize(Sim.PACK_SLOTS)
	for i in entries.size():
		pack[i] = entries[i]
	snap["inventory"]["pack"] = pack
	sim.restore(snap)


## Overrides top-level or nested state keys through restore(), e.g. {"warmth": 3}.
static func patch(sim: Sim, changes: Dictionary) -> void:
	var snap := sim.snapshot()
	snap.merge(changes, true)
	sim.restore(snap)


static func pack_count(sim: Sim, kind: String) -> int:
	return Inventory.count_of(sim.state["inventory"]["pack"], kind)


static func stash_count(sim: Sim, kind: String) -> int:
	return Inventory.count_of(sim.state["stash"]["slots"], kind)


## Puts the player at `pos` through restore(), standing still with nothing to do.
static func place(sim: Sim, pos: Array) -> void:
	var snap := sim.snapshot()
	snap["player"]["pos"] = pos
	snap["player"]["path"] = []
	snap["player"]["target_object"] = ""
	snap["player"]["activity"] = {}
	sim.restore(snap)


## Puts `weapon` in the weapon slot ("" for bare hands) and `entries` in the pack, through
## restore(), so a fight can start this tick without waiting for a queued equip.
static func arm(sim: Sim, weapon: String, entries: Array = []) -> void:
	set_pack(sim, entries)
	var snap := sim.snapshot()
	snap["inventory"]["equipment"]["weapon"] = weapon
	sim.restore(snap)


## Overrides fields of one enemy's state through restore(), e.g. {"health": 1}.
static func patch_enemy(sim: Sim, id: String, changes: Dictionary) -> void:
	var snap := sim.snapshot()
	snap["enemies"][id].merge(changes, true)
	sim.restore(snap)


## Steps one tick at a time for `ticks` ticks, stamping every event with the `tick` it
## happened on.
static func run_stamped(sim: Sim, ticks: int) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for i in ticks:
		sim.step()
		for e in sim.drain_events():
			e["tick"] = int(sim.state["tick"])
			events.append(e)
	return events


## Events of `kind` whose `field` equals `value`.
static func where(events: Array[Dictionary], kind: String, field: String, value: Variant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e in of_kind(events, kind):
		if e.get(field) == value:
			out.append(e)
	return out


## Stand-in kinds for the feint, fight-phase, answer and area-blow rules, which no enemy uses
## yet. A feint pretends to be a lunge (or, for the kiting kind, a dart); a smash strikes a
## front mark and a stomp a ring mark, each 3 m across the radius; an ice fall drops a mark 2.5 m
## across the radius where the player stands, and a quick fall, told one tick ahead, a smaller
## one. `add_stand_ins()` puts them
## in CombatTable for a test.
const STAND_IN_ACTIONS := {
	"feint_lunge": {"label": "Lunge", "damage": 0, "feint": "lunge"},
	"feint_dart": {"label": "Dart", "damage": 0, "feint": "dart"},
	"quicken": {"label": "Quickens", "damage": 0, "stance": true},
	"ground_smash": {"label": "Smash", "damage": 20, "heavy": true, "shape": CombatTable.MARK_FRONT, "size": 3.0},
	"ground_stomp": {"label": "Stomp", "damage": 16, "heavy": true, "shape": CombatTable.MARK_RING, "size": 3.0},
	"ice_fall": {"label": "Ice fall", "damage": 14, "heavy": true, "shape": CombatTable.MARK_DROP, "size": 2.5},
	"quick_fall": {"label": "Quick fall", "damage": 12, "shape": CombatTable.MARK_DROP, "size": 1.5, "warn": 1},
	"quick_smash": {"label": "Quick smash", "damage": 12, "shape": CombatTable.MARK_FRONT, "size": 4.0, "warn": 1},
}
const STAND_IN_KINDS := {
	# Feints a lunge, then lunges for real, rests, winds up into another feint, and rests.
	"stand_in_feinter": {
		"label": "Feinter", "health": 500, "weapon": "fangs", "speed": 2.0, "sight": 6.0,
		"actions": ["feint_lunge", "lunge", CombatTable.ACTION_REST, "wind_up", "feint_lunge", CombatTable.ACTION_REST],
		"loot": [], "rare_percent": 0, "respawn_ticks": 100,
	},
	# Backs away inside 4 m like a ruin stalker, and feints its first dart.
	"stand_in_kiting_feinter": {
		"label": "Kiting feinter", "health": 500, "weapon": "stalker_bow", "speed": 1.5, "sight": 10.0,
		"kite": 4.0, "actions": ["feint_dart", CombatTable.ACTION_REST, "dart", CombatTable.ACTION_REST],
		"loot": [], "rare_percent": 0, "respawn_ticks": 100,
	},
	# Fights like an ice troll, winding up a tick before its crush. Below half health it
	# quickens and crushes with no wind-up; below 45 % it draws a bow and shoots instead.
	"stand_in_phaser": {
		"label": "Phaser", "health": 100, "weapon": "troll_club", "speed": 1.5, "sight": 6.0,
		"actions": ["smash", CombatTable.ACTION_REST, "wind_up", "crush", CombatTable.ACTION_REST, CombatTable.ACTION_REST],
		"phases": [
			{"below": 50, "actions": ["quicken", "smash", "crush", CombatTable.ACTION_REST]},
			{
				"below": 45, "actions": ["draw_bow", "loose", CombatTable.ACTION_REST, "volley", CombatTable.ACTION_REST],
				"stances": ["captain_bow", "captain_bow", "captain_bow", "captain_bow", "captain_bow"],
			},
		],
		"loot": [], "rare_percent": 0, "respawn_ticks": 100,
	},
	# Fights through sabre, bow and staff like the captain, winding up before its cleave, and
	# answers a counter: a staff with its bow, a blade with its staff. It has no answer to a bow.
	"stand_in_answerer": {
		"label": "Answerer", "health": 500, "weapon": "captain_sabre", "speed": 2.0, "sight": 7.0,
		"actions": [
			"slash", CombatTable.ACTION_REST, "wind_up", "cleave", CombatTable.ACTION_REST,
			"draw_bow", "loose", CombatTable.ACTION_REST, "volley", CombatTable.ACTION_REST,
			"draw_staff", "rime_bolt", CombatTable.ACTION_REST, "blizzard", CombatTable.ACTION_REST,
			"draw_sabre",
		],
		"stances": [
			"captain_sabre", "captain_sabre", "captain_sabre", "captain_sabre", "captain_sabre",
			"captain_bow", "captain_bow", "captain_bow", "captain_bow", "captain_bow",
			"captain_staff", "captain_staff", "captain_staff", "captain_staff", "captain_staff",
			"captain_sabre",
		],
		"answers": {CombatTable.STYLE_MAGIC: 5, CombatTable.STYLE_MELEE: 10},
		"answer_ticks": 8,
		"loot": [], "rare_percent": 0, "respawn_ticks": 100,
	},
	# Slashes with its sabre and answers nothing until below half health, where it draws sabre,
	# bow and staff in turn and answers a staff with its bow and a blade with its staff.
	"stand_in_late_answerer": {
		"label": "Late answerer", "health": 100, "weapon": "captain_sabre", "speed": 2.0, "sight": 7.0,
		"actions": ["slash", CombatTable.ACTION_REST, "cleave", CombatTable.ACTION_REST],
		"phases": [
			{
				"below": 50,
				"actions": [
					"draw_sabre", "slash", CombatTable.ACTION_REST, "draw_bow", "loose", CombatTable.ACTION_REST,
					"draw_staff", "rime_bolt", CombatTable.ACTION_REST,
				],
				"stances": [
					"captain_sabre", "captain_sabre", "captain_sabre", "captain_bow", "captain_bow", "captain_bow",
					"captain_staff", "captain_staff", "captain_staff",
				],
				"answers": {CombatTable.STYLE_MAGIC: 3, CombatTable.STYLE_MELEE: 6},
				"answer_ticks": 8,
			},
		],
		"loot": [], "rare_percent": 0, "respawn_ticks": 100,
	},
	# Smashes the ground in front of it, rests, bites, rests.
	"stand_in_smasher": {
		"label": "Smasher", "health": 500, "weapon": "fangs", "speed": 2.0, "sight": 6.0,
		"actions": ["ground_smash", CombatTable.ACTION_REST, "bite", CombatTable.ACTION_REST],
		"loot": [], "rare_percent": 0, "respawn_ticks": 100,
	},
	# Stomps a ring round itself, rests, bites, rests.
	"stand_in_stomper": {
		"label": "Stomper", "health": 500, "weapon": "fangs", "speed": 2.0, "sight": 6.0,
		"actions": ["ground_stomp", CombatTable.ACTION_REST, "bite", CombatTable.ACTION_REST],
		"loot": [], "rare_percent": 0, "respawn_ticks": 100,
	},
	# Smashes and rests until below half health, where it quickens and bites instead.
	"stand_in_area_phaser": {
		"label": "Area phaser", "health": 100, "weapon": "fangs", "speed": 2.0, "sight": 6.0,
		"actions": ["ground_smash", CombatTable.ACTION_REST, CombatTable.ACTION_REST],
		"phases": [{"below": 50, "actions": ["quicken", "bite", CombatTable.ACTION_REST]}],
		"loot": [], "rare_percent": 0, "respawn_ticks": 100,
	},
	# Drops ice on the player's spot, rests, bites, rests.
	"stand_in_dropper": {
		"label": "Dropper", "health": 500, "weapon": "fangs", "speed": 2.0, "sight": 6.0,
		"actions": ["ice_fall", CombatTable.ACTION_REST, "bite", CombatTable.ACTION_REST],
		"loot": [], "rare_percent": 0, "respawn_ticks": 100,
	},
	# Bites and rests until below half health, where it quickens and drops ice told one tick
	# ahead, then smashes in front of it the same way.
	"stand_in_quick_phaser": {
		"label": "Quick phaser", "health": 100, "weapon": "fangs", "speed": 2.0, "sight": 6.0,
		"actions": ["bite", CombatTable.ACTION_REST, CombatTable.ACTION_REST],
		"phases": [{"below": 50, "actions": ["quicken", "quick_fall", CombatTable.ACTION_REST, "quick_smash", CombatTable.ACTION_REST]}],
		"loot": [], "rare_percent": 0, "respawn_ticks": 100,
	},
	# Smashes with its sabre, then draws its bow for a shot and back; answers a staff with its bow.
	"stand_in_area_answerer": {
		"label": "Area answerer", "health": 500, "weapon": "captain_sabre", "speed": 2.0, "sight": 7.0,
		"actions": ["ground_smash", CombatTable.ACTION_REST, "draw_bow", "loose", CombatTable.ACTION_REST, "draw_sabre"],
		"stances": ["captain_sabre", "captain_sabre", "captain_bow", "captain_bow", "captain_bow", "captain_sabre"],
		"answers": {CombatTable.STYLE_MAGIC: 2}, "answer_ticks": 8,
		"loot": [], "rare_percent": 0, "respawn_ticks": 100,
	},
}


static func add_stand_ins() -> void:
	CombatTable.add_stand_ins(STAND_IN_KINDS, STAND_IN_ACTIONS)


## A sim of the real world with only `enemies` in it (id -> {kind, home}), each its own pack,
## in the order given.
static func arena(enemies: Dictionary) -> Sim:
	var world := WorldDef.outpost()
	world.enemies = {}
	for id in enemies:
		world.enemies[id] = {"kind": enemies[id]["kind"], "home": enemies[id]["home"], "pack": id}
	return SimScript.new(world)
