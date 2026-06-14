@tool
@icon("res://addons/wobbly_shapes/icons/wobble_control.svg")
class_name WobbleControl
extends Control

## Control wrapper: a wobbly rounded rectangle that fills the node's rect.
## Ideal for hand-drawn UI panels. Rebuilds on resize; the bump count is fixed
## on first build so stretching the rect slides points smoothly (no twitch).
##
## A Control cannot inherit WobbleItem (which is a Node2D), so it re-declares the
## shared exports but delegates ALL behaviour to the same WobbleBody component,
## keeping the boil/style/draw logic in one place.

# --- Exposed properties -----------------------------------------------------

@export_range(0.0, 200.0, 0.5) var corner_radius := 18.0:
	set(v):
		corner_radius = v
		_ensure_body().mark_geometry_dirty()        # positions move, no re-roll
		queue_redraw()

@export var style: WobbleStyle:
	set(v):
		style = v
		_ensure_body().set_style(v)

@export_group("Animation")

@export var playing := false:
	set(v):
		playing = v
		_ensure_body().set_playing(v)

@export var auto_play := false

@export_range(0.0, 60.0, 0.5) var animation_speed := 10.0:
	set(v):
		animation_speed = v
		_ensure_body().configure(animation_speed, wiggle_frequency)

@export_range(0.0, 8.0, 0.1) var wiggle_frequency := 1.0:
	set(v):
		wiggle_frequency = v
		_ensure_body().configure(animation_speed, wiggle_frequency)


# --- API (external drivers) -------------------------------------------------

## Manual one-frame boil (back-compat).
func reseed(new_seed: int) -> void:
	_ensure_body().reseed(new_seed)


# --- Internal ----------------------------------------------------------------

var _body: WobbleBody


func _ready() -> void:
	if not resized.is_connected(_on_resized):
		resized.connect(_on_resized)
	set_notify_transform(true)              # keep the clip outline overlay aligned
	_ensure_style()
	_ensure_body().ready()
	# auto_play is a runtime behavior; in the editor the boil previews only when
	# the user toggles `playing` themselves (issue #7).
	if auto_play and not Engine.is_editor_hint():
		playing = true


func _draw() -> void:
	_ensure_style()
	if size.x < 2.0 or size.y < 2.0:
		return
	_ensure_body().draw(WobblePath.rounded_rect(size, corner_radius), true)


func _process(delta: float) -> void:
	_ensure_body().process(delta)


## Re: issue #84755 — a @tool Control's `resized` may not fire when it is the
## edited scene root, so we also catch the notification as a fallback.
func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_ensure_body().mark_geometry_dirty()
		queue_redraw()
	elif what == NOTIFICATION_TRANSFORM_CHANGED and _body != null:
		_body.sync_overlay_transform()      # the overlay is top_level: move it with us


func _on_resized() -> void:
	_ensure_body().mark_geometry_dirty()
	queue_redraw()


## Keep the `style` export non-null so it is visible, editable, and serialized.
func _ensure_style() -> void:
	if style == null:
		style = WobbleStyle.new()


func _ensure_body() -> WobbleBody:
	if _body == null:
		_body = WobbleBody.new(self)
		if style != null:
			_body.set_style(style)
		_body.configure(animation_speed, wiggle_frequency)
	return _body
