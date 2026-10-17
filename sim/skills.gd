## The eight skills and the one experience curve they all share.
##
## A skill is `{xp: int, level: int}` in the state. Experience only ever goes up, and the
## stored level is the highest the curve has granted, so a level never decreases even if
## the curve is retuned later. Engine-free like the rest of sim/.
class_name SkillTable
extends RefCounted

const WOODCUTTING := "woodcutting"
const MINING := "mining"
const FISHING := "fishing"
const COOKING := "cooking"
const SMITHING := "smithing"
const MELEE := "melee"
const RANGED := "ranged"
const MAGIC := "magic"

## Every skill, in the brief's order: gathering, crafting, combat.
const NAMES: Array[String] = [WOODCUTTING, MINING, FISHING, COOKING, SMITHING, MELEE, RANGED, MAGIC]

const MAX_LEVEL := 99
## Total experience to reach level L is XP_STEP * L * (L - 1) / 2: level 2 needs 50,
## level 3 150, level 4 300, level 5 500. Each level costs XP_STEP more than the last.
const XP_STEP := 50


## Total experience needed to reach `level`. Level 1 needs none.
static func xp_for_level(level: int) -> int:
	var l := clampi(level, 1, MAX_LEVEL)
	return XP_STEP * l * (l - 1) / 2


## The level a total of `xp` experience reaches on the shared curve.
static func level_for_xp(xp: int) -> int:
	var level := 1
	while level < MAX_LEVEL and xp >= xp_for_level(level + 1):
		level += 1
	return level


## A fresh skill table: every skill at level 1 with no experience.
static func new_table() -> Dictionary:
	var out := {}
	for name in NAMES:
		out[name] = {"xp": 0, "level": 1}
	return out
