# Handoff: ticket #15 (ring-two monster silhouettes and remaining character clips)

Branch `fm/frostmark-monsters`. Remove this file before the PR. The silhouette board is done
and Travis has picked; nothing monster-side is built yet. Context budget ran out after the board.

## Travis's picks (Lavish board, session ended by Travis, 2026-10-17)

- **Ice troll = A. Yeti**: Quaternius "Yeti", Ultimate Monsters, via Poly Pizza
  https://poly.pizza/m/ceRHrn8HHE, CC0. Source file: `data/frostmark-monsters/yeti1.glb`
  (413 KB, 6.1k tris, clips `CharacterArmature|Idle|Walk|Run|Punch|Weapon|HitReact|Death`,
  lengths Idle 1.0 s, Walk 1.0, Run 0.54, Weapon 0.83, Death 0.75). Bones include
  `Torso`, `LowerArm.R` (club hangs here), faces +Z like KayKit.
- **Ruin stalker = B. Bare skeleton**: KayKit Skeletons `Skeleton_Minion.glb`, CC0,
  https://kaylousberg.com/game-assets/characters-skeletons (repo
  KayKit-Game-Assets/KayKit-Character-Pack-Skeletons-1.0, LICENSE.txt in `data/frostmark-monsters/`).
  Same rig and clip names as the adventurers (`Idle`, `Walking_A`, `Running_A`, `2H_Ranged_Shoot`,
  `Hit_A`, `Death_A`, `handslot_l/r`). 4.7 MB raw: trim with `tools/trim_glb.py` to ~1 MB.
