# Frostmark assets: characters and animations

Research date: 2026-10-16. Licences were read from each source's own page on that date; where a page did not show a licence, the cell says "unverified". Nothing was downloaded; file contents (bone names, tri counts, real clip lists) are NOT inspected and must be checked on import.

## Best picks for Frostmark

The strongest, lowest-risk stack is all CC0 and shares one humanoid skeleton: **Quaternius Universal Base Characters** (+ **Modular Character Outfits - Fantasy** for bandit/guard/trader variety) driven by **Quaternius Universal Animation Library 1 and 2** (UAL2 has fishing, farming, melee combos; UAL1 has locomotion, combat, death). Add **KayKit Character Animations** (133 clips incl. 28 tool clips: fishing, digging, hammering - ideal for woodcutting/mining/smithing) and **KayKit Adventurers / Skeletons** for a low-poly flat-shaded look with ready-made weapons, plus the **Quaternius Bestiary - Dungeon Monsters Kit** (QAL licence, free for commercial use but no redistribution) and **Quaternius Ultimate Monsters** for enemies. Wolves are the gap: the best CC0 options are the Quaternius Poly Pizza "Wolf" models and the Animal Pack Vol.2 wolf; the Quaternius "Ultimate Animated Animals" pack page did not list its animals, so confirm a wolf is in it. Mixamo is a useful gap-filler for extra clips but cannot be redistributed as raw files (relevant if this repo is public).

Licence flags used below: **CC0** = no restrictions. **QAL** = Quaternius Asset License v1.0 (free commercial use, no attribution, but you may not resell or redistribute the assets themselves, e.g. committing raw asset files to a public repo is a grey area; treat as a redistribution restriction). **BY** = attribution required.

## Quaternius (quaternius.com)

Site-wide: packs marked CC0 on each pack page. Most "Standard" tiers are free downloads; "Source" tiers (blend + engine setups, including Godot) are paid/Patreon credits.

