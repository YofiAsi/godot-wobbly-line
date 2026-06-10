@tool
@icon("res://addons/wobbly_shapes/icons/wobble_shape_2d.svg")
class_name WobbleBezier
extends WobbleItem

## A wobbly shape whose base path is a Curve2D, flattened with Godot's own
## adaptive tessellation. Edit the curve with the standard Path2D in/out handles;
## set `bezier_closed` to fill the loop.

@export var curve: Curve2D:
	set(v):
		curve = v
		notify_topology_changed()

@export var bezier_closed := false:
	set(v):
		bezier_closed = v
		notify_topology_changed()


func _base_path() -> PackedVector2Array:
	return WobblePath.bezier(curve)


func is_closed() -> bool:
	return bezier_closed
