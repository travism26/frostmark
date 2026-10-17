## Flat-shaded mesh building shared by the world's hand-made looks (the palisade, the ice
## cliffs, the ruin kit, the landmarks): a SurfaceTool with vertex colours, a quad and a
## triangle wound to face a given way, and the few shapes every piece is made of. Presentation
## only, no nodes of its own.
class_name MeshKit
extends RefCounted

## Fresh snow on the hand-made meshes, before the ring look tints the scene.
const SNOW := Color(0.94, 0.96, 1.0)
const ICE_PALE := Color(0.78, 0.88, 0.97)


## A deterministic generator seeded from where a piece stands, so every session sees the
## same frontier.
static func rng(centre: Vector2) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = int(centre.x * 31.0 + centre.y * 7.0) + 1000
	return r


## Maps a point along (`u`) and across (`v`) a footprint to its own axes.
static func local(u: float, v: float, along_x: bool) -> Vector3:
	return Vector3(u, 0.0, v) if along_x else Vector3(v, 0.0, u)


static func begin() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st


## Flat normals from the unshared vertices, and one fresh material so this mesh can fade on
## its own when it hides the character.
static func finish(st: SurfaceTool) -> ArrayMesh:
	st.generate_normals()
	var mesh := st.commit()
	mesh.surface_set_material(0, material())
	return mesh


## The one material every hand-made mesh carries: vertex colours, flat shading.
static func material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	m.vertex_color_use_as_albedo = true
	m.roughness = 1.0
	return m


## A quad `a b c d` whose bottom edge is `a b` in `low` and top edge `c d` in `high`, wound so
## its normal leans towards `outward`.
static func quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, low: Color, high: Color, outward: Vector3) -> void:
	tri_shade(st, a, b, c, low, low, high, outward)
	tri_shade(st, a, c, d, low, high, high, outward)


static func tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, colour: Color, outward: Vector3) -> void:
	tri_shade(st, a, b, c, colour, colour, colour, outward)


## One triangle, flipped if needed so Godot's clockwise front face points along `outward`.
static func tri_shade(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color, outward: Vector3) -> void:
	if (b - a).cross(c - a).dot(outward) > 0.0:
		var t := b
		b = c
		c = t
		var tc := cb
		cb = cc
		cc = tc
	st.set_color(ca)
	st.add_vertex(a)
	st.set_color(cb)
	st.add_vertex(b)
	st.set_color(cc)
	st.add_vertex(c)


## An axis-aligned box of `size` centred at `at`, its sides in `colour` and its top in `top`.
static func box(st: SurfaceTool, at: Vector3, size: Vector3, colour: Color, top: Color) -> void:
	var h := size * 0.5
	var c: Array[Vector3] = []
	for i in 8:
		c.append(at + Vector3(-h.x if i & 1 == 0 else h.x, -h.y if i & 2 == 0 else h.y, -h.z if i & 4 == 0 else h.z))
	# Bottom corners 0 1 4 5, top corners 2 3 6 7 (bit 1 = +x, bit 2 = +y, bit 4 = +z).
	quad(st, c[0], c[1], c[3], c[2], colour, colour, Vector3.BACK * -1.0)
	quad(st, c[4], c[5], c[7], c[6], colour, colour, Vector3.BACK)
	quad(st, c[0], c[4], c[6], c[2], colour, colour, Vector3.LEFT)
	quad(st, c[1], c[5], c[7], c[3], colour, colour, Vector3.RIGHT)
	quad(st, c[2], c[3], c[7], c[6], top, top, Vector3.UP)
	quad(st, c[0], c[1], c[5], c[4], colour, colour, Vector3.DOWN)


## A box turned `turn` about the up axis and tilted `tilt` about its own x axis, centred at
## `at`: the tumbled blocks of a ruin, a crate, a wagon bed.
static func block(st: SurfaceTool, at: Vector3, size: Vector3, turn: float, tilt: float, colour: Color, top: Color) -> void:
	var basis := Basis(Vector3.UP, turn) * Basis(Vector3.RIGHT, tilt)
	var h := size * 0.5
	var c: Array[Vector3] = []
	for i in 8:
		c.append(at + basis * Vector3(-h.x if i & 1 == 0 else h.x, -h.y if i & 2 == 0 else h.y, -h.z if i & 4 == 0 else h.z))
	var up := basis * Vector3.UP
	var top_colour := top if up.y > 0.6 else colour
	quad(st, c[0], c[1], c[3], c[2], colour, colour, basis * Vector3.FORWARD)
	quad(st, c[4], c[5], c[7], c[6], colour, colour, basis * Vector3.BACK)
	quad(st, c[0], c[4], c[6], c[2], colour, colour, basis * Vector3.LEFT)
	quad(st, c[1], c[5], c[7], c[3], colour, colour, basis * Vector3.RIGHT)
	quad(st, c[2], c[3], c[7], c[6], top_colour, top_colour, up)
	quad(st, c[0], c[1], c[5], c[4], colour, colour, -up)


