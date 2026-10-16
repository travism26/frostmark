# Frostmark asset research: weapons, tools and items

Checked 2026-10-16. Licences were read from each source's own page on that date. Where a page did not state something, the cell says "unverified" or "not stated".

## Best picks for Frostmark

The strongest single-style stack is the **KayKit** family (Fantasy Weapons Bits, Resource Bits, RPG Tools Bits, Adventurers, Restaurant Bits). All are CC0 and share one 1024x1024 gradient atlas, so they look consistent and are cheap in a web build. Together they cover swords, axes, spears, bows, shields, pickaxe, hammer, anvil, wood, stone, iron, copper, gold, and food. Notable gaps in the free tiers are fishing gear (paid Extra tier of RPG Tools Bits) and money/gems/containers (paid Extra tier of Resource Bits). **Quaternius Ultimate RPG Pack** (106 models, CC0) and **Fantasy Props MegaKit** (potions, chests, weapons, tools; CC0) fill chests, potions, and gear. For 2D inventory icons, **game-icons.net** (CC BY 3.0, SVG, thousands of icons, attribution required) is the largest consistent set, with CC0 pixel-art sets from OpenGameArt as fallback. Fishing rod and ingot models come from small OpenGameArt CC0 uploads. Armour tiers (wooden/bronze/iron) are mostly covered by tinting the KayKit atlas or by character outfits, not by standalone armour pieces.

## KayKit (Kay Lousberg)

| Name | URL | Author | Licence | Attribution | Formats | Count/size | Godot 4 notes | Fit | Checked |
|---|---|---|---|---|---|---|---|---|---|
| KayKit Fantasy Weapons Bits | https://kaylousberg.itch.io/fantasy-weapons-bits | Kay Lousberg | CC0 1.0 | Not required; none specified (asks that unmodified copies not be resold) | OBJ, FBX, GLTF; .blend in Source tier | Free: 25+ models; full 40+ (Extra adds 15 elemental weapons); 1024x1024 gradient atlas | glTF imports directly; tiny atlas suits web export | high: swords, axes, hammers, bows, staves, spears, shields in one flat-shaded style | 2026-10-16 |
| KayKit Resource Bits | https://kaylousberg.itch.io/resource-bits | Kay Lousberg | CC0 1.0 | Not required; none specified | OBJ, FBX, glTF; .blend in Source tier | Free: 75+ models; Extra (paid) adds 55+ incl. money, gems, containers, food | glTF; shared 1024 atlas (can downsample to 128) | high: wood, stone, iron, copper, silver, gold, textiles for gathering and smithing | 2026-10-16 |
| KayKit RPG Tools Bits | https://kaylousberg.itch.io/rpg-tools-bits | Kay Lousberg | CC0 1.0 | Not required; none specified | OBJ, FBX, glTF; .blend in Source tier | Free: 45+ models (pickaxe, hammer, axe, anvil, lantern etc.); Extra (paid, $4.99+) adds 20 incl. fishing | glTF; shared atlas | high: pickaxe, hatchet, anvil, hammer match mining/woodcutting/smithing; fishing is paid | 2026-10-16 |
| KayKit Adventurers | https://kaylousberg.itch.io/kaykit-adventurers | Kay Lousberg | CC0 1.0 | Not required; none specified | FBX, GLTF; .blend in Source tier | Free: 5 rigged characters with 25+ weapons/accessories (swords, shields, axes, bow, crossbow, arrows, quiver, staff, potion bottles) | Rigged and animated; glTF; attach weapons to bone attachments | medium: weapons are reusable; characters are a separate category | 2026-10-16 |
| KayKit Dungeon Pack (1.0) | https://opengameart.org/content/kaykit-dungeon-pack-10 | Kay Lousberg | CC0 | Not required; none specified | Formats not listed on page (31 MB zip) | "200+" assets; 24 weapons in 3 tiers, loot, gold pickups, potions, props | Page does not list formats; check zip contents | high: weapon tiers, loot and potions fit; dungeon props are extra | 2026-10-16 |
| KayKit Restaurant Bits | https://kaylousberg.itch.io/restaurant-bits | Kay Lousberg | CC0 1.0 | Not required; none specified | OBJ, FBX, glTF; .blend in Source tier | Free: 140+ models; Extra (paid) adds 75+ ice-cream/pizza themed | glTF; shared atlas | medium: pots, pans, food for cooking skill; some items too modern | 2026-10-16 |
| KayKit Medieval Hexagon Pack | https://kaylousberg.itch.io/kaykit-medieval-hexagon | Kay Lousberg | CC0 1.0 | Not required; none specified | FBX, glTF, OBJ; .blend in Source tier | Free: 200+ models (hex tiles, buildings, props); 250 total | glTF | low: environment kit, not items; useful only for world props | 2026-10-16 |

