@tool
@icon("res://addons/wobbly_shapes/icons/wobble_shape_2d.svg")
class_name WobbleShape
extends WobbleItem

## A wobbly primitive: a rounded rectangle or a circle/ellipse, selected by
## `kind`. Both are filled closed loops, centered on the node's local origin.
##
## The `size` and `radius` Vector2 fields show Godot's inspector link/chain
## button: lock it to keep a square / circle, unlock it for a rect / ellipse.

enum Kind {
	RECTANGLE,   ## from `size` + `border_radius`
	CIRCLE,      ## from `radius` (locked = circle, unlocked = ellipse)
}

@export var kind: Kind = Kind.RECTANGLE:
	set(v):
		kind = v
		notify_topology_changed()        # different primitive -> re-roll

@export_group("Rectangle")

## Rectangle extents. Lock x/y (link button) for a square.
@export var size := Vector2(160, 120):
	set(v):
		size = v
		mark_geometry_dirty()            # resize slides points -> no twitch
		queue_redraw()

@export_range(0.0, 200.0, 0.5) var border_radius := 18.0:
	set(v):
		border_radius = v
		mark_geometry_dirty()
		queue_redraw()

@export_group("Circle")

## Circle/ellipse radii. Lock x/y (link button) for a circle, unlock for an ellipse.
@export var radius := Vector2(80, 80):
	set(v):
		radius = v
		mark_geometry_dirty()
		queue_redraw()


func _base_path() -> PackedVector2Array:
	match kind:
		Kind.RECTANGLE:
			return WobblePath.rounded_rect(size, border_radius, 6, true)
		Kind.CIRCLE:
			return WobblePath.ellipse(Vector2.ZERO, radius.x, radius.y)
		_:
			return PackedVector2Array()


func is_closed() -> bool:
	return true
