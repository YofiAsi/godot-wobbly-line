@tool
extends Node2D

## Demo glue. The wobbly nodes now drive their own "boil" via `auto_play`, so this
## script only seeds the bezier shape's Curve2D as a fallback (the scene file also
## serializes it, so this is a no-op unless the curve is missing).

func _ready() -> void:
	_build_bezier()


func _build_bezier() -> void:
	var bz := get_node_or_null("Shapes/Bezier") as WobbleBezier
	if bz == null:
		return
	if bz.curve != null and bz.curve.point_count >= 2:
		return
	var c := Curve2D.new()
	# position, in-handle (relative), out-handle (relative)
	c.add_point(Vector2(-110, 30), Vector2.ZERO, Vector2(40, -90))
	c.add_point(Vector2(0, -50), Vector2(-60, 0), Vector2(60, 0))
	c.add_point(Vector2(110, 30), Vector2(-40, -90), Vector2.ZERO)
	bz.curve = c
