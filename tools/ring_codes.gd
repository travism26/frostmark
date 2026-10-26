## Board-only, not shipped: prints a save code that puts a fresh character in each ring, for
## importing into a browser build to screenshot it. `ring_one_cold` is ring one with the
## warmth run low, for the frost vignette; `dungeon_mouth` stands on ring one's side of the
## ring-one dungeon's mouth, and `ring_one_dungeon` just inside it. `ring_one_dungeon_boss` is a
## ring-one character just outside the great frost bear's room with a ring-one kit (iron gear, a
## staff, food and warm fur), for fighting the bear by hand. tools/test_codes.gd lists the same
## codes.
##   godot --headless -s tools/ring_codes.gd
extends SceneTree

const H := preload("res://tests/sim_helpers.gd")
const SPOTS := {
	"outpost": [0.5, 4.5], "inner_ring": [-1.5, 16.5], "ring_one": [-11.5, 36.5], "ring_two": [2.5, 71.5],
	"ring_three": [-33.5, 136.5], "dungeon_mouth": [57.5, -47.0], "ring_one_dungeon": [69.5, -47.5],
}
## The warmth `ring_one_cold` is left with.
const COLD_WARMTH := 70
## Just outside the great frost bear's room, at its open south-east end, past the dungeon's last
## fight and out of the bear's sight.
const BOSS_SPOT := [88.5, 56.5]
## The ring-one kit the boss code carries: iron armour and an iron staff worn, an iron sword, frost
## shards, cooked trout and a fur set (warmth for the walk back) in the pack, and combat skills at
## a level a player who has cleared ring one has reached.
const BOSS_EQUIPMENT := {"weapon": "iron_staff", "helm": "iron_helm", "body": "iron_body", "legs": "iron_legs"}
const BOSS_PACK := [
	{"item": "iron_sword", "count": 1}, {"item": "frost_shards", "count": 100},
	{"item": "cooked_trout", "count": 5}, {"item": "fur_hood", "count": 1},
	{"item": "fur_coat", "count": 1}, {"item": "fur_legs", "count": 1},
]
const BOSS_LEVEL := 20


func _init() -> void:
	var all := codes()
	for name in all:
		print("CODE %s %s" % [name, all[name]])
	quit(0)


## Every ring code by name, in the order printed.
static func codes() -> Dictionary:
	var all := {}
	for ring in SPOTS:
		all[ring] = _placed(SPOTS[ring])
	all["ring_one_cold"] = _placed(SPOTS["ring_one"], COLD_WARMTH)
	all["ring_one_dungeon_boss"] = boss_sim().export_code()
	return all


## A new character with the ring-one kit at BOSS_SPOT, the dungeon already reached.
static func boss_sim() -> Sim:
	var sim := Sim.new()
	sim.command(SimVocab.NEW_CHARACTER, {"previous": ""})
	var snap := sim.snapshot()
	for skill in [SkillTable.MELEE, SkillTable.RANGED, SkillTable.MAGIC]:
		snap["skills"][skill] = {"xp": SkillTable.xp_for_level(BOSS_LEVEL), "level": BOSS_LEVEL}
	var pack: Array = BOSS_PACK.duplicate(true)
	pack.resize(Sim.PACK_SLOTS)
	snap["inventory"] = {"pack": pack, "equipment": BOSS_EQUIPMENT.duplicate()}
	snap["dungeons_reached"] = ["ring_one_dungeon"]
	snap["player"]["pos"] = BOSS_SPOT.duplicate()
	snap["player"]["path"] = []
	sim.restore(snap)
	return sim


static func _placed(spot: Array, warmth: int = -1) -> String:
	var sim := Sim.new()
	sim.command(SimVocab.NEW_CHARACTER, {"previous": ""})
	H.place(sim, spot)
	if warmth >= 0:
		sim.state["warmth"] = warmth
	return sim.export_code()
