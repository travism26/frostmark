# Gear sets and set bonuses: RuneScape and World of Warcraft

Research input for issue #138 (gear design). It covers how Old School RuneScape (OSRS), RuneScape 3 (RS3) and World of Warcraft (WoW) build sets and set bonuses, where set pieces come from, how found gear compares with crafted gear, and how unique single pieces fit beside sets.

Words follow `GLOSSARY.md`: a **set** is a named group of pieces, a **set bonus** is what wearing several pieces gives on top of the pieces, and a **unique piece** is a single named piece with one special effect. The games themselves often say "set effect"; this note uses that phrase only when quoting them.

Sources are the OSRS Wiki and RS3 Wiki (both officially endorsed by Jagex), Jagex news posts and Blizzard news and patch notes. Wowhead is used only for WoW item and drop data that Blizzard does not publish, and is marked "(Wowhead)" where it is. Figures marked "my calculation" are worked out here from the cited rates; they are not quoted from any source.

All facts were checked on 27 October 2026. Wiki numbers change with game updates.

---

## 1. Set bonus thresholds: steps, kinds of bonus, scaling

### The four patterns seen

Across the three games, set bonuses come in four shapes.

| Pattern | How it works | Examples |
|---|---|---|
| All or nothing | Nothing until every piece is worn, then one effect | OSRS Barrows, Void Knight, Justiciar, Obsidian |
| Per piece, adding up | Each piece gives a slice; the full set is just the sum | OSRS Crystal armour, Inquisitor's (since July 2026), RS3 Tectonic |
| Per piece plus a completion step | Each piece gives a slice, and the full set adds an extra amount | OSRS Angler outfit, Graceful outfit |
| Thresholds that stack | Bonuses at 2 and 4 pieces (WoW now) or 3, 5 and 8 (WoW Classic); later steps add to earlier ones | WoW class sets, RS3 Elite Dracolich, Tumeken's Resplendence |

The first is all or nothing. The other three are stepped shapes, where wearing more pieces gives more.

### OSRS examples

**Barrows sets (4 pieces, all or nothing, effects).** Each of the six Barrows brothers has a 4-piece set (helm, body, legs, weapon). The set effect needs all four pieces, and the wiki describes no partial bonus. The effects are procs or conditional effects, not flat stats. Examples: Guthan's "Attacks have a 25% chance of replenishing the player's health equal to the damage dealt", Verac's "Attacks have a 25% chance of ignoring any armour, Defence, and protection prayers", and Dharok's damage rising as hitpoints fall, to about +98% at 1 HP. Pieces degrade over 15 hours of combat, and a fully degraded piece loses its stats and breaks the set effect. The Amulet of the damned, a separate item, "enhances the set effects while equipped." Source: https://oldschool.runescape.wiki/w/Barrows_equipment

**Void Knight (4 pieces, all or nothing, percentage boost).** One of three helmets, plus gloves, top and robe. Melee helm: +10% melee damage and accuracy. Ranged helm: +10% ranged damage and accuracy, or 12.5% damage with the elite top and robe. Mage helm: +45% magic accuracy, plus 5% magic damage when elite. The helmet picks the style, so one body serves three styles. Source: https://oldschool.runescape.wiki/w/Void_Knight_equipment

**Inquisitor's armour (3 pieces, per piece, crush only).** It works only with the crush attack style. It boosts crush damage and accuracy by 0.5% for the great helm, 1% for the hauberk and 1% for the plateskirt. Until 22 July 2026 the full set added another 1%. That update moved the extra 1% onto the hauberk and plateskirt, so the set now adds up piece by piece. The wiki's intro and changelog do not fully agree on the helm's value, so treat 0.5% as unconfirmed. A 2024 rule tripled the set effect while wearing the Inquisitor's mace; the 2026 update removed it and gave the mace +7 strength and +7 crush attack instead. Source: https://oldschool.runescape.wiki/w/Inquisitor%27s_armour

