## The ruin kit and the landmarks: hand-made, flat-shaded, in one material language (cut
## stone in the ring's own `stone` colour from the ring-look table, dark joints, snow on every
## top) so the pieces sit together whichever ring they stand in. Broken walls, a collapsed
## tower base, a fallen arch, pillars, cairns, standing stones carved or rough, a snapped
## caravan wagon, a frozen campfire ring; and the landmarks the player steers by: a split
## rock, a fallen giant pine, a frozen waterfall, a dead giant, an ice spire, a watch post;
## and a mine's dressing: ore-streaked boulders, spoil heaps and a rock face with an adit.
##
## Presentation only. Every piece is an ArrayMesh standing on the ground at y = 0 (or at
## `base_y` for a solid's look, which GameRoot centres on its footprint), seeded from where
## it stands so every session sees the same ruins. Nothing here has collision.
class_name RuinKit
extends RefCounted

const SNOW := MeshKit.SNOW
const ICE_DEEP := Color(0.30, 0.50, 0.76)
const ICE := Color(0.52, 0.72, 0.92)
const ICE_PALE := MeshKit.ICE_PALE
const TIMBER := Color(0.42, 0.30, 0.20)
const TIMBER_DARK := Color(0.30, 0.21, 0.14)
const CHAR := Color(0.12, 0.11, 0.11)
const ASH := Color(0.42, 0.42, 0.44)
const BONE := Color(0.90, 0.88, 0.80)
const CANVAS := Color(0.64, 0.56, 0.44)
## Cut blocks run about this long and this high; the kit is coursed, not random rubble.
const BLOCK := 0.9
const COURSE := 0.45


# --- Ruins over the sim's footprints -----------------------------------------------------

## A broken wall filling a `size` footprint (x, height, z) centred at the origin with its
## foot at `base_y`: coursed blocks with staggered joints, a ragged top that falls to about
## half height in places and tumbled blocks at the foot. Blocks never reach more than 0.35 m
## past the footprint, so the sim's collision still reads true.
static func wall(size: Vector3, centre: Vector2, stone: Color, base_y := 0.0) -> ArrayMesh:
	var rng := MeshKit.rng(centre)
	var st := MeshKit.begin()
	var along_x := size.x >= size.z
	var length := size.x if along_x else size.z
	var thick := minf(size.z if along_x else size.x, 1.2)
	var courses := maxi(int(size.y / COURSE), 2)
	var count := maxi(int(length / BLOCK), 1)
	var span := length / count
	# The top edge: a slow wave with a few breaks, so the wall reads as fallen, not sawn.
	var breaks: Array[float] = []
	for i in rng.randi_range(1, 2 + int(length / 10.0)):
		breaks.append(rng.randf_range(-length * 0.45, length * 0.45))
	for row in courses:
		var y0 := base_y + row * COURSE
		var stagger := 0.5 * span if row % 2 == 1 else 0.0
		for i in range(-1, count + 1):
			var u0 := -length * 0.5 + i * span + stagger
			var u1 := minf(u0 + span, length * 0.5)
			u0 = maxf(u0, -length * 0.5)
			if u1 - u0 < 0.2:
				continue
			var u := (u0 + u1) * 0.5
			var limit := size.y * (0.78 + 0.22 * sin(u * 0.7 + centre.x))
			for b in breaks:
				limit = minf(limit, size.y * (0.45 + 0.55 * clampf(absf(u - b) / 2.4, 0.0, 1.0)))
			if y0 - base_y + COURSE * 0.5 > limit:
				continue
			var top := y0 - base_y + COURSE > limit - 0.25
			var shade := stone * rng.randf_range(0.86, 1.06)
			shade.a = 1.0
			var at := MeshKit.local(u, 0.0, along_x) + Vector3(0, y0 + COURSE * 0.5, 0)
			var block_size := MeshKit.local(u1 - u0 - 0.04, thick, along_x) + Vector3(0, COURSE - 0.03, 0)
			if block_size.x == 0.0 or block_size.z == 0.0:
				block_size += Vector3(0.0001, 0, 0.0001)
			MeshKit.box(st, at, block_size, shade, SNOW if top else shade)
	# Tumbled blocks at the foot, leaning against the wall.
	for i in maxi(int(length / 3.0), 1):
		var u := rng.randf_range(-length * 0.5 + 0.4, length * 0.5 - 0.4)
		var v := (thick * 0.5 + 0.15) * (1.0 if rng.randf() < 0.5 else -1.0)
		var at := MeshKit.local(u, v, along_x) + Vector3(0, base_y + 0.2, 0)
		var shade := stone * rng.randf_range(0.8, 1.0)
		shade.a = 1.0
		MeshKit.block(st, at, Vector3(0.5, 0.35, 0.4), rng.randf() * TAU, rng.randf_range(-0.3, 0.3), shade, SNOW)
	return MeshKit.finish(st)


## A broken pillar filling a `size` footprint: a square plinth, an eight-sided drum snapped
## off below its full height, and the fallen drum lying beside its foot.
static func pillar(size: Vector3, centre: Vector2, stone: Color, base_y := 0.0) -> ArrayMesh:
	var rng := MeshKit.rng(centre)
	var st := MeshKit.begin()
	var r := minf(size.x, size.z) * 0.5
	var dark := stone.darkened(0.2)
	MeshKit.box(st, Vector3(0, base_y + 0.15, 0), Vector3(size.x, 0.3, size.z), dark, SNOW)
	var standing := size.y * rng.randf_range(0.55, 0.95)
	MeshKit.prism(st, Vector3(0, 0, 0), 8, r * 0.78, r * 0.7, base_y + 0.3, base_y + standing, rng.randf() * TAU, stone, stone, SNOW)
	# The snapped top lies against the plinth.
	var fallen := Vector3(r * 0.9, base_y + r * 0.5, -r * 0.6)
	MeshKit.block(st, fallen, Vector3(size.y - standing, r * 1.1, r * 1.1), rng.randf_range(0.3, 1.2), 0.0, stone * 0.92, SNOW)
	return MeshKit.finish(st)


