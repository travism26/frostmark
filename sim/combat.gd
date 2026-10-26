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
const STYLE_MAGIC := "magic"

## The combat skill each style trains.
const STYLE_SKILLS := {STYLE_MELEE: SkillTable.MELEE, STYLE_RANGED: SkillTable.RANGED, STYLE_MAGIC: SkillTable.MAGIC}

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
## The full triangle: melee beats ranged, ranged beats magic, magic beats melee, and the same
## style is neutral. Melee's edge on ranged holds up close, where a blade reaches; at distance
## the bow keeps its slice-4 edge on a melee defender. Magic's two edges hold at any range.
const EDGES := {
	STYLE_MELEE: {STYLE_RANGED: {"dealt": 1.5, "taken": 0.5, "range": RANGE_CLOSE}},
	STYLE_RANGED: {
		STYLE_MELEE: {"dealt": 1.5, "taken": 0.5, "range": RANGE_FAR},
		STYLE_MAGIC: {"dealt": 1.5, "taken": 0.5, "range": RANGE_ANY},
	},
	STYLE_MAGIC: {STYLE_MELEE: {"dealt": 1.5, "taken": 0.5, "range": RANGE_ANY}},
}

## Weapons that are not items: a player with nothing in the weapon slot fights with fists,
## and a wolf with its fangs. Same fields as a weapon item.
const NATURAL_WEAPONS := {
	"fists": {"label": "Fists", "style": STYLE_MELEE, "power": 2, "speed": 2, "reach": CLOSE_RANGE},
	"fangs": {"label": "Fangs", "style": STYLE_MELEE, "power": 0, "speed": 1, "reach": CLOSE_RANGE},
	"captain_sabre": {"label": "Sabre", "style": STYLE_MELEE, "power": 0, "speed": 1, "reach": CLOSE_RANGE},
	"captain_bow": {"label": "War bow", "style": STYLE_RANGED, "power": 0, "speed": 1, "reach": 8.0},
	"captain_staff": {"label": "Rime staff", "style": STYLE_MAGIC, "power": 0, "speed": 1, "reach": 6.0},
	"troll_club": {"label": "Ice club", "style": STYLE_MELEE, "power": 0, "speed": 1, "reach": CLOSE_RANGE},
	"stalker_bow": {"label": "Bone bow", "style": STYLE_RANGED, "power": 0, "speed": 1, "reach": 8.0},
	"veil_bow": {"label": "Veil bow", "style": STYLE_RANGED, "power": 0, "speed": 1, "reach": 8.0},
	"rime_blade": {"label": "Rime blade", "style": STYLE_MELEE, "power": 0, "speed": 1, "reach": CLOSE_RANGE},
	"aurora_staff": {"label": "Aurora staff", "style": STYLE_MAGIC, "power": 0, "speed": 1, "reach": 6.0},
	"seer_blade": {"label": "Seer's blade", "style": STYLE_MELEE, "power": 0, "speed": 1, "reach": CLOSE_RANGE},
	"tyrant_greatblade": {"label": "Greatblade", "style": STYLE_MELEE, "power": 0, "speed": 1, "reach": CLOSE_RANGE},
	"tyrant_bow": {"label": "Warbow", "style": STYLE_RANGED, "power": 0, "speed": 1, "reach": 8.0},
	"tyrant_staff": {"label": "Tyrant's staff", "style": STYLE_MAGIC, "power": 0, "speed": 1, "reach": 6.0},
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
## the style edge. `heavy` marks the hits worth countering. A `stance` action is a rest that
## is announced a tick ahead like an attack: the captain changing weapon, so the change of
## style can be read and countered, or a troll winding up, so its crush can be seen coming
## two ticks out. A `windup` commits the enemy: the next action of its cycle is declared even
## if the player has stepped out of reach, and a blow that finds nobody misses. A `feint` names
## the attack it pretends to be: it is declared and telegraphed exactly as that attack, then
## lands nothing (the Snowveil archer's piercing shot is the first; ring three's others will).
## An attack with a `shape` is an area blow (see MARK_SHAPES): it strikes a ground mark of
## that shape and `size` rather than the player.
const ACTION_MOVE := "move"
const ACTION_REST := "rest"
const ACTIONS := {
	ACTION_MOVE: {"label": "Move", "damage": 0},
	ACTION_REST: {"label": "Rest", "damage": 0},
	"bite": {"label": "Bite", "damage": 3},
	"lunge": {"label": "Lunge", "damage": 7, "heavy": true},
	"shot": {"label": "Shot", "damage": 4},
	"aimed_shot": {"label": "Aimed shot", "damage": 9, "heavy": true},
	"slash": {"label": "Slash", "damage": 8},
	"cleave": {"label": "Cleave", "damage": 17, "heavy": true},
	"draw_bow": {"label": "Draws his bow", "damage": 0, "stance": true},
	"loose": {"label": "Loose", "damage": 7},
	"volley": {"label": "Volley", "damage": 16, "heavy": true},
	"draw_staff": {"label": "Raises his staff", "damage": 0, "stance": true},
	"rime_bolt": {"label": "Rime bolt", "damage": 7},
	"blizzard": {"label": "Blizzard", "damage": 16, "heavy": true},
	"draw_sabre": {"label": "Draws his sabre", "damage": 0, "stance": true},
	"frost_bolt": {"label": "Frost bolt", "damage": 4},
	"ice_lance": {"label": "Ice lance", "damage": 9, "heavy": true},
	"smash": {"label": "Smash", "damage": 8},
	"wind_up": {"label": "Winds up", "damage": 0, "stance": true, "windup": true},
	"crush": {"label": "Crush", "damage": 26, "heavy": true},
	"dart": {"label": "Dart", "damage": 4},
	"barbed_volley": {"label": "Barbed volley", "damage": 10, "heavy": true},
	"quick_shot": {"label": "Quick shot", "damage": 7},
	"piercing_shot": {"label": "Piercing shot", "damage": 22, "heavy": true},
	"feint_pierce": {"label": "Piercing shot", "damage": 0, "feint": "piercing_shot"},
	"hack": {"label": "Hack", "damage": 12},
	"rime_cleave": {"label": "Rime cleave", "damage": 28, "heavy": true},
	"raise_blade": {"label": "Raises its blade", "damage": 0, "stance": true, "windup": true},
	"feint_cleave": {"label": "Rime cleave", "damage": 0, "feint": "rime_cleave"},
	"knight_quickens": {"label": "Its frost cracks", "damage": 0, "stance": true},
	"aurora_bolt": {"label": "Aurora bolt", "damage": 8},
	"aurora_lance": {"label": "Aurora lance", "damage": 22, "heavy": true},
	"conjure_blade": {"label": "Conjures a blade", "damage": 0, "stance": true},
	"ice_slash": {"label": "Ice slash", "damage": 10},
	"ice_rend": {"label": "Ice rend", "damage": 24, "heavy": true},
	"raise_aurora": {"label": "Raises its staff", "damage": 0, "stance": true},
	"tyrant_slash": {"label": "Greatblade slash", "damage": 12},
	"tyrant_cleave": {"label": "Glacier cleave", "damage": 32, "heavy": true},
	"raise_greatblade": {"label": "Raises its greatblade", "damage": 0, "stance": true, "windup": true},
	"feint_tyrant_cleave": {"label": "Glacier cleave", "damage": 0, "feint": "tyrant_cleave"},
	"draw_warbow": {"label": "Draws its warbow", "damage": 0, "stance": true},
	"tyrant_loose": {"label": "Loose", "damage": 10},
	"tyrant_volley": {"label": "Hail volley", "damage": 28, "heavy": true},
	"feint_volley": {"label": "Hail volley", "damage": 0, "feint": "tyrant_volley"},
	"raise_tyrant_staff": {"label": "Raises its staff", "damage": 0, "stance": true},
	"tyrant_bolt": {"label": "Rime bolt", "damage": 10},
	"tyrant_storm": {"label": "Whiteout", "damage": 28, "heavy": true},
	"feint_storm": {"label": "Whiteout", "damage": 0, "feint": "tyrant_storm"},
	"draw_greatblade": {"label": "Draws its greatblade", "damage": 0, "stance": true},
	"tyrant_roars": {"label": "Roars", "damage": 0, "stance": true},
}

## Enemy kinds. `weapon` sets the style and reach. `speed` is metres per tick (the player walks
## 2). `sight` is the radius at which an idle enemy notices the player. `actions` is the cycle
## an enemy works through while the player is in its reach, one per tick. `loot` always drops;
## `rare_percent` is the chance of one piece of RARE_LOOT on top. A dead enemy comes back at
## home `respawn_ticks` later.
##
## A kind with `kite` keeps its distance: after acting on a tick with the player closer than
## `kite` metres, it backs off a step, so it has to be cornered against a wall to be caught.
##
## A kind with `stances` fights with more than one weapon: `stances[i]` is the weapon it holds
## for `actions[i]`, so its style and reach follow its place in the cycle. `boss_loot` is a
## list of which exactly one always drops. A `boss` has its first death recorded for good. A
## boss that is a ring's guardian (the captain) opens that ring's gate with the matching upgrade,
## and once that gate stands open it no longer comes back; one that guards no gate (the Frost
## tyrant, a dungeon's boss) keeps coming back.
##
## A kind with `phases` fights differently near the end: each phase is {below, actions,
## stances?}, in order of falling `below`, a percentage of its health. Once a blow takes it
## below a phase's mark, its next declaration from the cycle starts that phase's `actions` from
## the first, which is always a stance so the change is announced, and the phase's `actions`
## and `stances` replace the kind's for the rest of that life (see `phase_problems`).
##
## A kind (or one of its phases) with `answers` answers a counter: {player style: cycle index},
## where the action at each index is a stance. When the player's style has the edge on the
## enemy's, it declares the stance answering that style instead of its next action, at most
## once every `answer_ticks` ticks and never straight after a wind-up (see `answer_problems`).
## The Aurora seer and the Frost tyrant answer (ring three, #182 and #183).
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
	# A hedge witch who throws the cold itself: magic at a staff's reach, so a bow beats her
	# and a blade walks into her edge.
	"frost_witch": {
		"label": "Frost witch", "health": 18, "weapon": "wooden_staff", "speed": 1.5, "sight": 8.0,
		"actions": ["frost_bolt", ACTION_REST, ACTION_REST, "ice_lance", ACTION_REST],
		"loot": [{"item": "frost_shards", "count": 10}], "rare_percent": 10, "respawn_ticks": 100,
	},
	# Sabre for two blows, then he draws his bow for two shots, then raises his staff for two
	# casts, then back: the second blow of each stance is the heavy one, each change of stance
	# is announced a tick ahead, and each stance has its own counter (magic or a bow at distance
	# for the sabre, a blade up close for the bow, a bow for the staff).
	"bandit_captain": {
		"label": "Bandit captain", "health": 240, "weapon": "captain_sabre", "speed": 2.0, "sight": 7.0,
		"actions": [
			"slash", ACTION_REST, "cleave", ACTION_REST, "draw_bow",
			"loose", ACTION_REST, "volley", ACTION_REST, "draw_staff",
			"rime_bolt", ACTION_REST, "blizzard", ACTION_REST, "draw_sabre",
		],
		"stances": [
			"captain_sabre", "captain_sabre", "captain_sabre", "captain_sabre", "captain_bow",
			"captain_bow", "captain_bow", "captain_bow", "captain_bow", "captain_staff",
			"captain_staff", "captain_staff", "captain_staff", "captain_staff", "captain_sabre",
		],
		"loot": [{"item": "arrows", "count": 20}],
		"boss_loot": ["iron_sword", "iron_bow", "iron_staff", "iron_helm", "iron_body", "iron_legs"],
		"rare_percent": 25, "respawn_ticks": 600, "boss": true,
	},
	# The ring-one dungeon's boss, a placeholder until its own fight is designed (#203): a wolf
	# grown past the captain, with his sabre's slash and cleave in its jaws and more health than
	# anything in ring one. It guards no gate, so it comes back, and the dungeon's way out is shut
	# while it stands.
	"great_wolf": {
		"label": "Great wolf", "health": 300, "weapon": "fangs", "speed": 2.0, "sight": 7.0,
		"actions": ["slash", ACTION_REST, ACTION_REST, "cleave", ACTION_REST, ACTION_REST],
		"loot": [{"item": "wolf_pelt", "count": 2}], "rare_percent": 10, "respawn_ticks": 600, "boss": true,
	},
	# Ring two. A troll smashes, rests, then winds up a tick before its crush: the longest
	# warning in the game, for the hardest blow. Slow, so it can be stepped away from.
	"ice_troll": {
		"label": "Ice troll", "health": 90, "weapon": "troll_club", "speed": 1.5, "sight": 6.0,
		"actions": ["smash", ACTION_REST, "wind_up", "crush", ACTION_REST, ACTION_REST],
		"loot": [{"item": "troll_hide", "count": 1}], "rare_percent": 15, "respawn_ticks": 400,
	},
	# Two darts, a breath, then a barbed volley; it backs away from anyone who closes in.
	"ruin_stalker": {
		"label": "Ruin stalker", "health": 35, "weapon": "stalker_bow", "speed": 1.5, "sight": 10.0,
		"kite": 4.0, "actions": ["dart", "dart", ACTION_REST, "barbed_volley", ACTION_REST, ACTION_REST],
		"loot": [{"item": "arrows", "count": 12}, {"item": "coal", "count": 1}], "rare_percent": 10,
		"respawn_ticks": 300,
	},
	# Ring three. A hunter in white who keeps its distance and bluffs its heaviest shot: the
	# first piercing shot is honest, the second is a feint and the real one comes straight
	# after. A blade has the edge up close, so it has to be cornered against a ridge or the
	# cliff; a bow trading shots at range is neutral, and a staff walks into its edge.
	"snowveil_archer": {
		"label": "Snowveil archer", "health": 70, "weapon": "veil_bow", "speed": 1.5, "sight": 10.0,
		"kite": 4.0, "actions": [
			"quick_shot", ACTION_REST, "piercing_shot", ACTION_REST, ACTION_REST,
			"quick_shot", "feint_pierce", "piercing_shot", ACTION_REST, ACTION_REST,
		],
		"loot": [{"item": "frost_sinew", "count": 1}], "rare_percent": 0, "respawn_ticks": 300,
	},
	# Ring three. A ruin warrior frozen into its armour, and the ring's first lesson: it winds up
	# like the troll, fakes its second cleave (the real one comes straight after), and below half
	# health drops its wind-ups, so each cleave is told one tick out where it was told two. A
	# staff has the edge on it at any range, and a bow at distance.
	"frostbound_knight": {
		"label": "Frostbound knight", "health": 120, "weapon": "rime_blade", "speed": 2.0, "sight": 7.0,
		"actions": [
			"hack", ACTION_REST, "raise_blade", "rime_cleave", ACTION_REST,
			"hack", ACTION_REST, "raise_blade", "feint_cleave", "rime_cleave", ACTION_REST,
		],
		"phases": [{
			"below": 50, "actions": ["knight_quickens", "hack", "rime_cleave", ACTION_REST, "feint_cleave", "rime_cleave", ACTION_REST],
		}],
		"loot": [{"item": "rime_steel", "count": 1}], "rare_percent": 0, "respawn_ticks": 400,
	},
	# Ring three. A caster who reads the player back: a bow turned on its staff is answered by
	# a conjured blade and it closes in, a staff turned on the blade by its staff raised again.
	# Left alone it works through both stances in turn.
	"aurora_seer": {
		"label": "Aurora seer", "health": 60, "weapon": "aurora_staff", "speed": 1.5, "sight": 8.0,
		"actions": [
			"aurora_bolt", ACTION_REST, "aurora_lance", ACTION_REST, ACTION_REST,
			"conjure_blade", "ice_slash", ACTION_REST, "ice_rend", ACTION_REST, "raise_aurora",
		],
		"stances": [
			"aurora_staff", "aurora_staff", "aurora_staff", "aurora_staff", "aurora_staff",
			"seer_blade", "seer_blade", "seer_blade", "seer_blade", "seer_blade", "aurora_staff",
		],
		"answers": {STYLE_RANGED: 5, STYLE_MAGIC: 10}, "answer_ticks": 8,
		"loot": [{"item": "aurora_glass", "count": 1}], "rare_percent": 0, "respawn_ticks": 300,
	},
	# Ring three's boss, and everything the ring has taught at once: the captain's three weapons,
	# a wound-up cleave, feinted heavies, answers to a counter-swap, and below half health a
	# quicker cycle with no wind-up, fewer rests and quicker answers. It guards no gate, so it
	# comes back.
	"frost_tyrant": {
		"label": "Frost tyrant", "health": 600, "weapon": "tyrant_greatblade", "speed": 2.0, "sight": 8.0,
		"actions": [
			"tyrant_slash", ACTION_REST, "raise_greatblade", "tyrant_cleave", ACTION_REST,
			"draw_warbow", "tyrant_loose", "feint_volley", "tyrant_volley", ACTION_REST,
			"raise_tyrant_staff", "tyrant_bolt", ACTION_REST, "tyrant_storm", ACTION_REST,
			"draw_greatblade",
		],
		"stances": [
			"tyrant_greatblade", "tyrant_greatblade", "tyrant_greatblade", "tyrant_greatblade", "tyrant_greatblade",
			"tyrant_bow", "tyrant_bow", "tyrant_bow", "tyrant_bow", "tyrant_bow",
			"tyrant_staff", "tyrant_staff", "tyrant_staff", "tyrant_staff", "tyrant_staff",
			"tyrant_greatblade",
		],
		"answers": {STYLE_MAGIC: 5, STYLE_RANGED: 15, STYLE_MELEE: 10}, "answer_ticks": 10,
		"phases": [{
			"below": 50,
			"actions": [
				"tyrant_roars", "tyrant_slash", "feint_tyrant_cleave", "tyrant_cleave", ACTION_REST,
				"draw_warbow", "tyrant_loose", "tyrant_volley", ACTION_REST,
				"raise_tyrant_staff", "tyrant_bolt", "feint_storm", "tyrant_storm", ACTION_REST,
				"draw_greatblade",
			],
			"stances": [
				"tyrant_greatblade", "tyrant_greatblade", "tyrant_greatblade", "tyrant_greatblade", "tyrant_greatblade",
				"tyrant_bow", "tyrant_bow", "tyrant_bow", "tyrant_bow",
				"tyrant_staff", "tyrant_staff", "tyrant_staff", "tyrant_staff", "tyrant_staff",
				"tyrant_greatblade",
			],
			"answers": {STYLE_MAGIC: 5, STYLE_RANGED: 14, STYLE_MELEE: 9}, "answer_ticks": 6,
		}],
		"loot": [{"item": "rime_steel", "count": 1}, {"item": "frost_sinew", "count": 1}, {"item": "aurora_glass", "count": 1}],
		"rare_percent": 0, "respawn_ticks": 900, "boss": true,
	},
}
## Area blows. An attack whose action names a `shape` strikes a ground mark, not the player:
## `front`, an arc of FRONT_ARC degrees in the direction the enemy faces, or `ring`, a circle
## centred on it, in either case `size` metres in radius. The mark is told MARK_TICKS ticks
## before the blow lands, and from then until it lands the enemy is rooted, so the mark is the
## ground that gets hit. The blow hits a player standing inside the mark on the landing tick
## and misses one who is not; the style edge never applies to it, armour does, and it is never
## feinted (see `area_problems`).
const MARK_FRONT := "front"
const MARK_RING := "ring"
const MARK_SHAPES: Array[String] = [MARK_FRONT, MARK_RING]
const FRONT_ARC := 120.0
const MARK_TICKS := 2

