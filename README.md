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