# --- The kit's free-standing pieces -----------------------------------------------------

## A collapsed tower base `radius` across: a ring of coursed stone, fallen away on one side,
## with rubble spilled inside and out.
static func tower_base(radius: float, height: float, centre: Vector2, stone: Color) -> ArrayMesh:
	var rng := MeshKit.rng(centre)
	var st := MeshKit.begin()
	var sides := 14
	var gap := rng.randf() * TAU
	var courses := int(height / COURSE)
	for row in courses:
		for k in sides:
			var a := (k + 0.5 * (row % 2)) * TAU / sides
			var away := absf(angle_difference(a, gap))
			var limit := height * clampf(0.25 + away / 1.6, 0.0, 1.0) * (0.85 + 0.15 * sin(k * 1.7))
			var y := row * COURSE
			if y + COURSE * 0.5 > limit:
				continue
			var top := y + COURSE > limit - 0.3
			var shade := stone * rng.randf_range(0.86, 1.06)
			shade.a = 1.0
			var at := Vector3(cos(a) * radius, y + COURSE * 0.5, sin(a) * radius)
			MeshKit.block(st, at, Vector3(TAU * radius / sides - 0.05, COURSE - 0.03, 0.8), -a, 0.0, shade, SNOW if top else shade)
	for i in 9:
		var a := gap + rng.randf_range(-1.2, 1.2)
		var d := radius * rng.randf_range(0.2, 1.5)
		var shade := stone * rng.randf_range(0.8, 1.0)
		shade.a = 1.0
		MeshKit.block(st, Vector3(cos(a) * d, 0.18, sin(a) * d), Vector3(0.6, 0.32, 0.45), rng.randf() * TAU, rng.randf_range(-0.3, 0.3), shade, SNOW)
	MeshKit.disc(st, Vector3(0, 0.02, 0), radius * 0.9, 12, stone.darkened(0.35), stone.darkened(0.25), rng)
	return MeshKit.finish(st)


## A fallen arch over a `span` wide gap: two pillars `depth` thick, a run of voussoirs from
## the taller one that breaks off before it meets the other, and the keystone on the ground.
## The pillars stand `span`/2 either side of the origin, so over a doorway they rest on the
## wall ends and the gap itself stays open.
static func arch(span: float, height: float, depth: float, centre: Vector2, stone: Color) -> ArrayMesh:
	var rng := MeshKit.rng(centre)
	var st := MeshKit.begin()
	var dark := stone.darkened(0.18)
	var half := span * 0.5 + 0.45
	for side in [-1.0, 1.0]:
		var tall := height if side < 0.0 else height * rng.randf_range(0.6, 0.8)
		var courses := int(tall / COURSE)
		for row in courses:
			var shade := stone * rng.randf_range(0.88, 1.06)
			shade.a = 1.0
			var top := row == courses - 1
			MeshKit.box(st, Vector3(side * half, row * COURSE + COURSE * 0.5, 0), Vector3(0.9, COURSE - 0.03, depth), shade, SNOW if top else shade)
	# Voussoirs: a half-circle from the tall pillar, stopping two-thirds of the way across.
	var r := span * 0.5 + 0.45
	var steps := 9
	var kept := 6
	for i in kept:
		var a0 := PI - PI * i / steps
		var a1 := PI - PI * (i + 1) / steps
		var inner0 := Vector3(cos(a0) * (r - 0.45), height + sin(a0) * (r - 0.45) - 0.4, 0)
		var inner1 := Vector3(cos(a1) * (r - 0.45), height + sin(a1) * (r - 0.45) - 0.4, 0)
		var outer0 := Vector3(cos(a0) * (r + 0.1), height + sin(a0) * (r + 0.1) - 0.4, 0)
		var outer1 := Vector3(cos(a1) * (r + 0.1), height + sin(a1) * (r + 0.1) - 0.4, 0)
		var shade := stone * rng.randf_range(0.88, 1.06)
		shade.a = 1.0
		var d := Vector3(0, 0, depth * 0.5)
		MeshKit.quad(st, inner0 + d, inner1 + d, outer1 + d, outer0 + d, shade, shade, Vector3.BACK)
		MeshKit.quad(st, inner0 - d, inner1 - d, outer1 - d, outer0 - d, shade, shade, Vector3.FORWARD)
		MeshKit.quad(st, inner0 - d, inner1 - d, inner1 + d, inner0 + d, dark, dark, -inner0.normalized())
		MeshKit.quad(st, outer0 - d, outer1 - d, outer1 + d, outer0 + d, SNOW, SNOW, Vector3.UP)
		if i == kept - 1:
			MeshKit.quad(st, inner1 - d, outer1 - d, outer1 + d, inner1 + d, dark, dark, Vector3(cos(a1 - PI * 0.5), sin(a1 - PI * 0.5), 0))
	# The keystone and a voussoir lie where they fell, off to one side of the gap.
	MeshKit.block(st, Vector3(span * 0.25, 0.25, depth * 0.5 + 0.9), Vector3(0.7, 0.5, 0.55), rng.randf() * TAU, 0.4, stone * 0.9, SNOW)
	MeshKit.block(st, Vector3(span * 0.4, 0.2, -depth * 0.5 - 0.8), Vector3(0.55, 0.4, 0.5), rng.randf() * TAU, -0.3, stone * 0.95, SNOW)
	return MeshKit.finish(st)


