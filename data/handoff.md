# Handoff: #19 UI round two (branch fm/frostmark-ui-panel)

Remove this file before the PR. Status file: /Users/rickjms/code/firstmate/state/frostmark-ui-panel.status
(open needs-decision key=ui-board; a `resolved [key=ui-board]` line closes it when the pick lands).

## Done (committed, pushed, tests 269/269 green, headless smoke clean)
- scenes/icon_table.gd + tests/test_icons.gd (seam 2), assets/ui/game_icons/<author>/*.svg (import scale 0.125, mipmaps), credits rows in docs/assets/CREDITS.md.
- scenes/ui_settings.gd (ui_scale, reduced_motion in user://frostmark_settings.cfg section [ui]; `UiSettings.reduced_motion_on()` is the accessor #17 uses). AudioSettings.save_to now preserves other sections.
- scenes/ui_tooltip.gd (UiTooltip.item / .skill; UiTooltip.Host button builds the tip on hover).
- scenes/hud.gd rewritten: side panel (tabs Pack/Equipment/Skills/Upgrades/Settings), Orb inner class, Light fire under the orbs, stash/craft panels top-left, settings tab emits sound_changed / ui_changed. scenes/sound_panel.gd deleted; main.tscn Title and Hint labels removed; Status label at the bottom-left.
- scenes/ui_theme.gd: three frame styles (UiTheme.FRAME_TIMBER/FROST/STONE, `set_frame_style`), procedural 9-slice frames, badge(), Inter buttons, checkbox icons.
- scenes/combat_cues.gd: ground ring on telegraph/stance, swing arc on hit/missed; game_root.gd wires it, hover-only labels (meta "hover_label" on click bodies; engaged enemies pinned), UiSettings applied via window content_scale_factor.
- tools/ui_shots.gd renders the board shots (`godot --resolution 1280x720 -s tools/ui_shots.gd -- <dir> [style]`). Board: .lavish/ui-board/board.html (not committed), Lavish url http://127.0.0.1:4387/session/b881746d2eff3024.
- Docs: README, docs/simulation.md updated.

## Waiting
- Travis's pick on the board: frame A/B/C (timber recommended) + four questions (minimap, counter text, kept-on-death mark, high contrast; "neither/ring only/not now/not now" recommended). Poll: `lavish-axi poll .lavish/ui-board/board.html`. Firstmate may relay via the inbox instead.

## After the pick
1. Hardcode the chosen frame in ui_theme.gd (`frame_style`), delete the other two branches of `_frame_image`, drop `set_frame_style` and FRAME_STYLES (tools/ui_shots.gd can then drop its style loop or be deleted). Apply any board notes.
2. Gate: `godot --headless --import`; `godot --headless -s tests/run.gd`; 60 s smoke `godot --headless --quit-after 7200` (check no ERROR/WARNING); web export `godot --headless --export-release Web build/web/index.html`; serve and load in Chrome, no console errors.
3. Measure once: baseline build of main is exported at /tmp/fm-base-web (pck 4,143,836 bytes). The first chrome_shoot attempt failed ("No page is currently selected"): open one page with `chrome-devtools-axi open <url>` first, then `tools/chrome_shoot.sh http://127.0.0.1:8012/index.html /tmp/fm-before/before outpost inner_ring ring_one ring_two` for main (serve /tmp/fm-base-web on 8012) and the same for build/web on another port for after. Report fps x1/x4 as measured. Screenshots to docs/screenshots/ (docs/.gdignore keeps them out of the pck; do not commit .import sidecars for them).
4. PR: title `feat: RuneScape-style side panel, orbs, icons and combat cues`, body `Closes #19`, before/after screenshots, pck and fps before/after, "Decisions taken" answering the four questions per the pick, asset rule note (game-icons CC BY 3.0 credited; no raster art). `gh-axi pr create`, confirm `draft: no`, wait for CI, append `done [at=<epoch>]: PR <url>`.
5. Rebase onto origin/main first if siblings (#16/#20, #17) merged; keep both sides.

## Known rough edges to consider
- Telegraph text over the enemy and its pinned name label can overlap in a fight (both kept on purpose; the ring is the primary cue).
- Reduced motion is stored and exposed but nothing on this branch reads it yet (screen shake and frost pulse belong to #17).
