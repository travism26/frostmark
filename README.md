# Frostmark

Frostmark is a single-player extraction RPG that runs in the browser. It plays top-down with click-to-move and a rotating camera.
You keep one character for the long haul. Its skills level by use, and its gear comes in tiers you can see on it.
Your base is a trading outpost at the edge of a frozen, low-fantasy wilderness. It has a safe stash, and the zones around it get more dangerous the farther out they are.
You head out to gather, fight and loot, and nothing you carry is safe until you walk back through the outpost gate.
If you die you keep your three most valuable items and lose the rest. Your stash is never touched.
Gathered resources pay for outpost upgrades, which work as a tech tree and push the frontier outward.

**Play:** <https://travism26.github.io/frostmark/>. Every merge to main redeploys it.

- [Game brief](docs/game-brief.md): what the game is and why.
- [Roadmap](docs/roadmap.md): the five slices, in ship order.
- [Simulation](docs/simulation.md): the tick, the command and event vocabulary, the state shape, and how the scene glues to it.

## Playing it

Start a new character on the title screen. Click the gate to walk out, then click a pine to chop it: logs go into your twelve-slot pack and woodcutting levels up as you cut. Warmth drains while you are outside; when it runs out your health starts to fall, so walk back through the gate in time. Crossing the gate inward banks your whole pack into the stash and saves.

Past the trees, over the line into ring one, two wolves wait to the south-west and a bandit archer to the south-east. Your stash starts with a wooden bow, 30 arrows and 5 cooked fish; withdraw them, then click an enemy to fight it. Combat runs on half-second ticks and you strike automatically while in reach. Every enemy shows its next blow over its head one tick before it lands, so counter it. A club up close beats the archer, and the bow at distance beats a wolf. Swapping weapons takes effect on the next tick, or you can step out of reach. Click cooked fish in your pack to eat it: it costs a tick and heals over the next few. Each shot spends an arrow. Dead enemies drop loot; click a pile to pick it up. If you die you wake by the fire, keeping your three most valuable things and losing the rest; your stash and skills are untouched.

Inside the outpost, stand by the fire to warm up. Click the stash to withdraw or deposit, and the workbench to craft a wooden club from four logs. Click a pack item to equip or eat it, right-click to drop it. Q and E, or a middle-mouse drag, rotate the camera; the mouse wheel zooms between fixed limits.

Progress is saved in the browser at the gate, after every stash or workbench action, and on death, so Continue on the title screen picks up where you left off. **Save code** shows your character as a text code; paste it into Import code on the title screen in any browser to carry it over.

## Running it locally

You need Godot 4.5.1 stable, plus its export templates if you want to export.

```sh
godot --headless --import            # once, to build the .godot/ import cache
godot --headless -s tests/run.gd     # unit tests; exits non-zero on any failure
godot --headless --quit-after 30     # smoke run of the main scene
```

To export the web build and play it in a browser:

```sh
mkdir -p build/web && touch build/.gdignore
godot --headless --export-release Web build/web/index.html
python3 -m http.server --directory build/web 8000   # then open http://localhost:8000
```

The export is single-threaded, so it needs no cross-origin isolation headers and runs from any static server, GitHub Pages included.
