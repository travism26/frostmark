## Where the character's equipped items are drawn, as a pure function from the equipment slots
## and whether the body is at work (chopping, mining or fishing): the item in use in the hand,
## at most one more slung on the back, and the armour on the body. Nothing else is drawn, so
## the KayKit barbarian's own axes, round shield and mug stay hidden (CharacterView puts them
## away), and with no shield in the equipment slots no shield shows.
##
## At rest or fighting, the weapon is in the hand and the tool on the back. At work, the tool
## comes to the hand and the weapon is put away, not drawn, so the back is empty. Pure data:
## no nodes, no scene, no sim and nothing saved; CharacterGear builds the meshes from it.
class_name GearLayout
extends RefCounted

const HAND := "hand"
const BACK := "back"
const BODY := "body"
const PLACES: Array[String] = [HAND, BACK, BODY]


## Each place's item ("" for nothing): {hand, back, body}.
static func place(equipment: Dictionary, working: bool) -> Dictionary:
	var weapon: String = equipment.get(ItemTable.SLOT_WEAPON, "")
	var tool: String = equipment.get(ItemTable.SLOT_TOOL, "")
	var layout := {HAND: weapon, BACK: tool, BODY: equipment.get(ItemTable.SLOT_ARMOUR, "")}
	if working and tool != "":
		layout[HAND] = tool
		layout[BACK] = ""
	return layout
