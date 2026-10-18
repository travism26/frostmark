## Which sound plays for which simulation event, as data. Every cue key names one or more
## clips under assets/audio/ (one is picked at random each time, so repeats vary), and
## `event_cues()` maps an event to the cue keys it sounds, reading only the event's own
## fields (and, for a build, the material YardLook declares for the upgrade). Loops (the wind and snow beds, the fire, the music) are keyed here too so a test
## can check that every key the director uses resolves to a file.
##
## Presentation-side on purpose: no rule lives here, and nothing here changes the state.
## The credits for every clip are in docs/assets/CREDITS.md and in `CREDITS` below, which
## the sound panel shows in the game.
class_name AudioCues
extends RefCounted

const DIR := "res://assets/audio/"

# --- Cue keys --------------------------------------------------------------------------

const STEP := "step"
const CHOP := "chop"
const MINE := "mine"
const CAST := "cast"
const CATCH := "catch"
const SMITH := "smith"
const COOK := "cook"
const HIT := "hit"
const HIT_TAKEN := "hit_taken"
const BOW := "bow"
const CUE_MELEE := "cue_melee"
const CUE_RANGED := "cue_ranged"
const FALL := "fall"
const STING_DEATH := "sting_death"
const STING_BANK := "sting_bank"
const STING_LEVEL := "sting_level"
const BUILT := "built"
const WIND := "wind"
const FIRE := "fire"
const MUSIC_OUTPOST := "music_outpost"
const MUSIC_OUTSIDE := "music_outside"

## Cue key -> its clips (file names under DIR, without the extension).
const SOUNDS := {
	STEP: ["step_snow_1", "step_snow_2", "step_snow_3", "step_snow_4"],
	CHOP: ["chop_1", "chop_2", "chop_3"],
	MINE: ["mine_1", "mine_2", "mine_3"],
	CAST: ["splash_1"],
	CATCH: ["splash_2"],
	SMITH: ["smith_1", "smith_2"],
	COOK: ["cook_1", "cook_2"],
	HIT: ["hit_1", "hit_2"],
	HIT_TAKEN: ["hit_heavy_1", "hit_heavy_2"],
	BOW: ["bow_release"],
	CUE_MELEE: ["cue_melee"],
	CUE_RANGED: ["cue_ranged"],
	FALL: ["fall"],
	STING_DEATH: ["sting_death"],
	STING_BANK: ["sting_bank"],
	STING_LEVEL: ["sting_level"],
	BUILT: ["chop_2", "mine_2", "smith_2"],
	WIND: ["amb_wind"],
	FIRE: ["amb_fire"],
	MUSIC_OUTPOST: ["music_outpost"],
	MUSIC_OUTSIDE: ["music_outside"],
}

## Cue keys that loop rather than play once.
const LOOPS: Array[String] = [WIND, FIRE, MUSIC_OUTPOST, MUSIC_OUTSIDE]

const SILENT_DB := -60.0

## Each one-shot cue's level, so the mix sits right without touching the clips.
const GAIN := {
	STEP: -14.0, CHOP: -5.0, MINE: -6.0, CAST: -8.0,
	CATCH: -5.0, SMITH: -5.0, COOK: -8.0, HIT: -4.0,
	HIT_TAKEN: -2.0, BOW: -5.0, CUE_MELEE: -3.0,
	CUE_RANGED: -3.0, FALL: -6.0, STING_DEATH: -4.0,
	STING_BANK: -6.0, STING_LEVEL: -6.0, BUILT: -5.0,
}
## Per region: the wind's level and pitch, and the snow's level (the same wind pitched up
## into the hiss of driven snow). Gentle behind the walls, a gale in ring one.
const BEDS := {
	WorldDef.REGION_OUTPOST: {"wind": -22.0, "pitch": 1.0, "snow": SILENT_DB},
	WorldDef.REGION_INNER_RING: {"wind": -12.0, "pitch": 1.0, "snow": -26.0},
	WorldDef.REGION_RING_ONE: {"wind": -6.0, "pitch": 0.85, "snow": -15.0},
}
## The strike a gathering skill makes while it works, and the sound of its success.
const GATHER_STRIKE := {SkillTable.WOODCUTTING: CHOP, SkillTable.MINING: MINE}
const GATHER_SUCCESS := {SkillTable.FISHING: CATCH}