## The rare drop in both rings: one piece of iron gear, ahead of smithing it at the Bloomery.
const RARE_LOOT: Array[String] = [
	"iron_sword", "iron_helm", "iron_body", "iron_legs", "iron_bow", "iron_axe", "iron_pickaxe", "iron_staff",
]


## Stand-in kinds and actions, on top of ENEMIES and ACTIONS: a test of a mechanic that no
## enemy uses yet defines its own kind here rather than in the tables. Empty in the game.
static var _stand_in_kinds := {}
static var _stand_in_actions := {}


## Adds stand-in `kinds` and `actions`, shaped like ENEMIES and ACTIONS entries, for a test.
static func add_stand_ins(kinds: Dictionary, actions: Dictionary) -> void:
	_stand_in_kinds.merge(kinds, true)
	_stand_in_actions.merge(actions, true)


static func clear_stand_ins() -> void:
	_stand_in_kinds.clear()
	_stand_in_actions.clear()


static func is_enemy_kind(kind: String) -> bool:
	return ENEMIES.has(kind) or _stand_in_kinds.has(kind)


static func enemy(kind: String) -> Dictionary:
	return ENEMIES[kind] if ENEMIES.has(kind) else _stand_in_kinds[kind]


static func has_action(action: String) -> bool:
	return ACTIONS.has(action) or _stand_in_actions.has(action)


