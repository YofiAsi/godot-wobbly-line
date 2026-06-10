@tool
@icon("res://addons/wobbly_shapes/icons/wobble_shape_2d.svg")
class_name WobblePolygon
extends WobbleItem

## A closed, filled wobbly polygon. Vertices come from `points` (editable live in
## the 2D viewport when this node is selected).

@export var points := PackedVector2Array([Vector2(-50, -40), Vector2(50, -40), Vector2(0, 50)]):
	set(v):
		points = v
		mark_geometry_dirty()            # vertex drag -> no re-roll
		queue_redraw()


func _base_path() -> PackedVector2Array:
	return points


func is_closed() -> bool:
	return true


func editable_points() -> bool:
	return true