## A cairn `height` tall: rough blocks stacked in a cone, the top one capped in snow.
static func cairn(height: float, centre: Vector2, stone: Color) -> ArrayMesh:
	var rng := MeshKit.rng(centre)
	var st := MeshKit.begin()
	var layers := maxi(int(height / 0.3), 3)
	var y := 0.0
	for layer in layers:
		var frac := float(layer) / layers
		var r := height * 0.42 * (1.0 - frac * 0.85)
		var count := maxi(int(TAU * r / 0.36), 1)
		var h := 0.26 + rng.randf_range(0.0, 0.08)
		for k in count:
			var a := k * TAU / count + layer * 0.4
			var shade := stone * rng.randf_range(0.82, 1.08)
			shade.a = 1.0
			var top := layer == layers - 1 or rng.randf() < 0.25
			MeshKit.block(st, Vector3(cos(a) * r * 0.75, y + h * 0.5, sin(a) * r * 0.75), Vector3(0.34, h, 0.28), -a + rng.randf_range(-0.3, 0.3), rng.randf_range(-0.15, 0.15), shade, SNOW if top else shade)
		y += h * 0.9
	MeshKit.block(st, Vector3(0, y + 0.12, 0), Vector3(0.3, 0.24, 0.26), rng.randf() * TAU, 0.0, stone, SNOW)
	return MeshKit.finish(st)


## A standing stone `height` tall: a tapered six-sided slab leaning a touch, snow on its
## head. `carved` cuts a dark band and a column of marks into its faces, the old hands' work
## (the waystones, the stones at the gate to ring two); rough stones are the outpost's own.
static func standing_stone(height: float, centre: Vector2, stone: Color, carved: bool, lean := Vector2.ZERO) -> ArrayMesh:
	var rng := MeshKit.rng(centre)
	var st := MeshKit.begin()
	var turn := rng.randf() * TAU
	var r0 := height * 0.17
	var r1 := height * 0.11
	var dark := stone.darkened(0.3)
	if lean == Vector2.ZERO:
		lean = Vector2(rng.randf_range(-0.05, 0.05), rng.randf_range(-0.05, 0.05))
	# Sunk a little, with a scatter of snow-covered rubble at the foot.
	MeshKit.prism(st, Vector3.ZERO, 6, r0 * 1.05, r0, -0.3, height * 0.12, turn, dark, stone, stone, lean)
	MeshKit.prism(st, Vector3.ZERO, 6, r0, r1, height * 0.12, height, turn, stone, stone, SNOW, lean)
	if carved:
		# A band near the head and a column of three marks down the face the player sees.
		var band_y := height * 0.74
		var mid := Vector3(lean.x * band_y, band_y, lean.y * band_y)
		var rb := lerpf(r0, r1, 0.74) + 0.012
		MeshKit.prism(st, mid - Vector3(0, 0.06, 0), 6, rb, rb, 0.0, 0.12, turn, dark, dark, dark)
		for i in 3:
			var y := height * (0.3 + 0.14 * i)
			var rr := lerpf(r0, r1, y / height)
			for face in 6:
				var a := turn + (face + 0.5) * TAU / 6.0
				var out := Vector3(cos(a), 0.0, sin(a))
				var at := Vector3(lean.x * y, y, lean.y * y) + out * (rr * cos(PI / 6.0) + 0.01)
				MeshKit.block(st, at, Vector3(0.05, 0.11, 0.03 + rr * 0.3), -a, 0.0, dark, dark)
	for i in 3:
		var a := rng.randf() * TAU
		var d := r0 * rng.randf_range(1.2, 1.7)
		MeshKit.block(st, Vector3(cos(a) * d, 0.1, sin(a) * d), Vector3(0.3, 0.2, 0.26), rng.randf() * TAU, 0.0, stone * 0.9, SNOW)
	return MeshKit.finish(st)


## A snapped caravan wagon: the bed tipped on a broken axle, one wheel still on, one lying
## flat, the shaft snapped, snow over everything. The crates that spilled from it are placed
## around it by the dressing from the shipped Kenney models.
static func wagon(centre: Vector2) -> ArrayMesh:
	var rng := MeshKit.rng(centre)
	var st := MeshKit.begin()
	var tilt := 0.32
	var bed := Basis(Vector3.RIGHT, tilt) * Basis(Vector3.FORWARD, 0.1)
	var bed_at := Vector3(0, 0.55, 0)
	# Bed, sides and a broken front board.
	_oriented_box(st, bed_at, bed, Vector3(1.6, 0.12, 2.8), TIMBER, SNOW)
	_oriented_box(st, bed_at + bed * Vector3(-0.78, 0.3, 0.0), bed, Vector3(0.08, 0.5, 2.8), TIMBER_DARK, SNOW)
	_oriented_box(st, bed_at + bed * Vector3(0.78, 0.3, -0.7), bed, Vector3(0.08, 0.5, 1.4), TIMBER_DARK, SNOW)
	_oriented_box(st, bed_at + bed * Vector3(0.0, 0.3, -1.38), bed, Vector3(1.6, 0.5, 0.08), TIMBER_DARK, SNOW)
	# Hoops of a torn cover, two of three still standing.
	for z in [-0.9, 0.0]:
		var hoop_at := bed_at + bed * Vector3(0, 0.95, z)
		_oriented_box(st, hoop_at, bed, Vector3(1.7, 0.08, 0.08), TIMBER_DARK, SNOW)
		for side in [-0.82, 0.82]:
			_oriented_box(st, bed_at + bed * Vector3(side, 0.5, z), bed, Vector3(0.07, 0.9, 0.07), TIMBER_DARK, TIMBER_DARK)
	_oriented_box(st, bed_at + bed * Vector3(0.0, 1.0, -0.45), bed, Vector3(1.6, 0.04, 1.0), CANVAS, SNOW)
	# Axle, the wheel still on it, and the wheel that came off lying in the snow.
	_oriented_box(st, Vector3(0, 0.45, 0.9), Basis(), Vector3(2.0, 0.12, 0.12), TIMBER_DARK, TIMBER_DARK)
	_wheel(st, Vector3(1.05, 0.55, 0.9), Basis(Vector3.FORWARD, PI * 0.5) * Basis(Vector3.UP, 0.1), 0.55)
	_wheel(st, Vector3(-1.9, 0.06, 1.6), Basis(Vector3.UP, rng.randf() * TAU), 0.55)
	# The shaft, snapped: the stump on the wagon, the rest a few steps ahead.
	_oriented_box(st, Vector3(-0.2, 0.5, -1.9), Basis(Vector3.RIGHT, -0.5), Vector3(0.1, 0.1, 1.1), TIMBER_DARK, SNOW)
	_oriented_box(st, Vector3(0.6, 0.06, -3.3), Basis(Vector3.UP, 0.4), Vector3(0.1, 0.1, 1.6), TIMBER_DARK, SNOW)
	return MeshKit.finish(st)


