## Which glyph and badge colour stand for which skill, item kind, panel tab, combat style and
## interface action, as data. Every key names one white SVG glyph under assets/ui/game_icons/
## (game-icons.net, CC BY 3.0, one folder per author) and the tint of the round badge it sits
## on, so the whole set reads as one family and the HUD never hard-codes a path.
##
## Presentation-side on purpose: no rule lives here. Every author in use is credited in
## docs/assets/CREDITS.md and in `credits()`, which the Settings tab shows in the game.
class_name IconTable
extends RefCounted

const DIR := "res://assets/ui/game_icons/"
const SITE := "https://game-icons.net"

# --- Keys that are not skills or items ------------------------------------------------

const TAB_PACK := "tab_pack"
const TAB_EQUIPMENT := "tab_equipment"
const TAB_SKILLS := "tab_skills"
const TAB_UPGRADES := "tab_upgrades"
const TAB_SETTINGS := "tab_settings"
const TABS: Array[String] = [TAB_PACK, TAB_EQUIPMENT, TAB_SKILLS, TAB_UPGRADES, TAB_SETTINGS]

const STYLE_MELEE := "style_melee"
const STYLE_RANGED := "style_ranged"
const STYLE_MAGIC := "style_magic"
## Combat style (CombatTable) -> its icon key.
const STYLE_KEYS := {
	CombatTable.STYLE_MELEE: STYLE_MELEE,
	CombatTable.STYLE_RANGED: STYLE_RANGED,
	CombatTable.STYLE_MAGIC: STYLE_MAGIC,
}

const UI_FIRE := "ui_fire"
const UI_HELP := "ui_help"
const UI_SAVE := "ui_save"
const UI_SOUND := "ui_sound"
const UI_ACTIONS: Array[String] = [UI_FIRE, UI_HELP, UI_SAVE, UI_SOUND]

## The empty quiver and cape slots' glyphs: the quiver's is the one the ranged quivers wear
## (#164) and the cape's the one the ranged top set capes wear (#165).
const SLOT_QUIVER := "slot_quiver"
const SLOT_CAPE := "slot_cape"

## Equipment slot (ItemTable) -> the icon key an empty slot shows.
const SLOT_KEYS := {
	ItemTable.SLOT_WEAPON: STYLE_MELEE,
	ItemTable.SLOT_HELM: "steel_helm",
	ItemTable.SLOT_BODY: "steel_body",
	ItemTable.SLOT_LEGS: "steel_legs",
	ItemTable.SLOT_TOOL: "wooden_pickaxe",
	ItemTable.SLOT_QUIVER: SLOT_QUIVER,
	ItemTable.SLOT_CAPE: SLOT_CAPE,
}

# --- Tints --------------------------------------------------------------------------------

## The colour a telegraph ring, a style badge and a style label share, so the counter reads
## the same everywhere: orange-red melee, blue ranged, violet magic.
const STYLE_COLOURS := {
	CombatTable.STYLE_MELEE: Color(0.95, 0.35, 0.20),
	CombatTable.STYLE_RANGED: Color(0.20, 0.55, 1.00),
	CombatTable.STYLE_MAGIC: Color(0.75, 0.40, 1.00),
}
## Gear badges take their tier's colour, so a steel axe and a steel sword match.
const TIER_TINTS := {
	ItemTable.TIER_WOODEN: Color(0.55, 0.38, 0.22),
	ItemTable.TIER_BRONZE: Color(0.74, 0.47, 0.20),
	ItemTable.TIER_IRON: Color(0.50, 0.54, 0.60),
	ItemTable.TIER_STEEL: Color(0.66, 0.74, 0.84),
}
## Fur has no tier, so its badges take a pelt brown of their own.
const TINT_FUR := Color(0.60, 0.52, 0.44)
const TINT_TAB := Color(0.30, 0.36, 0.46)
const TINT_RAW := Color(0.34, 0.54, 0.70)
const TINT_COOKED := Color(0.82, 0.50, 0.20)

# --- The table ----------------------------------------------------------------------------

