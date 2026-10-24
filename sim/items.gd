## Every item kind as data: label, stack size, weight, value and, for gear, its equipment slot.
##
## Weight is whole kilograms and value whole coins so both stay exact through JSON. `stack`
## is how many fit in one pack or stash slot; 1 means the item never stacks. `slot` is the
## equipment slot the item goes in, or "" for materials. `tool` names what a tool counts as
## for gathering ("axe" for woodcutting, "pickaxe" for mining, "rod" for fishing). `tier` is
## the gear tier the brief shows on the character (wooden, bronze, iron, steel); a better tool
## gathers faster and surer. A weapon carries its combat `style`, `power` (damage per hit
## before the style edge), `speed` (ticks between swings), `reach` (metres) and, for a ranged
## weapon, the `ammo` item each shot uses (arrows for a bow, frost shards for a staff's cast).
## Armour (a helm, a body and legs, each worn in its own slot) carries `defence`, and the
## worn pieces' defence added up is taken off every hit. Food
## carries `heal`, the health it restores spread over `heal_ticks` ticks. Engine-free like sim/.
class_name ItemTable
extends RefCounted

const SLOT_WEAPON := "weapon"
const SLOT_HELM := "helm"
const SLOT_BODY := "body"
const SLOT_LEGS := "legs"
const SLOT_TOOL := "tool"
const EQUIPMENT_SLOTS: Array[String] = [SLOT_WEAPON, SLOT_HELM, SLOT_BODY, SLOT_LEGS, SLOT_TOOL]
## The three armour slots, head to foot.
const ARMOUR_SLOTS: Array[String] = [SLOT_HELM, SLOT_BODY, SLOT_LEGS]

const TOOL_AXE := "axe"
const TOOL_PICKAXE := "pickaxe"
const TOOL_ROD := "rod"

const TIER_WOODEN := "wooden"
const TIER_BRONZE := "bronze"
const TIER_IRON := "iron"
const TIER_STEEL := "steel"
## The gear tiers in order. A tier's rank is its index: wooden 0, bronze 1, iron 2, steel 3.
const TIERS: Array[String] = [TIER_WOODEN, TIER_BRONZE, TIER_IRON, TIER_STEEL]

