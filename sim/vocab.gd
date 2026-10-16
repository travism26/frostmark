## The command and event vocabulary of the simulation, for the whole first playable.
##
## Every command the presentation can issue and every event the simulation can emit
## is named here once, so later slices extend this list instead of inventing strings.
## Slice 2 implements only movement; the other commands are accepted by `Sim.command()`
## and answered with `not_implemented` until their slice lands.
## The human-readable version of this vocabulary is docs/simulation.md.
class_name SimVocab
extends RefCounted

# --- Commands -------------------------------------------------------------------

const MOVE_TO := "move_to"          # {pos: [x, z]}            walk to a ground point
const INTERACT := "interact"        # {object_id: String}      walk to an object and start its action
const GATHER := "gather"            # slice 3
const COOK := "cook"                # slice 3
const SMITH := "smith"              # slice 3
const EQUIP := "equip"              # slice 3
const EAT := "eat"                  # slice 4
const DROP := "drop"                # slice 3
const DEPOSIT := "deposit"          # slice 3
const WITHDRAW := "withdraw"        # slice 3
const BUILD := "build"              # slice 3
const ATTACK := "attack"            # slice 4
const CROSS_GATE := "cross_gate"    # slice 3
const EXPORT_SAVE := "export_save"  # slice 3
const IMPORT_SAVE := "import_save"  # slice 3

## Every command kind, in spec order. `Sim.command()` rejects anything else as `unknown_command`.
const COMMANDS: Array[String] = [
	MOVE_TO, INTERACT, GATHER, COOK, SMITH, EQUIP, EAT, DROP, DEPOSIT, WITHDRAW,
	BUILD, ATTACK, CROSS_GATE, EXPORT_SAVE, IMPORT_SAVE,
]

## Commands that do something in this slice. The rest answer `not_implemented`.
const IMPLEMENTED: Array[String] = [MOVE_TO, INTERACT]

# --- Events ---------------------------------------------------------------------
# Every event is a Dictionary with a `kind` key plus the fields listed beside it.

const EV_COMMAND_REJECTED := "command_rejected"  # {command, reason, args}
const EV_PATH_SET := "path_set"                  # {from, to, length, object_id}
const EV_MOVED := "moved"                        # {from, to, path, facing}  path: polyline walked this tick
const EV_ARRIVED := "arrived"                    # {pos, object_id}          object_id is "" for a plain move
const EV_INTERACTED := "interacted"              # {object_id, object_kind, action}  action is "none" in slice 2
const EV_REGION_CHANGED := "region_changed"      # {from, to}

# Reserved for later slices, named now so the presentation can bind to them early.
const EV_GATHERED := "gathered"
const EV_LEVELLED := "levelled"
const EV_CRAFTED := "crafted"
const EV_EQUIPPED := "equipped"
const EV_ATE := "ate"
const EV_DROPPED := "dropped"
const EV_DEPOSITED := "deposited"
const EV_WITHDREW := "withdrew"
const EV_BUILT := "built"
const EV_TOOK_DAMAGE := "took_damage"
const EV_ENEMY_TELEGRAPHED := "enemy_telegraphed"
const EV_ENEMY_DIED := "enemy_died"
const EV_DIED := "died"
const EV_BANKED := "banked"
const EV_WARMTH_CHANGED := "warmth_changed"
const EV_SAVED := "saved"
const EV_SAVE_REJECTED := "save_rejected"

# --- Rejection reasons ------------------------------------------------------------

const REASON_UNKNOWN_COMMAND := "unknown_command"
const REASON_NOT_IMPLEMENTED := "not_implemented"
const REASON_BAD_ARGS := "bad_args"
const REASON_OUTSIDE_WORLD := "outside_world"
const REASON_NOT_WALKABLE := "not_walkable"
const REASON_UNREACHABLE := "unreachable"
const REASON_UNKNOWN_OBJECT := "unknown_object"