## A frozen campfire ring: a circle of stones around ash and charred log ends, snow in the
## ash. It gives no warmth; the fires that do are the sim's.
static func fire_ring(centre: Vector2) -> ArrayMesh:
	var rng := MeshKit.rng(centre)
	var st := MeshKit.begin()
	var stone := Color(0.42, 0.44, 0.50)
	MeshKit.disc(st, Vector3(0, 0.02, 0), 0.7, 9, ASH, ASH.lightened(0.25), rng)
	for k in 9:
		var a := k * TAU / 9.0 + rng.randf_range(-0.1, 0.1)
		var shade := stone * rng.randf_range(0.85, 1.1)
		shade.a = 1.0
		MeshKit.block(st, Vector3(cos(a) * 0.72, 0.11, sin(a) * 0.72), Vector3(0.3, 0.22, 0.24), -a, 0.0, shade, SNOW)
	for i in 3:
		var a := rng.randf() * TAU
		MeshKit.block(st, Vector3(cos(a) * 0.2, 0.08, sin(a) * 0.2), Vector3(0.14, 0.14, 0.7), a + 0.3, 0.0, CHAR, SNOW)
	return MeshKit.finish(st)


# --- Scatter pieces ------------------------------------------------------------------------

## A heap of tumbled blocks, for the ring-two scatter.
static func rubble(seed_value: int, stone: Color) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var st := MeshKit.begin()
	for i in rng.randi_range(3, 5):
		var a := rng.randf() * TAU
		var d := rng.randf_range(0.0, 0.6)
		var shade := stone * rng.randf_range(0.82, 1.06)
		shade.a = 1.0
		MeshKit.block(st, Vector3(cos(a) * d, 0.16 + (0.3 if i == 0 else 0.0), sin(a) * d), Vector3(rng.randf_range(0.4, 0.7), 0.32, rng.randf_range(0.35, 0.5)), rng.randf() * TAU, rng.randf_range(-0.35, 0.35), shade, SNOW)
	return MeshKit.finish(st)


## A dead tree `height` tall: a bare, tapering trunk and a few snapped branches holding snow.
static func dead_tree(height: float, seed_value: int, wood: Color) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var st := MeshKit.begin()
	var dark := wood.darkened(0.25)
	var lean := Vector2(rng.randf_range(-0.06, 0.06), rng.randf_range(-0.06, 0.06))
	MeshKit.prism(st, Vector3.ZERO, 5, height * 0.06, height * 0.015, 0.0, height, rng.randf() * TAU, dark, wood, SNOW, lean)
	for i in rng.randi_range(3, 5):
		var y := height * rng.randf_range(0.4, 0.85)
		var a := rng.randf() * TAU
		var length := height * rng.randf_range(0.18, 0.32)
		var up := rng.randf_range(0.35, 0.8)
		var base := Vector3(lean.x * y, y, lean.y * y)
		var branch_lean := Vector2(cos(a), sin(a)) / up
		MeshKit.prism(st, base, 4, height * 0.022, height * 0.006, 0.0, length * up, a, dark, wood, SNOW, branch_lean)
	return MeshKit.finish(st)


