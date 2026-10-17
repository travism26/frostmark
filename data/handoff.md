# Handoff: ticket #18, ring looks and dusk lighting (branch fm/frostmark-ring-looks)

Written 2026-10-17 because the worker's context budget ran out. Everything below is committed and pushed on `fm/frostmark-ring-looks`. **No PR yet: the brief says no PR before Travis's palette pick.**

## State

**Built and committed (4 commits + docs):**
- `scenes/ring_look.gd` (RingLook): the ring-look table, `at(world, pos)`, `entry(ring)`, `blend`, `distance`, `brightness`, `warmth`, 8 m blend band. `tests/test_ring_look.gd`: 7 tests, all green (262 pass total).
- `scenes/atmosphere.gd` rewritten: no day-night cycle, no breath puffs. Fixed sun (17° up, azimuth -45°), depth fog, ambient, five snow layers (density/wind from the look), snow tint on ground + snow caps (`WorldDressing.apply_tint`, `Props.apply_tint`), a CanvasLayer ColorRect grade with `scenes/shaders/colour_grade.gdshader` (split tone + contrast + saturation + aurora band at the top of the view). `set_look_override(look)` exists for boards/screenshots.
- `scenes/fire_fx.gd`: amber pool disc (Kenney `light_01.png`, CC0, already shipped) out to `size/2 + Sim.FIRE_REACH + 0.4`; omni light range `1.6×` that; `set_lit()`. `scenes/game_root.gd`: `MAX_FIRE_LIGHTS := 4`, `_flicker()` enables the light on the 4 fires nearest the character each frame; atmosphere `setup(..., sim.world)`; `set_outside` calls removed.
- `docs/.gdignore`: main's pck was 9.31 MB because `docs/screenshots/*.jpg` were imported as textures; with the ignore the pck is 4.15 MB. Report this in the PR.
- `export_presets.cfg`: `exclude_filter="tests/*,tools/*"` so the board scripts under `tools/` are not shipped.
- `docs/simulation.md`: the presentation-glue bullet now describes the ring look and the atmosphere.
- `tools/` (board-only): `ring_shots.gd` (native render of the four rings under a palette: `godot --resolution 1280x720 -s tools/ring_shots.gd -- <out_dir> [table|steel_blue|ember_and_ink]`), `ring_codes.gd` + `ring_codes.txt` (save codes placing a fresh character in each ring), `chrome_type_import.js` + `chrome_shoot.sh` (chrome-devtools-axi: open a build, type a code, click Import, screenshot, measure fps; the eval reports "timed out" but completes), `board.py` (generates `.lavish/ring-palette/board.html`; `.lavish/` is untracked).

**Gates run so far:** `--import` clean, unit tests 262/0, headless `--quit-after 3600` (26 s wall, no output at all), web export of the branch succeeds (`build/web`, pck 4.15 MB). Not yet: Chrome load of the branch build and console check, after-screenshots, after-fps.

## The open decision (key=ring-palette)

Lavish board: http://127.0.0.1:4387/session/e9ebb6843fc1e990 (file `.lavish/ring-palette/board.html`). A `lavish-axi poll` was running in this worker; re-run `lavish-axi poll .lavish/ring-palette/board.html` to pick up the answer, or take it from the Firstmate inbox. The board queues one prompt: "Ring palette pick: A|B|C. Toon/outlines: none|banding only|banding and outlines. Notes: ...".

- **A violet dusk** = what is in `scenes/ring_look.gd` now (recommended). Nothing to change.
- **B steel blue / C ember and ink** = the dictionaries in `tools/ring_shots.gd` `PALETTES`; paste the chosen one over `LOOKS` in `scenes/ring_look.gd`, then run `godot --headless -s tests/run.gd -- ring_look` (monotonic brightness/warmth/snow/fog tests must still pass; they do for both as written).
- Toon: recommendation is none. If Travis asks for banding/outlines that is new work (a banded `light()` spatial shader over every material, or inverted hull); scope it with firstmate first.

## Baseline numbers (main, Chrome 1440x900, Apple M3 Pro)

- pck 9.31 MB as main exports today (3.94 MB in #37's PR body; the difference is the committed screenshots, fixed by `docs/.gdignore`).
- fps in the outpost: 120 (display cap) unthrottled; 66.6 at chrome-devtools-axi `emulate --cpu 4`.
- Before screenshots per ring: `/tmp/fm-before_<ring>.png` (may be gone); 960px copies in `.lavish/ring-palette/today_<ring>.jpg`. Re-take with `tools/chrome_shoot.sh http://127.0.0.1:8011/index.html /tmp/fm-before outpost inner_ring ring_one ring_two` after `python3 -m http.server --directory build/before 8011` (build/before = export of main; rebuild it from `main` if missing).

## Remaining steps

1. Get the pick; apply it (above). Collapse nothing else: the table stays data.
2. After build: `godot --headless --import`, tests, `--quit-after 3600`, `--export-release Web build/web/index.html`; serve `build/web` on 8012 and run `tools/chrome_shoot.sh http://127.0.0.1:8012/index.html /tmp/fm-after outpost inner_ring ring_one ring_two` (also prints fps ×1 and ×4 on the outpost shot; check `chrome-devtools-axi console --type error` is empty). Throttled fps must hold ~60: if it drops, first suspect the grade pass (full-screen `hint_screen_texture`) and the 4 omni lights; `MAX_FIRE_LIGHTS` is the knob.
3. Commit the after screenshots under `docs/screenshots/` as JPEGs (`before_<ring>.jpg`, `after_<ring>.jpg`; they no longer bloat the pck).
4. PR: title `feat: ring looks and dusk lighting`, body `Closes #18`, before/after table per ring (raw.githubusercontent URLs on the branch like #37 did), pck 9.31 → 4.15 MB (explain), fps before/after at ×1 and ×4, the chosen palette, and **Decisions taken**: (a) a fire's pool matches its warmth radius exactly (disc edge = FIRE_REACH past the footprint, +0.4 m feather) and the omni light reaches 1.6× that as the landmark; (b) 4 dynamic lights per view, nearest the character, the rest keep the emissive pool and flames; (c) no toon banding or outlines (unless Travis picked them); (d) the aurora is a screen-space band because the 55° camera never sees the sky; (e) docs/.gdignore and the pck fix. No CC-BY assets were added (nothing new in CREDITS.md). Not a draft; wait for CI; `done [at=...]: PR <url>`.
5. Then `resolved [at=<epoch>] [key=ring-palette]: ...` is firstmate's line; do not write it unless the pick clears without a reply.