| Name | URL | Author | Licence | Attribution | Formats | Count/size | Godot 4 notes | Fit | Checked |
|---|---|---|---|---|---|---|---|---|---|
| Universal Base Characters | https://quaternius.com/packs/universalbasecharacters.html | Quaternius | CC0 | none required; none specified | FBX, glTF, OBJ (Standard); Blend (Source) | 6 base characters, 20 hairstyles, 26 models, ~13k tris avg | Humanoid rig built for retargeting; works with UAL. Standard tier is 60-70% of the pack (free); Source tier is paid | high: shared humanoid rig, player + NPC base; tri count higher than flat low-poly style | 2026-10-16 |
| Modular Character Outfits - Fantasy | https://quaternius.com/packs/modularcharacteroutfitsfantasy.html | Quaternius | CC0 | none required; none specified | FBX, glTF, OBJ (Standard); Blend (Source) | 12 outfits, 62 parts, 3 colour variants each (74 models) | Humanoid rig; fits Universal Base Characters + UAL. Source tier includes a Godot implementation with shaders (paid) | high: mix-and-match bandits, guards, traders; also useful for armour tiers | 2026-10-16 |
| Universal Animation Library (UAL1) | https://quaternius.com/packs/universalanimationlibrary.html | Quaternius | CC0 | none required; none specified | FBX, GLB, Blend (Source) | 120+ animations | Universal humanoid rig, designed for Godot/Unity/Unreal retargeting; 8-dir locomotion, combat, death, swim, emotes | high: covers walk/run/combat/death for player and NPCs | 2026-10-16 |
| Universal Animation Library 2 (UAL2) | https://quaternius.com/packs/universalanimationlibrary2.html | Quaternius | CC0 | none required; none specified | FBX, GLB, Blend (Source) | 130+ animations | Same universal humanoid rig; includes melee/armed combos, farming, fishing, zombie locomotion | high: fishing + melee combos map directly to two skills | 2026-10-16 |
| Bestiary - Dungeon Monsters Kit | https://quaternius.com/packs/bestiarydungeonmonsterskit.html | Quaternius | QAL v1.0 (page links /license.html; QAL text read at https://quaternius.com/license.html) | none required (QAL); none specified | FBX, GLB (Standard: OBJ, FBX, glTF; Source: Blend) | 7 monsters with weapons, 3 colour variants each | Rigged; listed as humanoid-rig compatible. Monster list not shown on page | medium: dungeon-flavoured (bandit-camp/ruin enemies need re-skinning); REDISTRIBUTION RESTRICTION under QAL | 2026-10-16 |
| Ultimate Monsters | https://quaternius.com/packs/ultimatemonsters.html | Quaternius | CC0 | none required; none specified | FBX, OBJ, Blend, glTF | 50 animated monsters | Animated; per-monster clip list not shown. Rigs are per-model, not a shared skeleton | medium: ruins/cave monsters; not wolves or humans | 2026-10-16 |
| RPG Character Pack | https://quaternius.com/packs/rpgcharacters.html | Quaternius | CC0 | none required; none specified | FBX, OBJ, Blend | 6 rigged, animated, textured fantasy characters | Per-character rigs; names not listed on page | medium: fantasy hero/NPC archetypes, quick prototyping | 2026-10-16 |
| Ultimate Modular Men Pack | https://quaternius.com/packs/ultimatemodularcharacters.html | Quaternius | CC0 | none required; none specified | FBX, OBJ, Blend (glTF mentioned in text) | 11 characters, 24 animations, 4 swappable parts each | Split into parts; needs assembly on shared skeleton | medium: NPC variety (male); older low-poly look matches flat shading | 2026-10-16 |
| Ultimate Animated Character Pack | https://quaternius.com/packs/ultimatedanimatedcharacter.html | Quaternius | CC0 | none required; none specified | FBX, OBJ, Blend | 52 animated characters | Page shows textured = no (inferred from icon); FBX only, convert/import per model | medium: big NPC/enemy roster, mixed themes | 2026-10-16 |
| Animated Knight Pack | https://quaternius.com/packs/knightcharacter.html | Quaternius | CC0 | none required; none specified | FBX, OBJ, Blend | 10 models (knight, swords, helmets) | Animated, untextured; July 2018 | low: plate knight is too high-tier for early gear; useful for iron-tier player/guard | 2026-10-16 |
| Animated Men Pack | https://quaternius.com/packs/animatedmen.html | Quaternius | CC0 | none required; none specified | FBX, OBJ, Blend | 4 human characters with animations | Per-model rigs | medium: simple NPC humans | 2026-10-16 |
| Easy Enemy Pack | https://quaternius.com/packs/easyenemy.html | Quaternius | CC0 | none required; none specified | FBX, OBJ, Blend | 5 animated, textured enemies | Per-model rigs; January 2019 | low: generic fantasy enemies, not frontier-themed | 2026-10-16 |
| Animated Monster Pack | https://quaternius.com/packs/animatedmonster.html | Quaternius | CC0 | none required; none specified | FBX, OBJ, Blend | 4 animated monsters (untextured) | Per-model rigs | low: generic | 2026-10-16 |
| Animated Zombie Pack | https://quaternius.com/packs/animatedzombie.html | Quaternius | CC0 | none required; none specified | FBX, OBJ, Blend | 2 models, atlas textured | Per-model rig | low: undead; only if the game adds draugr-style enemies | 2026-10-16 |
| Ultimate Animated Animals | https://quaternius.com/packs/ultimateanimatedanimals.html | Quaternius | CC0 | none required; none specified | FBX, OBJ, Blend, glTF | 12 models, "12+ animations" each | Animal list not shown on the page - wolf unconfirmed; verify before relying | medium: wolf/deer/fox likely but unconfirmed | 2026-10-16 |
| Animated Human Low Poly (OGA) | https://opengameart.org/content/animated-human-low-poly | Quaternius | CC0 | none required; none specified | zip (formats not listed; Blender tag) | 1 model; idle, jump, punch, run, walk, work, death | Rigged; format inside zip unverified | low-medium: single base human with a "work" clip | 2026-10-16 |
| Animated Animales Low Poly / Animal Pack Vol.2 (OGA) | https://opengameart.org/content/animated-animales-low-poly | Quaternius | CC0 | none required; none specified | zip (FBX reported by commenters; Blender tag) | wolf, eagle, dog, cat, piranha (2.1 MB) | Formats unverified; piranha could serve fishing | high for wolf/fish: CC0 animated wolf | 2026-10-16 |
| Wolf (Poly Pizza) | https://poly.pizza/m/P1gU3Qkr9r | Quaternius | Public Domain (CC0) | none required; none specified | FBX, glTF | 1 model, tagged Animated (clips not confirmed) | glTF ready for Godot 4 import; check clip names | high: CC0 glTF wolf | 2026-10-16 |
| Wolf #2 (Poly Pizza) | https://poly.pizza/m/XU7oNeKShV | Quaternius | Public Domain (CC0) | none required; none specified | FBX, glTF | 1 model, tagged Animated | As above; likely a second wolf variant | high: wolf variant | 2026-10-16 |

