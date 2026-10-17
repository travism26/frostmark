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

1. Start a new character, walk out through the gate and chop pines, then walk back in: crossing the gate banks your pack. Craft a pickaxe and a fishing rod from logs at the workbench.
2. Mine copper and tin beside the outpost, fish the hole north of the walls, and cook the catch at any fire: the outpost's, or one you light from three logs. Warmth drains whenever you are outside.
3. Build upgrades from your stash with the **Upgrades** button: the forge unlocks bronze bars, tools, a sword and a bow, and the armoury unlocks bronze armour.
4. Past the red stakes is ring one: wolves, bandit archers, frost pines, iron and an ice hole. Read the cue over an enemy's head and counter it (a blade up close beats a bow, a bow at range beats a blade), eat to heal, and get home before the cold or a blow takes you.
5. Build the ring-two gate winch, then beat the bandit captain at the far southern gate. He switches between sabre and bow. Walk through the gate he guarded to finish the first playable.

Click the ground to walk and anything else to use it. Click a pack item to equip or eat it (or, by a fire, to cook it), and right-click to drop it. Q and E, or a middle-mouse drag, rotate the camera; the mouse wheel zooms. If you die you wake by the fire, keeping your three most valuable things; your stash, skills and upgrades are untouched.

Progress is saved in the browser at the gate, after every stash, workbench or upgrade action, and on death, so Continue on the title screen picks up where you left off. **Save code** shows your character as a text code; paste it into Import code on the title screen in any browser to carry it over.

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
