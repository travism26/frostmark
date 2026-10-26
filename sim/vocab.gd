## The command and event vocabulary of the simulation.
##
## Every command the presentation can issue and every event the simulation can emit
## is named here once, so later slices extend this list instead of inventing strings.
## Commands not in IMPLEMENTED are accepted by `Sim.command()` and answered with
## `not_implemented` until their slice lands (none are left in the first playable).
## The human-readable version of this vocabulary is docs/simulation.md.
class_name SimVocab
extends RefCounted

# --- Commands -------------------------------------------------------------------

const MOVE_TO := "move_to"          # {pos: [x, z]}            walk to a ground point
const INTERACT := "interact"        # {object_id: String}      walk to an object or loot pile and start its action
const GATHER := "gather"            # {object_id}              walk to a node and gather until it is spent
const COOK := "cook"                # {index}                  cook a pack slot's raw food at a fire, one at a time
const SMITH := "smith"              # {recipe}                 craft a recipe at the workbench
const EQUIP := "equip"              # {index} | {unequip: slot} equip a pack item, or unequip into the pack
const EAT := "eat"                  # {index}                  eat food from a pack slot; costs the tick
const DROP := "drop"                # {index, count?}          drop from a pack slot
const DEPOSIT := "deposit"          # {index, count?}          pack slot to stash, inside the outpost
const WITHDRAW := "withdraw"        # {index, count?}          stash slot to pack, inside the outpost
const DEPOSIT_HAUL := "deposit_haul"  # {}                     every haul slot to the stash, kit stays; inside the outpost
const BUILD := "build"              # {upgrade}                build an outpost upgrade from the stash, inside the outpost
const ATTACK := "attack"            # {enemy_id}               close to reach and strike every ready tick
const CROSS_GATE := "cross_gate"    # {}                       walk through the gate to its other side
const EXPORT_SAVE := "export_save"  # {}                       returns {ok, reason, code}
const IMPORT_SAVE := "import_save"  # {code}                   replaces the state from a save code
const LIGHT_FIRE := "light_fire"    # {}                       burn logs from the pack into a field fire where you stand
const SET_HINTS := "set_hints"      # {on: bool}               turn the first-outing guide off (dismiss) or back on
const NEW_CHARACTER := "new_character"  # {previous: String}   start over; a previous save code turns the guide off
const TRAVEL := "travel"            # {object_id}              channel at a waystone, then stand at the outpost gate
const SET_AUTO_RETALIATE := "set_auto_retaliate"  # {on: bool}  fight back when hit while idle (on) or not

## Every command kind: the spec's fifteen in spec order, then the brief's field fire, then the
## first-outing guide's two, then waystone travel, then auto-retaliate, then Deposit haul.
## `Sim.command()` rejects anything else as `unknown_command`.
const COMMANDS: Array[String] = [
	MOVE_TO, INTERACT, GATHER, COOK, SMITH, EQUIP, EAT, DROP, DEPOSIT, WITHDRAW,
	BUILD, ATTACK, CROSS_GATE, EXPORT_SAVE, IMPORT_SAVE, LIGHT_FIRE, SET_HINTS, NEW_CHARACTER, TRAVEL,
	SET_AUTO_RETALIATE, DEPOSIT_HAUL,
]