## Key -> {icon: "author/name", tint: Color}. Items without a tint take their tier's.
const ICONS := {
	# Skills, in the brief's order.
	SkillTable.WOODCUTTING: {"icon": "lorc/axe-in-stump", "tint": Color(0.38, 0.60, 0.34)},
	SkillTable.MINING: {"icon": "lorc/mining", "tint": Color(0.70, 0.50, 0.34)},
	SkillTable.FISHING: {"icon": "delapouite/fishing-pole", "tint": Color(0.34, 0.60, 0.86)},
	SkillTable.COOKING: {"icon": "lorc/campfire", "tint": Color(0.86, 0.46, 0.14)},
	SkillTable.SMITHING: {"icon": "lorc/anvil", "tint": Color(0.52, 0.56, 0.64)},
	SkillTable.MELEE: {"icon": "lorc/crossed-swords", "tint": Color(0.80, 0.30, 0.26)},
	SkillTable.RANGED: {"icon": "lorc/high-shot", "tint": Color(0.76, 0.62, 0.28)},
	SkillTable.MAGIC: {"icon": "lorc/ice-bolt", "tint": Color(0.56, 0.42, 0.86)},
	# Materials.
	"logs": {"icon": "delapouite/log", "tint": Color(0.55, 0.38, 0.22)},
	"copper_ore": {"icon": "faithtoken/ore", "tint": Color(0.74, 0.44, 0.26)},
	"tin_ore": {"icon": "faithtoken/ore", "tint": Color(0.60, 0.64, 0.68)},
	"iron_ore": {"icon": "faithtoken/ore", "tint": Color(0.46, 0.40, 0.42)},
	"coal": {"icon": "delapouite/coal-pile", "tint": Color(0.24, 0.26, 0.30)},
	"bronze_bar": {"icon": "lorc/metal-bar", "tint": Color(0.74, 0.47, 0.20)},
	"iron_bar": {"icon": "lorc/metal-bar", "tint": Color(0.50, 0.54, 0.60)},
	"steel_bar": {"icon": "lorc/metal-bar", "tint": Color(0.66, 0.74, 0.84)},
	"wolf_pelt": {"icon": "delapouite/animal-hide", "tint": Color(0.50, 0.44, 0.40)},
	"troll_hide": {"icon": "delapouite/animal-hide", "tint": Color(0.38, 0.52, 0.58)},
	"arrows": {"icon": "lorc/arrow-cluster", "tint": Color(0.60, 0.54, 0.36)},
	"ice_crystal": {"icon": "lorc/crystal-growth", "tint": Color(0.40, 0.68, 0.94)},
	"frost_shards": {"icon": "lorc/crystal-shine", "tint": Color(0.52, 0.78, 1.00)},
	# Food.
	"raw_fish": {"icon": "lorc/fish-corpse", "tint": TINT_RAW},
	"raw_trout": {"icon": "lorc/fish-corpse", "tint": TINT_RAW},
	"raw_char": {"icon": "lorc/fish-corpse", "tint": TINT_RAW},
	"cooked_fish": {"icon": "darkzaitzev/fish-cooked", "tint": TINT_COOKED},
	"cooked_trout": {"icon": "darkzaitzev/fish-cooked", "tint": TINT_COOKED},
	"cooked_char": {"icon": "darkzaitzev/fish-cooked", "tint": TINT_COOKED},
	# Tools, tinted by tier.
	"wooden_axe": {"icon": "delapouite/hatchet"},
	"bronze_axe": {"icon": "delapouite/hatchet"},
	"iron_axe": {"icon": "delapouite/hatchet"},
	"steel_axe": {"icon": "delapouite/hatchet"},
	"wooden_pickaxe": {"icon": "delapouite/war-pick"},
	"bronze_pickaxe": {"icon": "delapouite/war-pick"},
	"iron_pickaxe": {"icon": "delapouite/war-pick"},
	"steel_pickaxe": {"icon": "delapouite/war-pick"},
	"fishing_rod": {"icon": "delapouite/fishing-pole"},
	# Weapons, tinted by tier.
	"wooden_club": {"icon": "delapouite/wood-club"},
	"bronze_sword": {"icon": "lorc/broadsword"},
	"iron_sword": {"icon": "lorc/broadsword"},
	"steel_sword": {"icon": "lorc/broadsword"},
	"wooden_bow": {"icon": "lorc/pocket-bow"},
	"bronze_bow": {"icon": "lorc/pocket-bow"},
	"iron_bow": {"icon": "lorc/pocket-bow"},
	"steel_bow": {"icon": "lorc/pocket-bow"},
	"wooden_staff": {"icon": "lorc/wizard-staff"},
	"bronze_staff": {"icon": "lorc/wizard-staff"},
	"iron_staff": {"icon": "lorc/wizard-staff"},
	"steel_staff": {"icon": "lorc/wizard-staff"},
	# Armour, tinted by tier.
	"wooden_helm": {"icon": "lorc/visored-helm"},
	"bronze_helm": {"icon": "lorc/visored-helm"},
	"iron_helm": {"icon": "lorc/visored-helm"},
	"steel_helm": {"icon": "lorc/visored-helm"},
	"wooden_body": {"icon": "lorc/breastplate"},
	"bronze_body": {"icon": "lorc/breastplate"},
	"iron_body": {"icon": "lorc/breastplate"},
	"steel_body": {"icon": "lorc/breastplate"},
	"wooden_legs": {"icon": "delapouite/leg-armor"},
	"bronze_legs": {"icon": "delapouite/leg-armor"},
	"iron_legs": {"icon": "delapouite/leg-armor"},
	"steel_legs": {"icon": "delapouite/leg-armor"},
	# Fur pieces: the armour glyphs, in fur.
	"fur_hood": {"icon": "lorc/visored-helm", "tint": TINT_FUR},
	"fur_coat": {"icon": "lorc/breastplate", "tint": TINT_FUR},
	"fur_legs": {"icon": "delapouite/leg-armor", "tint": TINT_FUR},
	# Set pieces (#162): each slot's glyph, in the set's base colour from its gear look.
	"hearthguard_helm": {"icon": "lorc/visored-helm"},
	"hearthguard_body": {"icon": "lorc/breastplate"},
	"hearthguard_legs": {"icon": "delapouite/leg-armor"},
	"hearthguard_broadsword": {"icon": "lorc/broadsword"},
	"wolfmark_helm": {"icon": "lorc/visored-helm"},
	"wolfmark_body": {"icon": "lorc/breastplate"},
	"wolfmark_legs": {"icon": "delapouite/leg-armor"},
	"wolfmark_axe": {"icon": "lorc/broadsword"},
	"ruinwarden_helm": {"icon": "lorc/visored-helm"},
	"ruinwarden_body": {"icon": "lorc/breastplate"},
	"ruinwarden_legs": {"icon": "delapouite/leg-armor"},
	"ruinwarden_greatsword": {"icon": "lorc/broadsword"},
	# The melee top sets (#163), the same way.
	"emberheart_helm": {"icon": "lorc/visored-helm"},
	"emberheart_body": {"icon": "lorc/breastplate"},
	"emberheart_legs": {"icon": "delapouite/leg-armor"},
	"emberheart_hammer": {"icon": "lorc/broadsword"},
	"hoarfrost_helm": {"icon": "lorc/visored-helm"},
	"hoarfrost_body": {"icon": "lorc/breastplate"},
	"hoarfrost_legs": {"icon": "delapouite/leg-armor"},
	"hoarfrost_greatsword": {"icon": "lorc/broadsword"},
	"auroral_helm": {"icon": "lorc/visored-helm"},
	"auroral_body": {"icon": "lorc/breastplate"},
	"auroral_legs": {"icon": "delapouite/leg-armor"},
	"auroral_glaive": {"icon": "lorc/broadsword"},
	"trollbone_helm": {"icon": "lorc/visored-helm"},
	"trollbone_body": {"icon": "lorc/breastplate"},
	"trollbone_legs": {"icon": "delapouite/leg-armor"},
	"trollbone_cleaver": {"icon": "lorc/broadsword"},
	# The ranged set pieces (#164): each slot's glyph in the set's base colour; the quivers take
	# the quiver slot's own glyph.
	"trapper_helm": {"icon": "lorc/visored-helm"},
	"trapper_body": {"icon": "lorc/breastplate"},
	"trapper_legs": {"icon": "delapouite/leg-armor"},
	"trapper_bow": {"icon": "lorc/pocket-bow"},
	"wolfstalker_helm": {"icon": "lorc/visored-helm"},
	"wolfstalker_body": {"icon": "lorc/breastplate"},
	"wolfstalker_legs": {"icon": "delapouite/leg-armor"},
	"wolfstalker_bow": {"icon": "lorc/pocket-bow"},
	"wolfstalker_quiver": {"icon": "delapouite/quiver"},
	"steelpoint_helm": {"icon": "lorc/visored-helm"},
	"steelpoint_body": {"icon": "lorc/breastplate"},
	"steelpoint_legs": {"icon": "delapouite/leg-armor"},
	"steelpoint_bow": {"icon": "lorc/pocket-bow"},
	"steelpoint_quiver": {"icon": "delapouite/quiver"},
	# The ranged top set pieces (#165), the same way; the two capes take the cape slot's glyph.
	"ember_hawk_helm": {"icon": "lorc/visored-helm"},
	"ember_hawk_body": {"icon": "lorc/breastplate"},
	"ember_hawk_legs": {"icon": "delapouite/leg-armor"},
	"ember_hawk_bow": {"icon": "lorc/pocket-bow"},
	"ember_hawk_quiver": {"icon": "delapouite/quiver"},
	"auroral_warden_helm": {"icon": "lorc/visored-helm"},
	"auroral_warden_body": {"icon": "lorc/breastplate"},
	"auroral_warden_legs": {"icon": "delapouite/leg-armor"},
	"auroral_warden_bow": {"icon": "lorc/pocket-bow"},
	"auroral_warden_quiver": {"icon": "delapouite/quiver"},
	"auroral_warden_cape": {"icon": "delapouite/cape"},
	"ruin_stalker_helm": {"icon": "lorc/visored-helm"},
	"ruin_stalker_body": {"icon": "lorc/breastplate"},
	"ruin_stalker_legs": {"icon": "delapouite/leg-armor"},
	"ruin_stalker_bow": {"icon": "lorc/pocket-bow"},
	"ruin_stalker_quiver": {"icon": "delapouite/quiver"},
	"ruin_stalker_cape": {"icon": "delapouite/cape"},
	"glacier_sovereign_helm": {"icon": "lorc/visored-helm"},
	"glacier_sovereign_body": {"icon": "lorc/breastplate"},
	"glacier_sovereign_legs": {"icon": "delapouite/leg-armor"},
	"glacier_sovereign_bow": {"icon": "lorc/pocket-bow"},
	"glacier_sovereign_quiver": {"icon": "delapouite/quiver"},
	# The side panel's tabs.
	TAB_PACK: {"icon": "lorc/knapsack", "tint": TINT_TAB},
	TAB_EQUIPMENT: {"icon": "lorc/battle-gear", "tint": TINT_TAB},
	TAB_SKILLS: {"icon": "delapouite/skills", "tint": TINT_TAB},
	TAB_UPGRADES: {"icon": "lorc/hammer-nails", "tint": TINT_TAB},
	TAB_SETTINGS: {"icon": "lorc/cog", "tint": TINT_TAB},
	# Combat styles, in the telegraph colours.
	STYLE_MELEE: {"icon": "lorc/crossed-swords", "tint": STYLE_COLOURS[CombatTable.STYLE_MELEE]},
	STYLE_RANGED: {"icon": "lorc/high-shot", "tint": STYLE_COLOURS[CombatTable.STYLE_RANGED]},
	STYLE_MAGIC: {"icon": "lorc/ice-bolt", "tint": STYLE_COLOURS[CombatTable.STYLE_MAGIC]},
	# Interface actions.
	UI_FIRE: {"icon": "lorc/campfire", "tint": Color(0.86, 0.46, 0.14)},
	UI_HELP: {"icon": "sbed/help", "tint": TINT_TAB},
	UI_SAVE: {"icon": "delapouite/save", "tint": TINT_TAB},
	UI_SOUND: {"icon": "delapouite/sound-on", "tint": TINT_TAB},
	# Empty equipment slots with no item of their own.
	SLOT_QUIVER: {"icon": "delapouite/quiver", "tint": TINT_TAB},
	SLOT_CAPE: {"icon": "delapouite/cape", "tint": TINT_TAB},
}