## A scatter of bones, for the mouth of a wolf den.
static func bones(seed_value: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var st := MeshKit.begin()
	for i in rng.randi_range(4, 6):
		var a := rng.randf() * TAU
		var d := rng.randf_range(0.0, 0.8)
		var long := rng.randf_range(0.35, 0.7)
		var at := Vector3(cos(a) * d, 0.04, sin(a) * d)
		MeshKit.block(st, at, Vector3(0.06, 0.06, long), rng.randf() * TAU, 0.0, BONE, BONE)
	MeshKit.block(st, Vector3(0.3, 0.1, -0.2), Vector3(0.26, 0.2, 0.34), rng.randf() * TAU, 0.0, BONE * 0.95, BONE)
	return MeshKit.finish(st)


## A spike of ice, for the ring-two scatter.
static func ice_shard(height: float, seed_value: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var st := MeshKit.begin()
	MeshKit.shard(st, Vector3(0, 0.2, 0), height * 0.28, height, rng.randf() * TAU, ICE)
	MeshKit.shard(st, Vector3(height * 0.3, 0.1, 0.1), height * 0.14, height * 0.45, rng.randf() * TAU, ICE_DEEP)
	return MeshKit.finish(st)


# --- Landmarks ---------------------------------------------------------------------------

## A boulder split in two, the halves leaning apart over a gap a child could squeeze through.
static func split_rock(size: float, centre: Vector2, stone: Color) -> ArrayMesh:
	var rng := MeshKit.rng(centre)
	var st := MeshKit.begin()
	var dark := stone.darkened(0.3)
	for side in [-1.0, 1.0]:
		var at := Vector3(side * size * 0.28, 0, 0)
		var lean := Vector2(side * 0.18, rng.randf_range(-0.04, 0.04))
		MeshKit.prism(st, at, 7, size * 0.3, size * 0.2, -0.2, size * 0.5, rng.randf() * TAU, dark, stone, stone, lean)
		MeshKit.prism(st, at + Vector3(lean.x * size * 0.5, size * 0.5, lean.y * size * 0.5), 7, size * 0.2, size * 0.08, 0.0, size * 0.4, rng.randf() * TAU, stone, stone, SNOW, lean * 0.6)
	# The split face is dark and sharp; a few shards of rock lie in the gap.
	for i in 4:
		MeshKit.block(st, Vector3(rng.randf_range(-0.2, 0.2), 0.12, rng.randf_range(-size * 0.3, size * 0.3)), Vector3(0.3, 0.24, 0.28), rng.randf() * TAU, 0.0, dark, SNOW)
	return MeshKit.finish(st)


## A fallen giant pine `length` long along +x: the trunk on the ground, the root plate torn
## up at the near end, a few snapped branch stubs and snow along its upper side.
static func fallen_pine(length: float, centre: Vector2, wood: Color) -> ArrayMesh:
	var rng := MeshKit.rng(centre)
	var st := MeshKit.begin()
	var dark := wood.darkened(0.25)
	var r0 := length * 0.085
	var r1 := length * 0.03
	var sides := 7
	var ring0: Array[Vector3] = []
	var ring1: Array[Vector3] = []
	for k in sides:
		var a := k * TAU / sides
		ring0.append(Vector3(-length * 0.5, r0 + sin(a) * r0, cos(a) * r0))
		ring1.append(Vector3(length * 0.5, r0 * 0.6 + sin(a) * r1, cos(a) * r1))
	for k in sides:
		var n := (k + 1) % sides
		var out := (ring0[k] + ring0[n]) * 0.5 - Vector3(-length * 0.5, r0, 0)
		var snowy := out.y > 0.3
		MeshKit.quad(st, ring0[k], ring0[n], ring1[n], ring1[k], SNOW if snowy else wood, SNOW if snowy else wood, out)
	# The root plate: a disc of roots standing on end where the tree tore out of the ground.
	var plate := Vector3(-length * 0.5, r0, 0)
	for k in 8:
		var a := k * TAU / 8.0
		var tip := plate + Vector3(-r0 * 0.6, sin(a) * r0 * 2.1, cos(a) * r0 * 2.1)
		var b := plate + Vector3(0, sin(a + 0.3) * r0 * 0.9, cos(a + 0.3) * r0 * 0.9)
		var c := plate + Vector3(0, sin(a - 0.3) * r0 * 0.9, cos(a - 0.3) * r0 * 0.9)
		MeshKit.tri_shade(st, b, c, tip, dark, dark, wood, Vector3.LEFT)
		MeshKit.tri_shade(st, b, c, tip, dark, dark, wood, Vector3.RIGHT)
	for i in 5:
		var x := rng.randf_range(-length * 0.3, length * 0.45)
		var a := rng.randf_range(0.3, PI - 0.3)
		var r := lerpf(r0, r1, (x + length * 0.5) / length)
		var base := Vector3(x, r0 + sin(a) * r * 0.8, cos(a) * r * 0.8)
		MeshKit.block(st, base + Vector3(0, sin(a) * 0.35, cos(a) * 0.35), Vector3(0.12, 0.7, 0.12), 0.0, -a + PI * 0.5, dark, SNOW)
	return MeshKit.finish(st)


## A dead giant: one huge bare tree, its crown snapped off, standing alone.
static func dead_giant(height: float, centre: Vector2, wood: Color) -> ArrayMesh:
	var rng := MeshKit.rng(centre)
	var st := MeshKit.begin()
	var dark := wood.darkened(0.3)
	MeshKit.prism(st, Vector3.ZERO, 7, height * 0.11, height * 0.07, -0.2, height * 0.08, rng.randf() * TAU, dark, dark, dark)
	MeshKit.prism(st, Vector3.ZERO, 7, height * 0.09, height * 0.035, height * 0.08, height, rng.randf() * TAU, dark, wood, dark)
	for i in 6:
		var y := height * rng.randf_range(0.35, 0.9)
		var a := i * TAU / 6.0 + rng.randf_range(-0.3, 0.3)
		var up := rng.randf_range(0.5, 1.1)
		var length := height * rng.randf_range(0.2, 0.36)
		MeshKit.prism(st, Vector3(0, y, 0), 4, height * 0.03, height * 0.008, 0.0, length * up, a, dark, wood, SNOW, Vector2(cos(a), sin(a)) / up)
	for i in 3:
		var a := rng.randf() * TAU
		MeshKit.block(st, Vector3(cos(a) * height * 0.2, 0.08, sin(a) * height * 0.2), Vector3(0.15, 0.15, rng.randf_range(0.8, 1.6)), rng.randf() * TAU, 0.0, dark, SNOW)
	return MeshKit.finish(st)


## A frozen waterfall `width` across and `height` tall hanging down a cliff face at -z: a
## sheet of deep blue ice in broad ribs, each bellying out as it falls and splaying into a
## frozen pool at the foot, with shards where the spray froze. Stands with the cliff face
## through the origin and the pool spreading to +z.
static func frozen_waterfall(width: float, height: float, centre: Vector2) -> ArrayMesh:
	var rng := MeshKit.rng(centre)
	var st := MeshKit.begin()
	MeshKit.disc(st, Vector3(0, 0.03, width * 0.5), width * 0.8, 12, ICE, ICE_PALE, rng)
	var ribs := maxi(int(width / 0.7), 3)
	for i in ribs:
		var u := -width * 0.5 + (i + 0.5) * width / ribs
		var w := width / ribs * rng.randf_range(0.45, 0.6)
		var top := height * rng.randf_range(0.75, 1.0)
		var belly := rng.randf_range(0.5, 0.9)
		var colour := ICE_DEEP if i % 2 == 0 else ICE_DEEP.lerp(ICE, 0.5)
		# Four bands from the pool to the lip: foot splayed, belly out, back in under the lip.
		var profile := [[0.0, 0.0, w * 1.6], [0.2, belly, w], [0.65, belly * 0.8, w * 0.9], [1.0, 0.1, w * 0.7]]
		for k in profile.size() - 1:
			var a: Array = profile[k]
			var b: Array = profile[k + 1]
			var y0 := top * float(a[0])
			var y1 := top * float(b[0])
			var z0 := float(a[1])
			var z1 := float(b[1])
			var w0 := float(a[2])
			var w1 := float(b[2])
			var shade := colour.lerp(ICE, float(k) / (profile.size() - 1))
			var cap := ICE_PALE if k == profile.size() - 2 else shade
			MeshKit.quad(st, Vector3(u - w0, y0, z0), Vector3(u + w0, y0, z0), Vector3(u + w1, y1, z1), Vector3(u - w1, y1, z1), shade, cap, Vector3.BACK)
			MeshKit.quad(st, Vector3(u + w0, y0, z0), Vector3(u + w0, y0, z0 - 0.3), Vector3(u + w1, y1, z1 - 0.3), Vector3(u + w1, y1, z1), shade, cap, Vector3.RIGHT)
			MeshKit.quad(st, Vector3(u - w0, y0, z0), Vector3(u - w0, y0, z0 - 0.3), Vector3(u - w1, y1, z1 - 0.3), Vector3(u - w1, y1, z1), shade, cap, Vector3.LEFT)
		MeshKit.quad(st, Vector3(u - w * 0.7, top, 0.1), Vector3(u + w * 0.7, top, 0.1), Vector3(u + w * 0.7, top, -0.3), Vector3(u - w * 0.7, top, -0.3), SNOW, SNOW, Vector3.UP)
	for i in 7:
		var x := rng.randf_range(-width * 0.6, width * 0.6)
		var z := rng.randf_range(0.8, width * 0.9)
		MeshKit.shard(st, Vector3(x, 0.25, z), rng.randf_range(0.2, 0.4), rng.randf_range(0.5, 1.4), rng.randf() * TAU, ICE)
	return MeshKit.finish(st)


## A spire of ice: a cluster of tall shards grown up through the snow.
static func ice_spire(height: float, centre: Vector2) -> ArrayMesh:
	var rng := MeshKit.rng(centre)
	var st := MeshKit.begin()
	MeshKit.shard(st, Vector3(0, 0.3, 0), height * 0.26, height, rng.randf() * TAU, ICE)
	for i in 6:
		var a := i * TAU / 6.0 + rng.randf_range(-0.3, 0.3)
		var d := height * rng.randf_range(0.2, 0.4)
		var h := height * rng.randf_range(0.3, 0.65)
		MeshKit.shard(st, Vector3(cos(a) * d, 0.2, sin(a) * d), h * 0.3, h, rng.randf() * TAU, ICE_DEEP if i % 2 == 0 else ICE)
	return MeshKit.finish(st)


## A ruined watch post in the outpost's own timber: four posts, what is left of the platform
## they held, a ladder fallen against them. The outpost once kept a lookout this far out.
static func watch_post(height: float, centre: Vector2) -> ArrayMesh:
	var rng := MeshKit.rng(centre)
	var st := MeshKit.begin()
	var half := 0.9
	var corners := [Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half)]
	for i in corners.size():
		var c: Vector2 = corners[i]
		var top := height * (1.0 if i < 2 else rng.randf_range(0.45, 0.7))
		MeshKit.log_post(st, Vector3(c.x, 0, c.y), -0.2, top, 0.14, 0.12, Vector2(rng.randf_range(-0.03, 0.03), rng.randf_range(-0.03, 0.03)), TIMBER_DARK)
	# The platform, half of it: planks across the two tall posts and sagging towards the broken side.
	var deck := Basis(Vector3.RIGHT, 0.18)
	for i in 4:
		_oriented_box(st, Vector3(0, height - 0.3, -half + 0.2 + i * 0.3), deck, Vector3(half * 2.3, 0.08, 0.26), TIMBER, SNOW)
	_oriented_box(st, Vector3(0, height - 0.1, -half - 0.1), Basis(), Vector3(half * 2.3, 0.08, 0.08), TIMBER_DARK, SNOW)
	for side in [-1.0, 1.0]:
		_oriented_box(st, Vector3(side * half * 1.1, height + 0.3, -half - 0.1), Basis(), Vector3(0.08, 0.9, 0.08), TIMBER_DARK, TIMBER_DARK)
	_oriented_box(st, Vector3(0, height + 0.7, -half - 0.1), Basis(), Vector3(half * 2.3, 0.08, 0.08), TIMBER_DARK, SNOW)
	# The ladder, fallen against the post that still stands.
	var ladder := Basis(Vector3.RIGHT, -1.1) * Basis(Vector3.UP, 0.2)
	var foot := Vector3(-half - 0.6, 0.1, half + 1.6)
	for side in [-0.25, 0.25]:
		_oriented_box(st, foot + ladder * Vector3(side, 1.6, 0), ladder, Vector3(0.07, 3.2, 0.07), TIMBER_DARK, SNOW)
	for i in 6:
		_oriented_box(st, foot + ladder * Vector3(0, 0.4 + i * 0.5, 0), ladder, Vector3(0.6, 0.06, 0.06), TIMBER, SNOW)
	return MeshKit.finish(st)


# --- The mine ----------------------------------------------------------------------------

## Crushed rock tipped out of a mine, an earthy grey against the snowfield.
const SPOIL := Color(0.50, 0.45, 0.40)
## The dark of a mine's mouth.
const ADIT := Color(0.07, 0.07, 0.08)


## A boulder `radius` round at its foot, with veins of ore streaking its faces, one colour per ore in
## `veins`, and snow on its crown. Bigger than any rock a pickaxe works, and never glinting,
## so it dresses a mine without passing for a node.
static func ore_boulder(radius: float, centre: Vector2, stone: Color, veins: Array) -> ArrayMesh:
	var rng := MeshKit.rng(centre)
	var st := MeshKit.begin()
	var dark := stone.darkened(0.3)
	var turn := rng.randf() * TAU
	var lean := Vector2(rng.randf_range(-0.08, 0.08), rng.randf_range(-0.08, 0.08))
	var body := radius * 1.1
	MeshKit.prism(st, Vector3.ZERO, 7, radius, radius * 0.75, -0.2, body, turn, dark, stone, stone, lean)
	var crown := Vector3(lean.x * (body + 0.2), body, lean.y * (body + 0.2))
	MeshKit.prism(st, crown, 7, radius * 0.75, radius * 0.3, 0.0, radius * 0.5, turn, stone, stone, SNOW, lean * 0.6)
	# Veins cut diagonally across the faces, a band of each ore in turn.
	for face in 7:
		var a := turn + (face + 0.5) * TAU / 7.0
		var out := Vector3(cos(a), 0.0, sin(a))
		for k in rng.randi_range(1, 2):
			var y := body * rng.randf_range(0.25, 0.8)
			var r := lerpf(radius, radius * 0.75, (y + 0.2) / (body + 0.2)) * cos(PI / 7.0)
			var at := Vector3(lean.x * (y + 0.2), y, lean.y * (y + 0.2)) + out * (r + 0.015)
			var vein: Color = veins[(face + k) % veins.size()]
			MeshKit.block(st, at, Vector3(0.04, 0.09, radius * rng.randf_range(0.5, 0.8)), -a, rng.randf_range(-0.6, 0.6), vein, vein)
	return MeshKit.finish(st)


## A spoil heap covering `half` (x, z extents): a low mound of crushed rock with a smaller
## one tipped against it, chips of stone and ore over both and only a dusting of snow, since
## the miners keep tipping fresh spoil on it.
static func spoil_heap(half: Vector2, centre: Vector2, stone: Color, veins: Array) -> ArrayMesh:
	var rng := MeshKit.rng(centre)
	var st := MeshKit.begin()
	var r := minf(half.x, half.y)
	var dusted := SPOIL.lerp(SNOW, 0.45)
	var mounds := [[Vector3((half.x - r) * 0.5, 0, 0), r, r * 0.8], [Vector3(-(half.x - r * 0.6), 0, r * 0.2), r * 0.6, r * 0.5]]
	for m in mounds:
		var at: Vector3 = m[0]
		var mr: float = m[1]
		var h: float = m[2]
		MeshKit.prism(st, at, 8, mr, mr * 0.55, -0.05, h * 0.6, rng.randf() * TAU, SPOIL.darkened(0.15), SPOIL, SPOIL)
		MeshKit.prism(st, at + Vector3(0, h * 0.6, 0), 8, mr * 0.55, mr * 0.15, 0.0, h * 0.4, rng.randf() * TAU, SPOIL, dusted, dusted)
	for i in 12:
		var a := rng.randf() * TAU
		var d := r * rng.randf_range(0.5, 1.0)
		var chip: Color = veins[i % veins.size()] if i % 3 == 0 else stone * rng.randf_range(0.8, 1.0)
		chip.a = 1.0
		MeshKit.block(st, Vector3(cos(a) * d * (half.x / r), 0.06, sin(a) * d), Vector3(0.2, 0.14, 0.17) * rng.randf_range(0.7, 1.3), rng.randf() * TAU, rng.randf_range(-0.4, 0.4), chip, chip)
	return MeshKit.finish(st)


## A rock face covering `half` (x, z extents) on a cliff, facing +x: slabs of rock rising
## above the ice, highest in the middle, streaked with `veins` of ore, and in the middle at
## its foot a timber-framed adit, boarded up. Nothing stands past the ground it covers.
static func mine_face(half: Vector2, height: float, centre: Vector2, stone: Color, veins: Array) -> ArrayMesh:
	var rng := MeshKit.rng(centre)
	var st := MeshKit.begin()
	var front := half.x - 0.45  # the face; the adit's frame stands before it
	var slabs := maxi(int(half.y * 2.0 / 1.5), 3)
	var width := half.y * 2.0 / slabs
	for i in slabs:
		var z := -half.y + (i + 0.5) * width
		var fall := 1.0 - 0.55 * pow(absf(z) / half.y, 2.0)
		var h := height * fall * rng.randf_range(0.85, 1.0)
		var depth := rng.randf_range(1.4, 2.0)
		var back := rng.randf_range(0.0, 0.35)
		var shade := stone * rng.randf_range(0.85, 1.05)
		shade.a = 1.0
		if absf(z) < 1.1:
			# Over the adit only the upper rock, held up by the lintel.
			MeshKit.block(st, Vector3(front - back - depth * 0.5, 2.3 + (h - 2.3) * 0.5, z), Vector3(depth, h - 2.3, width * 0.92), rng.randf_range(-0.05, 0.05), 0.0, shade, SNOW)
		else:
			MeshKit.block(st, Vector3(front - back - depth * 0.5, h * 0.5, z), Vector3(depth, h, width * 0.92), rng.randf_range(-0.05, 0.05), 0.0, shade, SNOW)
		# A second, set-back tier so the top steps up into the cliff like a mountainside.
		var upper := h * rng.randf_range(0.2, 0.35)
		MeshKit.box(st, Vector3(-half.x + 0.75, h + upper * 0.5 - 0.3, z + rng.randf_range(-0.1, 0.1)), Vector3(1.4, upper + 0.3, width * 0.8), shade, SNOW)
		# Veins slanting down the face.
		for k in 2:
			var vein: Color = veins[(i + k) % veins.size()]
			var y := rng.randf_range(0.6, h - 0.5)
			if absf(z) < 1.1 and y < 2.5:
				continue
			MeshKit.block(st, Vector3(front - back + 0.015, y, z + rng.randf_range(-0.1, 0.1)), Vector3(0.04, 0.12, width * 0.6), 0.0, rng.randf_range(-0.7, 0.7), vein, vein)
	# The adit: a dark mouth in the rock, its timber frame, and boards nailed across it.
	MeshKit.box(st, Vector3(front - 0.6, 1.1, 0), Vector3(1.2, 2.2, 2.2), ADIT, ADIT)
	for side in [-1.0, 1.0]:
		MeshKit.log_post(st, Vector3(front + 0.2, 0, side * 0.95), -0.1, 2.25, 0.12, 0.0, Vector2.ZERO, TIMBER_DARK, TIMBER_DARK)
	_oriented_box(st, Vector3(front + 0.2, 2.35, 0), Basis(), Vector3(0.26, 0.24, 2.4), TIMBER_DARK, SNOW)
	for i in 3:
		var tilt: float = [0.25, -0.18, 0.1][i]
		_oriented_box(st, Vector3(front + 0.12, 0.5 + i * 0.6, 0), Basis(Vector3.RIGHT, tilt), Vector3(0.05, 0.2, 1.95), TIMBER, TIMBER)
	# Fallen rock at the foot of the face, either side of the adit.
	for i in 6:
		var z := rng.randf_range(1.4, half.y - 0.5) * (1.0 if i % 2 == 0 else -1.0)
		MeshKit.block(st, Vector3(front + rng.randf_range(-0.2, 0.1), 0.15, z), Vector3(0.45, 0.3, 0.4), rng.randf() * TAU, rng.randf_range(-0.3, 0.3), stone * 0.9, SNOW)
	return MeshKit.finish(st)


## A dungeon's mouth through a cliff: a passage `depth` metres long along +x and `width`
## across, between dark rock jambs a little above the cliff, under a rock arch at each end with
## icicles hanging from it. The passage is open to the sky between the arches and dark all the
## way down (ADIT), so from above it reads as a black cleft in the ice, and anyone walking
## through goes into the shadow of the rock. Nothing stands past the ground it covers but the
## fallen rock at its ends.
static func cave_mouth(width: float, depth: float, height: float, centre: Vector2, stone: Color) -> ArrayMesh:
	var rng := MeshKit.rng(centre)
	var st := MeshKit.begin()
	var rock := stone.darkened(0.35)
	var jamb_top := height * 0.95
	MeshKit.box(st, Vector3(0, jamb_top * 0.5, 0), Vector3(depth + 0.2, jamb_top, width), ADIT, ADIT)
	for side in [-1.0, 1.0]:
		for k in 3:
			var x := -depth * 0.5 + (k + 0.5) * depth / 3.0
			var tall := jamb_top * rng.randf_range(0.95, 1.2)
			var shade := rock * rng.randf_range(0.85, 1.1)
			shade.a = 1.0
			MeshKit.block(st, Vector3(x, tall * 0.5, side * (width * 0.5 + 0.8)), Vector3(depth / 3.0 + 0.3, tall, 1.6), rng.randf_range(-0.08, 0.08), 0.0, shade, shade.lightened(0.15))
	# An arch at each end: a slab of rock over the way through, a boulder on it, snow on top.
	for end in [-1.0, 1.0]:
		var x: float = end * (depth * 0.5 - 0.1)
		MeshKit.block(st, Vector3(x, jamb_top + 0.35, 0), Vector3(1.1, 0.9, width + 2.8), rng.randf_range(-0.05, 0.05), 0.0, rock, SNOW)
		var r := rng.randf_range(0.7, 0.95)
		MeshKit.block(st, Vector3(x, jamb_top + 0.8 + r * 0.4, rng.randf_range(-0.6, 0.6)), Vector3(r * 1.3, r, r * 1.6), rng.randf() * TAU, rng.randf_range(-0.2, 0.2), rock * 1.1, SNOW)
		for i in 6:
			var z := -width * 0.5 + (i + 0.5) * width / 6.0 + rng.randf_range(-0.15, 0.15)
			var long := rng.randf_range(0.5, 1.1)
			MeshKit.prism(st, Vector3(x + end * 0.45, 0, z), 4, 0.1, 0.01, jamb_top - 0.1, jamb_top - 0.1 - long, rng.randf() * TAU, ICE, ICE_PALE, ICE_PALE)
	# Fallen rock at the foot of both ends, to either side of the way through.
	for i in 8:
		var end := 1.0 if i % 2 == 0 else -1.0
		var z := rng.randf_range(width * 0.5 - 0.2, width * 0.5 + 1.4) * (1.0 if i % 4 < 2 else -1.0)
		MeshKit.block(st, Vector3(end * (depth * 0.5 + rng.randf_range(0.3, 1.0)), 0.2, z), Vector3(0.6, 0.4, 0.5), rng.randf() * TAU, rng.randf_range(-0.3, 0.3), rock, SNOW)
	return MeshKit.finish(st)


# --- Helpers -----------------------------------------------------------------------------

## A box of `size` in the frame `basis`, centred at `at`; its top takes `top` if it faces up.
static func _oriented_box(st: SurfaceTool, at: Vector3, basis: Basis, size: Vector3, colour: Color, top: Color) -> void:
	var h := size * 0.5
	var c: Array[Vector3] = []
	for i in 8:
		c.append(at + basis * Vector3(-h.x if i & 1 == 0 else h.x, -h.y if i & 2 == 0 else h.y, -h.z if i & 4 == 0 else h.z))
	var up := basis * Vector3.UP
	var top_colour := top if up.y > 0.6 else colour
	MeshKit.quad(st, c[0], c[1], c[3], c[2], colour, colour, basis * Vector3.FORWARD)
	MeshKit.quad(st, c[4], c[5], c[7], c[6], colour, colour, basis * Vector3.BACK)
	MeshKit.quad(st, c[0], c[4], c[6], c[2], colour, colour, basis * Vector3.LEFT)
	MeshKit.quad(st, c[1], c[5], c[7], c[3], colour, colour, basis * Vector3.RIGHT)
	MeshKit.quad(st, c[2], c[3], c[7], c[6], top_colour, top_colour, up)
	MeshKit.quad(st, c[0], c[1], c[5], c[4], colour, colour, -up)


## A cart wheel: a rim of eight blocks and four spokes, lying in the plane `basis` turns
## the xz plane into.
static func _wheel(st: SurfaceTool, at: Vector3, basis: Basis, radius: float) -> void:
	for k in 8:
		var a := k * TAU / 8.0
		var local := Vector3(cos(a) * radius, 0, sin(a) * radius)
		_oriented_box(st, at + basis * local, basis * Basis(Vector3.UP, -a), Vector3(radius * 0.8, 0.1, 0.12), TIMBER_DARK, TIMBER_DARK)
	for k in 2:
		_oriented_box(st, at, basis * Basis(Vector3.UP, k * PI * 0.5), Vector3(radius * 1.9, 0.08, 0.08), TIMBER, TIMBER)
	_oriented_box(st, at, basis, Vector3(0.22, 0.18, 0.22), TIMBER_DARK, TIMBER_DARK)
