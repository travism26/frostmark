## Combat as data: the style edge table, the natural weapons that are not items, the enemy
## kinds and their action lists, noise, and the damage arithmetic.
##
## A combatant's style comes from its weapon: an item from ItemTable (the club, the bow) or
## a natural weapon listed here (fists for an unarmed player, a wolf's fangs). Damage is
## whole numbers and deterministic, so the same fight always plays out the same way.
## Engine-free like the rest of sim/.
class_name CombatTable
extends RefCounted

const STYLE_MELEE := "melee"
const STYLE_RANGED := "ranged"
## Reserved: magic arrives with ring two and widens the edge table into the full triangle.
const STYLE_MAGIC := "magic"

## The combat skill each style trains.
const STYLE_SKILLS := {STYLE_MELEE: SkillTable.MELEE, STYLE_RANGED: SkillTable.RANGED}

## Two combatants stand close when they are at most this far apart, centre to centre. A melee
## weapon reaches exactly this far; anything farther is distance.
const CLOSE_RANGE := 1.5

const RANGE_CLOSE := "close"
const RANGE_FAR := "far"
const RANGE_ANY := "any"

## The style edge, keyed by (attacker style, defender style). An attacker with the edge deals
## `dealt` times its damage to that defender and takes `taken` times the damage that defender
## deals back, while the two stand at `range` ("close", "far" or "any"). Pairs not listed, and
## listed pairs at the wrong range, are neutral both ways.
##
## At launch the rule is two-way: melee up close has the edge on a ranged defender, ranged at
## distance has the edge on a melee defender, the same style is neutral. Magic turns this into
## the full triangle (melee beats ranged, ranged beats magic, magic beats melee) by adding
## rows, not by changing the arithmetic.
const EDGES := {
	STYLE_MELEE: {STYLE_RANGED: {"dealt": 1.5, "taken": 0.5, "range": RANGE_CLOSE}},
	STYLE_RANGED: {STYLE_MELEE: {"dealt": 1.5, "taken": 0.5, "range": RANGE_FAR}},
}

## Weapons that are not items: a player with nothing in the weapon slot fights with fists,
## and a wolf with its fangs. Same fields as a weapon item.
const NATURAL_WEAPONS := {
	"fists": {"label": "Fists", "style": STYLE_MELEE, "power": 2, "speed": 2, "reach": CLOSE_RANGE},
	"fangs": {"label": "Fangs", "style": STYLE_MELEE, "power": 0, "speed": 1, "reach": CLOSE_RANGE},
	"captain_sabre": {"label": "Sabre", "style": STYLE_MELEE, "power": 0, "speed": 1, "reach": CLOSE_RANGE},
	"captain_bow": {"label": "War bow", "style": STYLE_RANGED, "power": 0, "speed": 1, "reach": 8.0},
}
const UNARMED := "fists"

## A player hit adds one point of damage for every this many levels of the style's skill
## above 1, and grants XP_PER_DAMAGE experience per point dealt.
const LEVELS_PER_POWER := 3
const XP_PER_DAMAGE := 4

## Combatants close to this fraction of their weapon's reach, so a single step by the other
## side does not break contact.
const APPROACH_FRACTION := 0.8

## Noise the player makes, as a radius in metres: every idle enemy inside it notices. A
## gathering attempt is quieter than a blow struck or taken.
const NOISE_GATHER := 9.0
const NOISE_FIGHT := 12.0

## Why an enemy joined the fight (the `cause` of `enemy_noticed`): it saw the player, heard
## them, its pack went, or the player struck it first.
const NOTICE_SIGHT := "sight"
const NOTICE_NOISE := "noise"
const NOTICE_PACK := "pack"
const NOTICE_HIT := "hit"

## What an enemy can do on a tick. `move` (close in) and `rest` are not attacks and are not
## telegraphed; every other action with a `damage` is an attack with that base damage before
## the style edge. `heavy` marks the hits worth countering. A `stance` action is a rest in
## which the enemy changes weapon (the captain drawing his bow); it is announced a tick ahead
## like an attack, so the change of style can be read and countered.
const ACTION_MOVE := "move"
const ACTION_REST := "rest"
const ACTIONS := {
	ACTION_MOVE: {"label": "Move", "damage": 0},
	ACTION_REST: {"label": "Rest", "damage": 0},
	"bite": {"label": "Bite", "damage": 3},
	"lunge": {"label": "Lunge", "damage": 7, "heavy": true},
	"shot": {"label": "Shot", "damage": 4},
	"aimed_shot": {"label": "Aimed shot", "damage": 9, "heavy": true},
	"slash": {"label": "Slash", "damage": 7},
	"cleave": {"label": "Cleave", "damage": 15, "heavy": true},
	"draw_bow": {"label": "Draws his bow", "damage": 0, "stance": true},
	"loose": {"label": "Loose", "damage": 6},
	"volley": {"label": "Volley", "damage": 14, "heavy": true},
	"draw_sabre": {"label": "Draws his sabre", "damage": 0, "stance": true},
}

