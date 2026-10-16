# Frostmark asset research: environment and props

**Best picks for Frostmark.** Start with Quaternius's **Medieval Village MegaKit** (CC0, glTF, modular walls/roofs/props for the trading outpost) and **Fantasy Props MegaKit** (CC0, 200+ furniture/crates/barrels/props), then fill out ruins, dungeon and camp pieces with Quaternius's **Ultimate Modular Ruins** and Kenney's **Survival Kit** (camp, fire, tents, crates, tools) and **Fantasy Town Kit** (walls, gates, bridges). Use the KayKit **Dungeon Pack**, **Resource Bits** (ore, wood, iron stacks) and **RPG Tools Bits** (anvil, pickaxe) for smithing/mining/woodcutting dressing. For the frozen look, no CC0 snow-specific kit turned up. Plan on recolouring the flat-shaded CC0 kits (white/blue palette, snow caps added by shader or a few hand-made meshes), with Kyrise's CC-BY winter pack as an optional extra. All "high" picks below are CC0, so there is no attribution burden.

Notes common to all rows:
- Date checked is 2026-10-16 for every row. Licences were read from the source's own page (or Poly Pizza model page) on that date.
- Godot 4.5: glTF/GLB imports natively and is the preferred format. FBX imports natively (ufbx) since 4.3. OBJ works but has no scene hierarchy/materials. `.blend` needs Blender installed for import, so avoid it for web CI.
- "Kenney formats: not listed on page" means the kenney.nl page itself doesn't state formats. I did not download anything to check, so formats are unverified.
- No NC or ND licences were found among the entries below. Flags are in the Licence column: **CC-BY** needs attribution; **unverified** means the page gave no licence.

## Kenney (CC0)

Kenney's site states: "all game assets on the asset pages are public domain licensed (CC0)... free to use them, even in commercial projects... Attribution is not required" (https://kenney.nl/support). Credit is optional. Do not use the Kenney logo.