- **Frost witch = A. Wide-hat mage**: KayKit Adventurers `Mage.glb`, CC0, same rig; keep
  `Spellcast_Shoot` (0.93 s) and `Spellcast_Raise`; hide `Spellbook`, `Spellbook_open`, `1H_Wand`,
  `2H_Staff` (the game's shaft-and-crystal staff goes in `handslot_r`). Recolour `#6670b3`.
  Raw file also in `data/frostmark-monsters/`.
- Travis's words: "Yeah, all your recommendations are good ... Let's go with your recommendations."
  No notes.

## Already on the branch

- `tools/silhouette_shots.gd` renders candidates in the real scene (spec JSON in
  `data/frostmark-monsters/board_spec.json`); its `_paint` shows how Quaternius materials must be
  repainted: they ship dark, metallic 0.4 base colours that read as shadow under the dusk sun.
  Yeti palette that worked: Yeti_Main `#dfe8f3`, Yeti_Secondary `#5b86b0`, Eye_White `#f2f5ff`,
  Eye_Black `#101420`, Yeti_Teeth `#efe6cf`, Tongue `#7a2f4a`; metallic 0, roughness 1, specular off.
- `tools/trim_glb.py <in> <out> <clips...>` keeps named clips and prunes the buffer (byte-exact
  mesh data). Used to re-trim `assets/models/kaykit_adventurers/barbarian.glb` from the full
  KayKit Barbarian.glb with `Spellcast_Shoot` added (16 clips, 1.03 MB).
- `assets/models/quaternius/fishing_rod.glb`: Quaternius "Fishing Rod" via Poly Pizza
  https://poly.pizza/m/0YAR0Lg58p, CC0, 28 KB, 522 tris. Not yet credited or wired.
- The board itself lives in `.lavish/monsters/` (untracked; never commit). Board frames are JPEGs
  there; the three "today" frames plus the picked options can serve as before/after shots.

## Plan worked out, not yet coded

FigureBody (`scenes/figure_body.gd`):
- `strike(style)`: pace the clip so its blow lands one tick (Sim.TICK_SECONDS = 0.5) after the
  telegraph: `speed_scale = (length * impact) / TICK_SECONDS`, `impact` from `clips["impact"]`
  (default 0.45; yeti Weapon 0.5). Reset `speed_scale = 1` in `_play` and `_on_clip_finished`.
- `wind_up(style)`: for the troll's `wind_up` stance (CombatTable.ACTIONS[action]["windup"]):
  play the strike clip, pause at `clips["raise"]` (default 0.2) of its length; the next
  `strike()` resumes from the paused position with speed so the blow still lands on the tick.
  Release the hold after ~1.2 s if no strike comes (disengage).
- `flinch()`: one-shot `clips["flinch"]` (`Hit_A`) when no one-shot is playing.
- `var lunge := 0.0`: on strike, tween `_model.position` to `Vector3(0, 0, -lunge)` over
  0.25 s and back over 0.3 s. Wolf: `lunge = 0.8`, impact 0.45 (Attack is 1.33 s).
- `current_clip()` accessor returning `_current` (CharacterGear needs it).

CharacterView: add `"magic": "Spellcast_Shoot"`, `"flinch": "Hit_A"`; ATTACK with a magic
weapon returns `clips["magic"]`.

GameRoot: on `EV_HIT` with `e["target"] == SimVocab.PLAYER` call `_character_view.flinch()`;
in `_show_cue`, when the action is a windup stance call `figure.wind_up(e["style"])`.

CharacterGear `_build_tool` TOOL_ROD: `Figures.rod(colour)` loads the rod glb, scales to ~1.4 m
on the Y axis (use `Props._bounds`), replaces materials with `Props.flat(colour)` for `Wood` and a
dark iron flat for `Metal`, grip ~15% up the butt on the origin. While `view.current_clip() ==
CharacterView.CLIP_FISH`, reparent the rod from the back sling to a `handslot_r` mount tilted
forward; back to the sling otherwise (enable `_process` only while a rod is shown).

Figures (`scenes/figures.gd`): new scenes behind `enemy(kind)`:
- `ice_troll`: yeti at 3.1 m (`model_height` from merged mesh AABB, see
  `silhouette_shots._rig_height`), repainted as above, `run_speed` 2.5, ice club on a
  BoneAttachment3D at `LowerArm.R` scaled by the inverse of the bone frame's scale (see the
  board script's club code; its orientation still needs tuning, the club did not show on the board).
- `ruin_stalker`: `humanoid("skeleton_minion.glb", 1.8, [])` with KAYKIT_HEIGHT, bone bow in
  `handslot_l`, no recolour (bone-white was the point), maybe a slight cool tint.
- `frost_witch`: `humanoid("mage.glb", 1.85, [...])`, recolour `#6670b3`, staff in `handslot_r`,
  clips with `"magic": "Spellcast_Shoot"`.
- Put the trimmed glbs under `assets/models/kaykit_skeletons/` (with LICENSE.txt) and
  `assets/models/kaykit_adventurers/mage.glb`; yeti under `assets/models/quaternius/yeti.glb`.
  Trim the yeti too (drop Duck, Jump*, No, Wave, Yes). Keep pck <= 15 MB (was ~4.15 MB).

Credits (`docs/assets/CREDITS.md`, "In use"): add KayKit Skeletons (Skeleton_Minion), extend
the KayKit Adventurers row with `mage` and the barbarian's Spellcast_Shoot, add Quaternius Yeti
and Fishing Rod (Poly Pizza links), all CC0. `tests/test_icons.gd` checks credits for icons only.

Decisions to note in the PR: fishing rod = Quaternius CC0 model (no Blender here for the AnyRPG
.blend); death = keep Death_A (0.8 s, the death screen covers it); wolf = shipped Attack clip
plus the scripted lunge.

Gate before the PR (from the brief): `godot --headless --import`, `godot --headless -s
tests/run.gd`, 60 s headless smoke of main, web export, Chrome console clean, pck and fps vs
main once (tools/chrome_shoot.sh, ring_codes.txt), screenshots once. Delete `assets/models/_board/`
(untracked) and this file before the PR. PR title `feat: ring-two monster silhouettes and
remaining character clips`, `Closes #15`.