static func _action(action: String) -> Dictionary:
	return ACTIONS.get(action, _stand_in_actions.get(action, {}))


static func is_attack(action: String) -> bool:
	return int(_action(action).get("damage", 0)) > 0


static func is_heavy(action: String) -> bool:
	return bool(_action(action).get("heavy", false))


static func action_damage(action: String) -> int:
	return int(_action(action).get("damage", 0))


static func is_stance(action: String) -> bool:
	return bool(_action(action).get("stance", false))


static func is_windup(action: String) -> bool:
	return bool(_action(action).get("windup", false))


static func is_feint(action: String) -> bool:
	return _action(action).has("feint")


static func is_area_blow(action: String) -> bool:
	return _action(action).has("shape")


## The ground mark of area blow `action`, told by an enemy standing at `pos` and facing
## `facing`, in world space: {shape, centre, radius}, and for a front mark its `facing` and
## its whole `arc` in degrees. Points are [x, z] like every position in the state.
static func area_mark(action: String, pos: Vector2, facing: Vector2) -> Dictionary:
	var def := _action(action)
	var mark := {"shape": str(def["shape"]), "centre": [pos.x, pos.y], "radius": float(def["size"])}
	if mark["shape"] == MARK_FRONT:
		var ahead := facing.normalized() if facing != Vector2.ZERO else Vector2(0, 1)
		mark["facing"] = [ahead.x, ahead.y]
		mark["arc"] = FRONT_ARC
	return mark


