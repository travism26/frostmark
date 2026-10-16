## Slot arrays as plain data: the pack and the stash are both fixed-length Arrays whose
## entries are `null` (empty) or `{item: String, count: int}`.
##
## Pure static functions so the simulation can reason about room, weight and stacking
## without owning a class per container. Adding fills existing stacks of the same kind
## first, then empty slots in order. Engine-free like the rest of sim/.
class_name Inventory
extends RefCounted


static func empty_slots(size: int) -> Array:
	var out: Array = []
	out.resize(size)
	return out


## How many of `kind` would fit in `slots` right now.
static func room_for(slots: Array, kind: String) -> int:
	var stack := ItemTable.stack_size(kind)
	var room := 0
	for s in slots:
		if s == null:
			room += stack
		elif s["item"] == kind:
			room += stack - int(s["count"])
	return room


## Adds up to `count` of `kind`; returns how many did not fit.
static func add(slots: Array, kind: String, count: int) -> int:
	var left := count
	var stack := ItemTable.stack_size(kind)
	for s in slots:
		if left <= 0:
			break
		if s != null and s["item"] == kind and int(s["count"]) < stack:
			var n := mini(left, stack - int(s["count"]))
			s["count"] = int(s["count"]) + n
			left -= n
	for i in slots.size():
		if left <= 0:
			break
		if slots[i] == null:
			var n := mini(left, stack)
			slots[i] = {"item": kind, "count": n}
			left -= n
	return left


static func count_of(slots: Array, kind: String) -> int:
	var n := 0
	for s in slots:
		if s != null and s["item"] == kind:
			n += int(s["count"])
	return n


## Removes `count` of `kind`, taking from the last slots first so the front of the pack
## keeps its order. The caller checks `count_of` beforehand.
static func remove(slots: Array, kind: String, count: int) -> void:
	var left := count
	for i in range(slots.size() - 1, -1, -1):
		if left <= 0:
			return
		var s: Variant = slots[i]
		if s == null or s["item"] != kind:
			continue
		var n := mini(left, int(s["count"]))
		s["count"] = int(s["count"]) - n
		left -= n
		if int(s["count"]) <= 0:
			slots[i] = null


## Takes up to `count` from slot `index`; returns `{item, count}` actually taken.
static func take(slots: Array, index: int, count: int) -> Dictionary:
	var s: Dictionary = slots[index]
	var n := mini(count, int(s["count"]))
	s["count"] = int(s["count"]) - n
	var kind: String = s["item"]
	if int(s["count"]) <= 0:
		slots[index] = null
	return {"item": kind, "count": n}


static func weight(slots: Array) -> int:
	var w := 0
	for s in slots:
		if s != null:
			w += ItemTable.weight(s["item"]) * int(s["count"])
	return w


static func is_full_for(slots: Array, kind: String) -> bool:
	return room_for(slots, kind) <= 0


## The slot list as compact `{item, count}` entries, empty slots skipped.
static func contents(slots: Array) -> Array:
	var out: Array = []
	for s in slots:
		if s != null:
			out.append({"item": s["item"], "count": int(s["count"])})
	return out