## KayKit (Kay Lousberg, kaylousberg.com / kaylousberg.itch.io)

| Name | URL | Author | Licence | Attribution | Formats | Count/size | Godot 4 notes | Fit | Checked |
|---|---|---|---|---|---|---|---|---|---|
| KayKit Character Animations | https://kaylousberg.com/game-assets/character-animations | Kay Lousberg | CC0 | none required ("no attribution required") | FBX, glTF | 133 humanoid animations (Rig_Medium + Rig_Large); itch update 1.1 added 28 tool clips (fishing, digging, hammering) | Rigged for KayKit characters; usable on other humanoids via Godot retargeting. Free ("name your own price" on itch) | high: tool/melee/ranged clips map to all seven skills | 2026-10-16 |
| KayKit Adventurers | https://kaylousberg.com/game-assets/characters-adventurers | Kay Lousberg | CC0 | none required | FBX, glTF | 5 characters (+3 EXTRA), 25+ weapons/accessories, 1024x1024 gradient atlas | Fully rigged and animated; low-poly flat style | high: matches the low-poly art direction; player/NPC archetypes | 2026-10-16 |
| KayKit Skeletons | https://kaylousberg.com/game-assets/characters-skeletons | Kay Lousberg | CC0 | none required | FBX, glTF | 4 characters (+2 EXTRA), 10+ weapons, 90+ animations | Rigged and animated, single gradient atlas | medium: undead enemies for ruins | 2026-10-16 |
| KayKit Mystery Monthly Series 4 / 5 | https://kaylousberg.itch.io/kaykit-series-5 | Kay Lousberg | unverified (listing paid, from $19.99; licence not shown in search results) | unverified | unverified (includes .blend) | 14+ characters (Series 5), 15+ (Series 4) | n/a | low: paid and licence unverified; listed only for completeness | 2026-10-16 |

## Kenney (kenney.nl)

All Kenney packs are CC0; credit "Kenney.nl" is optional.

| Name | URL | Author | Licence | Attribution | Formats | Count/size | Godot 4 notes | Fit | Checked |
|---|---|---|---|---|---|---|---|---|---|
| Blocky Characters | https://kenney.nl/assets/blocky-characters | Kenney | CC0 | none required; none specified | not stated on page | 20 files; v2.0 "Completely remade"; tagged Animation | Blocky style, voxel-ish; confirm skeleton on import | low-medium: very simple, clashes with a detailed style | 2026-10-16 |
| Mini Characters | https://kenney.nl/assets/mini-characters | Kenney | CC0 | none required; none specified | zip (formats not listed) | 25 files; tagged Animation | Small stylised characters, 2024 | medium: cheap placeholder NPCs | 2026-10-16 |
| Mini Dungeon | https://kenney.nl/assets/mini-dungeon | Kenney | CC0 | none required; none specified | not stated | 30 files; v1.5 notes "Character rig(s)" | Includes some dungeon characters; animation unconfirmed | low-medium: dungeon props + some enemies | 2026-10-16 |
| Mini Arena | https://kenney.nl/assets/mini-arena | Kenney | CC0 | none required; none specified | zip (formats not listed) | 20 files; tagged Animation | Roman arena fighters | low: wrong theme | 2026-10-16 |
| Animated Characters 2 (OGA mirror) | https://opengameart.org/content/animated-characters-2 | Kenney | CC0 | optional ("Credit Kenney.nl ... not mandatory") | zip (formats not listed) | 1 rigged model, 4 skins, 3 animations (idle, jump, run) | Basic; 581 KB | low: minimal animations | 2026-10-16 |
| Animated Characters 3 (OGA mirror) | https://opengameart.org/content/animated-characters-3 | Kenney | CC0 | optional (credit Kenney.nl, not mandatory) | zip (formats not listed) | 1 rigged model, 4 skins, idle/jump/run | 707 KB | low: minimal animations | 2026-10-16 |