## Quaternius

| Name | URL | Author | Licence | Attribution | Formats | Count/size | Godot 4 notes | Fit | Checked |
|---|---|---|---|---|---|---|---|---|---|
| Ultimate RPG Pack | https://quaternius.com/packs/ultimaterpg.html (also https://opengameart.org/content/low-poly-rpg-pack) | Quaternius | CC0 | Not required; page only asks to consider supporting on Patreon | FBX, OBJ, Blend; PNG renders included | 106 models; 44.6 MB zip | No glTF; import FBX or convert in Blender; models not textured (vertex/flat colours) | high: weapons, shields, gems, chests, potions, staves in flat low-poly style | 2026-10-16 |
| Ultimate Food Pack | https://quaternius.com/packs/ultimatefood.html | Quaternius | CC0 | Not required (page) | FBX, OBJ, Blend | 103 models | FBX import; untextured flat colours | medium: bread, meat, fish-like items for cooking; many are modern or fast food | 2026-10-16 |
| Fantasy Props MegaKit | https://quaternius.com/packs/fantasypropsmegakit.html | Quaternius | CC0 | Not required; page says free for personal, educational and commercial use | FBX, OBJ, glTF, Blend (Source) | 211 models; Standard (free) is about 60-70% of pack; 4 texture sets | glTF; Pro/Source tiers are paid and add Godot integration | high: weapons, tools, potions, chests, market stalls, vegetables | 2026-10-16 |
| LowPoly RPG pack (2018) | https://opengameart.org/content/lowpoly-rpg | Quaternius | CC0 | Not required; asks for Patreon support | Blend, OBJ, FBX | 2.6 MB zip; staff, sword, helmet, book, gems, chest, shield | FBX import | medium: small and older; subset of the larger pack | 2026-10-16 |
| Low Poly Medieval Weapons (22) | https://quaternius.itch.io/lowpoly-medieval-weapons | Quaternius | CC0 | Not stated on page; none specified | FBX, OBJ, Blend | 22 weapons | FBX import | high: swords, axes, daggers, clubs in a consistent low-poly style | 2026-10-16 |
| Medieval Weapons Pack (2016) | https://opengameart.org/content/low-poly-medieval-weapons | Quaternius | CC0 | Not required; asks for Patreon support | Blend (MedievalPack.zip, formats not itemised) | 800 KB | Blender file only likely; export to glTF | low: superseded by the 22-weapon itch.io pack | 2026-10-16 |

## Kenney

| Name | URL | Author | Licence | Attribution | Formats | Count/size | Godot 4 notes | Fit | Checked |
|---|---|---|---|---|---|---|---|---|---|
| Survival Kit | https://kenney.nl/assets/survival-kit | Kenney | CC0 | Not required; none specified on page | Not listed on page (Kenney 3D kits typically ship several; unverified) | 80 files | Not stated | high: tools, chests, barrels, resources in a survival theme | 2026-10-16 |
| Food Kit | https://kenney.nl/assets/food-kit | Kenney | CC0 | Not required; none specified | Not listed on page | 200 files | Not stated | medium: wide food set, mostly modern; usable for cooking art | 2026-10-16 |
| Mini Dungeon | https://kenney.nl/assets/mini-dungeon | Kenney | CC0 | Not required; none specified | Not listed on page | 30 files; includes weapons and shields | Not stated | medium: small weapon set in a tiny style | 2026-10-16 |
| Castle Kit | https://kenney.nl/assets/castle-kit | Kenney | CC0 | Not required; none specified | Not listed on page | 75 files | Not stated | low: structures, not items | 2026-10-16 |
| Generic Items (2D) | https://kenney.nl/assets/generic-items | Kenney | CC0 | Not required; none specified | Not listed on page | 160 files; tags: items, tools, household | Sprites; import as textures | medium: 2D inventory-style icons, generic rather than frontier-themed | 2026-10-16 |
| Tiny Dungeon (2D) | https://kenney.nl/assets/tiny-dungeon | Kenney | CC0 | Not required; none specified | Not listed on page | 130 files; 16x16 pixel art | Needs nearest filtering | low: pixel art clashes with low-poly style | 2026-10-16 |

