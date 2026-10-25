## Every item kind as data: label, stack size, weight, value and, for gear, its equipment slot.
##
## Weight is whole kilograms and value whole coins so both stay exact through JSON. `stack`
## is how many fit in one pack or stash slot; 1 means the item never stacks. `slot` is the
## equipment slot the item goes in, or "" for materials. `tool` names what a tool counts as
## for gathering ("axe" for woodcutting, "pickaxe" for mining, "rod" for fishing). `tier` is
## the gear tier the brief shows on the character (wooden, bronze, iron, steel); a better tool
## gathers faster and surer. Fur pieces are armour with no tier: a sideways choice, not a
## rung. A weapon carries its combat `style`, `power` (damage per hit before the style edge),
## `speed` (ticks between swings), `reach` (metres) and, for a ranged weapon, the `ammo` item
## each shot uses (arrows for a bow, frost shards for a staff's cast). Armour (a helm, a body
## and legs, each worn in its own slot) carries `defence`, and the worn pieces' defence added
## up is taken off every hit. `warmth` is points of cold kept out while worn (1 on each fur
## piece); the more is worn, the slower warmth drains outside (see Sim.WARMTH_PACE). Food
## carries `heal`, the health it restores spread over `heal_ticks` ticks.
##
## A gear piece of a set carries `"set": "<set key>"` and no `tier`: like fur, a sideways piece
## with no rank until #138 places the sets on the ladder. Until #138 settles its stats and
## sources, a set item takes the stats of the steel item of its slot and style (weight, value
## and defence, and for a weapon its power, speed, reach and ammo), and it has no recipe and
## no drop. A quiver or a cape has no steel counterpart, so until #138 a quiver or cape set item
## takes weight 1, value 40, no defence and no warmth. Engine-free like sim/.
class_name ItemTable
extends RefCounted

const SLOT_WEAPON := "weapon"
const SLOT_HELM := "helm"
const SLOT_BODY := "body"
const SLOT_LEGS := "legs"
const SLOT_TOOL := "tool"
## A quiver worn on the back and a cape hung behind the body (#161). Neither is an armour slot,
## so neither adds to worn defence.
const SLOT_QUIVER := "quiver"
const SLOT_CAPE := "cape"
const EQUIPMENT_SLOTS: Array[String] = [
	SLOT_WEAPON, SLOT_HELM, SLOT_BODY, SLOT_LEGS, SLOT_TOOL, SLOT_QUIVER, SLOT_CAPE,
]
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

