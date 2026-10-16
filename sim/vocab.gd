## The command and event vocabulary of the simulation, for the whole first playable.
##
## Every command the presentation can issue and every event the simulation can emit
## is named here once, so later slices extend this list instead of inventing strings.
## Commands not yet in IMPLEMENTED are accepted by `Sim.command()` and answered with
## `not_implemented` until their slice lands.
## The human-readable version of this vocabulary is docs/simulation.md.
class_name SimVocab
extends RefCounted

# --- Commands -------------------------------------------------------------------

const MOVE_TO := "move_to"          # {pos: [x, z]}            walk to a ground point
const INTERACT := "interact"        # {object_id: String}      walk to an object and start its action
const GATHER := "gather"            # {object_id}              walk to a node and gather until it is spent
const COOK := "cook"                # a later slice
const SMITH := "smith"              # {recipe}                 craft a recipe at the workbench
const EQUIP := "equip"              # {index} | {unequip: slot} equip a pack item, or unequip into the pack
const EAT := "eat"                  # slice 4
const DROP := "drop"                # {index, count?}          drop from a pack slot
const DEPOSIT := "deposit"          # {index, count?}          pack slot to stash, inside the outpost
const WITHDRAW := "withdraw"        # {index, count?}          stash slot to pack, inside the outpost
const BUILD := "build"              # a later slice
const ATTACK := "attack"            # slice 4
const CROSS_GATE := "cross_gate"    # {}                       walk through the gate to its other side
const EXPORT_SAVE := "export_save"  # {}                       returns {ok, reason, code}
const IMPORT_SAVE := "import_save"  # {code}                   replaces the state from a save code

## Every command kind, in spec order. `Sim.command()` rejects anything else as `unknown_command`.
const COMMANDS: Array[String] = [
	MOVE_TO, INTERACT, GATHER, COOK, SMITH, EQUIP, EAT, DROP, DEPOSIT, WITHDRAW,
	BUILD, ATTACK, CROSS_GATE, EXPORT_SAVE, IMPORT_SAVE,
]

## Commands that do something in this slice. The rest answer `not_implemented`.
const IMPLEMENTED: Array[String] = [
	MOVE_TO, INTERACT, GATHER, SMITH, EQUIP, DROP, DEPOSIT, WITHDRAW, CROSS_GATE,
	EXPORT_SAVE, IMPORT_SAVE,
]

# --- Events ---------------------------------------------------------------------
# Every event is a Dictionary with a `kind` key plus the fields listed beside it.

const EV_COMMAND_REJECTED := "command_rejected"  # {command, reason, args}
const EV_PATH_SET := "path_set"                  # {from, to, length, object_id}
const EV_MOVED := "moved"                        # {from, to, path, facing}  path: polyline walked this tick
const EV_ARRIVED := "arrived"                    # {pos, object_id}          object_id is "" for a plain move
const EV_INTERACTED := "interacted"              # {object_id, object_kind, action}  see ACTION_* below
const EV_REGION_CHANGED := "region_changed"      # {from, to}
const EV_GATHERED := "gathered"                  # {object_id, skill, item, count, xp}
const EV_ACTIVITY_STOPPED := "activity_stopped"  # {activity, object_id, reason}
const EV_NODE_DEPLETED := "node_depleted"        # {object_id, respawn_tick}
const EV_NODE_RESPAWNED := "node_respawned"      # {object_id}
const EV_LEVELLED := "levelled"                  # {skill, level}
const EV_CRAFTED := "crafted"                    # {recipe, item, count}
const EV_EQUIPPED := "equipped"                  # {slot, item, previous}  item is "" when unequipping
const EV_DROPPED := "dropped"                    # {item, count}
const EV_DEPOSITED := "deposited"                # {item, count}
const EV_WITHDREW := "withdrew"                  # {item, count}
const EV_BANKED := "banked"                      # {items, overflow}  each a list of {item, count}
const EV_WARMTH_CHANGED := "warmth_changed"      # {warmth, max}
const EV_TOOK_DAMAGE := "took_damage"            # {amount, cause, health}
const EV_COLLAPSED := "collapsed"                # {cause, pos}  health hit zero; woke by the fire
const EV_SAVED := "saved"                        # {reason, tick}  a save point: persist sim.export_code()
const EV_SAVE_REJECTED := "save_rejected"        # {reason}

# Reserved for later slices, named now so the presentation can bind to them early.
const EV_ATE := "ate"
const EV_BUILT := "built"
const EV_ENEMY_TELEGRAPHED := "enemy_telegraphed"
const EV_ENEMY_DIED := "enemy_died"
const EV_DIED := "died"

# --- Interaction actions (the `action` of `interacted`) --------------------------

const ACTION_NONE := "none"
const ACTION_GATHER := "gather"
const ACTION_WARM := "warm"
const ACTION_STASH := "stash"
const ACTION_CRAFT := "craft"

# --- Rejection reasons ------------------------------------------------------------

const REASON_UNKNOWN_COMMAND := "unknown_command"
const REASON_NOT_IMPLEMENTED := "not_implemented"
const REASON_BAD_ARGS := "bad_args"
const REASON_OUTSIDE_WORLD := "outside_world"
const REASON_NOT_WALKABLE := "not_walkable"
const REASON_UNREACHABLE := "unreachable"
const REASON_UNKNOWN_OBJECT := "unknown_object"
const REASON_NOT_GATHERABLE := "not_gatherable"
const REASON_NO_TOOL := "no_tool"
const REASON_DEPLETED := "depleted"
const REASON_LEVEL_TOO_LOW := "level_too_low"
const REASON_PACK_FULL := "pack_full"
const REASON_STASH_FULL := "stash_full"
const REASON_EMPTY_SLOT := "empty_slot"
const REASON_NOT_EQUIPPABLE := "not_equippable"
const REASON_NOT_IN_OUTPOST := "not_in_outpost"
const REASON_NOT_AT_WORKBENCH := "not_at_workbench"
const REASON_UNKNOWN_RECIPE := "unknown_recipe"
const REASON_UPGRADE_MISSING := "upgrade_missing"
const REASON_MISSING_INPUTS := "missing_inputs"
const REASON_MOVED := "moved"
const REASON_COLLAPSED := "collapsed"
# Save codes
const REASON_BAD_CODE := "bad_code"
const REASON_BAD_CHECKSUM := "bad_checksum"
const REASON_UNSUPPORTED_VERSION := "unsupported_version"
const REASON_BAD_SNAPSHOT := "bad_snapshot"