## Enemy kinds. `weapon` sets the style and reach. `speed` is metres per tick (the player walks
## 2). `sight` is the radius at which an idle enemy notices the player. `actions` is the cycle
## an enemy works through while the player is in its reach, one per tick. `loot` always drops;
## `rare_percent` is the chance of one piece of RARE_LOOT on top. A dead enemy comes back at
## home `respawn_ticks` later.
##
## A kind with `stances` fights with more than one weapon: `stances[i]` is the weapon it holds
## for `actions[i]`, so its style and reach follow its place in the cycle. `boss_loot` is a
## list of which exactly one always drops. A `boss` is a ring's guardian: its first death is
## recorded for good (it opens that ring's gate with the matching upgrade).
const ENEMIES := {
	"wolf": {
		"label": "Wolf", "health": 15, "weapon": "fangs", "speed": 2.5, "sight": 6.0,
		"actions": ["bite", ACTION_REST, "lunge", ACTION_REST],
		"loot": [{"item": "wolf_pelt", "count": 1}], "rare_percent": 5, "respawn_ticks": 100,
	},
	"bandit_archer": {
		"label": "Bandit archer", "health": 20, "weapon": "wooden_bow", "speed": 1.5, "sight": 9.0,
		"actions": ["shot", ACTION_REST, ACTION_REST, "aimed_shot", ACTION_REST],
		"loot": [{"item": "arrows", "count": 8}], "rare_percent": 10, "respawn_ticks": 100,
	},
	# Sabre for two blows, then he draws his bow for two shots, then back: the second blow of
	# each stance is the heavy one, and each change of stance is announced a tick ahead.
	"bandit_captain": {
		"label": "Bandit captain", "health": 150, "weapon": "captain_sabre", "speed": 2.0, "sight": 7.0,
		"actions": [
			"slash", ACTION_REST, "cleave", ACTION_REST, "draw_bow",
			"loose", ACTION_REST, "volley", ACTION_REST, "draw_sabre",
		],
		"stances": [
			"captain_sabre", "captain_sabre", "captain_sabre", "captain_sabre", "captain_bow",
			"captain_bow", "captain_bow", "captain_bow", "captain_bow", "captain_sabre",
		],
		"loot": [{"item": "arrows", "count": 20}], "boss_loot": ["iron_sword", "iron_bow", "iron_armour"],
		"rare_percent": 25, "respawn_ticks": 600, "boss": true,
	},
}
## Ring one's rare drop: one piece of iron gear. Iron is found, never smithed.
const RARE_LOOT: Array[String] = ["iron_sword", "iron_armour", "iron_bow", "iron_axe", "iron_pickaxe"]


static func is_enemy_kind(kind: String) -> bool:
	return ENEMIES.has(kind)


static func enemy(kind: String) -> Dictionary:
	return ENEMIES[kind]


static func is_attack(action: String) -> bool:
	return ACTIONS.has(action) and int(ACTIONS[action]["damage"]) > 0


static func is_heavy(action: String) -> bool:
	return ACTIONS.has(action) and bool(ACTIONS[action].get("heavy", false))


static func action_damage(action: String) -> int:
	return int(ACTIONS[action]["damage"]) if ACTIONS.has(action) else 0


static func is_stance(action: String) -> bool:
	return ACTIONS.has(action) and bool(ACTIONS[action].get("stance", false))


## The weapon an enemy of `kind` holds for the action at `index` of its cycle.
static func stance_weapon(kind: String, index: int) -> String:
	var def: Dictionary = ENEMIES[kind]
	var stances: Array = def.get("stances", [])
	if stances.is_empty():
		return def["weapon"]
	return stances[posmod(index, stances.size())]


static func action_label(action: String) -> String:
	return ACTIONS[action]["label"] if ACTIONS.has(action) else action


## A weapon's stats: {label, style, power, speed, reach, ammo}. Unknown or empty ids are fists.
static func weapon(id: String) -> Dictionary:
	var src: Dictionary = NATURAL_WEAPONS.get(id, {})
	if src.is_empty() and ItemTable.has(id) and ItemTable.ITEMS[id].has("style"):
		src = ItemTable.ITEMS[id]
	if src.is_empty():
		src = NATURAL_WEAPONS[UNARMED]
	return {
		"label": src["label"], "style": src["style"], "power": int(src["power"]),
		"speed": int(src["speed"]), "reach": float(src["reach"]), "ammo": src.get("ammo", ""),
	}


## The attacker's edge on the defender at `distance`: {dealt, taken}, both 1.0 when neutral.
static func edge(attacker: String, defender: String, distance: float) -> Dictionary:
	var row: Dictionary = EDGES.get(attacker, {})
	var e: Variant = row.get(defender)
	if e == null or not _in_range(str(e["range"]), distance):
		return {"dealt": 1.0, "taken": 1.0}
	return {"dealt": float(e["dealt"]), "taken": float(e["taken"])}


## What a blow from `attacker` style on `defender` style at `distance` is multiplied by: the
## attacker's `dealt` against the defender times the defender's own `taken` against the
## attacker. 1.5 is a blow with the edge, 0.5 one into it, 1.0 neutral.
static func multiplier(attacker: String, defender: String, distance: float) -> float:
	return edge(attacker, defender, distance)["dealt"] * edge(defender, attacker, distance)["taken"]


## Damage of one blow: `base` times the style multiplier, rounded, less the defender's armour
## `defence`, and never below 1 for a real attack.
static func damage(base: int, attacker: String, defender: String, distance: float, defence := 0) -> int:
	if base <= 0:
		return 0
	return maxi(1, roundi(base * multiplier(attacker, defender, distance)) - defence)


static func _in_range(band: String, distance: float) -> bool:
	match band:
		RANGE_CLOSE:
			return distance <= CLOSE_RANGE
		RANGE_FAR:
			return distance > CLOSE_RANGE
	return true
