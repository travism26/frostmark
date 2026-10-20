# Testing by hand

## The test-mode code

To check something deep in the rings without playing up to it, load the test-mode character. There are three ways, all giving the same save:

- **Short code:** on the title screen type `PELTKEG7` into **Import code** (case and spaces do not matter).
- **Link:** open <https://travism26.github.io/frostmark/?hearth=tallow> (or `?hearth=tallow` on a local build). The game skips the title screen and loads the character on startup, every time the page loads with that parameter.
- **Full code:** paste the whole of `tools/test_mode_code.txt` into **Import code**.

To start in ring two instead of the outpost, add `ring=two` to the link: <https://travism26.github.io/frostmark/?hearth=tallow&ring=two> (or `?hearth=tallow&ring=two` on a local build). It is the same character standing just inside the ring-two gate, within reach of the brazier so it starts warming; without `ring=`, or with any other value, the link loads in the outpost as before. The parameter does nothing on its own or beside the build-from-scratch link.

They work on the live site and in a local build. The short code and the link are obscurity, not security: the repo is public, so anyone reading this file can use them, and the game only keeps their sha256 hashes (`scenes/field_kit.gd`) so they do not turn up in a search of the code. Nothing in the game's interface mentions them.

It is an ordinary save code of the current save version, not a cheat: the rules are unchanged, so the character can still freeze, be hit and die. It loads a character in the outpost with:

- every skill at level 99
- steel sword, steel helm, steel body, steel legs and steel pickaxe worn; a steel axe, fishing rod, steel bow, steel staff, 100 arrows, 100 frost shards, 5 cooked char and 3 logs (one field fire) in the pack, at the carry limit
- every upgrade built, so the stash has 20 slots, all holding full stacks of every material, food and ammunition
- the captain down and the ring-two gate open, ring two already reached
- both waystones attuned and awake, so `travel` home works from either
- full warmth and health, and the hints off

Loading it replaces the browser save, so export your own code first if you want it back.

`scenes/field_kit.gd` builds it from a new character through `restore()`, so the short code and the link always give a save of the current version. `tools/test_mode_code.gd` writes the same code to the file:

```
godot --headless -s tools/test_mode_code.gd
```

`tests/test_test_mode.gd` imports the file and checks every point above, that the short code loads the same character, and that `ring=two` loads it in ring two beside the brazier. An older code still migrates forward, but regenerate it when the save version moves on or a test there fails (a new skill would load at level 1, for example).

## The build-from-scratch code

To build the outpost up by hand (the build moment, the yard pieces, the build sounds and the "You can now build" line), load the build-from-scratch character instead. Two ways, both giving the same save:

- **Short code:** on the title screen type `RIMEKNOT` into **Import code** (case and spaces do not matter).
- **Link:** open <https://travism26.github.io/frostmark/?hearth=kindling> (or `?hearth=kindling` on a local build). Like the test-mode link, it loads the character on every page load with that parameter.

The same note holds: obscurity, not security, only their sha256 hashes are in `scenes/field_kit.gd`, and nothing in the game mentions them. It is an ordinary save of the current version, with the rules unchanged. It loads a new character in the outpost with:

- every skill at its starting level, the starting pack and axe, full warmth and health, and the hints as a new character has them
- nothing built, the captain standing, no ring reached and no waystone attuned
- the stash holding the starting kit and, beside it, every upgrade's cost added up

The summed cost is worked out from `sim/upgrades.gd` each time the code is loaded, so a new or repriced upgrade is covered without touching it. It fills more slots than a new stash has, so this save alone starts with as many stash slots as it fills (23 today rather than 8); the shelves, cellar and vault still add their slots when built. Built in the table's order, every upgrade goes up and the materials run out together.

`tests/test_bare_mode.gd` checks each point and builds every upgrade from it in turn.

## Other codes

`tools/ring_codes.gd` prints a new character standing in each ring (and one in ring one with the warmth run low), for screenshots. Its output is in `tools/ring_codes.txt`.