## OpenGameArt and itch.io (individual creators)

| Name | URL | Author | Licence | Attribution | Formats | Count/size | Godot 4 notes | Fit | Checked |
|---|---|---|---|---|---|---|---|---|---|
| LowPoly Dummy Character | https://opengameart.org/content/lowpoly-dummy-character | Umplix | CC0 | not required, appreciated | Unity package, FBX, per-animation FBX | 1 character, 10 animations (idle, walk, run, sword idle/taunt/attack x2/charge) | Mixamo-compatible rig; FBX imports directly | medium: sword clips on a neutral dummy; good for rig testing | 2026-10-16 |
| 3D Rigged Character (Plewr) | https://plewr.itch.io/3d-rigged-character | Plewr | CC0 | none specified | GLB, Blender, Mixamo-ready FBX | 1 low-poly character | Includes rigged GLB and a Mixamo FBX for uploading | medium: free Mixamo-ready base | 2026-10-16 |
| Fantasy Pawn Shape 3D Character Pack | https://therulermeasure.itch.io/fantasy-pawn-shape-3d-character-pack | TheRulerMeasure | CC0 | none specified | FBX, glTF, OBJ (OBJ has no rig) | 4 rigged characters, 1 slime, 7 props, 15 animations; name-your-price | Stylised pawn bodies | low-medium: cute style, not frontier-grim | 2026-10-16 |
| Free Cartoon Low-Poly Rigged Character Base | https://overactiongames.itch.io/rigged-character-base-model | Overaction Game Studio | CC0 | none specified | Blender + FBX zip (2 MB) | 1 base model, optional hair; NOT animated | Pair with Mixamo or UAL animations | medium: unanimated rigged base | 2026-10-16 |
| Animated Low-Poly Cartoon Fantasy Character Pack | https://overactiongames.itch.io/medieval-cartoon-character-pack | Overaction Game Studio | CC0 | none specified | FBX, OBJ, Blend; Rigify | 11 characters (warrior, archers, mage, peasant, goblin, hero...); idle/attack/hit/die/walk/run | PAID: from $11.63 | medium: fits low-poly medieval, but not free | 2026-10-16 |
| Low Poly Wolf (ManNeko) | https://manneko.itch.io/low-poly-wolf | ManNeko | custom: "free personal and commercial" (not a CC licence; no formal licence text found) | credit not required, appreciated | FBX, GLB, Blend | 1 wolf; idle, idle2, running, sniffing, falling | GLB imports to Godot 4; name-your-price. Custom terms: no formal text, so redistribution rights are unclear | medium: good wolf but no attack clip | 2026-10-16 |
| Animated Wolf (CoinCoin) | https://opengameart.org/content/animated-wolf | CoinCoin | CC-BY 4.0 | REQUIRED; no credit line specified (suggested: "Wolf by CoinCoin, CC BY 4.0, via OpenGameArt") | zip (3.1 MB; formats not listed) | 1 low-poly wolf; clips viewable on author's Sketchfab | Format unverified | medium: BY, wolf | 2026-10-16 |
| Wolf (Micket) | https://opengameart.org/content/wolf-1 | Micket | CC0 | none specified | zip (formats not listed) | 696 tris, unwrapped and rigged; no animations listed | Needs custom animation | medium: very low-poly wolf, matches flat style | 2026-10-16 |
| Wolf Low Poly (Rigged) | https://opengameart.org/content/wolf-low-poly-rigged | crownjoshua | CC0 | not necessary, appreciated | OBJ, 3DS, Blender | rigged + non-rigged versions; no clips listed | Convert/export from Blender; spline IK tail | low-medium: needs animating, old formats | 2026-10-16 |
| Dog Low Poly (Rigged) | https://opengameart.org/content/dog-low-poly-rigged | crownjoshua | CC0 | none specified | Blend, OBJ | 1428 verts; no animations described | Rig details not listed | low: dog stand-in | 2026-10-16 |
| White Bear (Low poly) | https://opengameart.org/content/white-bear-low-poly | STKRudy85 | CC0 | none required (License.txt included) | 7z archive (formats not listed) | 1 polar bear, textured, NOT rigged | Needs rigging | medium: arctic animal but unrigged | 2026-10-16 |
| Rigged Horse | https://opengameart.org/content/rigged-horse | Lyndon Daniels / ChadM | CC0 | credit to Lyndon Daniels requested, not required | Blend (20 MB) | 1 horse, rigged, no animations; some weights missing per a comment | Needs animation and weight fixes | low | 2026-10-16 |
| Lowpoly animated slime | https://opengameart.org/content/fbx-blend-lowpoly-animated-slime | PINKCANNON | CC0 | none ("Public domain") | FBX, Blend | 304 tris; idle, attack, roam | Note FBX export contained a stray light/plane | low: slime enemy, off-theme | 2026-10-16 |
| Skeleton (GreyFrogGames) | https://greyfroggames.itch.io/skeleton | GreyFrogGames | CC BY 4.0 | REQUIRED/expected ("greatly appreciated"); no credit line specified; no resale/redistribution as-is | GLB, FBX | Free tier: 3 animations (idle, walk, jump); 19 with $5+ tier | Godot compatible | low-medium: undead; KayKit Skeletons is better and CC0 | 2026-10-16 |
| CC0 - 3D Animals / Creatures (curated list) | https://opengameart.org/content/cc0-3d-animals-creatures | various (OGA collection) | CC0 per collection title; per-entry licences NOT individually verified | check each entry; collection CREDITS.TXT available | varies | 71 entries (wolf, bear, deer, boar-like pigs, raven, rabbit, fish, horse, spider, rat) | Use as a shopping list; entries vary in rigging | medium: good source of fauna | 2026-10-16 |

