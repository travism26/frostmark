## Shots in flight: an arrow for a bow and a frost shard for a staff, flown from the shooter to
## its target with a small puff where it lands. Presentation only, driven by the events the
## simulation already emits. A player's shot is loosed on its `hit` and lands a moment later,
## when GameRoot's flinch for it plays. A monster's shot is loosed from its telegraph so that it
## arrives on the tick the blow resolves; it lands on the player when that tick's `hit` comes,
## in the snow past them when `missed` does, and shrinks away in the air when the blow was an
## `enemy_feinted`. Shots are hand-made meshes and a trail quad,
## with no shadow and no state beyond what is on screen.
##
## Every shot and puff of a look shares one set of meshes and materials, made once and held
## for the session. The browser compiles a material's shader when it is first drawn and drops
## it when the last material of its kind is freed, so a fresh material per shot froze the game
## for 60 to 120 ms on every arrow and shard.
class_name Projectiles
extends Node3D

const PARTICLES := "res://assets/particles/kenney_particle_pack/"
const SMOKE := preload(PARTICLES + "smoke_01.png")
const STAR := preload(PARTICLES + "star_05.png")

const ARROW := "arrow"
const SHARD := "shard"

## Flight speed, metres a second, and the limits on any one flight, so a point-blank shot is
## still seen and a long one still lands before the next blow.
const SPEED := 20.0
const FLIGHT_MIN := 0.18
const FLIGHT_MAX := 0.45
## An arrow lobs this fraction of its range above the straight line; a shard flies straight.
const LOB := 0.06
## Where a shot leaves the shooter and meets a target, above their feet; a shot that misses
## lands this far past the target, in the snow.
const RELEASE_HEIGHT := 1.2
const CHEST_HEIGHT := 1.0
const MISS_REACH := 1.2
const MISS_SECONDS := 0.12
## How long an arrived shot waits for the blow's tick to say whether it hit before it drops.
const GRACE := 0.2
## Drawn larger than life, so a shot reads from the default camera 32 m up.
const ARROW_LENGTH := 1.5
const SHARD_LENGTH := 1.0
const TRAIL_LENGTH := 2.4
const PUFF_SECONDS := 0.45
## How long a feinted shot takes to shrink away in the air.
const FADE_SECONDS := 0.2

const COLOR_SHAFT := Color(0.45, 0.30, 0.18)
const COLOR_HEAD := Color(0.62, 0.66, 0.72)
const COLOR_FLETCH := Color(0.95, 0.93, 0.88)
const COLOR_ICE := Color(0.25, 0.70, 1.0)
const COLOR_ICE_CORE := Color(0.88, 0.98, 1.0)
const COLOR_SNOW := Color(0.94, 0.96, 1.0)
## The streaks take their style's colour, as the telegraph rings do, so they stand out on snow.
const COLOR_ARROW_TRAIL := Color(IconTable.STYLE_COLOURS[CombatTable.STYLE_RANGED], 0.95)
const COLOR_SHARD_TRAIL := Color(IconTable.STYLE_COLOURS[CombatTable.STYLE_MAGIC], 0.85)

const WAITING := "waiting"
const FLYING := "flying"
const HOLDING := "holding"
const LANDED := "landed"
const DROPPED := "dropped"
const FADING := "fading"
const FADED := "faded"

## Whether a puff bursts outward; off with reduced motion, so it only glows and fades in place.
var reduced_motion := false
## Each shot: {node, kind, shooter, from, target, to, key, delay, seconds, time, held,
## result (null until resolved, then true for a hit, false for a miss), miss_at, faded_at
## (set when the blow was a feint), on_land}.
var _shots: Array[Dictionary] = []

static var _trail_texture: Texture2D
## Look name -> the meshes, materials, curves and ramps every node of that look shares.
static var _looks := {}


## The projectile a blow of `style` throws: an arrow for ranged, a shard for magic, none for melee.
static func kind_for(style: String) -> String:
	match style:
		CombatTable.STYLE_RANGED:
			return ARROW
		CombatTable.STYLE_MAGIC:
			return SHARD
	return ""


## How long a shot `distance` metres long is in the air.
static func flight_seconds(distance: float) -> float:
	return clampf(distance / SPEED, FLIGHT_MIN, FLIGHT_MAX)


## How long after its telegraph a monster looses a shot `distance` long so that it arrives
## `until_blow` seconds later, on the blow's tick; at once when the flight needs all of it.
static func launch_delay(distance: float, until_blow: float) -> float:
	return maxf(until_blow - flight_seconds(distance), 0.0)


## Where a shot of `kind` from `from` to `to` is, `t` of the way (0 to 1) through its flight.
static func point(from: Vector3, to: Vector3, t: float, kind: String) -> Vector3:
	var p := from.lerp(to, clampf(t, 0.0, 1.0))
	if kind == ARROW:
		p.y += from.distance_to(to) * LOB * 4.0 * t * (1.0 - t)
	return p


