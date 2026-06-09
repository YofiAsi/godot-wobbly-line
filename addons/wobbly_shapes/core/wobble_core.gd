@tool
class_name WobbleCore
extends RefCounted

## Shared, stateless geometry pipeline for the wobbly-shapes addon.
##
## Pure static functions, open/closed aware, allocating only the buffers they
## must. The pipeline mirrors the proven rounded-rect prototype, generalized:
##
##   base path  ->  arc-length resample to K points
##              ->  per-point normal offset ("wiggle") by stable amplitudes
##              ->  Chaikin corner-cutting ("smoothen", N passes)
##
## Amplitudes are rolled ONCE per seed/frequency change (see WobbleState) and
## passed in here, so resizing/dragging never re-rolls them -> no twitch.


## Total length of a polyline. When [code]closed[/code], the wrap segment
## (last -> first) is included.
static func perimeter(pts: PackedVector2Array, closed: bool) -> float:
	var n := pts.size()
	if n < 2:
		return 0.0
	var total := 0.0
	for i in n - 1:
		total += pts[i].distance_to(pts[i + 1])
	if closed:
		total += pts[n - 1].distance_to(pts[0])
	return total


## Number of bumps (control points) for a given perimeter. FREQUENCY is bumps
## per 100 px of perimeter. Closed shapes get a higher floor so small shapes
## still read as "wobbly".
static func point_count(perim: float, frequency: float, closed: bool) -> int:
	var floor_k := 8 if closed else 3
	return maxi(floor_k, int(round(frequency * perim / 100.0)))


## Roll one random amplitude in [-1, 1] per bump. Deterministic for a seed.
static func roll_amplitudes(count: int, p_seed: int) -> PackedFloat32Array:
	var amps := PackedFloat32Array()
	if count <= 0:
		return amps
	amps.resize(count)
	var rng := RandomNumberGenerator.new()
	rng.seed = p_seed
	for i in count:
		amps[i] = rng.randf_range(-1.0, 1.0)
	return amps


## Full pipeline. [code]amplitudes.size()[/code] sets K (the point count), so
## the caller controls re-rolling. Returns the final ring/polyline to draw.
static func process(base: PackedVector2Array, closed: bool, amplitudes: PackedFloat32Array, wiggle: float, smoothen_passes: int) -> PackedVector2Array:
	var k := amplitudes.size()
	if k < 2 or base.size() < 2:
		return PackedVector2Array()
	var ring := resample(base, closed, k)
	ring = jitter(ring, closed, amplitudes, wiggle)
	for _i in smoothen_passes:
		ring = chaikin(ring, closed)
	return ring


## Resample a polyline into exactly [code]n[/code] points evenly spaced by arc
## length. Closed paths wrap (n points around the loop, point n == point 0).
## Open paths pin both endpoints (point 0 == start, point n-1 == end) and add
## no closing segment.
static func resample(pts: PackedVector2Array, closed: bool, n: int) -> PackedVector2Array:
	if pts.size() < 2 or n < 2:
		return pts.duplicate()

	# Build the segment list (append the wrap point for closed paths).
	var src := pts.duplicate()
	if closed:
		src.append(pts[0])
	var seg_lens := PackedFloat32Array()
	var total := 0.0
	for i in src.size() - 1:
		var l := src[i].distance_to(src[i + 1])
		seg_lens.append(l)
		total += l
	if total <= 0.0:
		return pts.duplicate()

	var step: float = total / float(n) if closed else total / float(n - 1)
	var out := PackedVector2Array()
	out.resize(n)
	var seg_i := 0
	var walked := 0.0
	for i in n:
		# Open paths land their last point exactly on the source endpoint.
		if not closed and i == n - 1:
			out[i] = src[src.size() - 1]
			continue
		var target := step * float(i)
		while seg_i < seg_lens.size() - 1 and walked + seg_lens[seg_i] < target:
			walked += seg_lens[seg_i]
			seg_i += 1
		var local := 0.0
		if seg_lens[seg_i] > 0.0:
			local = (target - walked) / seg_lens[seg_i]
		out[i] = src[seg_i].lerp(src[seg_i + 1], clampf(local, 0.0, 1.0))
	return out


## Push each point along its local normal by its (stable) amplitude * wiggle.
## Closed: tangent from neighbors (i-1, i+1) mod k. Open: one-sided tangents at
## the ends, and amplitude pinned to 0 at both endpoints so an open path starts
## and ends exactly where the user placed it.
static func jitter(ring: PackedVector2Array, closed: bool, amps: PackedFloat32Array, wiggle: float) -> PackedVector2Array:
	var k := ring.size()
	var out := PackedVector2Array()
	out.resize(k)
	for i in k:
		var tang: Vector2
		if closed:
			tang = ring[(i + 1) % k] - ring[(i - 1 + k) % k]
		elif i == 0:
			tang = ring[1] - ring[0]
		elif i == k - 1:
			tang = ring[k - 1] - ring[k - 2]
		else:
			tang = ring[i + 1] - ring[i - 1]
		if tang.length() < 0.0001:
			tang = Vector2.RIGHT
		tang = tang.normalized()
		var nrm := Vector2(-tang.y, tang.x)
		var amp: float = (amps[i] if i < amps.size() else 0.0) * wiggle
		if not closed and (i == 0 or i == k - 1):
			amp = 0.0
		out[i] = ring[i] + nrm * amp
	return out


## One Chaikin corner-cutting pass (classic 0.25/0.75 ratios). Closed rings cut
## every edge including the wrap edge. Open polylines keep the first and last
## points fixed and only cut interior corners.
static func chaikin(p: PackedVector2Array, closed: bool) -> PackedVector2Array:
	var n := p.size()
	if n < 3:
		return p.duplicate()
	var out := PackedVector2Array()
	if not closed:
		out.append(p[0])
	var limit := n if closed else n - 1
	for i in limit:
		var a := p[i]
		var b := p[(i + 1) % n]
		out.append(a.lerp(b, 0.25))
		out.append(a.lerp(b, 0.75))
	if not closed:
		out.append(p[n - 1])
	return out
