## The first-outing guide as data: the hint path a new player walks once, and the short
## contextual tips. Every line of text and every trigger is here, so rewording a hint or
## retuning a tip never touches the rules in Sim.
##
## A hint step is done by its `trigger`: the first event of that kind whose fields match.
## A tip fires on any one of its `triggers`, or on its named `condition` checked at the end
## of every tick, then stays quiet for `cooldown` ticks, or for good when it fires `once`. Sim runs the guide only while it
## is on; a player turns it off, and every character after the first starts with it off.
## No quests and no dialogue, per the brief: the guide only ever says what to try next.
class_name GuideTable
extends RefCounted

## Warmth at or below this, outside and away from a fire, fires the cold tip (45 seconds left).
const COLD_WARMTH := 90

## A named tip condition Sim evaluates against the state rather than an event.
const CONDITION_COLD := "cold"

## The hint path, in order. A trigger is {event, match?: {field: value}, nonempty?: field}.
const STEPS: Array[Dictionary] = [
	{
		"id": "walk",
		"text": "Click the ground to walk. Q and E turn the camera, and the wheel zooms.",
		"trigger": {"event": SimVocab.EV_MOVED},
	},
	{
		"id": "chop",
		"text": "Walk out through the south gate and click a pine to cut logs.",
		"trigger": {"event": SimVocab.EV_GATHERED, "match": {"item": "logs"}},
	},
	{
		"id": "bank",
		"text": "Walk back in through the gate. Inside the walls nothing can be lost.",
		"trigger": {"event": SimVocab.EV_RETURNED, "nonempty": "items"},
	},
	{
		"id": "craft",
		"text": "Click the workbench and make a wooden pickaxe.",
		"trigger": {"event": SimVocab.EV_CRAFTED},
	},
]

## What the guide says once the path is walked.
const FINISHED_TEXT := "That is the loop: head out, gather, walk it home, craft. Help has the controls."

const TIPS := {
	"cold": {
		"text": "Warmth is low. Get inside the walls or to a fire before the cold starts on your health. Three logs light a fire anywhere.",
		"condition": CONDITION_COLD,
		"cooldown": 600,
	},
	"pack_full": {
		"text": "Your pack is full. Walk home and put the haul in the stash, or right-click an item to drop it.",
		"triggers": [
			{"event": SimVocab.EV_ACTIVITY_STOPPED, "match": {"reason": SimVocab.REASON_PACK_FULL}},
			{"event": SimVocab.EV_COMMAND_REJECTED, "match": {"reason": SimVocab.REASON_PACK_FULL}},
		],
		"cooldown": 240,
	},
	"telegraph": {
		"text": "The word over an enemy's head is its next blow, one beat early. A blade up close beats a bow; a bow at range beats a blade.",
		"triggers": [{"event": SimVocab.EV_ENEMY_TELEGRAPHED}],
		"cooldown": 600,
	},
	"ground_mark": {
		"text": "Step off the red.",
		"triggers": [{"event": SimVocab.EV_GROUND_MARKED}],
		"once": true,
	},
}


static func step_count() -> int:
	return STEPS.size()


## The id of hint step `index`, or "" past the end of the path.
static func step_id(index: int) -> String:
	return STEPS[index]["id"] if index >= 0 and index < STEPS.size() else ""


## The text of a hint step by id; the finished line for "".
static func hint_text(id: String) -> String:
	for s in STEPS:
		if s["id"] == id:
			return s["text"]
	return FINISHED_TEXT


static func tip_text(id: String) -> String:
	return TIPS[id]["text"] if TIPS.has(id) else ""


## Whether `event` satisfies `trigger`.
static func matches(trigger: Dictionary, event: Dictionary) -> bool:
	if event.get("kind") != trigger["event"]:
		return false
	var wanted: Dictionary = trigger.get("match", {})
	for field in wanted:
		if event.get(field) != wanted[field]:
			return false
	var listed: String = trigger.get("nonempty", "")
	return listed == "" or (event.get(listed) is Array and not (event[listed] as Array).is_empty())
