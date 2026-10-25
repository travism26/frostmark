## One tooltip for everything the player hovers: a tinted badge, a Cinzel title, body lines
## and a muted footnote on the frosted frame. `item()` builds it for a pack, stash or
## equipment slot (tier, weight and value, what it crafts into and builds, what a click does) and
## `skill()` for a skill cell (level, xp to go, the next unlock). Hosts are `UiTooltip.Host`
## buttons: Godot asks a Control for its tooltip through `_make_custom_tooltip`, so a host
## keeps a Callable that builds the control fresh on each hover from the live state.
##
## Glue only: it reads the tables and `sim` and changes nothing.
class_name UiTooltip
extends PanelContainer

const WIDTH := 250.0


## A button whose tooltip is built by `make` on each hover. `set_tip(Callable())` for none.
class Host:
	extends Button
	var make: Callable

	func set_tip(builder: Callable) -> void:
		make = builder
		tooltip_text = " " if builder.is_valid() else ""

	func _make_custom_tooltip(_for_text: String) -> Object:
		if not make.is_valid():
			return null
		return make.call()


## The control itself: badge and title on one line, then the body lines, then the note.
static func build(icon_key: String, title: String, lines: Array[String], note := "") -> UiTooltip:
	var tip := UiTooltip.new()
	tip.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	column.custom_minimum_size = Vector2(WIDTH, 0)
	tip.add_child(column)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	column.add_child(head)
	if icon_key != "" and IconTable.has(icon_key):
		head.add_child(UiTheme.badge(icon_key, 26))
	var heading := UiTheme.heading(title, 14)
	heading.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(heading)
	for line in lines:
		var l := UiTheme.body(line, 13)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(l)
	if note != "":
		var n := UiTheme.muted(note, 12)
		n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(n)
	return tip


## An item's tooltip: its tier, weight and value, what it does or crafts into, and `verb`
## (what a click does here), with the drop reminder as the note.
static func item(kind: String, verb := "", note := "Right-click to drop.") -> UiTooltip:
	return build(kind, ItemTable.label(kind), item_lines(kind, verb), note)


## The body lines of `kind`'s tooltip, with `verb` last when given. Pure: it reads the tables only.
static func item_lines(kind: String, verb := "") -> Array[String]:
	var lines: Array[String] = []
	var tier := ItemTable.tier(kind)
	var facts: PackedStringArray = []
	if tier != "":
		facts.append("%s tier" % tier.capitalize())
	facts.append("%d kg" % ItemTable.weight(kind))
	facts.append("worth %d each" % ItemTable.value(kind))
	lines.append(", ".join(facts).capitalize() if tier == "" else ", ".join(facts))
	if ItemTable.heal(kind) > 0:
		lines.append("Heals %d when eaten." % ItemTable.heal(kind))
	if ItemTable.defence(kind) > 0:
		lines.append("Takes %d off every hit." % ItemTable.defence(kind))
	elif ItemTable.ARMOUR_SLOTS.has(ItemTable.slot(kind)):
		lines.append("Takes nothing off a hit on its own.")
	if ItemTable.slot(kind) == ItemTable.SLOT_WEAPON:
		var w := CombatTable.weapon(kind)
		lines.append("%s, power %d, reach %s m." % [str(w["style"]).capitalize(), w["power"], str(w["reach"])])
	var makes := crafts_into(kind)
	if not makes.is_empty():
		lines.append("Crafts into %s." % ", ".join(makes))
	var upgrades := builds(kind)
	if not upgrades.is_empty():
		lines.append("Builds %s." % ", ".join(upgrades))
	if verb != "":
		lines.append(verb + ".")
	return lines


## A skill's tooltip: the level, the xp to the next, and the first thing a higher level unlocks.
static func skill(name: String, sim: Sim) -> UiTooltip:
	var p := sim.skill_progress(name)
	var level := int(p["level"])
	var lines: Array[String] = ["Level %d" % level]
	if level < SkillTable.MAX_LEVEL:
		lines.append("%d / %d xp to level %d." % [p["into"], p["span"], level + 1])
	var unlock := next_unlock(name, level)
	return build(name, name.capitalize(), lines, unlock)


## The labels of what `kind` is an input to: workbench recipes, and cooking for raw food.
static func crafts_into(kind: String) -> Array[String]:
	var out: Array[String] = []
	if RecipeTable.is_cookable(kind):
		out.append(ItemTable.label(RecipeTable.cooking(kind)["output"]).to_lower())
	for id in RecipeTable.ids():
		var r := RecipeTable.get_recipe(id)
		if r["inputs"].has(kind):
			out.append(str(r["label"]).to_lower())
	return out


## The labels of every outpost upgrade whose cost includes `kind`, in upgrade-table order,
## built or not.
static func builds(kind: String) -> Array[String]:
	var out: Array[String] = []
	for id in UpgradeTable.ids():
		var u := UpgradeTable.get_upgrade(id)
		if u["cost"].has(kind):
			out.append(str(u["label"]))
	return out


## "Level 3 unlocks iron ore (bronze pickaxe)": the lowest-level thing above `level` the skill
## gates, from the gatherable nodes, the recipes and the cooking table; "" when nothing is left.
static func next_unlock(name: String, level: int) -> String:
	var best_level := SkillTable.MAX_LEVEL + 1
	var what := ""
	for kind in WorldDef.NODE_KINDS:
		var def: Dictionary = WorldDef.NODE_KINDS[kind]
		if def["skill"] == name and int(def["level"]) > level and int(def["level"]) < best_level:
			best_level = int(def["level"])
			what = ItemTable.label(def["item"]).to_lower()
			if def["tool_tier"] != "":
				what += " (%s %s)" % [def["tool_tier"], def["tool"]]
	for id in RecipeTable.ids():
		var r := RecipeTable.get_recipe(id)
		if r["skill"] == name and int(r["level"]) > level and int(r["level"]) < best_level:
			best_level = int(r["level"])
			what = str(r["label"]).to_lower()
	if name == SkillTable.COOKING:
		for kind in RecipeTable.COOKING:
			var c: Dictionary = RecipeTable.COOKING[kind]
			if int(c["level"]) > level and int(c["level"]) < best_level:
				best_level = int(c["level"])
				what = "cooking %s" % ItemTable.label(kind).to_lower()
	if what != "":
		return "Level %d unlocks %s." % [best_level, what]
	if CombatTable.STYLE_SKILLS.values().has(name):
		return "Every %d levels add a point of power." % CombatTable.LEVELS_PER_POWER
	return ""
