---
name: verify-frostmark
description: Drive Frostmark (the browser extraction RPG in this repo) to prove a feature works, the way a player would. The simulation through headless probes for rules (gather, return, craft, build, fight, rings, travel, save codes), and CI's web build in an isolated headless Chrome for the screen (title, import, HUD, Continue). Use to check a change in the real game before a PR, to reproduce a player-facing bug, or when maintaining features/. Not the ticket grader; that is tools/verify/run.sh.
---

# Verify Frostmark

Frostmark is a Godot 4.5 game that ships as a web build. Two surfaces, in this order:

1. **The simulation** (`sim/`), which owns every rule. A player's click is a `sim.command()`; the game is `step()` ticks and the events they emit (`docs/simulation.md`). Drive it with probes: GDScript files that play it the way the presentation does and print `PROBE` lines. Fast (seconds), deterministic, and covers uncommitted changes.
2. **The web build** (`scenes/` on a canvas), for what only the screen proves: the title screen, Import code, the HUD and panels, the browser save and Continue. Drive it with `scripts/web.sh`, on CI's build of a pushed commit (there is no local web export: local Godot is 4.7, the project and its export templates are 4.5.1).

`tools/verify/run.sh <ticket>` is a different tool: a blind grader of one ticket's acceptance criteria (`docs/testing.md`). This skill reuses its probe base and lint, so a probe written here can be handed to that verifier as a recipe.

Read `features/README.md`, then the feature file for what you are checking.

## Launch

The simulation needs no server. `probe.sh` copies the checkout (tracked and untracked-but-not-ignored files) to a temp folder outside the repo, imports it, and runs each probe there:

```sh
.claude/skills/verify-frostmark/scripts/probe.sh .claude/skills/verify-frostmark/probes/gather_return.gd
```

Ready means it printed `PASS|FAIL|ERROR <probe>` lines and `evidence: <dir>`. About 5 s for the import, then about 1 s per probe. Nothing is left running.

The web build needs a pushed commit with a green CI run (the `frostmark-web` artifact):

```sh
.claude/skills/verify-frostmark/scripts/web.sh serve [sha]     # default HEAD
```

It downloads the artifact once (cached), serves it on a free port on 127.0.0.1 and prints `url: http://127.0.0.1:<port>/index.html (build <sha7>, pid <pid>)` only when `index.html` and `index.pck` answer. A new commit's CI takes a few minutes; `serve` refuses with "no successful CI run" until then. To check a branch's head: push it, wait for CI, `serve <sha>`.

## Doctor

Run it before the first browser drive, after any drive that did something surprising, and whenever anything looks off:

```sh
.claude/skills/verify-frostmark/scripts/web.sh doctor
```

It checks, read-only: the server pid is alive, it owns the port, `index.html` answers, which build and CI run it serves (and says so if HEAD has moved on), and that the browser session is the isolated `frostmark-verify` one. Exit 1 means do not drive; `stop` and `serve` again.

For probes, `tools/check.sh` is the doctor: it prints the Godot on the PATH and its version and runs the unit suite. A probe ERROR on code that `check.sh` passes is the probe's fault.

## Drive

### Probes

A probe extends `res://tools/verify/probe_base.gd`, overrides `run()`, and grades with `grade("AC<n>", ok, observed)`. In a feature probe, `AC<n>` is the numbered check in that probe's header comment and the feature file's Sub-features. The lint (`tools/verify/lint.gd`) refuses anything that loads outside `res://sim/`, `res://scenes/`, `res://tests/sim_helpers.gd`, `res://tests/play_bot.gd` and `res://tests/fixtures/`, or touches files or processes.

- Play it as a player: `sim.command(Vocab.CROSS_GATE, {})`, `Vocab.GATHER {object_id}`, `INTERACT`, `ATTACK`, `TRAVEL`, `SMITH`, `BUILD`, `DEPOSIT_HAUL`, `IMPORT_SAVE`, then step with `H.run(sim, n)` / `H.run_until_idle(sim, cap)` and read events with `H.of_kind` / `H.where`. Object ids are in `docs/simulation.md` (The world as data).
- To reach a deep state, import a test character the way a player pastes a code: `sim.command(Vocab.IMPORT_SAVE, {"code": FieldKit.code()})` for test mode in the outpost, `FieldKit.code(null, FieldKit.RING_SPOTS["two"|"three"|"dungeon"])` for its `ring=` spots, `FieldKit.bare_code()` and `FieldKit.gear_code()` for the other two (`docs/testing.md`, The test codes).
- `H.set_pack`, `H.place`, `H.patch` (all `restore()`) only arrange a start. Never use them to skip the step being proved.
- Every wait has a tick cap; the alarm kills a probe after 60 s.

Run several at once: `probe.sh probes/a.gd probes/b.gd`. Write a new probe in `probes/` when you map a feature, or anywhere for a one-off check.