**Justiciar armour (3 pieces, all or nothing, damage reduction).** With the full set, incoming damage is reduced by the wearer's relevant defence bonus divided by 3,000. For example, +450 crush defence gives 15% less crush damage. The wiki says the effect needs the full set and does not mention a partial effect. Source: https://oldschool.runescape.wiki/w/Justiciar_armour

**Obsidian armour (3 pieces, all or nothing, tied to a weapon family).** Helmet, platebody and platelegs give "a 10% boost in melee accuracy and melee strength", but only with obsidian melee weapons. Source: https://oldschool.runescape.wiki/w/Obsidian_armour

**Crystal armour (3 pieces, per piece, tied to a weapon).** With the crystal bow or bow of Faerdhinen: helm 5% accuracy and 2.5% damage, body 15% and 7.5%, legs 10% and 5%. The full set gives 30% accuracy and 15% damage, which is just the sum. Source: https://oldschool.runescape.wiki/w/Crystal_armour

**Angler outfit and Graceful outfit (skilling sets, per piece plus a completion step).** Angler pieces give 0.4%, 0.8%, 0.6% and 0.2% extra Fishing XP, which is 2% total. The full set adds 0.5%, for 2.5%. Graceful pieces each add 3–4% run energy restoration, 20% across six pieces. The full set adds another 10%, for 30%. Sources: https://oldschool.runescape.wiki/w/Angler_outfit and https://oldschool.runescape.wiki/w/Graceful_outfit

### RS3 examples

RS3 calls these "set effects" and defines them as passive bonuses that apply once a minimum number of pieces from one set is worn. Source: https://runescape.wiki/w/Set_effect

