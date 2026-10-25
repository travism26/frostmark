# Testing by hand

## The local gate

Before testing by hand, run `tools/check.sh`. It prints the Godot version, then runs the import, the unit suite and a headless smoke run of the main scene (`--quit-after 3600`), each under a `perl` alarm since macOS has no `timeout` (exit 142 means a step timed out). It exits non-zero if any step fails, if the unit suite logs a `SCRIPT ERROR` (which aborts a test method without failing it), or if the smoke run logs a `SCRIPT ERROR` or `ERROR:` line. The unit runner prints `RUN <file>` before each test file, so a hung run names the file it hung in.

It does not export the web build: CI, on Godot 4.5.1, is the only web-export authority. For the browser check, download the PR's CI artifact (`gh run download <run> -n frostmark-web`) and serve it with `python3 -m http.server`.

## Verify

`tools/verify/run.sh <ticket>` checks a commit against its ticket's acceptance criteria with a verifier that never sees the change (spec #144). Run it on a clean tree at the commit you'll push, after `tools/check.sh` passes:

```
tools/verify/run.sh 140
```

It fetches the ticket from GitHub by number and lints it. A ticket with no `## Acceptance criteria` checklist is INCONCLUSIVE. One whose criteria all end in `(look)` or `(playtest)` is a no-op PASS. Neither starts a verifier. Otherwise it exports the commit and its base (`git merge-base origin/main <sha>`) with `git archive` and imports both. Then:

- **The first run for a ticket** starts the verifier: a headless `claude --print --model sonnet` session, from a temp folder outside any repo, with no `GIT_*` variables. It can read the head copy and its work folder, write only its work folder, and run only `drive <probe.gd>` (`tools/verify/verifier-brief.md` is its brief). It writes a probe for each criterion, drives it on head and base, and grades the criteria in `grades.json`. It is capped at 15 minutes and 12 drive calls. Hitting either cap makes the run INCONCLUSIVE. A session that ends within its caps freezes its probes for the ticket.
- **A later run**, after a fix or on a new SHA, re-drives the frozen probes in seconds with no session. A fresh verifier starts only when a frozen probe errors on head (a lint refusal, a `SCRIPT ERROR`, no `PROBE` line), when the criteria have been edited, or with `--fresh`.

Either way it reads CI's conclusion for the head SHA and takes the test guard from the diff of `tests/`. Then it writes the verdict (`tools/verify/verdict.gd`) and prints the report, `verdict: <word>` and `record: <path>`.

`tools/verify/run.sh <ticket> --replay <record>` is the merge-time check. It re-drives that record's probes with its grades at its head SHA and recomputes the verdict in a new record, with no session. CI's conclusion is the only input it reads again. It prints whether it reproduces the record's verdict. It refuses when the head is another SHA or the ticket's criteria have been edited since; ticking a checkbox is not an edit.

**Records** live in `$FROSTMARK_VERIFY_HOME/<ticket>/<sha>-<stamp>/`. Firstmate sets that to a folder outside every worktree, and it defaults to `${TMPDIR:-/tmp/}frostmark-verify-home`. A run always makes a new folder and never touches an earlier one. A record holds:

- the ticket (`ticket.md`) and its criteria hash (`criteria.json`);
- the probes and the raw head and base output (`probes/`, `head.log`, `base.log`, `drive/`);
- `grades.json`, `verdict.json` and `report.md`;
- what the run read (`inputs.json`, `ci.json`, `tests.diff`);
- for a session, the prompt, its transcript and `session.json`, which notes the session's cwd, model, environment, caps, wall time and tokens.

`<ticket>/frozen` names the record whose probes are frozen. Nothing from a record goes in the PR.

**Verdicts:**