| Name | URL | Author | Licence | Attribution | Formats | Count/size | Godot 4 notes | Fit | Checked |
|---|---|---|---|---|---|---|---|---|---|
| Survival Kit (v2.0) | https://kenney.nl/assets/survival-kit | Kenney | CC0 | Not required; none specified | Not listed on page (unverified) | Files "80x"; v2.0 added 40 models | Page flags "Animation" feature. Check the zip's import settings | high: camp, tents, crates, tools, fire, resource-gathering props | 2026-10-16 |
| Castle Kit | https://kenney.nl/assets/castle-kit | Kenney | CC0 | Not required; none specified | Not listed on page (unverified) | Files "75x" | Modular walls, gates, towers. Flat-colour style, matches brief | high: outpost walls/gates, bandit fort | 2026-10-16 |
| Fantasy Town Kit | https://kenney.nl/assets/fantasy-town-kit | Kenney | CC0 | Not required; none specified | Not listed on page (unverified) | Files "160x" | Modular houses, walls, bridges, props | high: trading outpost core | 2026-10-16 |
| Graveyard Kit | https://kenney.nl/assets/graveyard-kit | Kenney | CC0 | Not required; none specified | Not listed on page (unverified) | Files "90x" | Crypt/fence/gravestone pieces | medium: ruins and cemetery dressing | 2026-10-16 |
| Nature Kit | https://kenney.nl/assets/nature-kit | Kenney | CC0 | Not required; none specified | Not listed on the kenney.nl page (the older OpenGameArt copy mentions OBJ) | Files "330x" | Trees, rocks, logs, stumps, bridges, fences, tents | high: resource nodes (rocks, stumps, trees), terrain dressing | 2026-10-16 |
| Pirate Kit | https://kenney.nl/assets/pirate-kit | Kenney | CC0 | Not required; none specified | Not listed on page (unverified) | Files "70x" | Ships, docks, barrels, chests | medium: docks, boats, fishing area | 2026-10-16 |
| Modular Dungeon Kit | https://kenney.nl/assets/modular-dungeon-kit | Kenney | CC0 | Not required; none specified | Not listed on page (unverified) | Files "40x" | Modular walls/floors | medium: ruins and bandit-camp interiors | 2026-10-16 |
| Mini Dungeon | https://kenney.nl/assets/mini-dungeon | Kenney | CC0 | Not required; none specified | Not listed on page (unverified) | Files "30x" | Small, compact dungeon props | low: small pack, mostly overlaps the above | 2026-10-16 |
| Modular Cave Kit | https://kenney.nl/assets/modular-cave-kit | Kenney | CC0 | Not required; none specified | Not listed on page (unverified) | Files "40x" | Cave tiles | medium: mine interiors (mining skill) | 2026-10-16 |
| Mini Forest | https://kenney.nl/assets/mini-forest | Kenney | CC0 | Not required; none specified | Not listed on page (unverified) | Files "20x" | Small tree/rock set | low: tiny, Nature Kit covers it | 2026-10-16 |
| Furniture Kit | https://kenney.nl/assets/furniture-kit | Kenney | CC0 | Not required; none specified | Not listed on page (unverified) | Files "140x" | Modern-ish furniture | low: style is modern, not frontier | 2026-10-16 |
| Hexagon Kit | https://kenney.nl/assets/hexagon-kit | Kenney | CC0 | Not required; none specified | Not listed on page (unverified) | Files "70x" | Hex tiles | low: only useful if the map is hex-based | 2026-10-16 |
| Tower Defense Kit | https://kenney.nl/assets/tower-defense-kit | Kenney | CC0 | Not required; none specified | Not listed on page (unverified) | Files "160x" | Towers, tiles, props | low: watchtower/palisade pieces only | 2026-10-16 |
| Holiday Kit | https://kenney.nl/assets/holiday-kit | Kenney | CC0 | Not required; none specified | Not listed on page (unverified) | Files "100x" | Winter/holiday props | medium: snow-themed props (trees, snowmen); check tone before use | 2026-10-16 |
| Kenney models on Poly Pizza (e.g. Campfire, Workbench Anvil) | https://poly.pizza/m/i6UFAevfcu, https://poly.pizza/m/bY1pp3kAAb | Kenney | CC0 ("Public Domain (CC0)") | Not required; none specified | OBJ, GLTF | Single models | GLTF imports directly | medium: handy single-model downloads of campfire/anvil | 2026-10-16 |

## Quaternius (CC0)

