## The player's body: the KayKit barbarian, 1.8 m tall, standing on the Character node's
## origin and facing its -Z. Besides the idle, walk and run clips every FigureBody plays, it
## reads the simulation's player activity once given a `sim` and swings an axe while
## gathering, strikes with the equipped weapon's style while attacking and stirs the pot while
## cooking; it casts with a staff and flinches when a blow lands on it. The model's own hat,
## axes, round shield and mug are hidden; CharacterGear hangs only the equipped gear off its
## bone slots.
class_name CharacterView
extends FigureBody

const MODEL := "res://assets/models/kaykit_adventurers/barbarian.glb"
const HEIGHT := 1.8
const CLIPS := {
	"idle": "Idle", "walk": "Walking_A", "run": "Running_A",
	"melee": "1H_Melee_Attack_Slice_Horizontal", "ranged": "2H_Ranged_Shoot", "magic": "Spellcast_Shoot",
	"flinch": "Hit_A", "death": "Death_A",
}
const CLIP_CHOP := "1H_Melee_Attack_Chop"
const CLIP_FISH := "Interact"
const CLIP_PUNCH := "Unarmed_Melee_Attack_Punch_A"
const CLIP_COOK := "Use_Item"
## The meshes the barbarian glb carries besides its body and cape: never drawn, so only the
## sim's equipment shows.
const BUILT_IN_GEAR := ["Barbarian_Hat", "1H_Axe", "1H_Axe_Offhand", "2H_Axe", "Barbarian_Round_Shield", "Mug"]

var _sim: Sim


func _init() -> void:
	name = "View"
	setup(MODEL, Figures.KAYKIT_HEIGHT, HEIGHT, CLIPS)
	hide_parts(BUILT_IN_GEAR)
	add_to_group("character_view")


## The simulation whose player activity drives the work and fighting clips.
func set_sim(sim: Sim) -> void:
	_sim = sim
	_current = ""
	_refresh()


## True while the body chops, mines or fishes (a flinch over it does not stop the work), so
## the tool is in the hand.
func is_working() -> bool:
	if _sim == null or is_moving():
		return false
	var clip := _base_clip()
	return clip == CLIP_CHOP or clip == CLIP_FISH


func _base_clip() -> String:
	if is_moving() or _sim == null:
		return super()
	var activity: Dictionary = _sim.state["player"]["activity"]
	match str(activity.get("kind", "")):
		SimVocab.GATHER:
			var object_id := str(activity.get("object_id", ""))
			if _sim.world.objects.has(object_id):
				var kind: String = _sim.world.objects[object_id]["kind"]
				if WorldDef.NODE_KINDS.has(kind) and WorldDef.NODE_KINDS[kind]["tool"] == ItemTable.TOOL_ROD:
					return CLIP_FISH
			return CLIP_CHOP
		SimVocab.ATTACK:
			var weapon: String = _sim.state["inventory"]["equipment"][ItemTable.SLOT_WEAPON]
			if weapon == "":
				return CLIP_PUNCH
			var style: String = CombatTable.weapon(weapon)["style"]
			if style == CombatTable.STYLE_RANGED:
				return clips["ranged"]
			return clips["magic"] if style == CombatTable.STYLE_MAGIC else clips["melee"]
		SimVocab.COOK:
			return CLIP_COOK
	return super()