const ITEMS := {
	# Materials
	"logs": {
		"label": "Logs", "stack": 10, "weight": 1, "value": 2, "slot": "",
	},
	"copper_ore": {
		"label": "Copper ore", "stack": 10, "weight": 1, "value": 3, "slot": "",
	},
	"tin_ore": {
		"label": "Tin ore", "stack": 10, "weight": 1, "value": 3, "slot": "",
	},
	"iron_ore": {
		"label": "Iron ore", "stack": 10, "weight": 2, "value": 8, "slot": "",
	},
	"bronze_bar": {
		"label": "Bronze bar", "stack": 10, "weight": 1, "value": 8, "slot": "",
	},
	# Smelted from two iron ore once the Bloomery is built.
	"iron_bar": {
		"label": "Iron bar", "stack": 10, "weight": 2, "value": 18, "slot": "",
	},
	# Ring two's seams. Coal and iron ore smelt into steel once the blast furnace is built.
	"coal": {
		"label": "Coal", "stack": 10, "weight": 1, "value": 6, "slot": "",
	},
	"steel_bar": {
		"label": "Steel bar", "stack": 10, "weight": 2, "value": 30, "slot": "",
	},
	"wolf_pelt": {
		"label": "Wolf pelt", "stack": 5, "weight": 1, "value": 8, "slot": "",
	},
	"troll_hide": {
		"label": "Troll hide", "stack": 5, "weight": 2, "value": 20, "slot": "",
	},
	"arrows": {
		"label": "Arrows", "stack": 100, "weight": 0, "value": 1, "slot": "",
	},
	# Mined from ice crystals in the inner ring, refined into frost shards at the workbench.
	"ice_crystal": {
		"label": "Ice crystal", "stack": 10, "weight": 1, "value": 4, "slot": "",
	},
	# A staff's charge: one shard per cast, as a bow spends an arrow per shot.
	"frost_shards": {
		"label": "Frost shards", "stack": 100, "weight": 0, "value": 1, "slot": "",
	},
	# Food: raw is edible but poor; cooking at a fire makes it worth carrying.
	"raw_fish": {
		"label": "Raw fish", "stack": 10, "weight": 1, "value": 2, "slot": "",
		"heal": 4, "heal_ticks": 2,
	},
	"cooked_fish": {
		"label": "Cooked fish", "stack": 10, "weight": 1, "value": 6, "slot": "",
		"heal": 24, "heal_ticks": 4,
	},
	"raw_trout": {
		"label": "Raw trout", "stack": 10, "weight": 1, "value": 4, "slot": "",
		"heal": 6, "heal_ticks": 2,
	},
	"cooked_trout": {
		"label": "Cooked trout", "stack": 10, "weight": 1, "value": 12, "slot": "",
		"heal": 40, "heal_ticks": 5,
	},
	"raw_char": {
		"label": "Raw char", "stack": 10, "weight": 1, "value": 6, "slot": "",
		"heal": 8, "heal_ticks": 2,
	},
	"cooked_char": {
		"label": "Cooked char", "stack": 10, "weight": 1, "value": 18, "slot": "",
		"heal": 56, "heal_ticks": 7,
	},
	# Tools
	"wooden_axe": {
		"label": "Wooden axe", "stack": 1, "weight": 2, "value": 5, "slot": SLOT_TOOL,
		"tool": TOOL_AXE, "tier": TIER_WOODEN,
	},
	"bronze_axe": {
		"label": "Bronze axe", "stack": 1, "weight": 2, "value": 24, "slot": SLOT_TOOL,
		"tool": TOOL_AXE, "tier": TIER_BRONZE,
	},
	"iron_axe": {
		"label": "Iron axe", "stack": 1, "weight": 3, "value": 60, "slot": SLOT_TOOL,
		"tool": TOOL_AXE, "tier": TIER_IRON,
	},
	"steel_axe": {
		"label": "Steel axe", "stack": 1, "weight": 3, "value": 120, "slot": SLOT_TOOL,
		"tool": TOOL_AXE, "tier": TIER_STEEL,
	},
	"wooden_pickaxe": {
		"label": "Wooden pickaxe", "stack": 1, "weight": 2, "value": 6, "slot": SLOT_TOOL,
		"tool": TOOL_PICKAXE, "tier": TIER_WOODEN,
	},
	"bronze_pickaxe": {
		"label": "Bronze pickaxe", "stack": 1, "weight": 3, "value": 24, "slot": SLOT_TOOL,
		"tool": TOOL_PICKAXE, "tier": TIER_BRONZE,
	},
	"iron_pickaxe": {
		"label": "Iron pickaxe", "stack": 1, "weight": 3, "value": 60, "slot": SLOT_TOOL,
		"tool": TOOL_PICKAXE, "tier": TIER_IRON,
	},
	"steel_pickaxe": {
		"label": "Steel pickaxe", "stack": 1, "weight": 3, "value": 120, "slot": SLOT_TOOL,
		"tool": TOOL_PICKAXE, "tier": TIER_STEEL,
	},
	"fishing_rod": {
		"label": "Fishing rod", "stack": 1, "weight": 1, "value": 6, "slot": SLOT_TOOL,
		"tool": TOOL_ROD, "tier": TIER_WOODEN,
	},
	# Weapons
	"wooden_club": {
		"label": "Wooden club", "stack": 1, "weight": 3, "value": 12, "slot": SLOT_WEAPON,
		"style": "melee", "power": 5, "speed": 2, "reach": 1.5, "tier": TIER_WOODEN,
	},
	"bronze_sword": {
		"label": "Bronze sword", "stack": 1, "weight": 3, "value": 40, "slot": SLOT_WEAPON,
		"style": "melee", "power": 7, "speed": 2, "reach": 1.5, "tier": TIER_BRONZE,
	},
	"iron_sword": {
		"label": "Iron sword", "stack": 1, "weight": 4, "value": 80, "slot": SLOT_WEAPON,
		"style": "melee", "power": 9, "speed": 2, "reach": 1.5, "tier": TIER_IRON,
	},
	"steel_sword": {
		"label": "Steel sword", "stack": 1, "weight": 4, "value": 160, "slot": SLOT_WEAPON,
		"style": "melee", "power": 11, "speed": 2, "reach": 1.5, "tier": TIER_STEEL,
	},
	"wooden_bow": {
		"label": "Wooden bow", "stack": 1, "weight": 2, "value": 20, "slot": SLOT_WEAPON,
		"style": "ranged", "power": 4, "speed": 2, "reach": 8.0, "ammo": "arrows", "tier": TIER_WOODEN,
	},
	"bronze_bow": {
		"label": "Bronze bow", "stack": 1, "weight": 2, "value": 44, "slot": SLOT_WEAPON,
		"style": "ranged", "power": 6, "speed": 2, "reach": 8.0, "ammo": "arrows", "tier": TIER_BRONZE,
	},
	"iron_bow": {
		"label": "Iron bow", "stack": 1, "weight": 2, "value": 84, "slot": SLOT_WEAPON,
		"style": "ranged", "power": 8, "speed": 2, "reach": 8.0, "ammo": "arrows", "tier": TIER_IRON,
	},
	"wooden_staff": {
		"label": "Wooden staff", "stack": 1, "weight": 2, "value": 22, "slot": SLOT_WEAPON,
		"style": "magic", "power": 4, "speed": 2, "reach": 6.0, "ammo": "frost_shards", "tier": TIER_WOODEN,
	},
	"bronze_staff": {
		"label": "Bronze staff", "stack": 1, "weight": 2, "value": 46, "slot": SLOT_WEAPON,
		"style": "magic", "power": 6, "speed": 2, "reach": 6.0, "ammo": "frost_shards", "tier": TIER_BRONZE,
	},
	"iron_staff": {
		"label": "Iron staff", "stack": 1, "weight": 2, "value": 86, "slot": SLOT_WEAPON,
		"style": "magic", "power": 8, "speed": 2, "reach": 6.0, "ammo": "frost_shards", "tier": TIER_IRON,
	},
	"steel_bow": {
		"label": "Steel bow", "stack": 1, "weight": 2, "value": 168, "slot": SLOT_WEAPON,
		"style": "ranged", "power": 10, "speed": 2, "reach": 8.0, "ammo": "arrows", "tier": TIER_STEEL,
	},
	"steel_staff": {
		"label": "Steel staff", "stack": 1, "weight": 2, "value": 172, "slot": SLOT_WEAPON,
		"style": "magic", "power": 10, "speed": 2, "reach": 6.0, "ammo": "frost_shards", "tier": TIER_STEEL,
	},
	# Armour: a full set of a tier adds up to the single armour it replaced (#38), in defence,
	# weight and value; the body carries the most.
	"wooden_helm": {
		"label": "Wooden helm", "stack": 1, "weight": 1, "value": 3, "slot": SLOT_HELM,
		"defence": 0, "tier": TIER_WOODEN,
	},
	"wooden_body": {
		"label": "Wooden body", "stack": 1, "weight": 2, "value": 8, "slot": SLOT_BODY,
		"defence": 1, "tier": TIER_WOODEN,
	},
	"wooden_legs": {
		"label": "Wooden legs", "stack": 1, "weight": 1, "value": 5, "slot": SLOT_LEGS,
		"defence": 0, "tier": TIER_WOODEN,
	},
	"bronze_helm": {
		"label": "Bronze helm", "stack": 1, "weight": 1, "value": 10, "slot": SLOT_HELM,
		"defence": 0, "tier": TIER_BRONZE,
	},
	"bronze_body": {
		"label": "Bronze body", "stack": 1, "weight": 3, "value": 24, "slot": SLOT_BODY,
		"defence": 1, "tier": TIER_BRONZE,
	},
	"bronze_legs": {
		"label": "Bronze legs", "stack": 1, "weight": 1, "value": 16, "slot": SLOT_LEGS,
		"defence": 1, "tier": TIER_BRONZE,
	},
	"iron_helm": {
		"label": "Iron helm", "stack": 1, "weight": 1, "value": 20, "slot": SLOT_HELM,
		"defence": 1, "tier": TIER_IRON,
	},
	"iron_body": {
		"label": "Iron body", "stack": 1, "weight": 3, "value": 40, "slot": SLOT_BODY,
		"defence": 1, "tier": TIER_IRON,
	},
	"iron_legs": {
		"label": "Iron legs", "stack": 1, "weight": 2, "value": 30, "slot": SLOT_LEGS,
		"defence": 1, "tier": TIER_IRON,
	},
	"steel_helm": {
		"label": "Steel helm", "stack": 1, "weight": 2, "value": 40, "slot": SLOT_HELM,
		"defence": 1, "tier": TIER_STEEL,
	},
	"steel_body": {
		"label": "Steel body", "stack": 1, "weight": 3, "value": 80, "slot": SLOT_BODY,
		"defence": 2, "tier": TIER_STEEL,
	},
	"steel_legs": {
		"label": "Steel legs", "stack": 1, "weight": 2, "value": 60, "slot": SLOT_LEGS,
		"defence": 1, "tier": TIER_STEEL,
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


## The item's gear tier ("wooden", "bronze", "iron", "steel"), or "" for materials and food.
static func tier(kind: String) -> String:
	return ITEMS[kind].get("tier", "") if ITEMS.has(kind) else ""


## A tier's rank: wooden 0, bronze 1, iron 2, steel 3, and -1 for "" or anything unknown.
static func tier_rank(tier_name: String) -> int:
	return TIERS.find(tier_name)


## How much health the item restores when eaten, or 0 when it is not food.
static func heal(kind: String) -> int:
	return int(ITEMS[kind].get("heal", 0))


## Whether the item is kit, carried to use rather than to bank: gear (anything with an
## equipment slot), the ammo of any weapon, or cooked food (what a cooking recipe makes).
## Everything else, raw food included, is haul.
static func is_kit(kind: String) -> bool:
	if not ITEMS.has(kind):
		return false
	if slot(kind) != "":
		return true
	for other in ITEMS:
		if ITEMS[other].get("ammo", "") == kind:
			return true
	for raw in RecipeTable.COOKING:
		if RecipeTable.COOKING[raw]["output"] == kind:
			return true
	return false


## Health taken off every hit while the item is worn, or 0.
static func defence(kind: String) -> int:
	return int(ITEMS[kind].get("defence", 0)) if ITEMS.has(kind) else 0


## Health taken off every hit by everything worn: the armour pieces' defence added up.
static func worn_defence(equipment: Dictionary) -> int:
	var total := 0
	for slot in ARMOUR_SLOTS:
		total += defence(str(equipment.get(slot, "")))
	return total
