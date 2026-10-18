# World dressing

What stands on the ground in each ring, and why. Decided in the graphics grill ([#35](https://github.com/travism26/frostmark/issues/35)), specified in [#40](https://github.com/travism26/frostmark/issues/40) and built in #16 and #20. Colour, fog, snow and wind per ring come from the ring-look table (`scenes/ring_look.gd`); what stands on the ground comes from the dressing table (`scenes/ring_dressing.gd`) and, in the yard, from the yard-look table (`scenes/yard_look.gd`); the meshes are built by `scenes/world_dressing.gd` and `scenes/ruin_kit.gd`. None of it has collision or changes the world definition: dressing is presentation, and a path may pass through it.

## One look per ring

| Ring | Ground and clutter | Why |
|------|--------------------|-----|
| Outpost | Trodden earth and snow, firewood stacks, planks, barrels and crates, banners on the north wall, a fence by the tent | Lived-in and warm; nothing inside the walls is dangerous |
| Safe ring | Pale snow, flat drifts, sparse snow-capped small pines at the edge, rocks, logs, a frozen rim around the fishing hole | Open, with clear sight lines back to the palisade |
| Ring one | Grey-blue snow, deeper drifts, dead trees across the ring and tall pines from 38 m out, wolf dens and bandit camps | Tighter and darker: wolf and bandit country |
| Ring two | Blue-black snow, rubble and ice shards, a few dead trees, a frozen lake under the deep holes, the ruins | The most dangerous place there is |

The snowfield is painted by ring: the ring look's `snow_tone` holds out to each ring's edge and steps to the next across a 2.5 m band, so the ground itself says where one ring ends. The look that follows the character (sun, fog, grade) still blends over 8 m.

## Boundaries and landmarks

- **The safe ring's edge** (24 m) is lined with rough standing stones every 6 m, with two pennant posts in the outpost's timber where the road south crosses it. Rough, uncut stone: the outpost's own markers.
- **The gate to ring two** is flanked on the far side by two carved standing stones in the ruins' hand.
- **One landmark per compass direction per ring**, so a route home can be planned without a minimap:

| Ring | North | East | South | West |
|------|-------|------|-------|------|
| Safe ring | A fallen pine | A split rock | A cairn by the road | A dead giant |
| Ring one | A frozen waterfall down the north cliff | A fallen giant pine past the iron | The caravan wreck on the road to the gate | A ruined watch post |
| Ring two | A collapsed tower in the gate yard | A fallen arch over the east gap in the outer wall | A ring of old stones around the waystone | A spire of ice on the frozen lake |

Every landmark's foot is reachable by click-to-move (`tests/test_dressing.gd` routes to each), and every one stands where paths rarely run.

## The yard: upgrades you can see

What the outpost has built stands in its yard, specified in [#47](https://github.com/travism26/frostmark/issues/47). The yard-look table (`scenes/yard_look.gd`) declares each upgrade's look as data by its id: its upgrade line and step, the spot it builds in, and the kit models and hand-made meshes it is assembled from. A pure function maps the list of built upgrades to the pieces to draw; WorldDressing builds them and GameRoot redraws them whenever the list changes, so a loaded save shows its yard with nothing extra saved. An unbuilt upgrade draws nothing. Like the rest of the dressing, a piece has no collision.

| Upgrade | Spot | Piece |
|---------|------|-------|
| Stash shelves | The stash corner, along the west wall south of the stash | A timber shelf rack with crates and a keg on its boards |

A later step of a line builds beside the earlier step in the same spot. Every piece stays inside the palisade and clear of the stations, the tent and the gate path (`tests/test_yard_look.gd`), and every piece's materials are sampled in the shader warm-up, built or not. `tools/spot_shots.gd` shows a spot with upgrades built.

## The ruin kit

Eight hand-made, flat-shaded pieces in one material language: coursed cut stone in the ring's `stone` colour, dark joints, snow on every top. Broken wall segments and pillars replace ring two's boxes in the same footprints, so collision and pathing are untouched. The collapsed tower base, the fallen arch, cairns, standing stones (rough or carved), the snapped caravan wagon and the frozen campfire ring dress the rings. The waystones are carved standing stones from the same kit, with frost runes and a cold light that wake when the outpost wakes them.

## Camps and dens

Bandit camps (a tent, a cold fire ring, crates, a bit of fence) and wolf dens (a rock pile with bones at its mouth) are placed by the sim's own enemy packs, read from the world definition, so a camp always marks where its archers really stand. No dressed fire gives warmth; the fires that do are the sim's.

## What the ruins imply (proposed, awaiting confirmation)

Told only through arrangement, never in dialogue. Later dressing should stay consistent with these:

1. **The outpost is the survivor of something larger.** The broken outer wall and the roofless keep in ring two were a walled town; the outpost's palisade is timber where the ruins are cut stone. The ruined watch post in ring one, in the outpost's own timber, says the outpost once kept a lookout farther out than it does now.
2. **The caravan was coming home.** The wreck on the road to the gate points north, toward the outpost; its load spilled on the gate side, and a cold fire ring beside it says they camped one night and went no farther.
3. **The waystones predate the outpost.** Both are carved in the ruins' stone, in the same hand as the stones at the gate to ring two and the arch; ring two's stands at the centre of a ring of older, leaning stones. The outpost's own boundary markers are rough and uncut.
4. **The ice took the town, not a war.** Shards of ice grow through the ruins and the lake has frozen over its deep holes; the only bones in the world lie at the wolf dens. Nothing in the ruins is burnt or broken by hand.