## The sound of a build, by what the upgrade is built of: an axe on timber, a pick on stone,
## a hammer on iron. An upgrade with no material sounds the shared BUILT cue. The level
## sting rises on top of either, so a build sounds like a milestone and not like crafting.
const BUILT_BY_MATERIAL := {YardLook.TIMBER: CHOP, YardLook.STONE: MINE, YardLook.IRON: SMITH}

## The telegraph cue for each style, so the counter can be heard as well as read.
const CUE_BY_STYLE := {CombatTable.STYLE_MELEE: CUE_MELEE, CombatTable.STYLE_RANGED: CUE_RANGED}

## Every clip shipped, its source and its licence, shown in the sound panel. The full
## table with links is docs/assets/CREDITS.md.
const CREDITS: Array[String] = [
	"Impact Sounds, RPG Audio, Interface Sounds and Music Jingles by Kenney (kenney.nl), CC0: footsteps, chopping, mining, smithing, cooking, hits, telegraph cues, the bow's string and the stingers.",
	"Swishes Sound Pack by artisticdude (OpenGameArt), CC0: the arrow's whoosh.",
	"6 Short water splashes by ezwa (OpenGameArt), from pdsounds.org, public domain: casting and landing a fish.",
	"Wind by IgnasD (OpenGameArt), CC0: the wind and snow beds.",
	"Fire Crackling by AntumDeluge (OpenGameArt), CC0: the outpost and field fires.",
	"Through the Snow (Snow theme). Music by Cleyton Kauffman - https://soundcloud.com/cleytonkauffman, CC0: the outpost's music.",
	"Crystal Cave (song18) by cynicmusic. Credit pixelsphere.org / The Cynic Project, CC0: the music outside the walls.",
]


## The file a clip name lives in.
static func path(clip: String) -> String:
	return DIR + clip + ".ogg"


## Every clip path a cue key can play.
static func paths(key: String) -> Array[String]:
	var out: Array[String] = []
	for clip in SOUNDS.get(key, []):
		out.append(path(clip))
	return out


## The one-shot cue keys an event sounds, from its own fields. Ongoing sounds (footsteps,
## gathering strikes, the beds and the music) are the director's, not an event's.
static func event_cues(e: Dictionary) -> Array[String]:
	var out: Array[String] = []
	match e.get("kind", ""):
		SimVocab.EV_GATHERED:
			if GATHER_SUCCESS.has(e.get("skill", "")):
				out.append(GATHER_SUCCESS[e["skill"]])
		SimVocab.EV_COOKED:
			out.append(COOK)
		SimVocab.EV_CRAFTED:
			out.append(SMITH)
		SimVocab.EV_BUILT:
			out.append(BUILT_BY_MATERIAL.get(YardLook.material(e.get("upgrade", "")), BUILT))
			out.append(STING_LEVEL)
		SimVocab.EV_HIT:
			if e.get("style", "") == CombatTable.STYLE_RANGED:
				out.append(BOW)
			out.append(HIT_TAKEN if e.get("target", "") == SimVocab.PLAYER else HIT)
		SimVocab.EV_ENEMY_TELEGRAPHED, SimVocab.EV_ENEMY_STANCE:
			if CUE_BY_STYLE.has(e.get("style", "")):
				out.append(CUE_BY_STYLE[e["style"]])
		SimVocab.EV_ENEMY_DIED:
			out.append(FALL)
		SimVocab.EV_DIED:
			out.append(STING_DEATH)
		SimVocab.EV_BANKED, SimVocab.EV_RING_TWO_REACHED:
			out.append(STING_BANK)
		SimVocab.EV_LEVELLED:
			out.append(STING_LEVEL)
	return out


## Every cue key the event mapping and the director can ask for.
static func all_keys() -> Array[String]:
	var out: Array[String] = []
	for key in SOUNDS:
		out.append(key)
	return out