## Which part of its life a shot is in: WAITING to be loosed, FLYING, HOLDING at its target
## for the blow's tick, LANDED (a hit, or a player's shot), DROPPED into the snow (a miss,
## or no word inside GRACE), or FADING away in the air and then FADED (a feint; one still
## waiting to be loosed is never seen). Only reads the shot's time, flight and result.
static func phase(shot: Dictionary) -> String:
	var time: float = shot["time"]
	var flown: float = shot["delay"] + shot["seconds"]
	if shot.has("faded_at"):
		var faded: float = shot["faded_at"]
		return FADING if faded >= shot["delay"] and time < faded + FADE_SECONDS else FADED
	if time < shot["delay"]:
		return WAITING
	if time < flown:
		return FLYING
	if shot["result"] == null:
		return HOLDING if time < flown + GRACE else DROPPED
	if shot["result"]:
		return LANDED
	return DROPPED if time >= maxf(flown, float(shot.get("missed_at", flown))) + MISS_SECONDS else HOLDING


## Looses a shot of `style` from `shooter` at `target` (their roots, on the ground), `delay`
## seconds from now, landing at once when it arrives (`resolved`) or on `resolve(key, ...)`.
## `on_land` runs when it lands on the target.
func loose(shooter: Node3D, target: Node3D, style: String, delay := 0.0, until_blow := -1.0, key := "", resolved := true, on_land := Callable()) -> void:
	var kind := kind_for(style)
	if kind == "" or shooter == null or target == null:
		if on_land.is_valid():
			on_land.call()
		return
	var from := _release(shooter, target)
	var distance := from.distance_to(_aim(target))
	if until_blow >= 0.0:
		delay = launch_delay(distance, until_blow)
	var node := arrow() if kind == ARROW else shard()
	node.visible = false
	add_child(node)
	_shots.append({
		"node": node, "kind": kind, "from": from, "target": target, "to": _aim(target), "key": key,
		"delay": delay, "seconds": flight_seconds(distance), "time": 0.0,
		"result": true if resolved else null, "on_land": on_land,
	})


## The blow `key` shot resolved: it `landed` on its target, or missed and drops past them.
func resolve(key: String, landed: bool) -> void:
	for shot in _shots:
		if shot["key"] == key and shot["result"] == null:
			shot["result"] = landed
			if not landed:
				shot["missed_at"] = shot["time"]
			return


## The blow `key` shot was a feint: it shrinks away where it is instead of landing or dropping.
func fade(key: String) -> void:
	for shot in _shots:
		if shot["key"] == key and shot["result"] == null:
			shot["result"] = false
			shot["faded_at"] = shot["time"]
			return


## Drops every shot in the air (a load, a death): nothing lands and no puff is thrown.
func clear() -> void:
	for shot in _shots:
		(shot["node"] as Node3D).queue_free()
	_shots.clear()


func _process(delta: float) -> void:
	var i := _shots.size() - 1
	while i >= 0:
		var shot: Dictionary = _shots[i]
		shot["time"] = float(shot["time"]) + delta
		if _advance(shot):
			(shot["node"] as Node3D).queue_free()
			_shots.remove_at(i)
		i -= 1


## Moves one shot on and returns true once it has landed or dropped.
func _advance(shot: Dictionary) -> bool:
	var node: Node3D = shot["node"]
	var target: Node3D = shot["target"]
	if shot["result"] != false and is_instance_valid(target) and target.is_inside_tree():
		shot["to"] = _aim(target)  # it follows the target until the blow says it missed
	var from: Vector3 = shot["from"]
	var to: Vector3 = shot["to"]
	match phase(shot):
		WAITING:
			return false
		FLYING:
			var t := (float(shot["time"]) - float(shot["delay"])) / float(shot["seconds"])
			_place(node, point(from, to, t, shot["kind"]), point(from, to, minf(t + 0.05, 1.0), shot["kind"]) - point(from, to, maxf(t - 0.05, 0.0), shot["kind"]))
			return false
		HOLDING:
			if shot["result"] == false:  # past the target and down into the snow
				var ahead := Vector3(to.x - from.x, 0.0, to.z - from.z).normalized()
				var ground := Vector3(to.x, 0.05, to.z) + ahead * MISS_REACH
				var flown: float = shot["delay"] + shot["seconds"]
				var started: float = maxf(flown, float(shot.get("missed_at", flown)))
				var t := clampf((float(shot["time"]) - started) / MISS_SECONDS, 0.0, 1.0)
				_place(node, to.lerp(ground, t), ground - to)
			else:
				_place(node, to, to - from)
			return false
		LANDED:
			_burst(shot["kind"], to)
			var on_land: Callable = shot["on_land"]
			if on_land.is_valid():
				on_land.call()
			return true
		FADING:
			node.scale = Vector3.ONE * (1.0 - (float(shot["time"]) - float(shot["faded_at"])) / FADE_SECONDS)
			return false
		FADED:
			return true
	var ahead := Vector3(to.x - from.x, 0.0, to.z - from.z).normalized()
	_burst(SHARD if shot["kind"] == SHARD else "", Vector3(to.x, 0.1, to.z) + ahead * MISS_REACH)
	return true