## Commands that do something in this slice. The rest answer `not_implemented`.
const IMPLEMENTED: Array[String] = [
	MOVE_TO, INTERACT, GATHER, COOK, SMITH, EQUIP, EAT, DROP, DEPOSIT, WITHDRAW, BUILD, ATTACK,
	CROSS_GATE, EXPORT_SAVE, IMPORT_SAVE, LIGHT_FIRE, SET_HINTS, NEW_CHARACTER, TRAVEL,
	SET_AUTO_RETALIATE, DEPOSIT_HAUL,
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
const EV_DEPOSITED_HAUL := "deposited_haul"      # {items, stayed} each a list of {item, count}; stayed is haul the stash had no room for
const EV_RETURNED := "returned"                  # {items, newly_affordable}  items: the pack as a list of {item, count}; newly_affordable: upgrade ids
const EV_WARMTH_CHANGED := "warmth_changed"      # {warmth, max}
const EV_TOOK_DAMAGE := "took_damage"            # {amount, cause, health}  cause: "cold" or an enemy kind
const EV_HEALED := "healed"                      # {amount, health}
const EV_ATE := "ate"                            # {item, heal, ticks}
const EV_DIED := "died"                          # {cause, kept, lost, spare, pos, chest}  kept/lost: lists of {item, count}; spare: item given back or ""; chest: the death chest the lost things went into, "" when they were destroyed
const EV_SAVED := "saved"                        # {reason, tick}  a save point: persist sim.export_code()
const EV_SAVE_REJECTED := "save_rejected"        # {reason}
# Combat
const EV_ENEMY_NOTICED := "enemy_noticed"        # {enemy_id, cause}  cause: sight, noise, pack, hit, or called (an add coming in)
const EV_ENEMY_MOVED := "enemy_moved"            # {enemy_id, from, to, path, facing}
const EV_ENEMY_TELEGRAPHED := "enemy_telegraphed"  # {enemy_id, action, style, damage, heavy, at}
const EV_HIT := "hit"                            # {attacker, target, amount, style, multiplier, health, area?, burning?, warded?}  area: true for an area blow; burning: true for burning ground's damage; warded: the one style the target's ward lets through, on a blow it turned to 0
const EV_MISSED := "missed"                      # {attacker, target, action, area?}  the target was out of reach, or off the ground mark
const EV_GROUND_MARKED := "ground_marked"        # {enemy_id, action, style, damage, heavy, mark, at}  an area blow's ground mark, landing on tick `at`
const EV_BURNING_STARTED := "burning_started"    # {patch_id, enemy_id, mark, damage, until}  an area blow left burning ground; it burns through tick `until`
const EV_BURNING_OUT := "burning_out"            # {patch_id}  the patch went out: it ran its course, or its enemy gave up the fight
const EV_ENEMY_FEINTED := "enemy_feinted"        # {enemy_id, action, style, at}  the blow telegraphed for `at` was a feint; action and style are the ones it showed
const EV_ENEMY_DIED := "enemy_died"              # {enemy_id, enemy_kind, pos}
const EV_ENEMY_DISENGAGED := "enemy_disengaged"  # {enemy_id}  heading home; the player is in the outpost
const EV_ENEMY_RESPAWNED := "enemy_respawned"    # {enemy_id, pos}
const EV_ADD_CALLED := "add_called"              # {enemy_id, enemy_kind, boss_id, pos, at}  a boss called an add in; it comes in at `pos` on tick `at`
const EV_ADD_LEFT := "add_left"                  # {enemy_id, boss_id}  the add's boss gave up the fight, so it left
const EV_LOOT_DROPPED := "loot_dropped"          # {loot_id, item, count, pos}
const EV_PICKED_UP := "picked_up"                # {loot_id, item, count}
const EV_LOOT_GONE := "loot_gone"                # {loot_id}  lay too long; the snow took it
const EV_ENEMY_STANCE := "enemy_stance"          # {enemy_id, action, style, at, ward?}  a weapon change, announced a tick ahead; ward: the one style that hurts it, on a warded phase's opening stance
# Cooking, field fires, the outpost, the ring gates, the dungeon mouths and the death chests
const EV_COOKED := "cooked"                      # {item, output, burnt, xp}  output is "" when it burnt
const EV_FIRE_LIT := "fire_lit"                  # {fire_id, pos, expires_tick}
const EV_FIRE_OUT := "fire_out"                  # {fire_id}
const EV_BUILT := "built"                        # {upgrade, effects}
const EV_RING_GATE_OPENED := "ring_gate_opened"  # {object_id}  its upgrade built and its guardian, if it has one, dead
const EV_RING_TWO_REACHED := "ring_two_reached"  # {object_id}  first walked into ring two, through that gate; once per character
const EV_RING_THREE_REACHED := "ring_three_reached"  # {object_id}  first walked into ring three, through that gate; once per character
const EV_DUNGEON_REACHED := "dungeon_reached"    # {dungeon_id, object_id}  first walked into a dungeon, through its mouth; once per dungeon per character
const EV_LEFT_DUNGEON := "left_dungeon"          # {dungeon_id, object_id, from, to}  took a dungeon's way out: the player stands at its set-down spot
const EV_TOOK_FROM_CHEST := "took_from_chest"    # {object_id, dungeon_id, items, left}  items: what moved from a death chest into the pack; left: what stays in the chest
# Waystones
const EV_WAYSTONE_ATTUNED := "waystone_attuned"  # {object_id}  first visit to a waystone; once per waystone
const EV_TRAVEL_STARTED := "travel_started"      # {object_id, ticks}  channelling began; done in `ticks` ticks unless interrupted
const EV_TRAVELLED := "travelled"                # {object_id, from, to}  the channel finished: the player stands outside the outpost gate
# The first-outing guide (text in GuideTable)
const EV_HINT := "hint"                          # {hint}  the guide's current hint step: a GuideTable id, "" once the path is walked
const EV_TIP := "tip"                            # {tip}   a contextual tip fired: a GuideTable.TIPS id
const EV_HINTS_SET := "hints_set"                # {on}    the guide was turned off or back on

## The combatant id of the player in `hit` and `missed` events; enemies use their own ids.
const PLAYER := "player"

# --- Interaction actions (the `action` of `interacted`) --------------------------

const ACTION_NONE := "none"
const ACTION_GATHER := "gather"
const ACTION_WARM := "warm"
const ACTION_STASH := "stash"
const ACTION_CRAFT := "craft"
const ACTION_PICK_UP := "pick_up"
const ACTION_RING_GATE := "ring_gate"
const ACTION_WAYSTONE := "waystone"
const ACTION_WAY_OUT := "way_out"
const ACTION_DEATH_CHEST := "death_chest"

# --- Upgrade status (the `status` of each `Sim.upgrade_status()` entry) ----------

const UPGRADE_BUILT := "built"
const UPGRADE_CAN_BUILD := "can_build"   # unlocked, prerequisites built, the stash holds the cost
const UPGRADE_NOT_YET := "not_yet"       # locked, a prerequisite unbuilt, or a cost item short

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
const REASON_NO_HAUL := "no_haul"
const REASON_NOT_AT_WORKBENCH := "not_at_workbench"
const REASON_UNKNOWN_RECIPE := "unknown_recipe"
const REASON_UPGRADE_MISSING := "upgrade_missing"
const REASON_MISSING_INPUTS := "missing_inputs"
const REASON_MOVED := "moved"
const REASON_DIED := "died"
# Combat and eating
const REASON_UNKNOWN_ENEMY := "unknown_enemy"
const REASON_TARGET_DEAD := "target_dead"
const REASON_IN_OUTPOST := "in_outpost"
const REASON_NO_AMMO := "no_ammo"
const REASON_NOT_FOOD := "not_food"
const REASON_ALREADY_EATING := "already_eating"
# Gathering tools, cooking, smithing and the outpost
const REASON_TOOL_TOO_WEAK := "tool_too_weak"
const REASON_NOT_AT_FIRE := "not_at_fire"
const REASON_NOT_COOKABLE := "not_cookable"
const REASON_NOTHING_LEFT := "nothing_left"
const REASON_TIER_CAPPED := "tier_capped"
const REASON_UNKNOWN_UPGRADE := "unknown_upgrade"
const REASON_ALREADY_BUILT := "already_built"
const REASON_UPGRADE_LOCKED := "upgrade_locked"
const REASON_WAY_OUT_SHUT := "way_out_shut"      # a dungeon's way out while its boss stands
# Waystones
const REASON_NOT_WAYSTONE := "not_waystone"
const REASON_NOT_ATTUNED := "not_attuned"
const REASON_NOT_AT_WAYSTONE := "not_at_waystone"
const REASON_INTERRUPTED := "interrupted"
# Save codes
const REASON_BAD_CODE := "bad_code"
const REASON_BAD_CHECKSUM := "bad_checksum"
const REASON_UNSUPPORTED_VERSION := "unsupported_version"
const REASON_BAD_SNAPSHOT := "bad_snapshot"