Quaternius FAQ (https://quaternius.com/faq.html): "attribution is not necessary. However, credit is always appreciated." Pack pages show "© Quaternius". Tiered packs (MegaKits): the **Standard tier is free**; Pro and Source tiers are paid and add models, Blender files and ready-made Godot projects. All tiers are CC0.

| Name | URL | Author | Licence | Attribution | Formats | Count/size | Godot 4 notes | Fit | Checked |
|---|---|---|---|---|---|---|---|---|---|
| Medieval Village MegaKit | https://quaternius.com/packs/medievalvillagemegakit.html (free tier: https://quaternius.itch.io/medieval-village-megakit) | Quaternius | CC0 | Not required; none specified | FBX, OBJ, glTF (+ .blend in paid Source) | 304 models total; free Standard tier is about 170 pieces (itch page says "170", pack page says 60-70%) | Page lists Godot 4.3 as tested, but ready-made Godot projects are paid-only. glTF imports directly | high: modular outpost buildings, walls, roofs, stairs | 2026-10-16 |
| Fantasy Props MegaKit | https://quaternius.com/packs/fantasypropsmegakit.html | Quaternius | CC0 | Not required; none specified | FBX, OBJ, glTF (+ .blend in Source) | 211 listed; free tier about 60-70% | glTF imports directly. Godot projects paid-only | high: crates, barrels, furniture, props | 2026-10-16 |
| Stylized Nature MegaKit | https://quaternius.com/packs/stylizednaturemegakit.html (itch: https://quaternius.itch.io/stylized-nature-megakit) | Quaternius | CC0 | Not required; none specified | FBX, OBJ, glTF, Blend (Source) | 116 listed; free tier 81 assets per itch page | Ghibli-styled, not strictly flat-shaded. Custom shaders only in paid Source | medium: trees, rocks, plants for resource nodes, but painterly rather than low-poly flat | 2026-10-16 |
| Ultimate Modular Ruins Pack | https://quaternius.com/packs/ultimatemodularruins.html | Quaternius | CC0 | Not required; none specified | FBX, OBJ, Blend | 90 models | Includes one animated character. Use FBX or OBJ | high: ruins and dungeon pieces | 2026-10-16 |
| Medieval Village Pack | https://quaternius.com/packs/medievalvillage.html (also https://opengameart.org/content/lowpoly-medieval-village-pack, 8.3 MB zip) | Quaternius | CC0 | Not required; none specified | FBX, OBJ, Blend | 44 models | Textured, not animated | high: older, smaller outpost building set | 2026-10-16 |
| Ultimate Buildings Pack (textured) | https://quaternius.com/packs/ultimatetexturedbuildings.html (OGA: https://opengameart.org/content/lowpoly-buildings-pack, 30 MB) | Quaternius | CC0 | Not required; none specified | FBX, OBJ, Blend | 76 models | Atlas textures swap palettes | low: modern city-style buildings, not frontier | 2026-10-16 |
| Modular Dungeons Pack | https://quaternius.com/packs/modulardungeon.html | Quaternius | CC0 | Not required; none specified | FBX, OBJ, Blend | 48 models | Untextured | medium: dungeon/ruin interiors | 2026-10-16 |
| Modular Dungeon Pack (2018) | https://quaternius.com/packs/medievaldungeon.html | Quaternius | CC0 | Not required; none specified | FBX, OBJ, Blend | 41 models (barrels, torches, potions, walls) | Untextured | medium: bandit-camp and dungeon props | 2026-10-16 |
| Farm Buildings Pack | https://quaternius.com/packs/farmbuildings.html | Quaternius | CC0 | Not required; none specified | FBX, OBJ, Blend | 13 models | Untextured | low: farm-style, few pieces | 2026-10-16 |
| Ultimate Nature Pack | https://quaternius.com/packs/ultimatenature.html | Quaternius | CC0 | Not required; none specified | FBX, OBJ, Blend | 150 models | Untextured | high: trees, rocks, stumps, logs for resource nodes | 2026-10-16 |
| Bonfire and Viking Boat (Poly Pizza) | https://poly.pizza/m/k1e0cOzi8A, https://poly.pizza/m/J7SCPiNoSy | Quaternius | CC0 ("Public Domain (CC0)") | Not required; none specified | FBX, GLTF | Single models | GLTF imports directly | medium: ready-made campfire and longship | 2026-10-16 |

## KayKit (Kay Lousberg, CC0 on itch.io)

Each KayKit page says "Free for personal and commercial use, no attribution required" and asks users not to resell unmodified copies or claim them as their own (a request, not a licence term; the licence is CC0). The base pack is "name your own price" (free); Extra and Source tiers cost money. Each pack uses a single 1024x1024 gradient atlas.

| Name | URL | Author | Licence | Attribution | Formats | Count/size | Godot 4 notes | Fit | Checked |
|---|---|---|---|---|---|---|---|---|---|
| KayKit Dungeon Pack | https://kaylousberg.itch.io/kaykit-dungeon-pack | Kay Lousberg | CC0 | Not required; none specified | FBX, glTF, OBJ | Free tier 200 assets (31 MB); Extra $7.95+ adds 75+ | glTF imports directly | high: walls, doors, chests, barrels, tables, tavern pieces | 2026-10-16 |
| KayKit Resource Bits | https://kaylousberg.itch.io/resource-bits | Kay Lousberg | CC0 | Not required; none specified | OBJ, FBX, glTF | Free 75+ models (8.1 MB) | Wood, stone, iron, copper, gold, textiles | high: ore, log, ingot items for woodcutting/mining/smithing | 2026-10-16 |
| KayKit RPG Tools Bits | https://kaylousberg.itch.io/rpg-tools-bits | Kay Lousberg | CC0 | Not required; none specified | OBJ, FBX, glTF | Free 45+ models (3.7 MB) | Anvil, pickaxe, hammer, axe, lantern; fishing items need paid Extra | high: smithing and gathering tools | 2026-10-16 |
| KayKit Restaurant Bits | https://kaylousberg.itch.io/restaurant-bits | Kay Lousberg | CC0 | Not required; none specified | OBJ, FBX, glTF | Free 140+ models (10 MB) | Food and kitchen items | medium: cooking items; style is modern restaurant | 2026-10-16 |
| KayKit Medieval Hexagon Pack | https://kaylousberg.itch.io/kaykit-medieval-hexagon | Kay Lousberg | CC0 | Not required; none specified | FBX, GLTF, OBJ | Free 200+ models (33 MB); Extra adds 150+ | Hex tiles and buildings (blacksmith, tavern, market, mine, windmill) in 4 colours | medium: great buildings, but hex-grid layout | 2026-10-16 |
| KayKit Medieval Builder Pack (legacy) | https://kaylousberg.itch.io/kaykit-medieval-builder-pack | Kay Lousberg | CC0 | Not required; none specified | FBX, OBJ, DAE, GLTF | 200+ assets (14 MB) | Page says legacy and won't be updated. Snow-biome variant is Patreon-only | medium: free placement or square grid, older | 2026-10-16 |
| KayKit Forest Nature Pack | https://kaylousberg.itch.io/kaykit-forest | Kay Lousberg | CC0 | Not required; none specified | FBX, glTF, OBJ | Free 100+ models (6.1 MB); Extra $9.99+ adds modular terrain | glTF imports directly | high: trees, rocks, bushes for resource nodes | 2026-10-16 |
| KayKit Halloween Bits | https://kaylousberg.itch.io/halloween-bits | Kay Lousberg | CC0 | Not required; none specified | OBJ, FBX, GLTF | Free 60+ models (5.3 MB) | Graveyard-themed | medium: graves and ruin dressing | 2026-10-16 |
| KayKit Furniture Bits | https://kaylousberg.itch.io/furniture-bits | Kay Lousberg | CC0 | Not required; none specified | OBJ, FBX, GLTF | Free 50+ models (3.6 MB) | Interior furniture | medium: tavern/house interiors | 2026-10-16 |

## OpenGameArt and itch.io (various authors)

| Name | URL | Author | Licence | Attribution | Formats | Count/size | Godot 4 notes | Fit | Checked |
|---|---|---|---|---|---|---|---|---|---|
| Modular Medieval Building Pack | https://opengameart.org/content/modular-medieval-building-pack | Daniel Andersson (submitted by hreikin) | CC0 | Not required. Page: "None required, but it would be nice if you could credit Daniel Andersson." | .blend only (10 zips, 0.9-5.2 MB each) | 10 house bases, 14 windows, 4 doors, balconies, stairs, chimneys, roofs, sign | Needs Blender to convert, or Godot with Blender installed | medium: good modular houses, extra conversion step | 2026-10-16 |
| Medieval House Pack | https://opengameart.org/content/medieval-house-pack | Daniel Andersson (submitted by hreikin) | CC0 | Not required; "it would be nice" to credit Daniel Andersson | .blend only (4 zips, about 29 MB total) | 4 houses | Same Blender conversion caveat | low: 4 houses, .blend only | 2026-10-16 |
| Modular Dungeon 2 - 3D Models | https://opengameart.org/content/modular-dungeon-2-3d-models | Keith at Fertile Soil Productions | CC0 | Not required; none specified | Zip (inner formats not listed on page); models untextured | About 90 pieces, 269.5 KB | Built for Asset Forge | low: untextured and tiny | 2026-10-16 |
| Modular Terrain | https://opengameart.org/content/modular-terrain | Keith at Fertile Soil Productions | CC0 | Not required; none specified | OBJ | 511 KB zip; hilly, cliff, beach sets with trees, bridges, fences | OBJ imports directly | low: forest terrain, no snow | 2026-10-16 |
| Nature Kit (older Kenney copy) | https://opengameart.org/content/nature-kit | Kenney | CC0 | Optional. Page: Credit "Kenney.nl" or "www.kenney.nl", this is not mandatory | Not listed (OBJ mentioned in comments) | 330+ objects, 10.5 MB | Same as Kenney Nature Kit; prefer kenney.nl for the current version | low: superseded by kenney.nl listing | 2026-10-16 |
| Free Modular Low Poly Dungeon Pack | https://rgsdev.itch.io/free-modular-low-poly-dungeon-pack-by-rgsdev | RGS_Dev | CC0 ("Credit is not needed") | Not required; none specified | Not listed (unverified); page notes .glb | 6.7 MB, count not stated; "in development" | Colours separated by material | medium: dungeon walls, doors, chests, traps | 2026-10-16 |
| Low Poly Dungeon Modular Asset Pack | https://hocineache.itch.io/modular-dungeon-assets | hocineache | CC0 | Not required; none specified | FBX, OBJ | 17 MB, count not stated | FBX imports natively | medium: extra dungeon pieces | 2026-10-16 |
| Lowpoly Goblin Camp (free folder only) | https://byndwalker.itch.io/lowpoly-goblin-camp | ByndWalker | **Free folder CC0. Extra folder is a Standard Commercial License (redistribution of standalone source files prohibited)** | Not required for the free folder | Not listed (unverified) | Free: 13 items (3 cabins/houses, 5 tents, fences, stones), 5.6 MB. Campfire, crates, barrels are in the paid Extra | Use only the free folder to stay CC0 | high: bandit camp tents, cabins, fences | 2026-10-16 |
| Low Poly Medieval Village (SquareWheel) | https://squarewheelinteractive.itch.io/low-poly-medieval-village | SquareWheelInteractive | CC0 | Not required; none specified | .blend plus textures (267 KB) | 5 buildings, 2 trees, 2 props | Needs Blender conversion | low: tiny | 2026-10-16 |
| Kyrise's Free Voxel Winter Environment Pack | https://kyrise.itch.io/kyrises-voxel-winter-environment-pack | Kyrise | **CC-BY 4.0 (attribution required)** | Required. Page's own credit format: title "Kyrise's Free Voxel Winter Environment Pack Low Poly", author Kyrise, 2021, link to CC BY 4.0 | OBJ, FBX, glTF, VOX | 20 models (5 snow blocks, 15 objects such as fence, gate, bench, pine) | Voxel style, different from flat low-poly. Zip file name doesn't match the pack title, so check the archive | medium: only snow-themed kit found, but voxel look and attribution needed | 2026-10-16 |
| Free Winter Bushes 3D Low Poly Pack | https://free-game-assets.itch.io/free-winter-bushes-3d-low-poly-pack | Free Game Assets | **unverified (page names no licence)** | unverified | FBX, PNG texture | 20 objects, 279 KB | FBX imports natively | low: licence unclear, bushes only | 2026-10-16 |

## Poly Pizza (per-model licences vary)

Poly Pizza listing pages don't show the licence; you must open each model. Two licences were seen: **CC0** (Kenney, Quaternius models, see rows above) and **CC BY 3.0** (Poly by Google, Don Carson). The pages give no exact credit line, so use the standard CC BY form "Title by Author, licensed under CC BY 3.0".

| Name | URL | Author | Licence | Attribution | Formats | Count/size | Godot 4 notes | Fit | Checked |
|---|---|---|---|---|---|---|---|---|---|
| Campfire | https://poly.pizza/m/0vzzmM-t8CP | Poly by Google | **CC BY 3.0** | Required. No author-specified string; suggested: "Campfire by Poly by Google, CC BY 3.0 (https://creativecommons.org/licenses/by/3.0/)" | OBJ, GLTF | Single model | GLTF imports directly | low: Kenney and Quaternius campfires are CC0 | 2026-10-16 |
| Anvil | https://poly.pizza/m/aTcKrofhCXS | Poly by Google | **CC BY 3.0** | Required; none specified by author. Suggested: "Anvil by Poly by Google, CC BY 3.0" | OBJ, GLTF | Single model | GLTF imports directly | low: use KayKit/Kenney CC0 anvils instead | 2026-10-16 |
| Forge (Medieval Blacksmith's Shop) | https://poly.pizza/m/2ZnLsJJL4Pe | Don Carson | **CC BY 3.0** ("Creative Commons Attribution") | Required; none specified by author. Credit "Don Carson" | OBJ, GLTF | Single model | GLTF imports directly | medium: a ready-made forge for smithing, if attribution is acceptable | 2026-10-16 |
| Smithy (Felix Gä.) | https://poly.pizza/m/d8NxRd_seIK | Felix Gä. | unverified (page timed out) | unverified | unverified | Single model | n/a | unverified: worth a manual look for smithing | 2026-10-16 |

## Other sources

| Name | URL | Author | Licence | Attribution | Formats | Count/size | Godot 4 notes | Fit | Checked |
|---|---|---|---|---|---|---|---|---|---|
| Free Viking 3D Assets (Low Poly) | https://assetpack.itch.io/vikings | assetpack.ai | **unverified: page says only "game-ready and free to use"; no licence named. Tagged AI Generated** | unverified | Not specified; zip (9.1 MB) holds "models and textures" | 50+ assets: longhouses, huts, blacksmith, fisherman's shack, pines, rune stones, firepit, crates | Check format after download. AI-generated, so licence and provenance risk | medium: closest Nordic theme, but licence unverified; do not ship without clarification | 2026-10-16 |
| Low Poly Viking Longhouse (Fab) | https://www.fab.com/listings/08a8c620-9308-4e09-92a2-8d9fe03b1d2d | unverified | unverified (page returned 403; search snippet said free, attribution appreciated, FBX/OBJ/Blender/GLB) | unverified | unverified | Single model | n/a | unverified: a Nordic longhouse, confirm Fab's licence terms manually | 2026-10-16 |

## Gaps and caveats

- **No snow/frozen kit with a clean licence.** Only Kenney's Holiday Kit (CC0) and Kyrise's voxel pack (CC-BY) are winter-themed. Expect to recolour CC0 kits (white-blue palette, snow caps via shader or hand-made meshes).
- **Nordic/Viking architecture** (longhouses, palisades, rune stones) is thin in verified CC0 sources. The only candidates (assetpack.ai Vikings, Fab longhouse) have unverified licences. Medieval Village MegaKit plus colour changes is the safe route.
- **Fishing spots, cooking stations, forges:** no dedicated CC0 pack found. Compose from Kenney Pirate Kit (docks), KayKit RPG Tools Bits and Restaurant Bits (anvil, kitchen), Survival Kit (campfire, cooking props), and the CC-BY Don Carson forge if needed.
- **Tiered packs:** Quaternius MegaKits and KayKit packs give only part of the content free. Ready-made Godot projects and shaders are paid-only. Counts above are the free tier where stated.
- **Format caveats:** Kenney pages don't list formats (unverified). Several OpenGameArt packs are .blend only, requiring Blender conversion. Prefer glTF/GLB where available.
- **Not checked:** Sketchfab (search is JavaScript-rendered and returned no results, and per-model licences vary), Fab beyond one blocked page, and Kenney 2D kits (Tiny Town etc.), which don't match the 3D low-poly direction. No asset files were downloaded, so zip contents and file formats were not inspected.
- **Style consistency:** Mixing Kenney, Quaternius and KayKit packs means mixed palettes and scales. Budget a pass to unify materials (shared palette texture or per-material recolour).