## Author folder -> the name the credit line carries, as on game-icons.net/about.html.
const AUTHORS := {
	"lorc": "Lorc",
	"delapouite": "Delapouite",
	"faithtoken": "Faithtoken",
	"darkzaitzev": "DarkZaitzev",
	"sbed": "sbed",
}


static func has(key: String) -> bool:
	return ICONS.has(key)


## The SVG file a key's glyph lives in.
static func path(key: String) -> String:
	return DIR + str(ICONS[key]["icon"]) + ".svg"


## The white glyph, loaded from the import cache.
static func texture(key: String) -> Texture2D:
	return load(path(key))


## The badge colour behind a key's glyph: the table's own, a set piece's base colour from its
## gear look (so a set's colour is tuned in one place), or the item's tier colour.
static func tint(key: String) -> Color:
	var entry: Dictionary = ICONS[key]
	if entry.has("tint"):
		return entry["tint"]
	if ItemTable.set_of(key) != "":
		return GearLook.palette(key)["base"]
	return TIER_TINTS.get(ItemTable.tier(key), TINT_TAB)


## The author folder of a key's glyph ("lorc").
static func author(key: String) -> String:
	return str(ICONS[key]["icon"]).get_slice("/", 0)


## The icon key for a combat style, or "" for an unknown one.
static func style_key(style: String) -> String:
	return STYLE_KEYS.get(style, "")


## Every key in the table.
static func all_keys() -> Array[String]:
	var out: Array[String] = []
	for key in ICONS:
		out.append(key)
	return out


## Every author folder some key draws from, in a fixed order.
static func authors_in_use() -> Array[String]:
	var seen := {}
	for key in ICONS:
		seen[author(key)] = true
	var out: Array[String] = []
	for folder in AUTHORS:
		if seen.has(folder):
			out.append(folder)
	return out


## One credit line per author in use, in game-icons.net's own wording.
static func credits() -> Array[String]:
	var out: Array[String] = []
	for folder in authors_in_use():
		out.append("Icons made by %s. Available on %s" % [AUTHORS[folder], SITE])
	return out