## The set keys (#157). The magic line's Ruinwarden is `ruinwarden_mage`, so no item id collides.
const SET_HEARTHGUARD := "hearthguard"
const SET_WOLFMARK := "wolfmark"
const SET_RUINWARDEN := "ruinwarden"
## The melee top sets (#163).
const SET_EMBERHEART := "emberheart"
const SET_HOARFROST := "hoarfrost"
const SET_AURORAL := "auroral"
const SET_TROLLBONE := "trollbone"
## The ranged sets' keys (#164).
const SET_TRAPPER := "trapper"
const SET_WOLFSTALKER := "wolfstalker"
const SET_STEELPOINT := "steelpoint"
## The ranged top sets' keys (#165).
const SET_EMBER_HAWK := "ember_hawk"
const SET_AURORAL_WARDEN := "auroral_warden"
const SET_RUIN_STALKER := "ruin_stalker"
const SET_GLACIER_SOVEREIGN := "glacier_sovereign"
## The magic sets (#166).
const SET_SHARDWEAVER := "shardweaver"
const SET_RIMECALLER := "rimecaller"
const SET_GLACIER_WARDEN := "glacier_warden"
## Every set key, in the ladder's order.
const SETS: Array[String] = [
	SET_HEARTHGUARD, SET_WOLFMARK, SET_RUINWARDEN,
	SET_EMBERHEART, SET_HOARFROST, SET_AURORAL, SET_TROLLBONE,
	SET_TRAPPER, SET_WOLFSTALKER, SET_STEELPOINT,
	SET_EMBER_HAWK, SET_AURORAL_WARDEN, SET_RUIN_STALKER, SET_GLACIER_SOVEREIGN,
	SET_SHARDWEAVER, SET_RIMECALLER, SET_GLACIER_WARDEN,
]

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
	# Fur, from wolf pelts once the Armoury is built: armour slots, no tier and no defence.
	"fur_hood": {
		"label": "Fur hood", "stack": 1, "weight": 1, "value": 20, "slot": SLOT_HELM,
		"defence": 0, "warmth": 1,
	},
	"fur_coat": {
		"label": "Fur coat", "stack": 1, "weight": 2, "value": 30, "slot": SLOT_BODY,
		"defence": 0, "warmth": 1,
	},
	"fur_legs": {
		"label": "Fur leggings", "stack": 1, "weight": 1, "value": 20, "slot": SLOT_LEGS,
		"defence": 0, "warmth": 1,
	},
	# The melee sets (#162): Hearthguard (mid), Wolfmark (mid-high) and Ruinwarden (high), each
	# a helm, a body, legs and a weapon under the set-item rule above. The weapon's kind (a
	# broadsword, a bearded axe, a greatsword) is look only; its stats are the steel sword's.
	"hearthguard_helm": {
		"label": "Hearthguard helm", "stack": 1, "weight": 2, "value": 40, "slot": SLOT_HELM,
		"defence": 1, "set": SET_HEARTHGUARD,
	},
	"hearthguard_body": {
		"label": "Hearthguard body", "stack": 1, "weight": 3, "value": 80, "slot": SLOT_BODY,
		"defence": 2, "set": SET_HEARTHGUARD,
	},
	"hearthguard_legs": {
		"label": "Hearthguard legs", "stack": 1, "weight": 2, "value": 60, "slot": SLOT_LEGS,
		"defence": 1, "set": SET_HEARTHGUARD,
	},
	"hearthguard_broadsword": {
		"label": "Hearthguard broadsword", "stack": 1, "weight": 4, "value": 160, "slot": SLOT_WEAPON,
		"style": "melee", "power": 11, "speed": 2, "reach": 1.5, "set": SET_HEARTHGUARD,
	},
	"wolfmark_helm": {
		"label": "Wolfmark helm", "stack": 1, "weight": 2, "value": 40, "slot": SLOT_HELM,
		"defence": 1, "set": SET_WOLFMARK,
	},
	"wolfmark_body": {
		"label": "Wolfmark body", "stack": 1, "weight": 3, "value": 80, "slot": SLOT_BODY,
		"defence": 2, "set": SET_WOLFMARK,
	},
	"wolfmark_legs": {
		"label": "Wolfmark legs", "stack": 1, "weight": 2, "value": 60, "slot": SLOT_LEGS,
		"defence": 1, "set": SET_WOLFMARK,
	},
	"wolfmark_axe": {
		"label": "Wolfmark axe", "stack": 1, "weight": 4, "value": 160, "slot": SLOT_WEAPON,
		"style": "melee", "power": 11, "speed": 2, "reach": 1.5, "set": SET_WOLFMARK,
	},
	"ruinwarden_helm": {
		"label": "Ruinwarden helm", "stack": 1, "weight": 2, "value": 40, "slot": SLOT_HELM,
		"defence": 1, "set": SET_RUINWARDEN,
	},
	"ruinwarden_body": {
		"label": "Ruinwarden body", "stack": 1, "weight": 3, "value": 80, "slot": SLOT_BODY,
		"defence": 2, "set": SET_RUINWARDEN,
	},
	"ruinwarden_legs": {
		"label": "Ruinwarden legs", "stack": 1, "weight": 2, "value": 60, "slot": SLOT_LEGS,
		"defence": 1, "set": SET_RUINWARDEN,
	},
	"ruinwarden_greatsword": {
		"label": "Ruinwarden greatsword", "stack": 1, "weight": 4, "value": 160, "slot": SLOT_WEAPON,
		"style": "melee", "power": 11, "speed": 2, "reach": 1.5, "set": SET_RUINWARDEN,
	},
	# The melee top sets (#163): Emberheart, Hoarfrost, Auroral and Trollbone, each a helm, a
	# body, legs and a weapon under the same rule. The weapon's kind (a forge hammer, an icicle
	# greatsword, a glaive, a tusk cleaver) is look only; its stats are the steel sword's.
	"emberheart_helm": {
		"label": "Emberheart helm", "stack": 1, "weight": 2, "value": 40, "slot": SLOT_HELM,
		"defence": 1, "set": SET_EMBERHEART,
	},
	"emberheart_body": {
		"label": "Emberheart body", "stack": 1, "weight": 3, "value": 80, "slot": SLOT_BODY,
		"defence": 2, "set": SET_EMBERHEART,
	},
	"emberheart_legs": {
		"label": "Emberheart legs", "stack": 1, "weight": 2, "value": 60, "slot": SLOT_LEGS,
		"defence": 1, "set": SET_EMBERHEART,
	},
	"emberheart_hammer": {
		"label": "Emberheart hammer", "stack": 1, "weight": 4, "value": 160, "slot": SLOT_WEAPON,
		"style": "melee", "power": 11, "speed": 2, "reach": 1.5, "set": SET_EMBERHEART,
	},
	"hoarfrost_helm": {
		"label": "Hoarfrost helm", "stack": 1, "weight": 2, "value": 40, "slot": SLOT_HELM,
		"defence": 1, "set": SET_HOARFROST,
	},
	"hoarfrost_body": {
		"label": "Hoarfrost body", "stack": 1, "weight": 3, "value": 80, "slot": SLOT_BODY,
		"defence": 2, "set": SET_HOARFROST,
	},
	"hoarfrost_legs": {
		"label": "Hoarfrost legs", "stack": 1, "weight": 2, "value": 60, "slot": SLOT_LEGS,
		"defence": 1, "set": SET_HOARFROST,
	},
	"hoarfrost_greatsword": {
		"label": "Hoarfrost greatsword", "stack": 1, "weight": 4, "value": 160, "slot": SLOT_WEAPON,
		"style": "melee", "power": 11, "speed": 2, "reach": 1.5, "set": SET_HOARFROST,
	},
	"auroral_helm": {
		"label": "Auroral helm", "stack": 1, "weight": 2, "value": 40, "slot": SLOT_HELM,
		"defence": 1, "set": SET_AURORAL,
	},
	"auroral_body": {
		"label": "Auroral body", "stack": 1, "weight": 3, "value": 80, "slot": SLOT_BODY,
		"defence": 2, "set": SET_AURORAL,
	},
	"auroral_legs": {
		"label": "Auroral legs", "stack": 1, "weight": 2, "value": 60, "slot": SLOT_LEGS,
		"defence": 1, "set": SET_AURORAL,
	},
	"auroral_glaive": {
		"label": "Auroral glaive", "stack": 1, "weight": 4, "value": 160, "slot": SLOT_WEAPON,
		"style": "melee", "power": 11, "speed": 2, "reach": 1.5, "set": SET_AURORAL,
	},
	"trollbone_helm": {
		"label": "Trollbone helm", "stack": 1, "weight": 2, "value": 40, "slot": SLOT_HELM,
		"defence": 1, "set": SET_TROLLBONE,
	},
	"trollbone_body": {
		"label": "Trollbone body", "stack": 1, "weight": 3, "value": 80, "slot": SLOT_BODY,
		"defence": 2, "set": SET_TROLLBONE,
	},
	"trollbone_legs": {
		"label": "Trollbone legs", "stack": 1, "weight": 2, "value": 60, "slot": SLOT_LEGS,
		"defence": 1, "set": SET_TROLLBONE,
	},
	"trollbone_cleaver": {
		"label": "Trollbone cleaver", "stack": 1, "weight": 4, "value": 160, "slot": SLOT_WEAPON,
		"style": "melee", "power": 11, "speed": 2, "reach": 1.5, "set": SET_TROLLBONE,
	},
	# The ranged sets (#164): Trapper's Leathers (mid), Wolfstalker (mid-high) and Steelpoint
	# Ranger (high), each a helm, a body, legs and a bow under the set-item rule above (the
	# bow's stats are the steel bow's), and a quiver for the two upper sets under the quiver
	# rule (weight 1, value 40, no defence, no warmth). The first items in the quiver slot.
	"trapper_helm": {
		"label": "Trapper hood", "stack": 1, "weight": 2, "value": 40, "slot": SLOT_HELM,
		"defence": 1, "set": SET_TRAPPER,
	},
	"trapper_body": {
		"label": "Trapper jerkin", "stack": 1, "weight": 3, "value": 80, "slot": SLOT_BODY,
		"defence": 2, "set": SET_TRAPPER,
	},
	"trapper_legs": {
		"label": "Trapper wraps", "stack": 1, "weight": 2, "value": 60, "slot": SLOT_LEGS,
		"defence": 1, "set": SET_TRAPPER,
	},
	"trapper_bow": {
		"label": "Trapper bow", "stack": 1, "weight": 2, "value": 168, "slot": SLOT_WEAPON,
		"style": "ranged", "power": 10, "speed": 2, "reach": 8.0, "ammo": "arrows", "set": SET_TRAPPER,
	},
	"wolfstalker_helm": {
		"label": "Wolfstalker hood", "stack": 1, "weight": 2, "value": 40, "slot": SLOT_HELM,
		"defence": 1, "set": SET_WOLFSTALKER,
	},
	"wolfstalker_body": {
		"label": "Wolfstalker mantle", "stack": 1, "weight": 3, "value": 80, "slot": SLOT_BODY,
		"defence": 2, "set": SET_WOLFSTALKER,
	},
	"wolfstalker_legs": {
		"label": "Wolfstalker leggings", "stack": 1, "weight": 2, "value": 60, "slot": SLOT_LEGS,
		"defence": 1, "set": SET_WOLFSTALKER,
	},
	"wolfstalker_bow": {
		"label": "Wolfstalker longbow", "stack": 1, "weight": 2, "value": 168, "slot": SLOT_WEAPON,
		"style": "ranged", "power": 10, "speed": 2, "reach": 8.0, "ammo": "arrows", "set": SET_WOLFSTALKER,
	},
	"wolfstalker_quiver": {
		"label": "Wolfstalker quiver", "stack": 1, "weight": 1, "value": 40, "slot": SLOT_QUIVER,
		"set": SET_WOLFSTALKER,
	},
	"steelpoint_helm": {
		"label": "Steelpoint cap", "stack": 1, "weight": 2, "value": 40, "slot": SLOT_HELM,
		"defence": 1, "set": SET_STEELPOINT,
	},
	"steelpoint_body": {
		"label": "Steelpoint jerkin", "stack": 1, "weight": 3, "value": 80, "slot": SLOT_BODY,
		"defence": 2, "set": SET_STEELPOINT,
	},
	"steelpoint_legs": {
		"label": "Steelpoint chaps", "stack": 1, "weight": 2, "value": 60, "slot": SLOT_LEGS,
		"defence": 1, "set": SET_STEELPOINT,
	},
	"steelpoint_bow": {
		"label": "Steelpoint bow", "stack": 1, "weight": 2, "value": 168, "slot": SLOT_WEAPON,
		"style": "ranged", "power": 10, "speed": 2, "reach": 8.0, "ammo": "arrows", "set": SET_STEELPOINT,
	},
	"steelpoint_quiver": {
		"label": "Steelpoint quiver", "stack": 1, "weight": 1, "value": 40, "slot": SLOT_QUIVER,
		"set": SET_STEELPOINT,
	},
	# The magic sets (#166): Shardweaver (mid), Rimecaller (mid-high) and Glacier Warden
	# (high), each a helm, a body, legs and a staff under the set-item rule above (the staff's
	# head is look only; its stats are the steel staff's), and a cloak for the two upper sets
	# under the cape rule (weight 1, value 40, no defence, no warmth): the first cape items.
	"shardweaver_helm": {
		"label": "Shardweaver cowl", "stack": 1, "weight": 2, "value": 40, "slot": SLOT_HELM,
		"defence": 1, "set": SET_SHARDWEAVER,
	},
	"shardweaver_body": {
		"label": "Shardweaver coat", "stack": 1, "weight": 3, "value": 80, "slot": SLOT_BODY,
		"defence": 2, "set": SET_SHARDWEAVER,
	},
	"shardweaver_legs": {
		"label": "Shardweaver leggings", "stack": 1, "weight": 2, "value": 60, "slot": SLOT_LEGS,
		"defence": 1, "set": SET_SHARDWEAVER,
	},
	"shardweaver_staff": {
		"label": "Shardweaver staff", "stack": 1, "weight": 2, "value": 172, "slot": SLOT_WEAPON,
		"style": "magic", "power": 10, "speed": 2, "reach": 6.0, "ammo": "frost_shards", "set": SET_SHARDWEAVER,
	},
	"rimecaller_helm": {
		"label": "Rimecaller hood", "stack": 1, "weight": 2, "value": 40, "slot": SLOT_HELM,
		"defence": 1, "set": SET_RIMECALLER,
	},
	"rimecaller_body": {
		"label": "Rimecaller robe", "stack": 1, "weight": 3, "value": 80, "slot": SLOT_BODY,
		"defence": 2, "set": SET_RIMECALLER,
	},
	"rimecaller_legs": {
		"label": "Rimecaller leggings", "stack": 1, "weight": 2, "value": 60, "slot": SLOT_LEGS,
		"defence": 1, "set": SET_RIMECALLER,
	},
	"rimecaller_staff": {
		"label": "Rimecaller staff", "stack": 1, "weight": 2, "value": 172, "slot": SLOT_WEAPON,
		"style": "magic", "power": 10, "speed": 2, "reach": 6.0, "ammo": "frost_shards", "set": SET_RIMECALLER,
	},
	"rimecaller_cape": {
		"label": "Rimecaller cloak", "stack": 1, "weight": 1, "value": 40, "slot": SLOT_CAPE,
		"set": SET_RIMECALLER,
	},
	"glacier_warden_helm": {
		"label": "Glacier Warden hood", "stack": 1, "weight": 2, "value": 40, "slot": SLOT_HELM,
		"defence": 1, "set": SET_GLACIER_WARDEN,
	},
	"glacier_warden_body": {
		"label": "Glacier Warden robe", "stack": 1, "weight": 3, "value": 80, "slot": SLOT_BODY,
		"defence": 2, "set": SET_GLACIER_WARDEN,
	},
	"glacier_warden_legs": {
		"label": "Glacier Warden greaves", "stack": 1, "weight": 2, "value": 60, "slot": SLOT_LEGS,
		"defence": 1, "set": SET_GLACIER_WARDEN,
	},
	"glacier_warden_staff": {
		"label": "Glacier Warden staff", "stack": 1, "weight": 2, "value": 172, "slot": SLOT_WEAPON,
		"style": "magic", "power": 10, "speed": 2, "reach": 6.0, "ammo": "frost_shards", "set": SET_GLACIER_WARDEN,
	},
	"glacier_warden_cape": {
		"label": "Glacier Warden cloak", "stack": 1, "weight": 1, "value": 40, "slot": SLOT_CAPE,
		"set": SET_GLACIER_WARDEN,
	},
	# The ranged top sets (#165): Ember Hawk, Auroral Warden, Ruin Stalker's Shroud and Glacier
	# Sovereign, each a helm, a body, legs and a bow under the set-item rule above (the bow's
	# stats are the steel bow's) and a quiver under the quiver rule, and Auroral Warden and
	# Ruin Stalker a cape under the same provisional rule (weight 1, value 40, no defence, no
	# warmth): the first items in the cape slot.
	"ember_hawk_helm": {
		"label": "Ember Hawk hood", "stack": 1, "weight": 2, "value": 40, "slot": SLOT_HELM,
		"defence": 1, "set": SET_EMBER_HAWK,
	},
	"ember_hawk_body": {
		"label": "Ember Hawk jerkin", "stack": 1, "weight": 3, "value": 80, "slot": SLOT_BODY,
		"defence": 2, "set": SET_EMBER_HAWK,
	},
	"ember_hawk_legs": {
		"label": "Ember Hawk kilt", "stack": 1, "weight": 2, "value": 60, "slot": SLOT_LEGS,
		"defence": 1, "set": SET_EMBER_HAWK,
	},
	"ember_hawk_bow": {
		"label": "Ember Hawk bow", "stack": 1, "weight": 2, "value": 168, "slot": SLOT_WEAPON,
		"style": "ranged", "power": 10, "speed": 2, "reach": 8.0, "ammo": "arrows", "set": SET_EMBER_HAWK,
	},
	"ember_hawk_quiver": {
		"label": "Ember Hawk quiver", "stack": 1, "weight": 1, "value": 40, "slot": SLOT_QUIVER,
		"set": SET_EMBER_HAWK,
	},
	"auroral_warden_helm": {
		"label": "Auroral Warden hood", "stack": 1, "weight": 2, "value": 40, "slot": SLOT_HELM,
		"defence": 1, "set": SET_AURORAL_WARDEN,
	},
	"auroral_warden_body": {
		"label": "Auroral Warden jerkin", "stack": 1, "weight": 3, "value": 80, "slot": SLOT_BODY,
		"defence": 2, "set": SET_AURORAL_WARDEN,
	},
	"auroral_warden_legs": {
		"label": "Auroral Warden kilt", "stack": 1, "weight": 2, "value": 60, "slot": SLOT_LEGS,
		"defence": 1, "set": SET_AURORAL_WARDEN,
	},
	"auroral_warden_bow": {
		"label": "Auroral Warden bow", "stack": 1, "weight": 2, "value": 168, "slot": SLOT_WEAPON,
		"style": "ranged", "power": 10, "speed": 2, "reach": 8.0, "ammo": "arrows", "set": SET_AURORAL_WARDEN,
	},
	"auroral_warden_quiver": {
		"label": "Auroral Warden quiver", "stack": 1, "weight": 1, "value": 40, "slot": SLOT_QUIVER,
		"set": SET_AURORAL_WARDEN,
	},
	"auroral_warden_cape": {
		"label": "Auroral Warden mantle", "stack": 1, "weight": 1, "value": 40, "slot": SLOT_CAPE,
		"set": SET_AURORAL_WARDEN,
	},
	"ruin_stalker_helm": {
		"label": "Ruin Stalker mask", "stack": 1, "weight": 2, "value": 40, "slot": SLOT_HELM,
		"defence": 1, "set": SET_RUIN_STALKER,
	},
	"ruin_stalker_body": {
		"label": "Ruin Stalker jerkin", "stack": 1, "weight": 3, "value": 80, "slot": SLOT_BODY,
		"defence": 2, "set": SET_RUIN_STALKER,
	},
	"ruin_stalker_legs": {
		"label": "Ruin Stalker kilt", "stack": 1, "weight": 2, "value": 60, "slot": SLOT_LEGS,
		"defence": 1, "set": SET_RUIN_STALKER,
	},
	"ruin_stalker_bow": {
		"label": "Ruin Stalker bow", "stack": 1, "weight": 2, "value": 168, "slot": SLOT_WEAPON,
		"style": "ranged", "power": 10, "speed": 2, "reach": 8.0, "ammo": "arrows", "set": SET_RUIN_STALKER,
	},
	"ruin_stalker_quiver": {
		"label": "Ruin Stalker quiver", "stack": 1, "weight": 1, "value": 40, "slot": SLOT_QUIVER,
		"set": SET_RUIN_STALKER,
	},
	"ruin_stalker_cape": {
		"label": "Ruin Stalker shroud", "stack": 1, "weight": 1, "value": 40, "slot": SLOT_CAPE,
		"set": SET_RUIN_STALKER,
	},
	"glacier_sovereign_helm": {
		"label": "Glacier Sovereign crown", "stack": 1, "weight": 2, "value": 40, "slot": SLOT_HELM,
		"defence": 1, "set": SET_GLACIER_SOVEREIGN,
	},
	"glacier_sovereign_body": {
		"label": "Glacier Sovereign jerkin", "stack": 1, "weight": 3, "value": 80, "slot": SLOT_BODY,
		"defence": 2, "set": SET_GLACIER_SOVEREIGN,
	},
	"glacier_sovereign_legs": {
		"label": "Glacier Sovereign kilt", "stack": 1, "weight": 2, "value": 60, "slot": SLOT_LEGS,
		"defence": 1, "set": SET_GLACIER_SOVEREIGN,
	},
	"glacier_sovereign_bow": {
		"label": "Glacier Sovereign bow", "stack": 1, "weight": 2, "value": 168, "slot": SLOT_WEAPON,
		"style": "ranged", "power": 10, "speed": 2, "reach": 8.0, "ammo": "arrows", "set": SET_GLACIER_SOVEREIGN,
	},
	"glacier_sovereign_quiver": {
		"label": "Glacier Sovereign quiver", "stack": 1, "weight": 1, "value": 40, "slot": SLOT_QUIVER,
		"set": SET_GLACIER_SOVEREIGN,
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


## The item's gear tier ("wooden", "bronze", "iron", "steel"), or "" for materials, food, fur
## and set items.
static func tier(kind: String) -> String:
	return ITEMS[kind].get("tier", "") if ITEMS.has(kind) else ""


## The key of the set the item belongs to, or "" for an item in no set.
static func set_of(kind: String) -> String:
	return ITEMS[kind].get("set", "") if ITEMS.has(kind) else ""


## A tier's rank: wooden 0, bronze 1, iron 2, steel 3, and -1 for "" or anything unknown.
static func tier_rank(tier_name: String) -> int:
	return TIERS.find(tier_name)


## How much health the item restores when eaten, or 0 when it is not food.
static func heal(kind: String) -> int:
	return int(ITEMS[kind].get("heal", 0))


## Whether the item is kit, carried to use rather than to put away: gear (anything with an
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


## Points of cold the item keeps out while worn, or 0.
static func warmth(kind: String) -> int:
	return int(ITEMS[kind].get("warmth", 0)) if ITEMS.has(kind) else 0


## Health taken off every hit by everything worn: the armour pieces' defence added up.
static func worn_defence(equipment: Dictionary) -> int:
	var total := 0
	for slot in ARMOUR_SLOTS:
		total += defence(str(equipment.get(slot, "")))
	return total
