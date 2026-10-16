## Every item kind as data: label, stack size, weight, value and, for gear, its equipment slot.
##
## Weight is whole kilograms and value whole coins so both stay exact through JSON. `stack`
## is how many fit in one pack or stash slot; 1 means the item never stacks. `slot` is the
## equipment slot the item goes in, or "" for materials. `tool` names what a tool counts as
## for gathering ("axe" for woodcutting). `tier` is the gear tier the brief shows on the
## character. Engine-free like the rest of sim/.
class_name ItemTable
extends RefCounted

const SLOT_WEAPON := "weapon"
const SLOT_ARMOUR := "armour"
const SLOT_TOOL := "tool"
const EQUIPMENT_SLOTS: Array[String] = [SLOT_WEAPON, SLOT_ARMOUR, SLOT_TOOL]

const TOOL_AXE := "axe"

const ITEMS := {
	"logs": {
		"label": "Logs", "stack": 10, "weight": 1, "value": 2, "slot": "",
	},
	"wooden_axe": {
		"label": "Wooden axe", "stack": 1, "weight": 2, "value": 5, "slot": SLOT_TOOL,
		"tool": TOOL_AXE, "tier": "wooden",
	},
	"wooden_club": {
		"label": "Wooden club", "stack": 1, "weight": 3, "value": 12, "slot": SLOT_WEAPON,
		"style": "melee", "tier": "wooden",
	},
}


static func has(kind: String) -> bool:
	return ITEMS.has(kind)


static func label(kind: String) -> String:
	return ITEMS[kind]["label"] if ITEMS.has(kind) else kind


static func stack_size(kind: String) -> int:
	return int(ITEMS[kind]["stack"])


static func weight(kind: String) -> int:
	return int(ITEMS[kind]["weight"])


static func value(kind: String) -> int:
	return int(ITEMS[kind]["value"])


static func slot(kind: String) -> String:
	return ITEMS[kind]["slot"]


static func tool(kind: String) -> String:
	return ITEMS[kind].get("tool", "")
