# Frostmark character model and animation catalogue

Research for [#63](https://github.com/travism26/frostmark/issues/63). Research date: **2026-10-18**. Nothing was downloaded and no asset, scene or credit was changed.

This goes deeper than [characters-and-animations.md](characters-and-animations.md) (2026-10-16): it is organised by what the game needs (player body, ring one, ring two, animation packs) and records rig, animations, prop handling and gear-slot friendliness for each entry.

## How to read this

- **Rule applied:** CC0 first, then CC-BY with the exact attribution line. Nothing AI-generated. Anything with an unclear licence, a custom "free" licence, NC, ND or SA terms is listed under "Excluded" and never recommended.
- **Licences** were read on each asset's own page (linked in the entry). Where a page could not be read, the cell says **unverified**.
- **Top-down look** is judged from publisher descriptions and previews only, never in engine. Treat it as a guess until a candidate is dropped into a test scene.
- **Poly counts** are "not stated" unless a page gave one.
- **Clip lists and bone names** come from page text, not from opening the files. Check them in the Godot import dialog before wiring anything.
- **Quaternius licence flag.** quaternius.com now has a site-wide [Quaternius Asset License (QAL)](https://quaternius.com/license.html) page, which bans redistributing the assets as assets. The individual pack pages used below still say **License CC0** (re-read on 2026-10-18 for Ultimate Animated Animals, Ultimate Monsters and Modular Character Outfits). We go by the pack page, as the existing CREDITS.md entries do, but re-read the pack page the day an asset is committed and keep a screenshot of it. The Bestiary pack says QAL on its own page and is excluded.
- **Attribution lines.** CC0 needs none. The CC-BY entries have the author's own line where one exists, otherwise they say so, and the line proposed is ours and must be confirmed with the author before use.

## Baseline: the current player (KayKit Adventurers barbarian)

| Field | Value |
|---|---|
| Source | [KayKit Adventurers](https://kaylousberg.itch.io/kaykit-adventurers), Kay Lousberg, CC0 (in CREDITS.md) |
| Format | glb in `assets/models/kaykit_adventurers/` |
| Rig | KayKit `Rig_Medium`, humanoid, with hand attachment bones such as `handslot_r` |
| Animations | Basic set in the pack; further clips from KayKit Character Animations (same rig). Idle, walk, run, chop, fish, spellcast and flinch are in use |
| Props | **Baked in as separate meshes on hand slots**: `1H_Axe`, `1H_Axe_Offhand`, `2H_Axe`, `Barbarian_Round_Shield`, `Mug`, plus `Barbarian_Hat`. PR #77 hides all of them in `character_view.gd` (`BUILT_IN_GEAR`) and draws the sim's equipped gear instead |
| Armour | **Not modular.** The body, legs and head are one skinned mesh with one texture. The only removable pieces are the hat and the cape. #38's helm, body and legs would have to be drawn as extra meshes laid over the body (as `character_gear.gd` does today), not swapped parts |
| Look | Chunky, flat-shaded, single gradient atlas. Reads well at 14 to 32 m. The reference for "fits the look" below |
| Limits | Props cannot be removed from the file (only hidden); no modular armour; one body type |

Any candidate has to beat this on modular armour or props, or match its look and rig for free.

## 1. Player body options

Gear-slot friendliness means: can helm, body and legs (#38) be separate, tiered pieces on the body, and are weapons and tools separate meshes.

| # | Name | Author | Licence | Link | Format | Rig and animations | Props | Polys | Top-down look (from previews) | Fit | Helm / body / legs |
|---|---|---|---|---|---|---|---|---|---|---|---|
| P1 | Modular Character Outfits - Fantasy | Quaternius | CC0 | [pack page](https://quaternius.com/packs/modularcharacteroutfitsfantasy.html), [itch](https://quaternius.itch.io/modular-character-outfits-fantasy) | glTF, FBX, OBJ (Blend in paid tier) | Humanoid rig for the Universal Base Characters; ships no clips, pair with a Universal Animation Library | Weapons not mentioned | not stated | Knight and medieval outfits in 3 colour variants; judged from text only | Medium: realistic proportions, finer than the KayKit barbarian | **Best.** 12 outfits from 62 parts. The page does not name the slots, so confirm head, torso and legs are separate. Free tier holds only some outfits; the rest need the Source tier ($20+) |
| P2 | Universal Base Characters | Quaternius | CC0 | [pack page](https://quaternius.com/packs/universalbasecharacters.html), [itch](https://quaternius.itch.io/universal-base-characters) | glTF, FBX | Humanoid rig that works with the Universal Animation Library; no clips bundled | None | ~13k tris average | Realistic-leaning proportions (Superhero, Regular, Teen) | Low to medium: heavier and less flat-shaded than KayKit | The bare body and 20 hairstyles that P1 dresses. Needed for P1 |
| P3 | Ultimate Modular Women | Quaternius | CC0 | [pack page](https://quaternius.com/packs/ultimatemodularwomen.html) | FBX, OBJ, glTF, Blend | Humanoid rig version, 24 animations | not stated | not stated | not judged | Medium | Fair: 10 characters, each in 4 swappable models; the page does not name the 4 parts |
| P4 | LowPoly Animated Knight | Quaternius | CC0 | [OpenGameArt](https://opengameart.org/content/lowpoly-animated-knight) | FBX, OBJ, Blend | Bone-driven; idle, walk, run, roll, death and more | **Separate:** parent a sword to `Palm.R`; helmet and pads are bone-attached | not stated | not judged | Medium | Partial: one knight with attachable pieces, not a tiered armour split |
| P5 | KayKit Adventurers (extra characters) | Kay Lousberg | CC0 | [itch](https://kaylousberg.itch.io/kaykit-adventurers) | FBX, glTF | Same `Rig_Medium`; basic clips, rest from KayKit Character Animations | 25+ weapons and accessories; the page does not say they are separate files | "low poly optimized" | Same gradient atlas and chunky look as the baseline | **High** (no change of style) | Limited: knight helmet, rogue hood and the Extra-tier barbarian helmet and collar come off; armour is not modular |
| P6 | Amir's modular character pack | Amir | **CC-BY 4.0** (page says "Creative Commons Attribution v4.0 International") | [itch](https://ahmedamirdev.itch.io/amir-the-only-modular-character-pack-youll-ever-need) | FBX, glTF | Fully rigged; 17 clips free, 39 in the paid tiers | Main and off-hand weapons listed as extras; separate files not confirmed | "lowpoly performance", not stated | low-poly, stylised; not stated whether flat-shaded | Unknown | Best on paper: separate Head, Torso, Arms/Hands and Legs/Feet plus hats, masks and backpacks. **Attribution line: none on the page.** Ask the author for one before use (proposed, ours: "Modular character pack by Amir, CC BY 4.0") |
| P7 | Modular RPG Characters | System G6 / Qoma | CC0 (page: "You don't need to credit me") | [OpenGameArt](https://opengameart.org/content/modular-rpg-characters) | .blend + PNG (Blender 2.79b); a commenter says FBX export works | Control and IK rig, ~45 clips each; author says some IK clips are inaccurate | Weapons on separate layers, but placeholders | ~2 to 3k per model | not judged | Low to medium: needs Blender conversion | Poor: only 1 male and 1 female |

**Excluded (licence):** Quin.GS Modular Knights (no licence stated), JustCreate3D modular fantasy (custom terms), Godot-Ready Low Poly Modular Character by gevonstria (CC-BY 4.0 but no attribution line and no formats listed; it does have show/hide Leather, Iron and Naked meshes, so worth asking the author), Fullplate Armor Knight (CC0 but unanimated single figure), Kenney Mini and Blocky Characters (CC0 but toy-like and not modular), Quaternius Ultimate Modular Men (its own page returned 404, only a re-upload by someone else was found).

### Shortlist: player body

1. **P1 + P2 (Quaternius Modular Outfits + Universal Base Characters).** The only fully CC0 route with a real modular outfit system and a humanoid rig built for retargeting. Costs: heavier meshes than KayKit, a Source tier for most outfits, and a rig swap (see section 4). Do a visual test before committing.
2. **P5 (stay on KayKit Adventurers).** Zero risk: same rig, same look, all clips available. For #38, draw tiered helm, body and legs as extra meshes on the body (the approach in `character_gear.gd`). Recommended unless a Quaternius test scene looks right.
3. **P6 (Amir) as a conditional third,** only if the author supplies an attribution line and a preview confirms the look. If not, fall back to P4.

## 2. Ring-one creatures

Ring one: wolves (melee), bandit archers (ranged), the bandit captain at the gate. Current: Quaternius "Wolf" ([Poly Pizza](https://poly.pizza/m/P1gU3Qkr9r)), KayKit rogue (archer), KayKit knight (captain).

### Wolves and fauna

| # | Name | Author | Licence | Link | Format | Rig and animations | Props | Polys | Top-down look | Fit |
|---|---|---|---|---|---|---|---|---|---|---|
| W1 | Ultimate Animated Animal Pack (12 animals: wolf, fox, deer, stag, husky, shiba, cow, donkey, bull, alpaca, two horses) | Quaternius | CC0 | [pack page](https://quaternius.com/packs/ultimateanimatedanimals.html); animal list on the [Poly Pizza bundle](https://poly.pizza/bundle/Animated-Animal-Pack-ILAPXeUYiS) | FBX, OBJ, Blend, glTF | Animated; page names Attack, Death, Kicks, Gallops, Walk, Jump ("12+ unique animations"). Idle and hit not confirmed | n/a | not stated | not judged; same family as the wolf in use | **High:** the one pack for wolves plus fox, deer, stag and a pale canine (husky). No pup or white wolf; recolour instead |
| W2 | Werewolf | br-n518 | CC0 | [OpenGameArt](https://opengameart.org/content/werewolf-0) | 7z source + Godot export zip | idle-loop, idle_sniff, idle_bare_teeth, walk-loop, run-loop, attack, death; no hit | n/a | 892 tris | not judged | Medium: a dire-wolf or elite stand-in, not a wolf |
| W3 | Wolf 1 | Micket | CC0 | [OpenGameArt](https://opengameart.org/content/wolf-1) | zip, contents not listed | Rigged, **no animations** | n/a | 696 tris | not judged | Medium: cheapest base for a white or frost wolf, but animations must be made |
| W4 | Animal Pack Vol.2 (wolf, eagle, dog, cat, piranha) | Quaternius | CC0 | [OpenGameArt](https://opengameart.org/content/animated-animales-low-poly) | zip, formats not listed | Animated, clips not listed; a commenter reports the dog importing oddly in Godot | n/a | not stated | not judged | Low: W1 supersedes it |
| W5 | Wolf Low Poly (Rigged) | crownjoshua | CC0 | [OpenGameArt](https://opengameart.org/content/wolf-low-poly-rigged) | Blend, OBJ, 3DS | Simple rig with spline-IK tail, no clips; jaw not posable | n/a | 318 vertices | not judged | Low: you animate it |
| W6 | Animated Wolf | CoinCoin | CC-BY 4.0 | [OpenGameArt](https://opengameart.org/content/animated-wolf) | zip, formats not listed | Animated, clips not listed | n/a | not stated | not judged | Low: **no attribution line on the page.** Proposed, ours, to confirm: "Animated Wolf by CoinCoin, CC BY 4.0" |
| F1 | Boar | Teh_Bucket | CC0 | [OpenGameArt](https://opengameart.org/content/boar) | Blend only | Rigged, walk and attack only | n/a | ~1k tris | not judged | Low: textured, needs conversion |

**Bears:** no animated CC0 bear was found. The CC0 white bear ([OpenGameArt](https://opengameart.org/content/white-bear-low-poly)) is textured and **not rigged**.

**Excluded:** ManNeko wolf (custom terms), Danimal wolf monsters and umask007 winter wolf (CC-BY-SA), the Poly Pizza Lee Mason wolf (CC-BY 3.0, not stated animated, no attribution line), Sketchfab WildPoly3D wolves (personal use), paid forest-animal kits (licence not stated).

### Bandits (archers, outlaws, captain)

| # | Name | Author | Licence | Link | Format | Rig and animations | Props | Polys | Top-down look | Fit |
|---|---|---|---|---|---|---|---|---|---|---|
| B1 | KayKit Adventurers: rogue_hooded, knight, ranger (5 free, 8 with Extra) | Kay Lousberg | CC0 | [itch](https://kaylousberg.itch.io/kaykit-adventurers) | FBX, glTF | `Rig_Medium`; full set from KayKit Character Animations (bow, melee, hit, death) | 25+ accessories; separate files not confirmed | not stated | Already in the game; reads well | **High.** In use. The Ranger is a second archer, not yet used |
| B2 | Modular Character Outfits - Fantasy + Universal Animation Library | Quaternius | CC0 | see P1 and section 4 | glTF, FBX | Universal humanoid rig | not mentioned | not stated | not judged | Medium: the only route to a distinctly "outlaw" look and many variants; needs retargeting |
| B3 | Ultimate Modular Men | Quaternius | CC0 | [pack page](https://quaternius.com/packs/ultimatemodularcharacters.html) | FBX, OBJ, Blend (glTF mentioned) | 11 characters, 24 animations, 4 swappable models each; clips not listed | not mentioned | not stated | Textured status unclear | Low to medium: older low-poly, per-pack rig |

**Excluded:** Poly Pizza Thug, Wren the thief and Hooded Stranger (CC-BY 3.0, not stated as animated, no attribution line), CoinCoin crossbow skeleton (CC-BY 4.0, no line, clips unlisted), Overaction cartoon pack (paid, licence disputed), Fab "LOWPO Bandit" (no licence stated).

### Shortlist: ring one

- **Wolves: 1. W1** (Quaternius Animated Animals: wolf plus fox, deer, stag, husky; it replaces the single Poly Pizza wolf and gives fauna for free; confirm the idle and hit clips in the file). **2. W2** (werewolf, CC0 with the fullest clip list, for a dire wolf elite). **3. W3** (Micket wolf as a recolourable frost-wolf base; animations must come from elsewhere).
- **Bandits: 1. B1** (stay on KayKit; add the Ranger for archer variety and recolour the rogue per camp). **2. B2** if the player moves to the Quaternius rig.

## 3. Ring-two creatures

Ring two: ruins and real monsters. Current: Quaternius Yeti (ice troll), KayKit Skeleton_Minion (ruin stalker), KayKit mage (frost witch).

| # | Name | Author | Licence | Link | Format | Rig and animations | Props | Polys | Top-down look | Fit |
|---|---|---|---|---|---|---|---|---|---|---|
| M1 | KayKit Skeletons: Minion, Warrior, Rogue, Mage, Skeleton Golem, Necromancer (Golem and Necromancer need the Extra tier, pay-what-you-want) | Kay Lousberg | CC0 | [itch](https://kaylousberg.itch.io/kaykit-skeletons) | FBX, glTF | Rigged with basic movement; full set from KayKit Character Animations (skeleton-specific idle, walk, hit, death, spawn) | Weapons on every character (axe, shield, crossbow, staff, scythe, large Golem weapons); separate files not stated | not stated | Single 1024 gradient atlas, flat, same as the barbarian | **High:** six undead variants plus a Golem mini-boss; Necromancer for a caster |
| M2 | Ultimate Monsters (50 animated) | Quaternius | CC0 | [pack page](https://quaternius.com/packs/ultimatemonsters.html); names on the [Poly Pizza bundle](https://poly.pizza/bundle/Ultimate-Monsters-Bundle-5oyGWAmOB6) | glTF, FBX, OBJ, Blend | Per-model rigs; bundle page names "attack, death, running, walking". Not a shared skeleton | Weapons look baked in; not confirmed | 212.2k tris for the whole 50 (Sketchfab mirror) | Chunky, flat-shaded, same family as the Yeti in use | **High.** Relevant names: Yeti, Wizard, Ghost, Ghost Skull, Demon, Blue Demon, Orc, Dragon, Goleling, Mushroom King, Tribal. The Ghost and Ghost Skull cover a wraith; Goleling covers a golem |
| M3 | Low Poly Ice Age: woolly mammoth, saber-tooth, giant sloth | rkuhlf-assets | CC0 | [itch](https://rkuhlf-assets.itch.io/ice-age) | FBX, Blend, Unity package | Rigged. Mammoth: idle, walk, head shake. Saber-tooth: idle, walk, run, bite. Sloth: idle, walk. **No hit or death**; mammoth has no attack | none | not stated | not judged | Medium: the only large arctic beast found; needs hit and death clips made |
| M4 | Low Poly Ice Skeleton | xTerryx | CC0 | [OpenGameArt](https://opengameart.org/content/low-poly-ice-skeleton) | .blend + 231-byte palette PNG | Attack, Hit, Walk; whether it is rigged is not stated; no idle or death | not stated | not stated | Single-colour palette suits flat shading | Medium: already ice-themed; too thin to rely on |
| M5 | Low Poly Ice Dragon | xTerryx | CC0 | [OpenGameArt](https://opengameart.org/content/low-poly-ice-dragon) | .blend + PNG | Fly and bite only | none | not stated | not judged | Low: possible boss, needs idle, walk and death |
| M6 | Easy Enemy Pack (spider, rat, wasp, frog, snake) | Quaternius | CC0 | [itch](https://quaternius.itch.io/animated-easy-enemies) | FBX, OBJ, Blend | Each has movement, attack, jump, death | none | not stated | not judged | Medium: the spider is a frost-spider repaint candidate |
| M7 | Animated Zombie Pack | Quaternius | CC0 | [pack page](https://quaternius.com/packs/animatedzombie.html) | FBX, OBJ, Blend | 2 models, "many animations", names not listed | not stated | not stated | Atlas textured | Low to medium: draugr repaint candidate |
| M8 | Skeleton | GreyFrogGames | **CC-BY 4.0**, author's line: "Skeleton © 2024 by GreyFrogGames is licensed under CC BY 4.0" | [itch](https://greyfroggames.itch.io/skeleton) | GLB, FBX | Free tier: idle, walk, jump only (attack, run and dead need the $5+ tier) | none mentioned | not stated | not judged | Low: KayKit Skeletons is stronger and needs no credit |
| M9 | Spider - Animated | PantherOne | CC-BY 3.0, credit "Panther-One" (page gives no fuller line) | [OpenGameArt](https://opengameart.org/content/spider-animated) | Blend + PNG | Rigged; 5-keyframe walk, 1-keyframe idle; no attack or death | none | 448 tris | not judged | Low |

**Excluded:** Bestiary Dungeon Monsters Kit (QAL on its own page), Fire/Ice/Stone Golem by umask007 (dual CC-BY 3.0 / CC-BY-SA 3.0 plus texture credit chain, not flat-shaded), Sketchfab Ultimate Monsters mirror (licence field says CC-BY, description says CC0; use the Quaternius page), Sloppy Joe draugr (paid, custom), CGTrader and Fab draugr packs (labelled AI-generated), paid golem, troll and ice elemental models (custom licences), Kenney Graveyard Kit and Mini Dungeon, Pixispider and Earth Dragon (contents or rigging not verifiable).

**Gaps:** no clean frost giant or ogre; no draugr (repaint a skeleton or zombie); no ice golem (only the bone Golem); no rigged bear.

### Shortlist: ring two

1. **M1 KayKit Skeletons.** Six CC0 characters in the current art style on the current rig, with every clip the game needs. Add the Warrior, Mage and Necromancer to the existing Minion; the Golem is a mini-boss candidate.
2. **M2 Ultimate Monsters.** Fifty options in the style of the Yeti already shipped. Ghost, Goleling and Orc are the likeliest picks. Open the glTFs to confirm clip names and whether weapons are separate.
3. **M3 Ice Age mammoth and saber-tooth** for large arctic beasts, if hit and death clips can be made or borrowed.

## 4. Animation packs that retarget onto the current rig

The current player rig is KayKit `Rig_Medium`. Retargeting method, from the Godot docs ([Retargeting 3D Skeletons](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/retargeting_3d_skeletons.html)):

1. Import the player glb with a BoneMap that uses `SkeletonProfileHumanoid`. It maps most bones from common English names; unmapped bones show as warnings.
2. Import each foreign pack the same way, with the same Rest Fixer settings, and save its animations as an AnimationLibrary.
3. Once bones are standardised the library plays on the player's AnimationPlayer. Check hands and feet, since proportions differ. *Overwrite Axis* is the key option for sharing animations and can give bad results if the rest pose matters; *Fix Silhouette* helps A-pose models; *Normalize Position Tracks* limits foot slip between sizes.
4. Keep attachment bones such as `handslot_r` unmapped and attach props to them separately (our inference; the docs do not cover non-humanoid bones). Do not use the *Remove Tracks* options on scenes with animated accessories.
5. KayKit's rest pose is not stated on its pages; check it in the import dialog.

| # | Name | Author | Licence | Link | Format | Source rig | Clips relevant to Frostmark | Retarget effort | Props |
|---|---|---|---|---|---|---|---|---|---|
| A1 | KayKit Character Animations | Kay Lousberg | CC0, no attribution ("CC0 Licensed", itch licence "Creative Commons Zero v1.0 Universal"); page says no generative AI | [itch](https://kaylousberg.itch.io/kaykit-character-animations) | FBX, glTF | `Rig_Medium` (100+ to 161 clips, the page's count varies) and `Rig_Large` (~23 to 25) | Idle, hit, death, spawn, interact, walk, run, jump, crouch, sneak, dodge, 1H/2H melee, unarmed, dual wield, block, bow and magic shoot and aim, emotes. **Update 1.1 tool clips (28):** Chop, Chopping, Dig, Digging, Hammer, Hammering, Pickaxe, Pickaxing, Saw, Sawing, Lockpick, Lockpicking, Holding A/B/C, Work A/B/C, Working A/B/C. **Fishing (7):** Bite, Cast, Catch, Idle, Reeling, Struggling, Tug ([devlog 1.1](https://kaylousberg.itch.io/kaykit-character-animations/devlog/1139588/character-animations-update-11)). Exact melee, bow and staff clip names not confirmed | **None:** same rig | Hands posed only; page pairs them with the KayKit RPG Tools pack and does not say props are baked into clips |
| A2 | Universal Animation Library 2 (UAL2), Standard tier free | Quaternius | CC0 (itch, Quaternius and [OpenGameArt](https://opengameart.org/content/universal-animation-library-2) pages agree) | [itch](https://quaternius.itch.io/universal-animation-library-2), [pack page](https://quaternius.com/packs/universalanimationlibrary2.html) | GLB, FBX | Universal humanoid rig (new naming scheme) | 42 clips free of "130+": sword regular A with combos, melee hook, sword dash, knockback, harvest, plant seed, chest open, overhand throw, walk carry, idles and ninja jump. Fishing and farming are in the full set. Bow, staff cast and mining not mentioned | BoneMap retarget | Not stated; clip names suggest hand poses only |
| A3 | Universal Animation Library (UAL1), Standard tier free | Quaternius | CC0; itch page says "No generative AI was used" | [itch](https://quaternius.itch.io/universal-animation-library), [pack page](https://quaternius.com/packs/universalanimationlibrary.html) | FBX, GLB | Universal humanoid rig | 45 clips free of 120+: 8-direction locomotion, jog, sprint, crawl, swim, sit, death, combat and gun, emotes. Bow, staff and mining not confirmed | BoneMap retarget | Unknown; gun clips imply a held pose |
| A4 | Quaternius animal sets (W1, W4) | Quaternius | CC0 | see section 2 | FBX, glTF | Per-animal skeletons | Attack, Death, Walk, Gallop, Jump (W1) | **Not retargetable to the humanoid.** Only useful with the matching animal model | n/a |

**Not recommended:**
- KayKit Animations (legacy v1, [itch](https://kaylousberg.itch.io/kaykit-animations)): CC0 but for the old leg-less KayKit characters and superseded by A1.
- Mixamo: Adobe terms, not CC0 or CC-BY, raw animation files cannot be redistributed (Adobe's FAQ returned 403, so current terms are unverified).
- Kevin Iglesias Human Crafting and Human Archer Animations (FREE) ([crafting](https://kevdev.itch.io/human-villager-animations-free), [archer](https://kevdev.itch.io/human-archer-animations-free)): the pages state **no licence**, so they are excluded. They are the only leads for mining and a bow shot outside KayKit; the author's support address would settle it.
- Kenney animated characters: CC0 reported only by third-party pages, custom small rigs.

**Gap:** no wolf or quadruped pack retargets onto the humanoid, so each animal needs the clips shipped with its own model. Bow draw, staff cast and mining are covered only by A1 among verified sources, and A1 is on the current rig, so no retargeting is needed for them.

### Shortlist: animation packs

1. **A1 KayKit Character Animations.** Same rig, CC0, and it already has everything the game needs including tools, fishing, melee, bow and magic. Import as an AnimationLibrary and confirm exact clip names.
2. **A2 UAL2** for sword combos, knockback and harvest, only if the player moves to the Quaternius rig (P1/P2) or a clip is missing.
3. **A3 UAL1** for extra death and locomotion clips.

## Recommendation summary

| Area | Top pick | Why |
|---|---|---|
| Player body | Stay on KayKit Adventurers (P5), with #38's helm, body and legs drawn as overlay meshes. Test Quaternius P1 + P2 as the upgrade | KayKit costs nothing and matches the look and rig. Quaternius is the only CC0 route to truly swappable armour, at the cost of a heavier mesh and a rig change |
| Ring one wolves | Quaternius Ultimate Animated Animals (W1) | CC0, glTF, documented attack, death, walk and gallop, and it adds fox, deer, stag and husky |
| Ring one bandits | KayKit rogue and Ranger (B1) | In use, same rig, all clips available |
| Ring two | KayKit Skeletons (M1), then Ultimate Monsters (M2) | CC0, current style and rig for M1; 50 models for M2 |
| Animations | KayKit Character Animations (A1) | Same rig, so no retargeting, and it is the only verified source for tool, fishing, bow and staff clips |

The look is still unproven for every Quaternius humanoid. The first follow-up should be a throwaway test scene (outside this ticket) with P1 + P2 driven by A2 or A3, viewed at 14 m and 32 m beside the barbarian.

## Open items to check on the actual downloads

- Exact clip names in KayKit Character Animations (melee, bow, staff), and the rest pose of `Rig_Medium`.
- Whether the Quaternius Standard (free) tiers include enough outfits (P1), and which slots P1 separates.
- Whether Ultimate Animated Animals has idle and hit clips, and whether Ultimate Monsters weapons are separate meshes.
- Whether Quaternius pack pages move to QAL.
- Attribution lines for Amir (P6) and CoinCoin (W6), if either is used.