func _place(node: Node3D, at: Vector3, heading: Vector3) -> void:
	node.visible = true
	node.position = at
	if heading.length_squared() > 0.0001:
		node.basis = Basis.looking_at(heading.normalized(), Vector3.UP if absf(heading.normalized().y) < 0.99 else Vector3.FORWARD)


func _burst(kind: String, at: Vector3) -> void:
	var p := puff(kind, reduced_motion)
	p.position = at
	add_child(p)
	p.finished.connect(p.queue_free)
	p.emitting = true


## Where a shot leaves `shooter`: bow height, a little in front of them toward `target`.
static func _release(shooter: Node3D, target: Node3D) -> Vector3:
	var at := shooter.global_position
	var ahead := Vector3(target.global_position.x - at.x, 0.0, target.global_position.z - at.z)
	if ahead.length_squared() > 0.0001:
		at += ahead.normalized() * 0.4
	return at + Vector3(0, RELEASE_HEIGHT, 0)


static func _aim(target: Node3D) -> Vector3:
	return target.global_position + Vector3(0, CHEST_HEIGHT, 0)


## An arrow pointing along its -Z: a wooden shaft, a steel head and pale fletching, with a
## faint streak behind it.
static func arrow() -> Node3D:
	if not _looks.has(ARROW):
		_looks[ARROW] = _shot_look(_arrow_mesh(), COLOR_ARROW_TRAIL, false)
	return _shot_node("Arrow", _looks[ARROW])


