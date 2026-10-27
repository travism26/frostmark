## Feature probe: crafting and upgrades (features/craft-and-build.md). A new character carrying
## 11 logs (two stacks: a stack holds 10) smiths a wooden pickaxe at the workbench, then builds
## the stash shelves.
##   AC1 smith: the workbench makes a wooden pickaxe from 3 logs into the pack, and saves
##   AC2 locked recipe: a bronze bar is refused as upgrade_missing before the forge is built
##   AC3 build: the stash shelves take 8 logs, built effects exactly {stash: 4}, capacity 8 -> 12, saves
##   AC4 short build: the forge is refused as missing_inputs; inventory, stash and upgrades unchanged
extends "res://tools/verify/probe_base.gd"

const H := preload("res://tests/sim_helpers.gd")
const Vocab := preload("res://sim/vocab.gd")


func run() -> void:
	var sim := Sim.new()
	H.set_pack(sim, [{"item": "logs", "count": 10}, {"item": "logs", "count": 1}])

	sim.command(Vocab.INTERACT, {"object_id": "workbench"})
	var walk := H.run_until_idle(sim, 200)
	var smith := sim.command(Vocab.SMITH, {"recipe": "wooden_pickaxe"})
	var made := H.run(sim, 2)
	grade("AC1", smith["ok"] and H.of_kind(made, Vocab.EV_CRAFTED).size() == 1
		and H.pack_count(sim, "wooden_pickaxe") == 1 and H.pack_count(sim, "logs") == 8
		and H.where(made, Vocab.EV_SAVED, "reason", "craft").size() == 1,
		{"interacted": H.of_kind(walk, Vocab.EV_INTERACTED), "command": smith,
		"crafted": H.of_kind(made, Vocab.EV_CRAFTED), "pickaxes": H.pack_count(sim, "wooden_pickaxe"),
		"logs": H.pack_count(sim, "logs")})

	var bar := sim.command(Vocab.SMITH, {"recipe": "bronze_bar"})
	grade("AC2", not bar["ok"] and bar["reason"] == "upgrade_missing", {"command": bar})

	var capacity0 := int(sim.state["stash"]["capacity"])
	var build := sim.command(Vocab.BUILD, {"upgrade": "stash_shelves"})
	var built := H.run(sim, 2)
	var built_ev := H.of_kind(built, Vocab.EV_BUILT)
	grade("AC3", build["ok"] and built_ev.size() == 1 and built_ev[0]["upgrade"] == "stash_shelves"
		and built_ev[0]["effects"] == {"stash": 4}
		and "stash_shelves" in sim.state["upgrades"]
		and capacity0 == 8 and int(sim.state["stash"]["capacity"]) == 12
		and H.pack_count(sim, "logs") + H.stash_count(sim, "logs") == 0
		and H.where(built, Vocab.EV_SAVED, "reason", "build").size() == 1,
		{"command": build, "built": built_ev,
		"capacity": [capacity0, int(sim.state["stash"]["capacity"])], "upgrades": sim.state["upgrades"]})

	var before := sim.snapshot()
	var forge := sim.command(Vocab.BUILD, {"upgrade": "forge"})
	H.run(sim, 2)
	grade("AC4", not forge["ok"] and forge["reason"] == "missing_inputs"
		and sim.state["inventory"] == before["inventory"] and sim.state["upgrades"] == before["upgrades"]
		and sim.state["stash"] == before["stash"],
		{"command": forge, "upgrades": sim.state["upgrades"],
		"stash_unchanged": sim.state["stash"] == before["stash"]})
