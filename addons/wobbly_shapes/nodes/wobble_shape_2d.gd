@tool
@icon("res://addons/wobbly_shapes/icons/wobble_shape_2d.svg")
class_name WobbleShape2D
extends Node2D

## Node2D wrapper: a wobbly shape in local space, ideal for animated world
## sprites (animate transform/scale freely; geometry stays local). The base
## path comes from one of several primitive sources.

enum Shape {
	POLYGON,    ## closed; vertices from `points`, fill enabled
	POLYLINE,   ## open; vertices from `points`, stroke only, anchored ends
	ELLIPSE,    ## closed; from `ellipse_radius`
	BEZIER,     ## from `curve` (Curve2D), open or closed via `bezier_closed`
}

@export var shape_type: Shape = Shape.POLYGON:
	set(v):
		shape_type = v
		_ensure_state().mark_pattern_dirty()         # topology change -> re-roll
		queue_redraw()

## Vertices for POLYGON / POLYLINE, in local space. Edited live with the 2D
## viewport handles when this node is selected.
@export var points := PackedVector2Array([Vector2(-50, -40), Vector2(50, -40), Vector2(0, 50)]):
	set(v):
		points = v
		_ensure_state().mark_geometry_dirty()        # vertex drag -> no re-roll
		queue_redraw()

@export var ellipse_radius := Vector2(80, 50):
	set(v):
		ellipse_radius = v
		_ensure_state().mark_geometry_dirty()
		queue_redraw()

@export var curve: Curve2D:
	set(v):
		curve = v
		_ensure_state().mark_pattern_dirty()
		queue_redraw()

@export var bezier_closed := false:
	set(v):
		bezier_closed = v
		_ensure_state().mark_pattern_dirty()
		queue_redraw()

@export var style: WobbleStyle:
	set(v):
		_bind_style(v)
		_ensure_state().mark_pattern_dirty()
		queue_redraw()

var _state: WobbleState


func _ready() -> void:
	_ensure_style()


func _draw() -> void:
	_ensure_style()
	var base := _base_path()
	if base.size() < 2:
		return
	var pts := _ensure_state().get_geometry(base, is_closed(), style)
	WobbleDraw.draw_shape(self, pts, is_closed(), style)


## True when the active shape is a filled closed loop.
func is_closed() -> bool:
	match shape_type:
		Shape.POLYGON, Shape.ELLIPSE:
			return true
		Shape.BEZIER:
			return bezier_closed
		_:
			return false


## True when the active shape exposes draggable `points` (for the editor gizmo).
func editable_points() -> bool:
	return shape_type == Shape.POLYGON or shape_type == Shape.POLYLINE


## Boil one frame: re-roll amplitudes (keeping bump count) and redraw.
func reseed(new_seed: int) -> void:
	_ensure_state().reseed_amplitudes(new_seed)
	queue_redraw()


func _base_path() -> PackedVector2Array:
	match shape_type:
		Shape.POLYGON, Shape.POLYLINE:
			return points
		Shape.ELLIPSE:
			return WobblePath.ellipse(Vector2.ZERO, ellipse_radius.x, ellipse_radius.y)
		Shape.BEZIER:
			return WobblePath.bezier(curve)
		_:
			return PackedVector2Array()


func _ensure_state() -> WobbleState:
	if _state == null:
		_state = WobbleState.new()
	return _state


func _ensure_style() -> void:
	if style == null:
		_bind_style(WobbleStyle.new())


func _bind_style(s: WobbleStyle) -> void:
	if style != null and style.changed.is_connected(_on_style_changed):
		style.changed.disconnect(_on_style_changed)
	style = s
	if style != null and not style.changed.is_connected(_on_style_changed):
		style.changed.connect(_on_style_changed)


func _on_style_changed() -> void:
	_ensure_state().mark_geometry_dirty()
	queue_redraw()