| Set | Steps | Bonus |
|---|---|---|
| Barrows (Dharok's, Guthan's, Verac's, etc.) | 4 | One effect, as in OSRS |
| Linza's | 5 | Chance to counter-attack when hit |
| Sirenic (Chromatic Choir) | 2 and 3 | 6% chance to trigger enchanted bolt effects; the elite version is 12%, and its 3-piece step adds Onyx and Hydrix bolt effects |
| Tectonic (Fracture Point) | 1 per piece | +1% critical strike chance per piece (elite: 2%) |
| Elite Dracolich | 1, 3, 4, 5 | Per piece adrenaline in Rapid Fire; 3 pieces unlock an infusion with +40% crit chance with a bow; pieces 4 and 5 each make it last 1.8 s longer |
| Tumeken's Resplendence | 3 and 5 | 1.5% crit chance per piece in Sunshine; 5 pieces add a 35% crit damage buff for 9 s |
| Robes of the First Necromancer | 2 and 4 | +7% conjured spirit damage per piece; +5% spirit duration per piece |
| Trimmed masterwork | 3 to 5 | Delays 10% of incoming damage per piece, up to 50% with all five |

All from https://runescape.wiki/w/Set_effect

### WoW examples

**Classic (3, 5 and 8 pieces).** Tier 2 Judgement Armor (paladin) has 8 pieces. At 3 pieces it "increases the radius of a Paladin's auras by 10". At 5 it adds up to 47 spell damage and healing, a flat stat. At 8 it adds extra Holy damage to Judgement, an effect. Source: Wowhead item set data, https://www.wowhead.com/classic/item-set=217/judgement-armor (Blizzard publishes no item set pages).

**Shadowlands 9.2 (2 and 4 of 5).** When class sets returned in Eternity's End, each set had 5 pieces (head, shoulders, chest, hands, legs). Equipping two or four pieces grants bonuses specific to your specialization. Source: https://news.blizzard.com/en-us/article/23778646/shadowlands-eternitys-end-class-set-preview

**Dragonflight onward.** The same shape continued: "Earn bonuses to your abilities based on your specialization when equipping two Primalist set pieces and four Primalist set pieces." Source: https://news.blizzard.com/en-us/article/23892221/dragonflight-season-1-content-update-notes

**What modern WoW bonuses are like.** They are almost always effects that change how abilities behave, not flat stats. Blizzard retunes them often. One Dragonflight 4-piece was redesigned into "a 20% chance to make your next Raptor Strike/Mongoose Bite, Carve, and Butchery cost 10 less Focus and deal 40% increased damage." Blizzard also cut a Season 1 set because it was so strong that players would not move to Season 2's set, raising the class's base damage to make up for it. Sources: https://news.blizzard.com/en-us/article/23892227/updated-january-24-dragonflight-10-0-5-content-update-notes and https://news.blizzard.com/en-us/article/23935248/dragonflight-embers-of-neltharion-content-update-notesnow-live. The exact quotes come from search excerpts of those patch notes and were not re-read on the full pages.

### How bonuses scale up the gear ladder

- **OSRS does not scale one bonus across tiers.** Each set has its own fixed effect, and newer, higher sets get different effects, not bigger versions of the same one. Barrows (Defence 70) gives procs. Justiciar, from a top raid, gives damage reduction that scales with the set's own defence stat. Source pages above.
- **WoW resets the set every season.** Each raid tier brings a new set with new bonuses. The new pieces also have higher item levels. Dragonflight Season 3 raised item levels by 39 over Season 2, more than the usual 26, so new gear would be "a useful upgrade over the previous season's gear immediately." Source: https://worldofwarcraft.blizzard.com/en-us/news/24017505
- **RS3 scales inside a family.** The elite version of a set gives a bigger version of the same bonus: Sirenic bolt-proc chance 6% to 12%, Tectonic crit 1% to 2% per piece. Source: https://runescape.wiki/w/Set_effect

---

## 2. Where dropped set pieces come from

### OSRS Barrows: separate pieces, duplicate protection inside a chest

- The chest gives 1 roll, plus 1 per brother killed, up to 7. Source: https://oldschool.runescape.wiki/w/Chest_(Barrows)
- The chance that a roll gives a piece is 1 / (450 − 58 × brothers killed): 1/392 for one brother, 1/102 for six. Only pieces from brothers you killed can drop. Same source.
- **Duplicate protection inside one chest:** a piece picked in a chest cannot be picked again on later rolls of that chest. There is no protection across chests. Same source.
- With all six brothers killed: about 1/15 chance of at least one piece per chest, and about 1/350 chance of a specific piece. Same source.
- The wiki's money-making guide assumes 12 chests an hour, and up to about 20 with maximum gear. Source: https://oldschool.runescape.wiki/w/Money_making_guide/Barrows

### OSRS bosses and minigames

- **The Nightmare (Inquisitor's):** the armour, mace and staff table hits at 1/83.33 per kill. Each Inquisitor's piece is between 1/420 and 1/240 depending on party size. Uniques go to one player, chosen by a weighted roll on damage dealt. Source: https://oldschool.runescape.wiki/w/The_Nightmare
- **Theatre of Blood (Justiciar):** about a 1 in 9.1 (11%) chance of a unique per raid at normal difficulty with no deaths. The unique is picked by weight out of 19, and each Justiciar piece has weight 2. One player gets it. Source: https://oldschool.runescape.wiki/w/Monumental_chest
- **The Gauntlet (Crystal armour seeds):** 1/120 per normal chest, 1/50 per Corrupted chest. A full set needs 6 seeds. Source: https://oldschool.runescape.wiki/w/Crystal_armour_seed
- **Void Knight is not a drop.** Pieces are bought with Pest Control points: 850 points for one helmet plus gloves, top and robe. That takes 107 to 284 wins, or about 3.5 to 9.5 hours in ideal conditions. The wiki says a realistic run for a new player is 12–14 hours. Source: https://oldschool.runescape.wiki/w/Void_Knight_equipment

### Time to complete an OSRS set

| Set | Source | Odds | Expected attempts for the full set | Time |
|---|---|---|---|---|
| Any one Barrows set | Barrows chest (6 brothers) | ~1/15 for any piece per chest | ~313 chests (wiki) | ~26 h at 12/h (my calculation) |
| A specific Barrows set | Barrows chest | ~1/350 per specific piece | ~728 chests (wiki) | ~61 h at 12/h (my calculation) |
| All six Barrows sets | Barrows chest | as above | ~1,319 chests (wiki) | ~110 h at 12/h (my calculation) |
| Justiciar (3 pieces) | Theatre of Blood | each piece ~1/86 per raid (my calculation: 11% × 2/19) | ~158 raids for the team, more for one player (my calculation) | not stated |
| Inquisitor's (3 pieces) | The Nightmare | each piece 1/420 at the low end | ~770 kills for the team at 1/420 (my calculation) | not stated |
| Crystal armour (6 seeds) | Corrupted Gauntlet | 1/50 per chest | ~300 chests (my calculation) | not stated |
| Void Knight | Pest Control points | fixed cost | 107–284 wins | 3.5–14 h (wiki) |

Chest counts are from https://oldschool.runescape.wiki/w/Chest_(Barrows); the hourly rate is from https://oldschool.runescape.wiki/w/Money_making_guide/Barrows. The full-set figures for the raid sets use the coupon-collector formula: for k equally likely pieces at p each, the expected attempts are (1/p) × (1 + 1/2 + … + 1/k).

### Bad-luck protection in RS3

RS3 has "bad luck mitigation": a rare drop becomes more likely after a player goes long enough without it, and some become guaranteed. Examples: King Black Dragon lore drops are guaranteed at 2,000 solo kills; some journals are guaranteed every 200 kills; boss pet rates rise at kill-count thresholds. Archaeology artefacts get duplicate protection: each repeat of the same artefact halves your chance of getting it again. Source: https://runescape.wiki/w/Bad_luck_mitigation

I found no general bad-luck protection for OSRS set gear. The only protection found is inside a single Barrows chest.

### WoW: tokens, the Great Vault and the Catalyst

- **Bosses drop slot tokens, not pieces.** In Sepulcher of the First Ones, each of five bosses dropped one set slot: Halondrus legs, Lihuvim hands, Anduin head, Lords of Dread shoulders, Rygelon chest. Each boss drops at least one token, more in bigger groups. A token turns into your own class's piece. Source: https://news.blizzard.com/en-us/article/23778646/shadowlands-eternitys-end-class-set-preview
- **Token rate.** In Dragonflight Season 3, "tier armor tokens will continue to drop at the current 1:3 rate relative to non-tier loot." Source: https://news.blizzard.com/en-us/world-of-warcraft/24020034/
- **Great Vault.** Weekly activity (raid bosses, Mythic+ dungeons, rated PvP) can offer a set piece in next week's vault. Source: https://news.blizzard.com/en-us/article/23778646/shadowlands-eternitys-end-class-set-preview
- **Catalyst (the main bad-luck protection).** The Creation Catalyst "turn[s] any non-set pieces of the appropriate slot into a new set piece of the same item level." Each charge converts one item. Charges build slowly at first and speed up later in the season, so alternate characters can catch up. Same source.
- **Catalyst pacing.** Dragonflight Season 3: the Catalyst opened in week 1, and players gained "a charge every two weeks instead of every week." Source: https://news.blizzard.com/en-us/world-of-warcraft/24020034/
- **Midnight (2026).** Getting the 4-piece bonus unlocks a per-character Feat of Strength. After that, Catalyst charges can drop from raid bosses, Mythic+, Bountiful Delves and rated PvP for the rest of the season. Blizzard's aim: players should not hold back from catalysing early, since more charges "will likely be farmable for them just several weeks into the season." Source: https://news.blizzard.com/en-us/article/24244646/midnight-content-update-notes

**What this adds up to:** WoW makes sure a regular player can get the 2-piece and 4-piece within a season, through several sources plus a converter. OSRS leaves full sets to raw drop odds and expects tens of hours per set.

---

## 3. Found gear against crafted gear of the same tier

### OSRS: Smithing makes the floor, drops make the ceiling

- **Smithed armour stops at rune, and rune is behind Barrows.** A rune platebody needs 99 Smithing and 5 runite bars. It gives +82 stab, +80 slash and +72 crush defence and needs Defence 40. Dharok's platebody, from Barrows, gives +122, +120 and +107 and needs Defence 70. So the top smithed body has about two-thirds of the defence of a mid-level dropped body. Sources: https://oldschool.runescape.wiki/w/Rune_platebody and https://oldschool.runescape.wiki/w/Dharok%27s_platebody
- **Smithed bodies have no set effects.** None of the smithed metal pieces checked had one. Source: https://oldschool.runescape.wiki/w/Smithing
- **Crafting stays useful by turning drops into gear.** The best "crafted" OSRS gear is built from dropped parts.
  - Dragon platebody: Smithing 90 assembles a dragon chainbody, a dragon metal lump and a dragon metal shard. Source: https://oldschool.runescape.wiki/w/Dragon_platebody
  - Crystal armour: dropped seeds plus shards, sung at Crafting and Smithing 70–74. Source: https://oldschool.runescape.wiki/w/Crystal_armour
  - Amulet of fury: an onyx amulet enchanted with Magic 87. Source: https://oldschool.runescape.wiki/w/Amulet_of_fury
- **Lower tiers.** Bronze platebody needs Smithing 18, iron 33, steel 48, mithril 68, adamant 88, rune 99. Source: https://oldschool.runescape.wiki/w/Smithing. This bronze–iron–steel ladder matches Frostmark's tiers. In OSRS, smithed gear is the normal early and mid route, and drops take over at the top.

### RS3: crafting reaches endgame on purpose

- The 2019 Mining and Smithing rework added Masterwork armour, "tier 90 power armour", the same tier as boss-dropped Malevolent, Sirenic and Tectonic. Jagex said: "Masterwork armour can be made with just the mining and smithing skills, so it's a great way for Ironmen and non-bossers to get hold of endgame armour." The cost is high: "A full set of masterwork takes 600 bars of each core metal to make." Source: https://secure.runescape.com/m=news/mining-and-smithing-rework
- The next step, Trimmed masterwork, is tier 92 and adds a set effect. It is made from Masterwork plus boss-dropped components, so the top version still needs drops. Same source, and https://runescape.wiki/w/Masterwork_armour
- The RS3 Wiki calls Masterwork "far superior" to Malevolent in upkeep. Malevolent "degrades to dust", while Masterwork can be repaired. Source: https://runescape.wiki/w/Malevolent_armour
- So in RS3, crafting matches drops on stats at tier 90. Crafting costs time and materials, while drops cost luck. The tier above needs both.

### WoW: crafted gear sits just under the top raid gear

- **Upgrade tracks set the ceiling for each source.** In Dragonflight 10.1 the tracks were Explorer 376–398, Adventurer 389–411, Veteran 402–424 (Raid Finder), Champion 415–437 (Normal), Hero 428–441 and Mythic 441 and up. Blizzard: "Anything that's at an item level comparable to a Mythic Raid isn't going to be upgradable," and "you'll still need to earn gear from drops." Source: https://worldofwarcraft.blizzard.com/en-us/news/23923485/developer-insights-new-upgrade-system-in-embers-of-neltharion
- **Crafted gear uses crests from the content you do.** The highest crest tiers come only from Heroic and Mythic content. So the best crafts still need you to clear hard content, but you choose the slot and piece. Same source.
- **Midnight Season 2 numbers (Wowhead; Blizzard does not publish the table).** Rare crafts reach item level 266–292. Epic crafts reach 305–318 with Hero crests and 318–331 with Myth crests. Myth crests come from Mythic raids, Mythic+ +9 and up, and similar content. Source: https://www.wowhead.com/guide/midnight/item-level-gear-upgrades-dawncrests. Wowhead also reports that Myth-track gear tops out at 344 in Season 2, quoting Blizzard's post on a 46 item-level seasonal step. Source: https://www.wowhead.com/news/item-levels-increasing-in-midnight-season-2-382120. On those numbers, the best craft sits about 13 item levels, one track step, below the best raid drops (my calculation; the track table is only an image, so I could not check the exact ranges).
- **Crafted gear is never a class-set piece.** The Catalyst converts any non-set item in the right slot into a set piece "of the same item level", so a crafted piece could in principle feed the Catalyst. Blizzard's notes do not single out crafted items here. Source: https://news.blizzard.com/en-us/article/23778646/shadowlands-eternitys-end-class-set-preview
- **Why crafting stays worth it in WoW:** you can pick the slot you are missing, it is reliable when drops are not, and it helps upgrades. Blizzard: "The crafted gear will help you with upgrading other things." Source: https://worldofwarcraft.blizzard.com/en-us/news/23923485/developer-insights-new-upgrade-system-in-embers-of-neltharion

### Summary of the three approaches

| Game | Crafted gear at the same tier as drops? | Gap | Why craft? |
|---|---|---|---|
| OSRS | No, smithing stops below the dropped tiers | Rune ~⅔ of Barrows defence | Early and mid gear; assembling dropped parts into top items |
| RS3 | Yes, at tier 90 | Same stats, cheaper upkeep | Sure path for non-bossers; needed for the tier-92 upgrade |
| WoW | Just below the top | ~1 track step under Mythic drops (Wowhead numbers) | Pick your slot, fill gaps, no luck |

---

## 4. Unique single pieces and how they live beside sets

| Item | Slot | What it is | How you get it | Source |
|---|---|---|---|---|
| Berserker ring | Ring | +4 strength, +4 crush defence; imbuing doubles it | 1/128 from Dagannoth Rex | https://oldschool.runescape.wiki/w/Berserker_ring |
| Fire cape | Cape | +11 to all defences, +4 strength, +2 prayer; second-best melee cape | Guaranteed for beating TzTok-Jad after 63 waves; not tradeable | https://oldschool.runescape.wiki/w/Fire_cape and https://oldschool.runescape.wiki/w/Fight_Caves |
| Infernal cape | Cape | +12 to all defences, +8 strength, +4 melee attack | Beat TzKal-Zuk in the Inferno; you give a fire cape to enter | https://oldschool.runescape.wiki/w/Infernal_cape and https://oldschool.runescape.wiki/w/Inferno |
| Amulet of fury | Amulet | +10 all attacks, +15 all defences, +8 strength, +5 prayer; "the most versatile amulet" | Crafted: onyx amulet, Magic 87 enchant | https://oldschool.runescape.wiki/w/Amulet_of_fury |
| Dragon defender | Shield | +25/+24/+23 attack and defence, +6 strength | 1/100 from level 106 Cyclopes in the Warriors' Guild; showing a rune defender unlocks the basement | https://oldschool.runescape.wiki/w/Dragon_defender |

### How they avoid overshadowing sets

- **They use slots the sets leave empty.** Barrows sets are helm, body, legs and weapon (https://oldschool.runescape.wiki/w/Barrows_equipment). Justiciar and Inquisitor's are helm, body and legs. None of them use the cape, amulet, ring or shield slots, and that is where the fire cape, fury, berserker ring and dragon defender go. So a unique adds to a set and never competes with it. I found no Jagex statement that this is a written rule; it is what the item data shows.
- **Their bonuses are mostly flat stats, not effects.** All five examples are stat items. Effects mostly live in sets. Newer variants add an effect on top: the Amulet of blood fury keeps the fury's stats and adds "a 20% chance to heal 30% of melee damage dealt" (https://oldschool.runescape.wiki/w/Amulet_of_fury).
- **They upgrade in a line inside their own slot.** Fire cape leads to Infernal cape, which you can only start by giving up a fire cape. Rune defender leads to dragon defender, which you can only farm after showing a rune defender. Sources as in the table.
- **Some are earned, not rolled.** The fire and infernal capes are guaranteed rewards for a hard challenge, not random drops.
- **Specialists beat them in narrow roles.** The Amulet of torture beats fury for melee attack and strength, but has no defence. So the all-rounder stays useful and specialists win specific fights. Source: https://oldschool.runescape.wiki/w/Amulet_of_fury

---

## What this suggests for Frostmark

These are suggestions for the grilling, not decisions.

1. **Percent bonuses at Frostmark's defence scale.** Defence is 0–2 per piece and 4 for full steel. A 10% boost to defence means nothing at that size, so Justiciar-style reductions based on defence would round to zero. Barrows- and WoW-style effects ("25% chance to heal", "ignore defence") or small flat steps (+1 defence, +1 damage) will feel much larger.
2. **Stacking steps already have models.** The glossary says each step adds to the ones before. Angler and Graceful (per piece plus a completion step) and WoW's 2 and 4 pieces both fit. With 4–6 piece sets, one option is a small flat step at 2 pieces, a second at 4, and an effect at the full set. Avoid the all-or-nothing Barrows shape, which makes a 3-of-4 set feel like nothing.
3. **Scale effects, not just numbers, up the ladder.** RS3's elite versions (6% to 12%, 1% to 2%) show one effect can grow from mid to high set. OSRS and WoW show that new effects per tier also work. Making the mid, mid-high and high set of one style the same effect at growing size would keep 21 sets readable.
4. **Drop odds against 3–5 hours a week.** OSRS-level set hunts (60 hours for a specific Barrows set) would be 12–20 weeks of Frostmark play. If each piece of a 5-piece set dropped at the rarity bands, the expected kills for the full set would be:

   | Band | Per-kill chance | No duplicate protection (5 pieces) | Rolls always give a missing piece | (my calculation) |
   |---|---|---|---|---|
   | Uncommon | 1/10 per kill | ~114 kills | 50 kills | |
   | Rare | 1/150 per kill | ~1,712 kills | 750 kills | |
   | Super rare | 1/25 per boss kill | ~285 boss kills | 125 boss kills | |
   | Ultra rare | 1/250 per boss kill | ~2,854 boss kills | 1,250 boss kills | |

   The "no protection" column uses the coupon formula: (1/p) × 5 × (1 + ½ + ⅓ + ¼ + ⅕), with p the band rate divided across 5 pieces. Turn kills into hours with Frostmark's own kill rate. Rare and ultra-rare sets look out of reach for this player unless pieces drop separately from several enemies, or there is protection.
5. **Choose a protection.** The options found: Barrows-style no repeats within one reward; RS3-style rates that rise after a dry streak, or guaranteed drops at a kill count; and WoW's Catalyst, which converts a spare piece into a missing set piece. "A roll on a set always gives a piece you lack" is the simplest and roughly halves the grind in the table.
6. **Make crafting the floor and drops the ceiling, or match them at a cost.** OSRS: smithed sets are the reliable early and mid route, and dropped sets are better. RS3: crafted gear matches drops at a high material cost. WoW: crafted gear is one step under the top. For Frostmark's craftable top sets made from rare materials, the OSRS dragon/crystal and RS3 trimmed-masterwork pattern fits: drops give the materials, and crafting turns them into the set. That keeps crafting relevant at the top without crafting skipping the luck.
7. **Put unique pieces in tool, quiver or cape.** OSRS keeps uniques in slots that sets do not use (cape, ring, amulet, shield). If Frostmark sets use helm, body, legs and maybe weapon, the tool, quiver and cape slots are the natural home for unique pieces. A 6-piece set would take most of the 7 slots, which leaves little room. That argues for keeping most sets at 4–5 pieces, or leaving at least the cape slot out of every set.
8. **A guaranteed unique for a hard challenge.** The fire cape model (a sure reward for a boss challenge, with a harder upgrade that needs the first one) gives a short-session player a goal that luck cannot block.

---

## Sources

OSRS Wiki (official, endorsed by Jagex):
- https://oldschool.runescape.wiki/w/Barrows_equipment
- https://oldschool.runescape.wiki/w/Chest_(Barrows)
- https://oldschool.runescape.wiki/w/Money_making_guide/Barrows
- https://oldschool.runescape.wiki/w/Void_Knight_equipment
- https://oldschool.runescape.wiki/w/Inquisitor%27s_armour
- https://oldschool.runescape.wiki/w/The_Nightmare
- https://oldschool.runescape.wiki/w/Justiciar_armour
- https://oldschool.runescape.wiki/w/Monumental_chest
- https://oldschool.runescape.wiki/w/Obsidian_armour
- https://oldschool.runescape.wiki/w/Crystal_armour
- https://oldschool.runescape.wiki/w/Crystal_armour_seed
- https://oldschool.runescape.wiki/w/Angler_outfit
- https://oldschool.runescape.wiki/w/Graceful_outfit
- https://oldschool.runescape.wiki/w/Smithing
- https://oldschool.runescape.wiki/w/Rune_platebody
- https://oldschool.runescape.wiki/w/Dharok%27s_platebody
- https://oldschool.runescape.wiki/w/Dragon_platebody
- https://oldschool.runescape.wiki/w/Berserker_ring
- https://oldschool.runescape.wiki/w/Fire_cape
- https://oldschool.runescape.wiki/w/Fight_Caves
- https://oldschool.runescape.wiki/w/Infernal_cape
- https://oldschool.runescape.wiki/w/Inferno
- https://oldschool.runescape.wiki/w/Amulet_of_fury
- https://oldschool.runescape.wiki/w/Dragon_defender

RS3 Wiki (official) and Jagex:
- https://runescape.wiki/w/Set_effect
- https://runescape.wiki/w/Masterwork_armour
- https://runescape.wiki/w/Malevolent_armour
- https://runescape.wiki/w/Bad_luck_mitigation
- https://secure.runescape.com/m=news/mining-and-smithing-rework (Jagex news, 2019)

Blizzard:
- https://news.blizzard.com/en-us/article/23778646/shadowlands-eternitys-end-class-set-preview
- https://news.blizzard.com/en-us/article/23892221/dragonflight-season-1-content-update-notes
- https://news.blizzard.com/en-us/article/23892227/updated-january-24-dragonflight-10-0-5-content-update-notes
- https://news.blizzard.com/en-us/article/23935248/dragonflight-embers-of-neltharion-content-update-notesnow-live
- https://worldofwarcraft.blizzard.com/en-us/news/23923485/developer-insights-new-upgrade-system-in-embers-of-neltharion
- https://news.blizzard.com/en-us/article/23944889/embers-of-neltharion-upgrade-system-overview
- https://worldofwarcraft.blizzard.com/en-us/news/24017505 (Dragonflight Season 3 upgrade changes)
- https://news.blizzard.com/en-us/world-of-warcraft/24020034/ (Guardians of the Dream notes)
- https://news.blizzard.com/en-us/article/24244646/midnight-content-update-notes

Wowhead (item and drop data only, where Blizzard publishes none):
- https://www.wowhead.com/classic/item-set=217/judgement-armor
- https://www.wowhead.com/guide/midnight/item-level-gear-upgrades-dawncrests
- https://www.wowhead.com/news/item-levels-increasing-in-midnight-season-2-382120 (quotes a Blizzard forum post)

### Not verified

- Inquisitor's great helm value after the July 2026 update: the wiki's intro and changelog do not fully agree.
- Exact Midnight upgrade-track ranges: Wowhead shows them only as an image. The Myth top of 344 is Wowhead's figure.
- Any Jagex statement that unique pieces are kept to slots sets do not use: none found. It is inferred from item data.
- Theatre of Blood and Nightmare hours per full set: no source gives completion times, only per-raid or per-kill odds.