## Poly Pizza (poly.pizza) - mixed licences, check per model

Poly Pizza's front page and search pages do not show licences; per-model pages do. The Terms page returned an error (503) when checked, so site-wide rules were not verified.

| Name | URL | Author | Licence | Attribution | Formats | Count/size | Godot 4 notes | Fit | Checked |
|---|---|---|---|---|---|---|---|---|---|
| Viking | https://poly.pizza/m/6UxTboeQ2G | blaeksprut | CC BY 3.0 | REQUIRED; no credit line specified (suggested: "Viking by blaeksprut, CC BY 3.0, via Poly Pizza") | OBJ, glTF | 1 model; NOT rigged | Static; needs rigging | low-medium: theme fit, no rig | 2026-10-16 |
| Beserker Viking | https://poly.pizza/m/nFpGL0W7CQ | blaeksprut | CC BY 3.0 | REQUIRED; no credit line specified | OBJ, glTF | 1 model; animation not mentioned | Probably static | low-medium | 2026-10-16 |
| Hooded Stranger | https://poly.pizza/m/0domsLgwnKq | Thomas DR | CC BY 3.0 | REQUIRED; no credit line specified | OBJ, glTF | 1 model; rig not stated | Check rig on import | low-medium: bandit/stranger look | 2026-10-16 |
| Agile knight | https://poly.pizza/m/7aYuk5Rdlr- | Spiros Koutsourelis | CC BY 3.0 | REQUIRED; no credit line specified | OBJ, glTF | 1 model; rig not stated | Check on import | low | 2026-10-16 |

