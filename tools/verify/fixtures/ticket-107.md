# #107 The gate brings you home safe without banking

## Parent

#101

## What to build

Crossing the outpost gate inward (a **return**) no longer moves anything. It brings you home safe: inside the walls nothing can be lost, but only the stash is safe for good, and whatever stays in the pack rides out on the next trip. The return is still a moment. It shows a "Home safe." banner with what you're carrying, plays the cue that banking used to play, saves the game, and names any upgrade you can now afford. Putting things away is done with Deposit haul (#106).

The `banked` event is replaced by `returned` `{items, newly_affordable}`. `items` is the merged pack contents at the moment of return, which can be empty. `newly_affordable` lists the upgrades buildable from the stash plus the pack inside the walls that weren't buildable from the stash alone just before. The gate's stash-full overflow goes away.

## Acceptance criteria

- [ ] Walking in through the gate leaves the pack and stash exactly as they were. Worn equipment is untouched.
- [ ] Each return emits exactly one `returned` with the pack contents, then a save with reason "gate". An empty pack still returns and saves. No `banked` event is ever emitted.
- [ ] `newly_affordable` names an upgrade only once the pack's contents make it buildable.
- [ ] GameRoot's banner text for a return reads "Home safe." plus what's in the pack, and adds the "You can now build: …" line only when `newly_affordable` isn't empty. The existing bank-line tests are reworked for it.
- [ ] The audio cue that played on `banked` plays on `returned`.
- [ ] Guide: the bank step reads "Walk back in through the gate. Inside the walls nothing can be lost." and completes on a `returned` with items, not on an empty one. The craft step reads "Click the workbench and make a wooden pickaxe." and completes when the pickaxe is made from pack logs.
- [ ] The play bot deposits haul instead of re-withdrawing its kit each trip. The balance test passes, and the balance doc records the re-measured route.
- [ ] The brief's pillar reads "Crossing the gate brings you home safe: nothing can be lost inside the walls. Only the stash is safe for good; whatever stays in your pack rides out with you."
- [ ] README step 1 and the simulation doc's gate section describe the new behaviour.
- [ ] Existing save fixtures load unchanged, with no version bump. A save made mid-trip keeps its pack on return.

## Blocked by

- #106

