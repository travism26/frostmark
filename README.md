# Frostmark

Frostmark is a single-player extraction RPG that runs in the browser. It plays top-down with click-to-move and a rotating camera.
You keep one character for the long haul. Its skills level by use, and its gear comes in tiers you can see on it.
Your base is a trading outpost at the edge of a frozen, low-fantasy wilderness. It has a safe stash, and the zones around it get more dangerous the farther out they are.
You head out to gather, fight and loot, and nothing you carry is safe until you walk back through the outpost gate.
If you die you keep your five most valuable items and lose the rest. Your stash is never touched.
Gathered resources pay for outpost upgrades, which work as a tech tree and push the frontier outward.

**Play:** <https://travism26.github.io/frostmark/>. Every merge to main redeploys it.

- [Game brief](docs/game-brief.md): what the game is and why.
- [Roadmap](docs/roadmap.md): the five slices, in ship order.
- [Simulation](docs/simulation.md): the tick, the command and event vocabulary, the state shape, and how the scene glues to it.

## Playing it

1. Start a new character, walk out through the gate and chop pines, then walk back in: crossing the gate banks your pack. Craft a pickaxe and a fishing rod from logs at the workbench.
2. Mine copper and tin beside the outpost, fish the hole north of the walls, and cook the catch at any fire: the outpost's, or one you light from three logs. Warmth drains whenever you are outside.
3. Build upgrades from the stash and your pack, inside the outpost, on the side panel's **Upgrades** tab: the forge unlocks bronze bars, tools, a sword and a bow, and the armoury unlocks a bronze helm, body and legs.
4. Past the line of standing stones is ring one: wolves, bandit archers, frost pines, iron and an ice hole. Read the ring under an enemy and the cue over its head and counter it (a blade up close beats a bow, a bow at range beats a blade), eat to heal, and get home before the cold or a blow takes you.
5. Build the ring-two gate winch, then beat the bandit captain at the far southern gate. He switches between sabre, bow and staff. Once his gate is open it stays open and he stays down.
6. Click the open gate to walk through into ring two: ruins, ice trolls and ruin stalkers. A troll winds up a tick before its crush, so step back; a stalker backs away from a blade and shrugs off a staff, so use a bow or corner it against a wall. An old brazier burns just past the gate. What you carry is still only banked at the outpost gate, a long walk home.
7. Mine coal and rich iron and fish the deep holes in the ruins, bring troll hides home, and build the **blast furnace**: it lifts smithing from bronze to steel, for steel bars, tools, a sword, a bow, a staff and a helm, body and legs.
8. Build **Waystones** after the winch to wake the standing stones in ring one (near the captain's road) and ring two (the far ruins). Walk up to one once to attune it; after that, standing by it, **Travel to the outpost** sets you down outside the gate after three seconds, unless a blow breaks it first. Travel does not bank: walk through the gate for that.

A first character gets short hints for the first outing and tips when it is cold, the pack is full or an enemy winds up; **Hide hints** turns them off, and **Controls** (on the side panel's Settings tab, or on the title screen) lists the controls and can turn them back on. Later characters start with hints off.

Click the ground to walk and anything else to use it. Everything you manage is on the side panel's tabs: Pack, Equipment, Skills, Upgrades and Settings; warmth and health are the two orbs beside it. Click a pack item to equip or eat it (or, by a fire, to cook it), and right-click to drop it; hover anything for what it is. Names in the world show only under the mouse. Q and E, or a middle-mouse drag, rotate the camera; the mouse wheel zooms. Sound starts with your first click; the **Settings** tab sets the volume, the music volume and mute, the interface size (90, 100 or 125 %), reduced motion and auto-retaliate (on by default: hit while standing still, you fight back with the weapon in hand; any move click wins), and credits every sound and icon. If you die you wake by the fire, keeping your five most valuable things; your stash, skills and upgrades are untouched.

Progress is saved in the browser at the gate, after every stash, workbench or upgrade action, on your first walk into ring two, when you attune or travel by a waystone, and on death, so Continue on the title screen picks up where you left off. **Save code** (on the Settings tab) shows your character as a text code; paste it into Import code on the title screen in any browser to carry it over. After 45 minutes of play the game reminds you to copy it. If the browser cannot keep saves (storage full, or blocked as in some private browsing), the game says so and keeps running: the save code is then your save.

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
