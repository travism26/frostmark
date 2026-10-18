# Testing by hand

## The test-mode code

To check something deep in the rings without playing up to it, import the test-mode code: on the title screen choose **Import code** and paste the whole of `tools/test_mode_code.txt`. It works on the live site and in a local build.

It is an ordinary save code of the current save version, not a cheat: the rules are unchanged, so the character can still freeze, be hit and die. It loads a character in the outpost with:

- every skill at level 99
- steel sword, steel armour and steel pickaxe worn; a steel axe, fishing rod, steel bow, steel staff, 100 arrows, 100 frost shards and 5 cooked char in the pack, under the carry limit
- every upgrade built, so the stash has 16 slots, all holding full stacks of every material, food and ammunition
- the captain down and the ring-two gate open, ring two already reached
- both waystones attuned and awake, so `travel` home works from either
- full warmth and health, and the hints off

Importing replaces the browser save, so export your own code first if you want it back.

`tools/test_mode_code.gd` builds it from a new character through `restore()` and writes the file:

```
godot --headless -s tools/test_mode_code.gd
```

`tests/test_test_mode.gd` imports the file and checks every point above. An older code still migrates forward, but regenerate it when the save version moves on or a test there fails (a new skill would load at level 1, for example).

## Other codes

`tools/ring_codes.gd` prints a new character standing in each ring (and one in ring one with the warmth run low), for screenshots. Its output is in `tools/ring_codes.txt`.