## Mixamo (Adobe)

| Name | URL | Author | Licence | Attribution | Formats | Count/size | Godot 4 notes | Fit | Checked |
|---|---|---|---|---|---|---|---|---|---|
| Mixamo | https://www.mixamo.com/ | Adobe | Adobe terms: royalty-free use in commercial games, but NO redistribution of raw character/animation files (per an Adobe community FAQ dated 2022, which describes a preview period; Adobe help page returned 403 so current terms are partly unverified). No ML training use | none required | FBX (download after Adobe ID login) | Large library of humanoid animations; auto-rigger for humanoids | Free with Adobe ID. Do not commit raw Mixamo FBX files to a public repo; ship only inside the built game. Retarget onto the Quaternius/KayKit skeleton | medium: useful extra clips; redistribution restriction | 2026-10-16 |

## Sketchfab (not recommended)

| Name | URL | Author | Licence | Attribution | Formats | Count/size | Godot 4 notes | Fit | Checked |
|---|---|---|---|---|---|---|---|---|---|
| Wolf Baby - Animated Low Poly | https://sketchfab.com/3d-models/wolf-baby-animated-low-poly-0f6a9258d9ee4e34ab3cca6a3e5c090a | WildPoly3D | CONFLICTING: notice says "This version is for personal use only"; commercial only via Patreon version. Treat as NOT usable | n/a | no download shown on page | ~1k tris | n/a | low: licence not usable | 2026-10-16 |
| Wolf - Animated Low Poly | https://sketchfab.com/3d-models/wolf-animated-low-poly-568274b4c7064e8e9bfa43f2e013d0ec | WildPoly3D | personal use only per search snippet (page not opened) | n/a | n/a | n/a | n/a | low: personal-use, unverified | 2026-10-16 |

## Paid, for reference only

| Name | URL | Author | Licence | Attribution | Formats | Count/size | Godot 4 notes | Fit | Checked |
|---|---|---|---|---|---|---|---|---|---|
| Low World forest animals kit (rigged, animated) | https://silver-delivery.itch.io/low-world-forest-animals-kit-rigged-animated | Silver Delivery | NO licence stated on page (a commenter asked about commercial use and got no answer) - unverified; paid $9.99+ | unverified | FBX, GLB, Godot, Unity, Blend | 8 animals (bear, boar, deer, fox, moose, rabbit, stag, wolf), 36 animations; wolf 1556 faces | Ships Godot files; 64x64 texture, flat-shaded style match | high on fit, but licence unverified and paid | 2026-10-16 |

## Gaps and caveats

- **Wolves:** best free option is the Quaternius Poly Pizza wolf (CC0, glTF). Clip names (idle/run/attack) were not confirmed; no free CC0 wolf with a confirmed attack clip was found. The Silver Delivery kit fits best but its licence is unverified and it is paid.
- **Bandits and a bandit captain:** no free CC0 bandit/outlaw character was found. Plan: dress Universal Base Characters with Modular Outfits, or reskin KayKit Adventurers; the captain can be a larger-scale variant with an extra outfit.
- **Frost-specific creatures** (polar bear, arctic fox, frost-wolf variants): only an unrigged CC0 white bear was found.
- **Poly counts** were not stated on most pages; Quaternius Universal characters average ~13k tris, heavier than the flat low-poly target. KayKit is the closer style match.
- **Redistribution:** QAL (Bestiary) and Mixamo forbid redistributing raw files. If this repo is public, keep those files out of git or out of the repo.
- **Licence checking limits:** page content was read through a text-extraction tool; several pages (Kenney, OGA) did not list file formats. The Quaternius "Ultimate Modular Women" and other pack pages were not individually opened. Poly Pizza Terms and Adobe's help FAQ could not be fetched.
- **Paid tiers:** Quaternius "Source" tiers (blend + Godot setups) are paid via Patreon credits; Standard tiers are free.