## A sharpened log: a six-sided trunk from `y0` to `top`, a short band blending into snow,
## and a snow-white point `tip` high, leaning by `lean` per metre of height.
static func log_post(st: SurfaceTool, at: Vector3, y0: float, top: float, r: float, tip: float, lean: Vector2, colour: Color, snow := SNOW) -> void:
	var band := top - 0.1
	var ring0: Array[Vector3] = []
	var ring1: Array[Vector3] = []
	var ring2: Array[Vector3] = []
	for k in 6:
		var a := k * TAU / 6.0
		var off := Vector3(cos(a) * r, 0.0, sin(a) * r)
		ring0.append(at + off + Vector3(0, y0, 0))
		ring1.append(at + off + Vector3(lean.x * (band - y0), band, lean.y * (band - y0)))
		ring2.append(at + off * 0.82 + Vector3(lean.x * (top - y0), top, lean.y * (top - y0)))
	var apex := at + Vector3(lean.x * (top + tip - y0), top + tip, lean.y * (top + tip - y0))
	for k in 6:
		var n := (k + 1) % 6
		var out := Vector3(cos((k + 0.5) * TAU / 6.0), 0.0, sin((k + 0.5) * TAU / 6.0))
		quad(st, ring0[k], ring0[n], ring1[n], ring1[k], colour, colour, out)
		quad(st, ring1[k], ring1[n], ring2[n], ring2[k], colour, snow, out)
		tri(st, ring2[k], ring2[n], apex, snow, out + Vector3.UP)


## A tapered prism `sides` around, `r0` wide at `y0` and `r1` wide at `y1`, standing at `at`
## and turned by `turn`; `low` at the foot, `high` at the top. The top is capped in `cap`
## (snow, or the stone itself) and the foot is left open.
static func prism(st: SurfaceTool, at: Vector3, sides: int, r0: float, r1: float, y0: float, y1: float, turn: float, low: Color, high: Color, cap: Color, lean := Vector2.ZERO) -> void:
	var ring0: Array[Vector3] = []
	var ring1: Array[Vector3] = []
	for k in sides:
		var a := turn + k * TAU / sides
		ring0.append(at + Vector3(cos(a) * r0, y0, sin(a) * r0))
		ring1.append(at + Vector3(cos(a) * r1 + lean.x * (y1 - y0), y1, sin(a) * r1 + lean.y * (y1 - y0)))
	var top_centre := at + Vector3(lean.x * (y1 - y0), y1, lean.y * (y1 - y0))
	for k in sides:
		var n := (k + 1) % sides
		var out := Vector3(cos(turn + (k + 0.5) * TAU / sides), 0.0, sin(turn + (k + 0.5) * TAU / sides))
		quad(st, ring0[k], ring0[n], ring1[n], ring1[k], low, high, out)
		tri(st, ring1[k], ring1[n], top_centre, cap, Vector3.UP)


## A four-sided spike of ice, pale towards its point.
static func shard(st: SurfaceTool, at: Vector3, r: float, h: float, turn: float, colour: Color, pale := ICE_PALE) -> void:
	var apex := at + Vector3(0, h, 0)
	var ring: Array[Vector3] = []
	for k in 4:
		var a := turn + k * TAU / 4.0
		ring.append(at + Vector3(cos(a) * r, -0.3, sin(a) * r))
	for k in 4:
		var m := (k + 1) % 4
		var out := (ring[k] + ring[m]) * 0.5 - at
		tri_shade(st, ring[k], ring[m], apex, colour, colour, pale, out + Vector3.UP * 0.5)


## A flat disc on the ground at `at`, `r` across, `sides` around, slightly ragged.
static func disc(st: SurfaceTool, at: Vector3, r: float, sides: int, colour: Color, rim: Color, rng_: RandomNumberGenerator) -> void:
	var ring: Array[Vector3] = []
	for k in sides:
		var a := k * TAU / sides
		var rr := r * rng_.randf_range(0.85, 1.0)
		ring.append(at + Vector3(cos(a) * rr, 0.0, sin(a) * rr))
	for k in sides:
		tri_shade(st, at, ring[k], ring[(k + 1) % sides], colour, rim, rim, Vector3.UP)
