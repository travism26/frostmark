## Every item kind as data: label, stack size, weight, value and, for gear, its equipment slot.
##
## Weight is whole kilograms and value whole coins so both stay exact through JSON. `stack`
## is how many fit in one pack or stash slot; 1 means the item never stacks. `slot` is the
## equipment slot the item goes in, or "" for materials. `tool` names what a tool counts as
## for gathering ("axe" for woodcutting). `tier` is the gear tier the brief shows on the
## character. A weapon carries its combat `style`, `power` (damage per hit before the style
## edge), `speed` (ticks between swings), `reach` (metres) and, for a ranged weapon, the
## `ammo` item each shot uses. Armour carries `defence`, taken off every hit. Food carries
## `heal`, the health it restores spread over `heal_ticks` ticks. Engine-free like sim/.
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
		"style": "melee", "power": 5, "speed": 2, "reach": 1.5, "tier": "wooden",
	},
	"wooden_bow": {
		"label": "Wooden bow", "stack": 1, "weight": 2, "value": 20, "slot": SLOT_WEAPON,
		"style": "ranged", "power": 4, "speed": 2, "reach": 8.0, "ammo": "arrows", "tier": "wooden",
	},
	"arrows": {
		"label": "Arrows", "stack": 100, "weight": 0, "value": 1, "slot": "",
	},
	"cooked_fish": {
		"label": "Cooked fish", "stack": 10, "weight": 1, "value": 6, "slot": "",
		"heal": 24, "heal_ticks": 4,
	},
	"wolf_pelt": {
		"label": "Wolf pelt", "stack": 5, "weight": 1, "value": 8, "slot": "",
	},
	"iron_sword": {
		"label": "Iron sword", "stack": 1, "weight": 4, "value": 80, "slot": SLOT_WEAPON,
		"style": "melee", "power": 9, "speed": 2, "reach": 1.5, "tier": "iron",
	},
	"iron_armour": {
		"label": "Iron armour", "stack": 1, "weight": 6, "value": 90, "slot": SLOT_ARMOUR,
		"defence": 2, "tier": "iron",
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


## How much health the item restores when eaten, or 0 when it is not food.
static func heal(kind: String) -> int:
	return int(ITEMS[kind].get("heal", 0))


## Health taken off every hit while the item is worn, or 0.
static func defence(kind: String) -> int:
	return int(ITEMS[kind].get("defence", 0)) if ITEMS.has(kind) else 0