## Whether `pos` lies inside `mark` (an `area_mark`): within its radius of the centre and, for
## a front mark, within half its arc either side of where it faces.
static func in_mark(mark: Dictionary, pos: Vector2) -> bool:
	var centre := Vector2(mark["centre"][0], mark["centre"][1])
	var offset := pos - centre
	if offset.length() > float(mark["radius"]):
		return false
	if mark["shape"] != MARK_FRONT or offset == Vector2.ZERO:
		return true
	var ahead := Vector2(mark["facing"][0], mark["facing"][1])
	return absf(rad_to_deg(ahead.angle_to(offset))) <= float(mark["arc"]) / 2.0


## Damage of an area blow: `base` less the defender's armour `defence`, never below 1. The
## style edge never applies, so no swap changes it.
static func area_damage(base: int, defence := 0) -> int:
	return maxi(1, base - defence) if base > 0 else 0


## What is wrong with the area blows in the cycles of an enemy definition and of each of its
## phases, or [] when nothing is: each names a known shape and a size above 0, and no feint
## pretends to be one, since a ground mark always lands.
static func area_problems(def: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var cycles: Array = [def] + def.get("phases", [])
	for i in cycles.size():
		var where := "the kind" if i == 0 else "phase %d" % i
		for action in cycles[i].get("actions", []):
			var entry := _action(str(action))
			if entry.has("feint") and is_area_blow(str(entry["feint"])):
				out.append("%s: %s feints an area blow, %s" % [where, action, entry["feint"]])
			if not entry.has("shape"):
				continue
			if not MARK_SHAPES.has(entry["shape"]):
				out.append("%s: %s's shape %s is not one of %s" % [where, action, entry["shape"], MARK_SHAPES])
			var size: Variant = entry.get("size")
			if not (size is float or size is int) or size <= 0:
				out.append("%s: %s's mark has no size" % [where, action])
	return out


## What an action shows the player: the attack a feint pretends to be, else the action itself.
static func shown_action(action: String) -> String:
	return str(_action(action)["feint"]) if is_feint(action) else action


## The weapon an enemy of `kind` holds for the action at `index` of its cycle in `phase`.
static func stance_weapon(kind: String, index: int, phase := 0) -> String:
	var stances: Array = _phase(kind, phase).get("stances", [])
	if stances.is_empty():
		return enemy(kind)["weapon"]
	return stances[posmod(index, stances.size())]


## The action cycle an enemy of `kind` works through in `phase`: 0 is the kind's own, then 1,
## 2 … into its `phases`.
static func cycle(kind: String, phase := 0) -> Array:
	return _phase(kind, phase)["actions"]


static func phase_count(kind: String) -> int:
	return (enemy(kind).get("phases", []) as Array).size()


## The phase an enemy of `kind` in `phase` with `health` left fights in: the deepest whose mark
## its health is below, and never one it has already left behind.
static func phase_at(kind: String, health: int, phase: int) -> int:
	var def := enemy(kind)
	var phases: Array = def.get("phases", [])
	var deepest := phase
	for i in range(phase, phases.size()):
		if health * 100 < int(def["health"]) * int(phases[i]["below"]):
			deepest = i + 1
	return deepest


## Phase 0 is the kind itself; phase n is its n-th entry in `phases`.
static func _phase(kind: String, phase: int) -> Dictionary:
	var def := enemy(kind)
	return def if phase <= 0 else def["phases"][phase - 1]


## What is wrong with the `phases` of an enemy definition, or [] when nothing is: each phase
## needs a `below` mark from 1 to 99 and lower than the phase before's, a cycle whose first
## action is a stance (so the change is announced a tick ahead), and one stance per action
## when it lists stances.
static func phase_problems(def: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var mark := 100
	var phases: Array = def.get("phases", [])
	for i in phases.size():
		var phase: Dictionary = phases[i]
		var below: Variant = phase.get("below")
		if not (below is int) or below < 1 or below > 99:
			out.append("phase %d: below %s is not from 1 to 99" % [i + 1, below])
		elif below >= mark:
			out.append("phase %d: below %d is not under the phase before's %d" % [i + 1, below, mark])
		else:
			mark = below
		var actions: Array = phase.get("actions", [])
		if actions.is_empty() or not is_stance(str(actions[0])):
			out.append("phase %d: its cycle does not begin with a stance" % [i + 1])
		var stances: Array = phase.get("stances", [])
		if not stances.is_empty() and stances.size() != actions.size():
			out.append("phase %d: %d stances for %d actions" % [i + 1, stances.size(), actions.size()])
	return out


## What an enemy of `kind` in `phase` answers each player style with: {style: cycle index}.
static func answers(kind: String, phase := 0) -> Dictionary:
	return _phase(kind, phase).get("answers", {})


## The fewest ticks between two answers of an enemy of `kind` in `phase`.
static func answer_ticks(kind: String, phase := 0) -> int:
	return int(_phase(kind, phase).get("answer_ticks", 0))


## What is wrong with the `answers` of an enemy definition and of each of its phases, or []
## when nothing is: each answer names a style and the index of a stance in that cycle, so the
## switch is announced a tick ahead, and a cycle with answers has `answer_ticks` of at least 1.
static func answer_problems(def: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var cycles: Array = [def] + def.get("phases", [])
	for i in cycles.size():
		var where := "the kind" if i == 0 else "phase %d" % i
		var answered: Dictionary = cycles[i].get("answers", {})
		if answered.is_empty():
			continue
		var actions: Array = cycles[i].get("actions", [])
		for style in answered:
			var index: Variant = answered[style]
			if not STYLE_SKILLS.has(style):
				out.append("%s: %s is not a style" % [where, style])
			elif not (index is int) or index < 0 or index >= actions.size():
				out.append("%s: the answer to %s, %s, is not in its cycle" % [where, style, index])
			elif not is_stance(str(actions[index])):
				out.append("%s: the answer to %s, %s, is not a stance" % [where, style, actions[index]])
		var ticks: Variant = cycles[i].get("answer_ticks")
		if not (ticks is int) or ticks < 1:
			out.append("%s: answer_ticks %s is not a whole number of ticks" % [where, ticks])
	return out


static func action_label(action: String) -> String:
	return _action(action).get("label", action)


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
