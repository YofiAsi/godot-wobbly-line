@tool
@icon("res://addons/wobbly_shapes/icons/wobble_shape_2d.svg")
class_name WobbleLine
extends WobbleItem

## A wobbly polyline that acts like a Line2D: an open stroke through `points`
## (editable live in the 2D viewport). Set `closed` to join the ends into a
## filled loop.

@export var points := PackedVector2Array([Vector2(-90, 40), Vector2(-45, -40), Vector2(0, 40), Vector2(45, -40), Vector2(90, 40)]):
	set(v):
		points = v
		mark_geometry_dirty()            # vertex drag -> no re-roll
		queue_redraw()

## When true the line closes into a filled loop (open vs. closed is a topology
## change, so this re-rolls the wobble pattern).
@export var closed := false:
	set(v):
		closed = v
		notify_topology_changed()


func _base_path() -> PackedVector2Array:
	return points


func is_closed() -> bool:
	return closed


func editable_points() -> bool:
	return true
