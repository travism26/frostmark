# Dungeons share the world grid

A dungeon is a stretch of the single world grid, fenced off by cliffs and reached only through its mouth. It is not a separate map that the scene swaps to. The sim, path-finding, region lookup, save and ring-look table all assume one world, and a second map would mean a sim that tracks which map you're on, a save that records it, and placements per map. That costs too much on three to five hours a week for something that only has to *feel* instanced. The mouth and the way out carry you in and out the way waystone travel does.

## Consequences

- The dungeons take up room in the grid, which has to grow or be laid out to fit them, out of reach of the rings they open from.
- If a region ever needs a map of its own, revisit this then, and move the dungeons onto that machinery at the same time.
