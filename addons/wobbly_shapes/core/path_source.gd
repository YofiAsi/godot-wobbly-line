@tool
class_name WobblePath
extends RefCounted

## Base-path builders. Each returns an ordered PackedVector2Array in local
## space; whether the result is closed is the caller's concern (see the wrapper
## nodes). These feed straight into WobbleCore.process().


## Rounded rectangle: straight edges + quarter-arc corners, as a closed ring.
## (Ported from the original WobblyRect prototype.)
static func rounded_rect(size: Vector2, radius: float, seg_per_corner := 6) -> PackedVector2Array:
	var w := size.x
	var h := size.y
	var r := clampf(radius, 0.0, minf(w, h) * 0.5)
	var pts := PackedVector2Array()
	var c_tr := Vector2(w - r, r)
	var c_br := Vector2(w - r, h - r)
	var c_bl := Vector2(r, h - r)
	var c_tl := Vector2(r, r)
	pts.append(Vector2(r, 0))
	pts.append(Vector2(w - r, 0))                       # top edge
	_append_arc(pts, c_tr, r, -PI / 2.0, 0.0, seg_per_corner)
	pts.append(Vector2(w, h - r))                       # right edge
	_append_arc(pts, c_br, r, 0.0, PI / 2.0, seg_per_corner)
	pts.append(Vector2(r, h))                           # bottom edge
	_append_arc(pts, c_bl, r, PI / 2.0, PI, seg_per_corner)
	pts.append(Vector2(0, r))                           # left edge
	_append_arc(pts, c_tl, r, PI, 3.0 * PI / 2.0, seg_per_corner)
	return pts


## Ellipse / circle, oversampled in the t parameter. Uniform t is NOT
## arc-length-uniform for an ellipse (points bunch near the major-axis ends),
## but the core's arc-length resample fixes that, so we just hand it plenty of
## points. A circle (rx == ry) is already uniform. Returned as a closed ring.
static func ellipse(center: Vector2, rx: float, ry: float, samples := 96) -> PackedVector2Array:
	var n := maxi(8, samples)
	var pts := PackedVector2Array()
	pts.resize(n)
	for i in n:
		var t := TAU * float(i) / float(n)
		pts[i] = center + Vector2(cos(t) * rx, sin(t) * ry)
	return pts


## Bezier path via Godot's own adaptive flattening. Reuse Curve2D so we inherit
## the engine's bezier data model and the Path2D in/out-handle metaphor.
static func bezier(curve: Curve2D, max_stages := 5, tolerance_degrees := 4.0) -> PackedVector2Array:
	if curve == null or curve.point_count < 2:
		return PackedVector2Array()
	return curve.tessellate(max_stages, tolerance_degrees)


static func _append_arc(pts: PackedVector2Array, c: Vector2, r: float, a0: float, a1: float, seg: int) -> void:
	for i in range(1, seg + 1):
		var t := float(i) / float(seg)
		var a := lerpf(a0, a1, t)
		pts.append(c + Vector2(cos(a), sin(a)) * r)