## OpenGameArt 3D models

| Name | URL | Author | Licence | Attribution | Formats | Count/size | Godot 4 notes | Fit | Checked |
|---|---|---|---|---|---|---|---|---|---|
| Stylized Low poly Tools | https://opengameart.org/content/stylized-low-poly-tools | zisongbr (page also lists "fmoreira" in attribution field; spelling unconfirmed) | CC0 | Not required; none specified | 3D model formats not listed; PNG icons included | 5 tools (pickaxe, hammer, shovel, hoe, axe); about 15 MB | Check zip contents | high: pickaxe and axe plus ready icons | 2026-10-16 |
| Simple low poly swords | https://opengameart.org/content/simple-low-poly-swords | CC0 Game Assets | CC0 | Not required; none specified | FBX plus 2 PNG textures | 12 swords; 150 KB | FBX import | medium: sword variants for bronze/iron tinting | 2026-10-16 |
| Medieval weapon pack | https://opengameart.org/content/medieval-weapon-pack | System G6 (Qoma) | CC0 | Not required. Optional: "System G6" or "Qoma" | One .blend (7z archive); 512x512 PNG textures | 14 weapons (bow, crossbow, quiver, sword, dagger, axe, mace, shield, staff); 36-198 tris; 2.9 MB | Needs 7z extraction and Blender export | high: very low poly, covers ranged and melee | 2026-10-16 |
| Crafting items | https://opengameart.org/content/crafting-items | FacadeGaikan | CC0 | Not required; none specified | .blend, textures, XCF, UV layouts | A few dozen items (axe, pickaxe, ingot, coin, chest, bread, soup, bowl); 2.9 MB; 128px textures | Blender export needed; use edge split per a comment | medium: has ingots and cooking items, but blocky-pixel texture style | 2026-10-16 |
| Fishing pole | https://opengameart.org/content/fishing-pole | AnyRPG | CC0 | Not required; none specified | .blend (FBX only inside AnyRPG Unity package) | 453 verts / 380 tris; 1.4 MB | Export from Blender | high: only free CC0 fishing rod found | 2026-10-16 |
| Low poly pick axe | https://opengameart.org/content/low-poly-pick-axe | p0ss | FLAG: page lists four options (CC-BY 3.0, CC-BY-SA 3.0, GPL 3.0, GPL 2.0) | Attribution required under CC-BY; page gives no credit line; avoid SA and GPL | .blend, .xcf | 58 polys | Blender export | low: licence is messy; use CC0 pickaxes instead | 2026-10-16 |

## itch.io 3D packs

| Name | URL | Author | Licence | Attribution | Formats | Count/size | Godot 4 notes | Fit | Checked |
|---|---|---|---|---|---|---|---|---|---|
| Low Poly Medieval Weapons | https://ankersassets.itch.io/low-poly-medieval-weapons | Anker's Assets | CC0 (per page) | Not required; none specified | FBX | 60+ meshes; pay-what-you-want | FBX import | high: large weapon variety | 2026-10-16 |
| Low Poly Simple Melee Weapon Pack | https://joe345.itch.io/low-poly-simple-weapon-pack | joe345 | CC0 1.0; page says credit appreciated | Optional | .glb | 7 weapons (sword, dagger, spear, hammer, glaive, hatchet, battleaxe); 52 KB | Native glb import | medium: small but spear and hatchet are useful | 2026-10-16 |
| Free Low Poly Tools | https://voxeledphoton.itch.io/low-poly-toolkit | voxeledphoton | Custom statement "free to use in personal or commercial projects"; no standard licence named. Uses Imphenzia gradient texture | Credit appreciated, not required | Not listed (259 KB zip); made for Roblox, may need about 100x scale | Count not stated | Rescale on import | medium: axes, pickaxes, swords; licence is informal | 2026-10-16 |

## 2D icon sets