- **PASS**: every graded criterion passed on its evidence. For a `sim` or `data` criterion, that's a `PROBE` line that passed on head; for a `doc` criterion, the quote found at its `path:line`; for a `gate` criterion, CI's success for the head SHA. A `new` criterion's probe must also fail on base. `(look)` and `(playtest)` criteria are listed as residue for a person.
- **FAIL**: a probe saw the criterion broken on head. The report names the criterion and what the probe saw. Fix the game, commit and run `run.sh` again; it re-drives the same probes. If you believe a probe misreads the ticket, report `needs-decision` naming the probe and the criterion. Don't argue it into passing.
- **INCONCLUSIVE**: the harness is short of something, not proof the code is wrong. Some causes: a criterion with no evidence, a `new` probe that also passes on base, a session that hit a cap, or a `gate` criterion before CI has run on the SHA (run again once CI is green: with frozen probes that's seconds).
- **FLAG**: a person should look. The verifier flagged a ticket contradiction, an uninterpretable criterion, suspected gaming or an oracle dispute, or the script raised one of its own flags: a third non-PASS run for the ticket; the test guard (the change deletes a test file under `tests/`, or removes more `assert_` lines than it adds there); or a sudden PASS on a probe that failed before with nothing changed under `sim/` or `scenes/`.

`tools/verify/selftest.sh` proves `drive`, and `tools/verify/selftest_run.sh` proves `run.sh` with stand-ins for `gh` and `claude`, so it spends no tokens. Run both on any PR that touches `tools/verify/`.

`tools/verify/prove.sh` proves the whole harness, the verifier included, against a planted bug. Run it on a PR that touches the verifier brief (`tools/verify/verifier-brief.md`), `drive`, the probe base (`tools/verify/probe_base.gd`) or the verdict rules (`tools/verify/verdict.gd`), on that PR's head; no other PR needs it. It starts two real verifier sessions, so it costs a few minutes and about 100k tokens a session. Its fixed case is ticket #107 at `c40cacb`, the commit that shipped it, with the ticket's text from `tools/verify/fixtures/ticket-107.md` rather than GitHub. It runs the two selftests first, then:

- checks that `tools/verify/fixtures/plant-107.patch`, applied to an export of `c40cacb`, leaves that copy's own unit suite passing as the shipped copy's does. The patch skips the gate's save on an empty-pack return and edits the matching test in `tests/test_sim_gate.gd`, so only the verifier can catch it;
- runs `run.sh 107` twice at once, each with its own `FROSTMARK_VERIFY_HOME` (`$FROSTMARK_VERIFY_HOME/prove/<stamp>/shipped` and `planted`), so each run has its own record and its own session. Run 1 verifies the commit as shipped and must PASS. Run 2 applies the patch to its head copy only (`VERIFY_HEAD_PATCH`, never the repo) and must FAIL, with AC2 failing on a probe that saw no `saved` after the empty-pack return. Its verdict carries the patch's hash as `head_patch`;
- checks that neither session saw the patch or the other run's record.

It prints each run's wall time and tokens and the two record paths, and exits non-zero unless every point holds. Put the two record paths in that PR's record, beside its own verify record.

## The test codes

Four test characters load a ready-made save, so something deep in the game can be checked without playing up to it: the test-mode character, the same character in ring two, the build-from-scratch character and the all-gear character. Each but the ring-two one has a **short code**, typed on the title screen into **Import code** (case and surrounding spaces do not matter), and a **link**, a `?name=value` parameter on the page (<https://travism26.github.io/frostmark/> or a local build) that skips the title screen and loads the character on startup, every time the page loads with it. Both work on the live site and in a local build.

The repo holds no short code or link in plain text, not here and not in the tests. `scenes/field_kit.gd` keeps only their sha256 hashes, and nothing in the game's interface mentions them. That is obscurity, not security: codes already in git history stay findable in earlier commits of this file and of `tests/`, so taking them out of the current tree keeps them out of code search but does not unpublish them.

Each is an ordinary save code of the current save version, not a cheat: the rules are unchanged, so the character can still freeze, be hit and die. Loading one replaces the browser save, so export your own code first if you want it back.

### The code map

`tools/test_codes.gd` writes the map of every test code to `tools/test_codes.local.md`:

```
godot --headless -s tools/test_codes.gd
```

The map has an entry for each test character: test mode, test mode in ring two, build from scratch, all gear, and each ring code from `tools/ring_codes.gd`. An entry gives the short code and link where the character has them, a summary of what it loads, read back from the save itself (for the all-gear character, how many gear items and from which sets or tiers), and the full save code to paste into **Import code**.

The plaintext short codes and links come from a seed, `tools/test_codes.local.cfg`, with one `name = code` line each: `test_mode_short`, `test_mode_query`, `bare_short`, `bare_query`, `gear_short` and `gear_query` (a query line holds the whole `name=value` pair). The tool checks every seed line against its hash in `scenes/field_kit.gd`. A line that does not match, or names no test code, is refused by name and no map is written. A code missing from the seed is written as "not known on this machine" beside its hash. The seed reaches a maintainer outside GitHub.

Neither file is committed (`.gitignore`). The save codes change with every upgrade, layout or item edit, so run the command again after any pull, merge or rebase before using a full code from the map. An older code still migrates forward, but a stale one can miss what changed since (a new skill would load at level 1, for example). The short codes and links are always built fresh by the game, so they never go stale.

`tools/test_mode_code.gd` still writes the test-mode full code alone to `tools/test_mode_code.txt` (also not committed):

```
godot --headless -s tools/test_mode_code.gd
```

### The test-mode character

It loads a character in the outpost with:

- every skill at level 99
- steel sword, steel helm, steel body, steel legs and steel pickaxe worn; a steel axe, fishing rod, steel bow, steel staff, 100 arrows, 100 frost shards, 5 cooked char and 3 logs (one field fire) in the pack, 30 kg in all, within the carry limit
- every upgrade built, so the stash has 20 slots, all holding full stacks of every material, food and ammunition
- the captain down and the ring-two gate open, ring two already reached
- both waystones attuned and awake, so `travel` home works from either
- full warmth and health, and the hints off

To start in ring two instead of the outpost, add `ring=two` to its link (the map gives the whole link). It is the same character standing just inside the ring-two gate, within reach of the brazier so it starts warming; without `ring=`, or with any other value, the link loads in the outpost as before. The parameter does nothing on its own or beside another character's link.

`scenes/field_kit.gd` builds it from a new character through `restore()`, so the short code and the link always give a save of the current version. `tests/test_test_mode.gd` builds the code the same way, imports it and checks every point above, that both stored hashes load the same character, that typed text is matched without its case or surrounding spaces, and that the ring-two spot stands it beside the brazier.

### The build-from-scratch character

To build the outpost up by hand (the build moment, the yard pieces, the build sounds and the "You can now build" line), load the build-from-scratch character. It loads a new character in the outpost with:

- every skill at its starting level, the starting pack and axe, full warmth and health, and the hints as a new character has them
- nothing built, the captain standing, no ring reached and no waystone attuned
- the stash holding the starting kit and, beside it, every upgrade's cost added up

The summed cost is worked out from `sim/upgrades.gd` each time the code is loaded, so a new or repriced upgrade is covered without touching it. It fills more slots than a new stash has, so this save alone starts with as many stash slots as it fills (26 today rather than 8); the shelves, cellar and vault still add their slots when built. Built in the table's order, every upgrade goes up and the materials run out together.

`tests/test_bare_mode.gd` checks each point and builds every upgrade from it in turn.

### The all-gear character

To try gear on in game, load the all-gear character. It is the test-mode character in the outpost (every skill at 99, the same worn and carried kit, every upgrade built, the captain down, ring two reached, both waystones attuned, full warmth and health, hints off) with a different stash:

- one of every item in `ItemTable.ITEMS` that has an equipment slot (weapons, tools, armour, and any new slot's gear), in the table's order so a set's pieces sit side by side
- then a full stack of each ammunition a weapon fires (arrows and frost shards today), so every bow and staff can fire

The list is read from the item table each time the code is built, so gear added later shows up without touching `scenes/field_kit.gd`. Like the build-from-scratch stash, it starts with as many slots as it fills when that is more than the built stash has (64 today).

`tests/test_gear_mode.gd` builds the expected stash from the item table and compares it with the imported save, and checks that everything else matches the test-mode save.

## Other codes

`tools/ring_codes.gd` prints a new character standing in each ring (and one in ring one with the warmth run low), for screenshots. Its output is in `tools/ring_codes.txt`, and the code map lists the same codes.
