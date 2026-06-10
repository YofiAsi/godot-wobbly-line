@tool
@icon("res://addons/wobbly_shapes/icons/wobble_control.svg")
class_name WobbleControl
extends Control

## Control wrapper: a wobbly rounded rectangle that fills the node's rect.
## Ideal for hand-drawn UI panels. Rebuilds on resize; the bump count is fixed
## on first build so stretching the rect slides points smoothly (no twitch).

@export_range(0.0, 200.0, 0.5) var corner_radius := 18.0:
	set(v):
		corner_radius = v
		_ensure_state().mark_geometry_dirty()       # positions move, no re-roll
		queue_redraw()

@export var style: WobbleStyle:
	set(v):
		_bind_style(v)
		_ensure_state().mark_pattern_dirty()
		queue_redraw()

var _state: WobbleState


func _ready() -> void:
	if not resized.is_connected(_on_resized):
		resized.connect(_on_resized)
	_ensure_style()


func _draw() -> void:
	_ensure_style()
	if size.x < 2.0 or size.y < 2.0:
		return
	var base := WobblePath.rounded_rect(size, corner_radius)
	var pts := _ensure_state().get_geometry(base, true, style)
	WobbleDraw.draw_shape(self, pts, true, style)


## Re: issue #84755 — a @tool Control's `resized` may not fire when it is the
## edited scene root, so we also catch the notification as a fallback.
func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_ensure_state().mark_geometry_dirty()
		queue_redraw()


## Boil one frame: re-roll amplitudes (keeping bump count) and redraw.
func reseed(new_seed: int) -> void:
	_ensure_state().reseed_amplitudes(new_seed)
	queue_redraw()


func _on_resized() -> void:
	_ensure_state().mark_geometry_dirty()
	queue_redraw()


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
