# Frostmark roadmap

There are five slices, listed in ship order. Each slice is one PR and has to be playable at the public GitHub Pages link once it merges.
Each section below can be pasted into a GitHub issue as it is. The design these slices build lives in [game-brief.md](game-brief.md).
The slice titles and their order were decided in the grill session. Which system goes into which slice is a proposal, and it can move.

## 1. Walking skeleton: Godot web export and GitHub Pages deploy

**Scope:** Create a Godot 4.5 project that uses the GL Compatibility renderer, with a single placeholder scene.
Export it to the web, and deploy it to GitHub Pages automatically on every merge to main.
Choose single-threaded or threaded export here, given that GitHub Pages can't send the cross-origin isolation headers (see the brief's technical foundation).

**Playable at the link:** Opening the public Pages URL in a desktop browser loads the Godot scene with no console errors, and the next merge to main updates it on its own.

## 2. Click-to-move and rotating camera in a grey-box outpost

**Scope:** Build a grey-box outpost with a gate, plus a character that moves top-down where the player clicks.
Add a camera that rotates around the character.
Put the tick-based simulation in place now, holding all game state in one place, so later slices build on it.

**Playable at the link:** At the Pages URL you can click to walk the character around the grey-box outpost and rotate the camera.

## 3. One full gathering-to-crafting loop

**Scope:** Add one end-to-end chain: gather a resource outside the gate, carry it back, bank it at the stash by crossing the gate, and craft with it at the workbench.
The outpost fire restores warmth, and warmth drains outside the outpost.
Skills level by use, and the browser-local save plus the export code keep progress.

**Playable at the link:** At the Pages URL you can walk out, gather, walk back through the gate, see the haul in the stash, craft an item, and still have your progress after reloading.

## 4. Combat with the triangle

**Scope:** Add tick-based combat with the melee/ranged/magic triangle, enemies that telegraph their next move, and countering by switching style or gear in time.
How the magic side of the triangle works before magic exists is the brief's open question 1, and it gets settled before this slice starts.
Food heals.
Dying keeps your three most valuable items and loses the rest, while the stash stays safe.

**Playable at the link:** At the Pages URL you can fight an enemy that telegraphs, win by countering, heal by eating, and die without losing your stash.

## 5. Ring one and the bandit captain

**Scope:** Build the safe ring (trees, rocks, a fishing hole) and ring one (wolves, bandit archers), with a bandit captain at the edge of ring one guarding the gate to ring two.
All seven skills are in, with smithing capped at the first metal tier, and the wooden, bronze and iron gear tiers show on the character.
This slice completes the first playable.

**Playable at the link:** At the Pages URL a new character can reach and fight the bandit captain in about thirty minutes, using all seven skills along the way.

## Ring-one dungeon

Decided in the dungeons grill ([#39](https://github.com/travism26/frostmark/issues/39)); the design is in the brief's [Dungeons](game-brief.md#dungeons). Specced in [#204](https://github.com/travism26/frostmark/issues/204). Its boss is the great frost bear from the boss fights grill ([#203](https://github.com/travism26/frostmark/issues/203)); the design is in the brief's [Boss fights](game-brief.md#boss-fights).

**Scope:** Add the first gentle dungeon, a pocket off ring one. Its mouth is open from the start and nothing crosses it, and a fire and a death chest stand just inside. Inside is one floor of ring-one enemies in the dark, plus one or two richer nodes, and a boss at the end. Beating the boss opens a way out that sets you down in ring one on the side nearest home. The dungeon is fenced off within the one world grid ([ADR 0001](adr/0001-dungeons-share-the-world-grid.md)) and gets a look of its own in the ring-look table.

**Playable at the link:** At the Pages URL you can walk into the ring-one dungeon, warm up at its fire, fight through to the boss and beat it, then take the way out into ring one. If you die inside, what you lost is waiting in the death chest.