### Web build

Godot draws everything on one `<canvas>`: there are no DOM handles, so input is mouse and key events at fixed coordinates in a 1440x900 viewport (`open` sets it). Use the helpers rather than raw coordinates where one exists:

```sh
W=.claude/skills/verify-frostmark/scripts/web.sh
$W open                    # the title screen (open '?<query>' for a test-code link from the code map)
$W shot title              # screenshot + console errors into the evidence folder
$W import ring_one         # paste tools/ring_codes.txt's ring_one code into Import code, click it
$W import --file <path>    # the same for any save code in a file
$W shot ring_one
$W open; $W continue       # reload, then click Continue (needs a browser save)
$W eval '<js>'             # anything else: dispatch canvas events, as scripts/paste_import.js does
```

Ring codes in `tools/ring_codes.txt`: `outpost`, `inner_ring`, `ring_one`, `ring_two`, `ring_three`, `dungeon_mouth`, `ring_one_dungeon`, `ring_one_cold`, `ring_one_dungeon_boss`. The title screen at 1440x900: the Import code box is at (720, 560) and its button at (720, 650); a saved character adds Continue at (720, 320) above New character and moves both down 30 px, still inside them. `paste_import.js` pastes with Cmd+V, which Godot's web build treats as paste only on a Mac user agent; on Linux or Windows Chrome change it to Ctrl+V (`ctrlKey`). In game, the side panel's tabs are icons along its top (Pack, Equipment, Skills, Upgrades, Settings, from x ≈ 1140 to 1377 at y ≈ 100); world clicks depend on the camera, so prove world rules with probes, not clicks.

## Evidence

Proof standards:

- Exercise the real user path: commands a click makes, a code pasted into Import code. Not internal setters, not `restore()` standing in for the step under test.
- Capture the action and the resulting state: a probe's `observed` carries the command result and the events, not only the end value. On the web, shoot before and after.
- Check side effects, not only what is visible: the `saved` event and its reason in probes; Continue on a reloaded title screen for the browser save.
- No mocks. The probe base strips autoloads so nothing writes to disk; that is the only stand-in.
- A FAIL is a finding. Never loosen a check to make it pass; write what is missing in the feature's Gotchas.

Where it goes (it survives cleanup):

- probes: `$FROSTMARK_VERIFY_HOME/features/<UTC stamp>-<sha7>[-dirty]/`, holding `tree.txt` (commit, status, diff hash), each probe as run, its full `.log` and `.rc`, and `summary.txt`;
- web: `$FROSTMARK_VERIFY_HOME/web/evidence/<sha7>/<name>.png` and `<name>.console.txt`.

`FROSTMARK_VERIFY_HOME` defaults to `${TMPDIR:-/tmp/}frostmark-verify-home`, as for `tools/verify/run.sh`. Quote the evidence paths in the PR or the report.

## Cleanup

```sh
.claude/skills/verify-frostmark/scripts/web.sh stop
```

It kills the server only if its pid still owns the recorded port, and stops the `frostmark-verify` browser session. Never kill by process name: other chrome-devtools-mcp bridges on this machine belong to other sessions. Never run bare `chrome-devtools-axi` for this skill; without `CHROME_DEVTOOLS_AXI_SESSION=frostmark-verify` it starts the default session's bridge, which `stop` does not touch. If you did, `chrome-devtools-axi stop` (default session) stops that one.

`probe.sh` deletes its copy on exit. Cleanup never removes `$FROSTMARK_VERIFY_HOME/features/` or `web/evidence/`; the cached builds in `web/<sha>/` may be deleted by hand.

Run cleanup after every failed attempt too, then `doctor` before driving again.

## Isolation

- The browser is `chrome-devtools-axi`'s isolated, headless Chrome under the session `frostmark-verify`: a throwaway profile, never the user's Chrome. Loading any code replaces the browser save, so never drive the user's browser or the live site's save. `web.sh` unsets `CHROME_DEVTOOLS_AXI_AUTO_CONNECT`, `_USER_DATA_DIR` and `_BROWSER_URL`.
- One `serve` per `FROSTMARK_VERIFY_HOME`: `serve` refuses while one runs. For a second at once, set another `FROSTMARK_VERIFY_HOME` (the browser session name is shared, so drive one at a time).
- Probes run in their own temp copies and can run side by side.

## Helpers

All in `.claude/skills/verify-frostmark/scripts/`; the shell scripts are executable, usage in each header:

- `probe.sh <probe.gd>...`: run probes on a copy of the checkout. Exit 0 only when every probe passed every check.
- `web.sh fetch|serve|doctor|open|import|continue|shot|eval|stop`: the web build and its browser. `continue` clicks Continue on the title screen.
- `paste_import.js`: the canvas paste `web.sh import` runs (Cmd+V, Mac only); edit it if the title screen's layout changes.
