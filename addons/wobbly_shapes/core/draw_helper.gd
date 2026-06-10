@tool
class_name WobbleDraw
extends RefCounted

## Shared fill + stroke drawing. Keeps every shape to one fill call and one
## stroke call (many small draw calls have real per-call overhead).
##
## Closed shapes: filled polygon + closed antialiased polyline.
## Open shapes:   no fill, antialiased polyline only.
##
## Note: draw_colored_polygon has no antialias argument, so fill AA relies on
## 2D MSAA (enabled in project.godot). draw_polyline does antialias the stroke.

static func draw_shape(ci: CanvasItem, pts: PackedVector2Array, closed: bool, style: WobbleStyle) -> void:
	if style == null or pts.size() < 2:
		return
	if closed and pts.size() >= 3:
		draw_colored_polygon_safe(ci, pts, style.fill_color)
	if style.stroke_width > 0.0:
		var line := pts.duplicate()
		if closed:
			line.append(pts[0])                 # close the loop
		ci.draw_polyline(line, style.stroke_color, style.stroke_width, true)


## draw_colored_polygon triangulates on the CPU and fails (logging
## "Invalid polygon data, triangulation failed." and dropping the fill) on
## self-intersecting outlines. triangulate_polygon is a silent pre-check; if it
## fails, resolve the self-intersection into simple sub-polygons via a
## self-union and fill each solid (counter-clockwise) region, skipping holes.
static func draw_colored_polygon_safe(ci: CanvasItem, pts: PackedVector2Array, color: Color) -> void:
	if color.a <= 0.0 or pts.size() < 3:
		return
	if not Geometry2D.triangulate_polygon(pts).is_empty():
		ci.draw_colored_polygon(pts, color)
		return
	for poly in Geometry2D.merge_polygons(pts, pts):
		if poly.size() >= 3 and not Geometry2D.is_polygon_clockwise(poly):
			ci.draw_colored_polygon(poly, color)
