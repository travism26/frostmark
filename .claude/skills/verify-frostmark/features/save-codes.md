# Save codes

A character is a text code. **Save code** on the Settings tab shows it; **Import code** on the title screen loads it in any browser, refusing a damaged one. The game also saves in the browser at every save point, so a reload offers **Continue**. Test characters are codes too.

## Sub-features

- AC1 `export`: exporting returns a code and changes nothing.
- AC2 `import`: the code loads the identical character in a new game and saves with reason `import_save`.
- AC3 `damaged-code`: a code with one changed character is refused (`save_rejected`) and the state is untouched.
- AC4 `test-code`: the test-mode code loads every skill at 99 and every upgrade built.
- `web-import` (web): pasting a ring code into Import code on the title screen loads that character in game.
- `web-continue` (web): after an import, reloading the page shows Continue above New character, and clicking it loads that character.

## How to get to it (user POV)

- Side panel → **Settings** tab → **Save code**, to copy the code.
- Title screen → paste into **Import a save code** → **Import code**.
- Reload the page: **Continue** on the title screen.

## Driving it with probe.sh and web.sh

Preconditions:

- Probes: `tools/check.sh` passes on this checkout.
- Web: `web.sh serve <sha>` on a commit with a green CI run, `web.sh doctor` clean, and `web.sh stop` run before `serve` if an earlier import should not carry over.

- **Probe, all four.** Run `.claude/skills/verify-frostmark/scripts/probe.sh .claude/skills/verify-frostmark/probes/save_codes.gd`. `PASS save_codes.gd`: an export of about 14k characters with the state unchanged; import ok, `same: true`, saved `import_save`; `bad_code` with one `save_rejected`; levels all 99, upgrades 11 of 11.
- **Title screen.** Run `web.sh open`, then `web.sh shot title`. The screenshot shows Frostmark, New character, Controls and the Import box (no Continue in a fresh profile).
- **Import.** Run `web.sh import ring_one`, then `web.sh shot ring_one`. `imported ring_one` only proves the paste ran; the screenshot is the proof: the warmth and health orbs, the Pack panel, "Ring One" at the lower left. A refused code leaves the title screen up with error text under the Import box.
- **Continue.** Run `web.sh open` again, then `web.sh shot continue-title`. The title screen now has Continue above New character: the import reached the browser save.
- **Continue loads.** Run `web.sh continue` (clicks Continue at (720, 320)), then `web.sh shot continued`. The game is back with the same character: the orbs, "Ring One" at the lower left, the same spot as the import.

## Gotchas

- Typing a code key by key (as `tools/chrome_shoot.sh` does, headed) takes longer than the bridge's 60 s eval timeout in headless Chrome, and the timeout loses the tab. `web.sh import` pastes it in one event instead.
- Sending both Cmd+V and Ctrl+V pastes once and types a stray `v` that breaks the code: `paste_import.js` sends Cmd+V only. Godot's web build maps Cmd+V to paste only on a Mac user agent; on Linux or Windows Chrome the script needs `ctrlKey: true` instead of `metaKey: true`.
- Continue resumes from the last browser save point, not from the moment of the last screenshot: a ring-one import saved at `import_save`, so a fight that went on after it replays (an archer killed after the import stands again).
- Loading any code replaces the browser save. That is why the browser must be the isolated `frostmark-verify` profile.
- Ring codes in `tools/ring_codes.txt` are full codes of the current save version and go stale after item, layout or upgrade edits (they still migrate forward). The short codes and query links are hashed in `scenes/field_kit.gd`; their plaintext seed (`tools/test_codes.local.cfg`) reaches maintainers outside GitHub and is absent on a machine that never got it.
- A one-character change can decode to a different refusal (`bad_code` or `bad_checksum`); AC3 checks the refusal, not its reason.
