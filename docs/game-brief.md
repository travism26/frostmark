# Frostmark: game brief

This brief records what the grill session in [issue #1](https://github.com/travism26/frostmark/issues/1) decided.
It is a brief, not a design document: each decision appears once with the reason it was made.
Anything the session left undecided goes under [Open questions](#open-questions) and is not settled here.

## Pitch

Frostmark is a single-player extraction RPG that runs in the browser. It plays top-down with click-to-move and a rotating camera.
You keep one character for the long haul. Its skills level by use, and its gear comes in tiers you can see on it.
Your base is a trading outpost at the edge of a frozen, low-fantasy wilderness. It has a safe stash, and the zones around it get more dangerous the farther out they are.
You head out to gather, fight and loot, and nothing you carry is safe until you walk back through the outpost gate.
If you die you keep your three most valuable items and lose the rest. Your stash is never touched.
Gathered resources pay for outpost upgrades, which work as a tech tree and push the frontier outward.

## The player it is for

Frostmark is for a player who plays for persistence and progression, the kind who enjoys WoW, Tarkov, Elder Scrolls, Civ V, RuneScape, New World and SWTOR.

- **Tension comes from the loot you're carrying, not from reflexes.** This player bounced off Call of Duty, Fortnite and Apex.
- **They like outplaying an enemy with attack and counter,** so fights are about reading the enemy, not about how fast you click.
- **A few deep systems beat many shallow ones.** Ashfall's building and zombies disappointed because they were thin.
- **They play for about an hour in the evening, at a desk, in short bursts.** One outing has to fit inside a session.
- **The build budget is three to five hours a week.** The fun of building it is playing what you made at a public link, so every slice has to ship playable.

Frostmark is not Ashfall. The earlier survival-sim direction was dropped on purpose, as "reinventing the game we already have".

## Core loop

One outing and one return:

1. Leave through the outpost gate. Warmth starts to drain.
2. Gather (woodcutting, mining, fishing), fight, and loot. Each ring outward is more dangerous and pays more.
3. Find fires to keep warm, and eat food to heal.
4. Choose when to turn back. Every step farther out puts more of what you're carrying at risk.
5. Walk back through the gate. Everything you carry is banked to the stash.
6. Turn your haul into crafted gear (cooking, smithing) and outpost upgrades, which open the next push outward.

## Systems

### Combat

- **Tick-based**, so it's about decisions, not reflexes, and it runs identically on a server later.
- **A combat triangle: melee beats ranged, ranged beats magic, magic beats melee.** It's a readable attack-and-counter rule.
- **Enemies telegraph their next move.** You counter by switching style or gear at the right moment, which is the outplaying this player enjoys.

### Skills

There are seven skills at launch, and each levels by use:

| Group     | Skills                       |
|-----------|------------------------------|
| Gathering | Woodcutting, mining, fishing |
| Crafting  | Cooking, smithing            |
| Combat    | Melee, ranged                |

Gathering feeds crafting, and crafting feeds combat, so all seven skills form one chain instead of sitting side by side.
Magic, farming and the other skills come in later slices. Shipping fewer skills keeps each one deep.

### Survival and cold

- **Cold is the run clock.** Warmth drains whenever you are outside the outpost, so every outing has a natural length without a timer on screen.
- **Only fires restore warmth.** Fires become landmarks you plan routes around.
- **Food is healing, as in RuneScape.** That gives cooking a direct purpose in combat.
- **There are no meters inside the outpost.** The hub is a place to rest, not another thing to manage.

### Extraction and the gate

- **It's one connected world, and you walk home.** The walk back is where the risk to your loot lives.
- **Crossing the outpost gate banks everything.** It's one clear, physical moment where loot becomes safe.
- **Waystones, unlocked later, are shortcuts back from deep zones,** so the outer rings stay reachable within an evening session.

### Outpost and tech tree

- **Upgrades cost gathered resources,** so every outing pays into something lasting.
- **Upgrades unlock stash size, crafting recipes, waystones, and the gate to the next ring.** It's one tree that drives progression, like a Civ-style tech tree, instead of free-placement building.

### Death

- **You keep your three most valuable items and lose the rest. The stash is safe.** Losing hurts enough to make the walk home tense, but never wipes out the long-term character.

### Zones and rings

The zones are concentric rings around the outpost, so danger grows with distance and "how far do I push" is easy to read.

| Ring     | Contents                                               |
|----------|--------------------------------------------------------|
| Inner    | Safe but cold: trees, rocks, a fishing hole            |
| Ring one | Wolves (melee) and bandit archers (ranged)             |
| Ring two | Ruins and real monsters                                |

### Gear tiers

- **The launch tiers are wooden, bronze and iron, and they show on the character.** You can see progress at a glance.
- **Steel and beyond arrive with ring two,** so a new gear tier comes with each new ring of danger.

### Saving

- **Saves are kept locally in the browser, and you can export a save code.** A long-haul character survives a cleared cache or a move to a second computer.

### Players and simulation

- **It's single-player.** That keeps the scope achievable at three to five hours a week.
- **The simulation runs on ticks and keeps all game state in one place,** so co-op can be added later without a rewrite. No networking code gets written now.

## Setting and tone

The setting is a frozen northern frontier with a low-fantasy feel. A trading outpost sits at the edge of the ice.
Ruins out in the wild hint at a story that is never told. The world suggests a past, and the game doesn't spell it out. This also keeps story dialogue out of scope.

## Art direction

The art is low-poly and flat-shaded, built from CC0 packs. It looks clean, reads well from a top-down camera, and runs on the web renderer. The frozen look takes its cue from Whiteout Survival.

Candidate sources (links only, nothing downloaded; licences checked on 2026-10-16):

| Source | Candidate packs | Licence |
|--------|-----------------|---------|
| [Kenney](https://kenney.nl/assets) | [Survival Kit](https://kenney.nl/assets/survival-kit), [Nature Kit](https://kenney.nl/assets/nature-kit), [Castle Kit](https://kenney.nl/assets/castle-kit) | CC0. [Kenney support](https://kenney.nl/support): "all game assets on the asset pages are public domain licensed (CC0)" |
| [Quaternius](https://quaternius.com) | [Ultimate Nature Pack](https://quaternius.com/packs/ultimatenature.html), [RPG Character Pack](https://quaternius.com/packs/rpgcharacters.html) | CC0. [Quaternius FAQ](https://quaternius.com/faq.html): "All models are under the CC0 License." |
| [Poly Pizza](https://poly.pizza) | Individual models, searched per need | **Varies by model.** Some are CC0, and many are CC-BY 3.0, which requires attribution. Check the licence on each model's page. |
| [Mixamo](https://www.mixamo.com) | Character animations | **Not CC0.** Adobe's [Mixamo FAQ](https://helpx.adobe.com/creative-cloud/faq/mixamo-faq.html) says it is royalty-free for games and needs an Adobe ID. Adobe's community FAQ says raw files can't be redistributed on their own. |

Start clean. Borrow from Ashfall by hand only when a particular script earns its place.

## Technical foundation

- **Godot 4.5** is a full 3D engine with a web export.
- **GL Compatibility renderer.** It's the renderer Godot's web export supports, and it runs on ordinary browsers and hardware.
- **Web export, deployed to GitHub Pages on every merge to main.** The game is always playable at a public link.

### Cross-origin isolation headers on GitHub Pages (verified 2026-10-16)

From the [Godot 4.5 web export docs](https://docs.godotengine.org/en/4.5/tutorials/export/exporting_for_web.html):

- A web export built with **Use Threads** relies on `SharedArrayBuffer`. That needs cross-origin isolation, which means two response headers:
  - `Cross-Origin-Opener-Policy: same-origin`
  - `Cross-Origin-Embedder-Policy: require-corp`
- Without those headers, or without the service-worker workaround, the docs say "the project will not run".
- Godot 4.3 added **single-threaded** export. The docs call it "the preferred and now default way" to export for the web, and it doesn't need the headers.
- For hosts that can't send the headers, Godot's export option **Progressive Web App > Enable**, with "Enable Cross Origin Isolation Headers", installs a service worker. The service worker adds the headers once the game first loads.

On GitHub Pages:

- **GitHub Pages can't set custom response headers, so it can't send COOP/COEP itself.** GitHub's Pages docs describe no header configuration. The community request for the feature ([community discussion #13309](https://github.com/orgs/community/discussions/13309)) is still open and unanswered. Its last official-sounding reply, on 2023-07-10, says "No ETA". `<meta http-equiv>` tags can't stand in for these headers.
- **What this means:** the default single-threaded export runs on Pages as is. A threaded export would need the PWA service-worker workaround. Users in that discussion say service-worker workarounds don't always work (one report names `coi-serviceworker` v0.1.7 on Firefox for Windows), so the threaded route is less certain.

## First playable

- **The outpost** has a fire, a stash and one workbench.
- **The safe ring** has trees, rocks and a fishing hole.
- **Ring one** has wolves and bandit archers.
- **A bandit captain** stands at the edge of ring one, guarding the gate to ring two. The first version ends at that gate.
- **All seven skills** are in, with smithing capped at the first metal tier.
- **It takes about thirty minutes to reach the captain.** That fits inside one evening session.

The ship order is in [roadmap.md](roadmap.md): five slices, one per PR, each playable at the public link.

## Explicit non-goals (for now)

- Multiplayer. The simulation is kept co-op-ready, but no networking gets written.
- Free-placement building. The tech tree takes its place.
- Magic and farming, which come in later slices.
- Story dialogue. The ruins imply the story instead.
- A Tarkov-style grid inventory.
- Any gameplay code in the brief task itself.

## Reference games

- **Old School RuneScape (Ironman mode):** skills that level by use, food as healing, tick-based combat, and doing everything yourself.
- **Escape from Tarkov:** tension from risking what you carry, and loot that only counts once you extract.
- **Melvor Idle:** skill chains in which gathering feeds crafting.
- **Valheim:** a cold northern frontier, and progression driven by gear tiers.
- **Zero Sievert:** a top-down extraction loop built around a base.
- **Whiteout Survival:** the look of the frozen world.

## Open questions

The decision list leaves these open. They are recorded here so nobody settles them by accident.

1. **The combat triangle without magic.** **Settled in slice 4:** until magic exists the rule is two-way. Melee has the edge up close and ranged has the edge at distance, and the same style is neutral. Wolves fight in melee and bandit archers at range, and the bandit captain alternates the two. The full triangle (melee beats ranged, ranged beats magic, magic beats melee) widens in when magic arrives with ring two. **Widened in [#23](https://github.com/travism26/frostmark/issues/23):** magic arrived as an eighth skill, ahead of ring two, and the triangle is in. A bow still has the edge on a melee defender at distance, so melee's edge on ranged is the one that needs to be up close.
2. **"Most valuable" on death.** Is value the trade price, the gear tier, or something the player picks? Do stacks count as one item?
3. **Running out of warmth.** What happens when warmth hits zero: damage over time, death, or something else? **Settled in slice 3:** at zero warmth health drains per tick, so a scramble home is possible. Until combat brings the real death rule, health at zero wakes you by the outpost fire with your pack intact.
4. **Waystones and banking.** Does travelling by waystone bank your loot, or does only the outpost gate do that? **Settled in [#24](https://github.com/travism26/frostmark/issues/24):** only the gate banks. A waystone sets you and your pack down just outside the outpost gate, so the last step through it is still yours, and a blow taken while it channels breaks it, so it is a way home and not a way out of a fight.
5. **Web export threading.** Use the single-threaded default, which runs on Pages without headers, or the threaded export plus the service-worker workaround? This should be settled in slice 1. **Settled in slice 1:** Frostmark ships the single-threaded export, which runs on Pages without headers or a service worker.
6. **Asset licence hygiene.** Poly Pizza CC-BY models need attribution and Mixamo isn't CC0. Should the game keep a credits file, or use only CC0 assets?
