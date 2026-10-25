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

## The test-mode code

To check something deep in the rings without playing up to it, load the test-mode character. There are three ways, all giving the same save:

- **Short code:** on the title screen type `PELTKEG7` into **Import code** (case and spaces do not matter).
- **Link:** open <https://travism26.github.io/frostmark/?hearth=tallow> (or `?hearth=tallow` on a local build). The game skips the title screen and loads the character on startup, every time the page loads with that parameter.
- **Full code:** write it to `tools/test_mode_code.txt` (below) and paste the whole file into **Import code**.

To start in ring two instead of the outpost, add `ring=two` to the link: <https://travism26.github.io/frostmark/?hearth=tallow&ring=two> (or `?hearth=tallow&ring=two` on a local build). It is the same character standing just inside the ring-two gate, within reach of the brazier so it starts warming; without `ring=`, or with any other value, the link loads in the outpost as before. The parameter does nothing on its own or beside the build-from-scratch link.

They work on the live site and in a local build. The short code and the link are obscurity, not security: the repo is public, so anyone reading this file can use them, and the game only keeps their sha256 hashes (`scenes/field_kit.gd`) so they do not turn up in a search of the code. Nothing in the game's interface mentions them.

It is an ordinary save code of the current save version, not a cheat: the rules are unchanged, so the character can still freeze, be hit and die. It loads a character in the outpost with:

- every skill at level 99
- steel sword, steel helm, steel body, steel legs and steel pickaxe worn; a steel axe, fishing rod, steel bow, steel staff, 100 arrows, 100 frost shards, 5 cooked char and 3 logs (one field fire) in the pack, 30 kg in all, within the carry limit
- every upgrade built, so the stash has 20 slots, all holding full stacks of every material, food and ammunition
- the captain down and the ring-two gate open, ring two already reached
- both waystones attuned and awake, so `travel` home works from either
- full warmth and health, and the hints off

Loading it replaces the browser save, so export your own code first if you want it back.

`scenes/field_kit.gd` builds it from a new character through `restore()`, so the short code and the link always give a save of the current version. `tools/test_mode_code.gd` writes the same code to the file:

```
godot --headless -s tools/test_mode_code.gd
```

The file is not committed (`.gitignore`), because it changed with every upgrade or layout edit and parallel branches kept conflicting on it. So a merge or rebase never touches it, and a copy written before one is stale: run the command above again after any pull, merge or rebase before pasting it. An older code still migrates forward, but a stale one can miss what changed since (a new skill would load at level 1, for example).

`tests/test_test_mode.gd` builds the code the same way, imports it and checks every point above, that the short code loads the same character, and that `ring=two` loads it in ring two beside the brazier.

## The build-from-scratch code

To build the outpost up by hand (the build moment, the yard pieces, the build sounds and the "You can now build" line), load the build-from-scratch character instead. Two ways, both giving the same save:

- **Short code:** on the title screen type `RIMEKNOT` into **Import code** (case and spaces do not matter).
- **Link:** open <https://travism26.github.io/frostmark/?hearth=kindling> (or `?hearth=kindling` on a local build). Like the test-mode link, it loads the character on every page load with that parameter.

The same note holds: obscurity, not security, only their sha256 hashes are in `scenes/field_kit.gd`, and nothing in the game mentions them. It is an ordinary save of the current version, with the rules unchanged. It loads a new character in the outpost with:

- every skill at its starting level, the starting pack and axe, full warmth and health, and the hints as a new character has them
- nothing built, the captain standing, no ring reached and no waystone attuned
- the stash holding the starting kit and, beside it, every upgrade's cost added up

The summed cost is worked out from `sim/upgrades.gd` each time the code is loaded, so a new or repriced upgrade is covered without touching it. It fills more slots than a new stash has, so this save alone starts with as many stash slots as it fills (26 today rather than 8); the shelves, cellar and vault still add their slots when built. Built in the table's order, every upgrade goes up and the materials run out together.

`tests/test_bare_mode.gd` checks each point and builds every upgrade from it in turn.

## Other codes

`tools/ring_codes.gd` prints a new character standing in each ring (and one in ring one with the warmth run low), for screenshots. Its output is in `tools/ring_codes.txt`.