static func _arrow_mesh() -> ArrayMesh:
	var st := MeshKit.begin()
	var half := ARROW_LENGTH * 0.5
	MeshKit.box(st, Vector3(0, 0, 0.1), Vector3(0.1, 0.1, ARROW_LENGTH - 0.3), COLOR_SHAFT, COLOR_SHAFT)
	var tip := Vector3(0, 0, -half)
	var back := -half + 0.34
	var head: Array[Vector3] = [Vector3(-0.15, 0, back), Vector3(0, 0.15, back), Vector3(0.15, 0, back), Vector3(0, -0.15, back)]
	for k in 4:
		var n := (k + 1) % 4
		MeshKit.tri_shade(st, head[k], head[n], tip, COLOR_HEAD, COLOR_HEAD, COLOR_FLETCH, (head[k] + head[n]) * 0.5 - Vector3(0, 0, back))
	for side in [Vector3(1, 0, 0), Vector3(0, 1, 0)]:
		for flip in [-1.0, 1.0]:
			var out: Vector3 = side * 0.2 * flip
			MeshKit.tri(st, Vector3(0, 0, half - 0.45), Vector3(0, 0, half), Vector3(0, 0, half) + out, COLOR_FLETCH, side.cross(Vector3.BACK))
	var mesh := MeshKit.finish(st)
	(mesh.surface_get_material(0) as StandardMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED  # the fletching is one face thick
	return mesh


## A frost shard pointing along its -Z: a long six-sided spike of ice, bright at its core,
## with a streak behind it.
static func shard() -> Node3D:
	if not _looks.has(SHARD):
		_looks[SHARD] = _shot_look(_shard_mesh(), COLOR_SHARD_TRAIL, true)
	return _shot_node("Shard", _looks[SHARD])


static func _shard_mesh() -> ArrayMesh:
	var st := MeshKit.begin()
	var nose := Vector3(0, 0, -SHARD_LENGTH * 0.6)
	var tail := Vector3(0, 0, SHARD_LENGTH * 0.4)
	var ring: Array[Vector3] = []
	for k in 6:
		var a := k * TAU / 6.0
		ring.append(Vector3(cos(a) * 0.18, sin(a) * 0.18, -SHARD_LENGTH * 0.15))
	for k in 6:
		var n := (k + 1) % 6
		var out := (ring[k] + ring[n]) * 0.5
		MeshKit.tri_shade(st, ring[k], ring[n], nose, COLOR_ICE, COLOR_ICE, COLOR_ICE_CORE, Vector3(out.x, out.y, 0) + Vector3(0, 0, -0.3))
		MeshKit.tri_shade(st, ring[k], ring[n], tail, COLOR_ICE, COLOR_ICE, COLOR_ICE_CORE, Vector3(out.x, out.y, 0) + Vector3(0, 0, 0.3))
	var mesh := MeshKit.finish(st)
	var mat := mesh.surface_get_material(0) as StandardMaterial3D
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED  # it glows with its own cold
	return mesh


## A shot's body `mesh` and the streak that lies flat behind it, so it reads from above as a
## line of travel.
static func _shot_look(mesh: ArrayMesh, trail_colour: Color, wide: bool) -> Dictionary:
	var quad := QuadMesh.new()
	quad.size = Vector2(0.36 if wide else 0.24, TRAIL_LENGTH)
	quad.orientation = PlaneMesh.FACE_Y
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = trail_colour
	mat.albedo_texture = _trail_tex()
	mat.disable_receive_shadows = true
	return {"body": mesh, "trail": quad, "trail_material": mat}


static func _shot_node(node_name: String, look: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = node_name
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = look["body"]
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(body)
	var trail := MeshInstance3D.new()
	trail.name = "Trail"
	trail.mesh = look["trail"]
	trail.material_override = look["trail_material"]
	trail.position = Vector3(0, 0, TRAIL_LENGTH * 0.5)
	trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(trail)
	return root


## A one-shot puff where a shot lands, not yet emitting: icy glints for a shard and a spray in
## the ranged colour for an arrow, or plain snow kicked up (`kind` "") for an arrow dropping
## into it. With `reduced`, one soft glow that fades where it is instead of a burst.
static func puff(kind: String, reduced: bool) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "Puff"
	p.one_shot = true
	p.emitting = false
	p.explosiveness = 1.0
	p.lifetime = PUFF_SECONDS
	p.local_coords = false
	var icy := kind == SHARD
	var look := _puff_look(kind, reduced)
	if reduced:
		p.amount = 1
		p.direction = Vector3.UP
		p.spread = 0.0
		p.initial_velocity_min = 0.0
		p.initial_velocity_max = 0.0
		p.gravity = Vector3.ZERO
	else:
		p.amount = 12 if icy else 10
		p.direction = Vector3.UP
		p.spread = 80.0
		p.initial_velocity_min = 1.2
		p.initial_velocity_max = 2.6
		p.gravity = Vector3(0, -3.0, 0)
		p.damping_min = 2.0
		p.damping_max = 4.0
		p.randomness = 0.5
		p.angle_min = -90.0
		p.angle_max = 90.0
		p.scale_amount_min = 0.6
		p.scale_amount_max = 1.1
	p.scale_amount_curve = look["scale"]
	p.color_ramp = look["ramp"]
	p.mesh = look["mesh"]
	return p


## The quad, curve and ramp every puff of `kind` (and `reduced`) shares.
static func _puff_look(kind: String, reduced: bool) -> Dictionary:
	var key := "puff %s %s" % [kind, reduced]
	if not _looks.has(key):
		var icy := kind == SHARD
		var colour := COLOR_SNOW
		if kind != "":
			colour = COLOR_SNOW.lerp(IconTable.STYLE_COLOURS[CombatTable.STYLE_MAGIC if icy else CombatTable.STYLE_RANGED], 0.6)
		var quad := QuadMesh.new()
		quad.size = Vector2(0.8, 0.8) if icy else Vector2(0.9, 0.9)
		quad.material = FireFx._billboard(STAR if icy else SMOKE, colour, false)
		_looks[key] = {
			"mesh": quad,
			"scale": FireFx._curve([[0.0, 1.0], [1.0, 1.0]] if reduced else [[0.0, 0.6], [0.3, 1.0], [1.0, 1.3]]),
			"ramp": FireFx._ramp([[0.0, Color(1, 1, 1, 0.0)], [0.1, Color(1, 1, 1, 0.9)], [1.0, Color(1, 1, 1, 0.0)]]),
		}
	return _looks[key]


## One of every look a shot can take, for the warm-up to compile before play.
static func samples() -> Node3D:
	var all := Node3D.new()
	all.add_child(arrow())
	all.add_child(shard())
	for kind in [ARROW, SHARD, ""]:
		for reduced in [false, true]:
			all.add_child(puff(kind, reduced))
	return all


## A streak that is brightest at the shot and fades to nothing behind it, drawn once.
static func _trail_tex() -> Texture2D:
	if _trail_texture == null:
		var w := 16
		var h := 64
		var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
		for y in h:
			for x in w:
				var across := 1.0 - absf((x + 0.5) / w * 2.0 - 1.0)
				var along := 1.0 - (y + 0.5) / h  # the quad's top (-z) end sits at the shot
				img.set_pixel(x, y, Color(1, 1, 1, clampf(across * 1.5, 0.0, 1.0) * along * along))
		_trail_texture = ImageTexture.create_from_image(img)
	return _trail_texture
