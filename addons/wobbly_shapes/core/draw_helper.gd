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
	draw_fill(ci, pts, closed, style)
	draw_stroke(ci, pts, closed, style)


## The filled silhouette only (closed shapes). Used on its own as the clip mask
## when children are clipped to the shape (see WobbleBody).
static func draw_fill(ci: CanvasItem, pts: PackedVector2Array, closed: bool, style: WobbleStyle) -> void:
	if style == null or pts.size() < 3:
		return
	if closed:
		draw_colored_polygon_safe(ci, pts, style.fill_color)


## The hand-drawn outline only. Drawn last (on top) when clipping is active so the
## child content can't cover the inner edge of the stroke.
static func draw_stroke(ci: CanvasItem, pts: PackedVector2Array, closed: bool, style: WobbleStyle) -> void:
	if style == null or pts.size() < 2 or style.stroke_width <= 0.0:
		return
	var line := pts.duplicate()
	if closed:
		line.append(pts[0])                     # close the loop
	ci.draw_polyline(line, style.stroke_color, style.stroke_width, true)


static func draw_colored_polygon_safe(ci: CanvasItem, pts: PackedVector2Array, color: Color) -> void:
	if color.a <= 0.0:
		return
	ci.draw_colored_polygon(pts, color)
