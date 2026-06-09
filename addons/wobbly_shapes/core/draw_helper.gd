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


static func draw_colored_polygon_safe(ci: CanvasItem, pts: PackedVector2Array, color: Color) -> void:
	if color.a <= 0.0:
		return
	ci.draw_colored_polygon(pts, color)