| Name | URL | Author | Licence | Attribution | Formats | Count/size | Godot 4 notes | Fit | Checked |
|---|---|---|---|---|---|---|---|---|---|
| game-icons.net | https://game-icons.net/about.html | Many (Lorc, Delapouite, and others; about 4,180 icons by page's author table) | CC BY 3.0 | REQUIRED. Suggested line: "Icons made by {author}. Available on https://game-icons.net" (substitute the icon's author) | SVG confirmed; PNG listed as roadmap only | About 4,180 icons | Godot 4 imports SVG as textures; recolour via modulate | high: huge coverage of swords, axes, ingots, ore, potions, fish, and meat; single-colour style suits inventory UI | 2026-10-16 |
| 496 Pixel Art Icons for Medieval/Fantasy RPG | https://opengameart.org/content/496-pixel-art-icons-for-medievalfantasy-rpg | Henrique Lazarini (7Soul1) | CC0 on the page; a commenter relays the author saying the true licence is public domain on DeviantArt | Not required; crediting suggested by commenters | PNG spritesheet in a 1.5 MB zip | 496 icons, about 34x34 | Needs nearest filtering | medium: wide coverage, but pixel art clashes with low-poly | 2026-10-16 |
| CC0 Potion Icons (AntumDeluge) | https://opengameart.org/content/cc0-potion-icons | AntumDeluge compiling 7Soul1, ArlanTR, Buch, kotnaszynce and others | CC0 | None stated; sources listed on page | PNG, 32x32 (some 64x64) | 11 zip files | Nearest filtering | medium: potions only | 2026-10-16 |
| Consolidated (AntumDeluge collection) | https://opengameart.org/content/consolidated | AntumDeluge, multiple sources | Collection page states no licence; 24 linked submissions labelled CC0 (check each) | Check each linked entry; generated CREDITS.TXT may be inaccurate | Mostly PNG, one SVG | 86 art entries; axes, swords, shields, potions, food, footwear | Nearest filtering | medium: useful index of weapon/food icon sets | 2026-10-16 |
| RPG Item Set | https://opengameart.org/content/rpg-item-set | Jetrel | CC0 | Not required; none specified | PNG | Count not stated; 32x32 tiles | Nearest filtering | low: small pixel props | 2026-10-16 |
| Generic Fantasy RPG Items | https://opengameart.org/content/generic-fantasy-rpg-items | HomoHikka | CC0 | Not required; none specified | PNG (2 files) | Small set (armour, helmet, shield) | Nearest filtering | low: very small | 2026-10-16 |
| Ravenmore Fantasy Icon Pack | https://ravenmore.itch.io/fantasy-icon-pack | Ravenmore | Custom: commercial use allowed. FLAG: redistribution in other asset packs, NFTs and AI training prohibited | Optional; link back appreciated | Formats not stated; 64, 128, 256 px | 50 icons plus 2 frames; pay-what-you-want | Standard textures | medium: painted style, few items, no food confirmed | 2026-10-16 |

## Aggregators (licence is per model)

| Name | URL | Author | Licence | Attribution | Formats | Count/size | Godot 4 notes | Fit | Checked |
|---|---|---|---|---|---|---|---|---|---|
| Poly Pizza | https://poly.pizza/ | Many | unverified (homepage only links to Terms; the terms page returned an error; third-party credits suggest a mix of CC0 and CC BY, per-model) | Per model; CC BY requires credit | Not verified | 10,700+ models advertised | Check each model's page | medium: good for odd single items, but licence must be recorded per model | 2026-10-16 |
| Sketchfab (CC-licensed downloads) | https://sketchfab.com/ | Many | unverified (the licence help page returned 404); Sketchfab offers CC variants including NC and ND, per-model | Per model | glTF on downloadable models | Very large | Filter by Downloadable and CC0/CC BY only | medium: wide choice but must avoid NC/ND | 2026-10-16 |

## Gaps and caveats

- **Armour tiers**: no free pack found that has wooden, bronze, and iron armour pieces as standalone items. Plan to recolour the KayKit atlas or use the character outfits.
- **Ore and ingots**: Resource Bits has metal resources, and Crafting Items has an ingot, but no dedicated CC0 ore chunk was found.
- **Fishing**: only the AnyRPG fishing pole (Blender only) is free; KayKit's fishing models are in the paid Extra tier.
- **Paid tiers**: KayKit Extra and Source tiers cost money; the free tiers listed here are $0 but differ in content.
- **Formats**: Kenney pages did not list file formats, so confirm after downloading. Quaternius older packs are FBX/OBJ/Blend only, without glTF.
- **Licence flags**: p0ss pickaxe (CC-BY/GPL options), game-icons.net (CC BY 3.0, credit required), Ravenmore (no redistribution), voxeledphoton (informal licence). No NC or ND-licensed asset was included.
- **Quaternius Modular Weapons Pack and RPG Essentials Pack**: listed on the Quaternius home page, but their pack pages returned 404 and licence was not verified. Quaternius's own License page was not read.
- **Style mix**: pixel-art icon sets clash with the low-poly direction; prefer game-icons.net or rendered icons from 3D models.
