# Frostmark free asset catalogue

Research only: this folder lists free game assets that could fit Frostmark. The catalogue itself downloads nothing; an asset is approved for use only when someone picks it, commits it under `assets/` and adds its credit to the "In use" table in [CREDITS.md](CREDITS.md).

Every licence was read from the source's own page on **2026-10-16** where the page could be loaded. Where a page was blocked, errored, or named no licence, the entry says **unverified** rather than guessing. Treat "unverified" as "do not use until checked".

## Catalogue

| File | Covers | Entries |
|------|--------|---------|
| [characters-and-animations.md](characters-and-animations.md) | Rigged characters, enemies, animals, animation packs, Mixamo | 52 |
| [character-catalogue.md](character-catalogue.md) | Deeper pass for #63: player bodies, ring-one and ring-two creatures, animation packs, with rigs, props and shortlists | 36 |
| [environment-and-props.md](environment-and-props.md) | Outpost, village, ruins, camp, dungeon and prop kits | 52 |
| [terrain-nature-and-weather.md](terrain-nature-and-weather.md) | Winter trees, rocks, PBR textures, skyboxes, terrain and weather | 37 |
| [weapons-tools-and-items.md](weapons-tools-and-items.md) | Weapons, tools, resources, food, loot, item icons | 37 |
| [ui-icons-and-fonts.md](ui-icons-and-fonts.md) | UI kits, icon sets, fonts | 43 |
| [audio-sfx-and-music.md](audio-sfx-and-music.md) | Sound effects, ambience, music | 26 |
| [vfx-shaders-and-godot-addons.md](vfx-shaders-and-godot-addons.md) | Particles, shaders, Godot 4 addons | 40 |

Each file opens with a short "best picks for Frostmark" paragraph, then tables with: name, URL, author, licence, attribution (and the exact credit line where the author gives one), formats, count or size, Godot 4 notes, fit (high, medium or low with a reason), and date checked. Each ends with "Gaps and caveats".

## Licence rule

Anything free to use is in the catalogue, even if it needs attribution. Attribution is tracked in [CREDITS.md](CREDITS.md) and posted in the GitHub repo. The rows are a research snapshot; licences can change, so re-check the source page when an asset is actually adopted.

## Licence legend

| Licence | What it means for Frostmark |
|---------|-----------------------------|
| **CC0** | Public domain. No credit needed (credit is still a courtesy). Safest. |
| **CC-BY** (3.0 / 4.0) | Free for commercial use; credit required. Add it to CREDITS.md. |
| **CC-BY-SA** | Credit required, and adaptations must carry the same licence. Avoid for assets we modify. |
| **OFL** (SIL Open Font Licence 1.1) | Fonts. Free to embed; keep the copyright notice; the font can't be sold on its own. |
| **MIT** | Code, addons, shaders. Keep the copyright and licence notice with copies. |
| **Proprietary but free** | Free to use under the author's own terms, e.g. Mixamo (Adobe account, no redistribution of raw files), Kenney's non-CC0 donationware, Quaternius's own licence on some packs (no redistribution of the asset files). Read the terms in the row. |
| **NC / ND / GPL / other** | Anything with a non-commercial, no-derivatives, copyleft or redistribution clause is flagged in the row's licence column. None of these is safe to ship until the clause has been read. |
| **unverified** | The licence could not be confirmed from the source page. Do not use. |

Frostmark's web build serves the game files publicly, so any licence that forbids redistributing raw asset files needs a second look before it is used.

## Top ten sources for the frozen low-poly look

Ranked by fit with a flat-shaded, top-down, frozen-frontier game and by licence safety.

1. **Quaternius** (CC0): Universal Base Characters, Modular Outfits, Universal Animation Libraries 1 and 2 (shared humanoid rig), Medieval Village MegaKit, Fantasy Props MegaKit, Ultimate Nature, Ultimate RPG Pack. Covers characters, animations, outpost and items in one style. Note the Bestiary pack uses Quaternius's own no-redistribution licence.
2. **KayKit** (CC0): Adventurers, Character Animations (133 clips including fishing, digging and hammering), Dungeon Pack, Resource Bits, Weapons Bits, RPG Tools Bits, Forest Nature. Matching shared atlas for gathering and smithing props.
3. **Kenney 3D kits** (CC0): Survival Kit, Castle Kit, Fantasy Town Kit, Nature Kit. Flat-colour, modular, quick to assemble an outpost, wall and gate.
4. **Kenney UI, particles and audio** (CC0): Fantasy UI Borders, Particle Pack, Impact Sounds, Interface Sounds. The one author that covers panels, effects and core SFX with no credit needed.
5. **Poly Haven and ambientCG** (CC0): snow, ice, rock and wood textures, plus overcast HDRIs. Realistic rather than low-poly, so use for terrain materials and sky only.
6. **game-icons.net** (CC-BY 3.0): about 4,180 SVG icons for skills, items and status. Credit per icon author is required.
7. **Google Fonts** (OFL 1.1): Cinzel for headings, Inter for body text, plus other medieval and pixel options listed in the UI file.
8. **godotshaders and GDScript addons** (CC0 / MIT): ice, frost overlay, snow, toon and outline shaders (several tested on Compatibility), haowg GODOT-VFX-LIBRARY, Godot State Charts, Phantom Camera, GLoot, GUT. Check each shader page, since authors may pick GPL. GDExtension addons such as Terrain3D and LimboAI are a web-export risk.
9. **OpenGameArt CC0 audio and music**: Medieval weapon impacts, Snow theme by Cleyton Kauffman, and other per-asset CC0 or CC-BY items. Fills Kenney's gaps; the file lists the missing wolf, pickaxe and blizzard sounds.
10. **Mixamo** (proprietary, free): fills animation gaps such as a bandit captain and wolf attack. Needs an Adobe ID and raw files can't be redistributed; Adobe's current terms page was not readable, so the terms are partly unverified.

Known gaps across the catalogue: no free bandit or captain model, no CC0 Nordic or snow-themed building kit (CC0 kits will need recolouring), no CC0 ore or ice-formation pack, no aurora skybox, and no CC0 wolf, pickaxe or blizzard audio.
