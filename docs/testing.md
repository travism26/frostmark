# Testing by hand

## The local gate

Before testing by hand, run `tools/check.sh`. It prints the Godot version, then runs the import, the unit suite and a headless smoke run of the main scene (`--quit-after 3600`), each under a `perl` alarm since macOS has no `timeout` (exit 142 means a step timed out). It exits non-zero if any step fails, if the unit suite logs a `SCRIPT ERROR` (which aborts a test method without failing it), or if the smoke run logs a `SCRIPT ERROR` or `ERROR:` line. The unit runner prints `RUN <file>` before each test file, so a hung run names the file it hung in.

It does not export the web build: CI, on Godot 4.5.1, is the only web-export authority. For the browser check, download the PR's CI artifact (`gh run download <run> -n frostmark-web`) and serve it with `python3 -m http.server`.

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
