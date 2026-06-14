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

# The node natively owns its look. Assigning a WobbleStyle to `style` (bottom)
# overrides every value below, Theme-style, and greys these out (see
# _validate_property). Defaults must match WobbleBody / WobbleStyle.

@export_group("Wobble")

## Number of bumps per 100 px of perimeter.
@export_range(0.5, 20.0, 0.1) var frequency := 4.0:
	set(v):
		frequency = v
		_apply_style()

## Amplitude in px of perpendicular jitter at each bump.
@export_range(0.0, 24.0, 0.1) var wiggle := 1.6:
	set(v):
		wiggle = v
		_apply_style()

## 0 = faceted polygon, 1 = soft waves (Chaikin rounding passes).
@export_range(0.0, 1.0, 0.01) var smoothen := 0.6:
	set(v):
		smoothen = v
		_apply_style()

## RNG seed for the bump pattern.
@export var seed := 12345:
	set(v):
		seed = v
		_apply_style()

@export_group("Appearance")

@export var fill_color := Color(0.99, 0.97, 0.90):
	set(v):
		fill_color = v
		_apply_style()

@export var stroke_color := Color(0.15, 0.15, 0.18):
	set(v):
		stroke_color = v
		_apply_style()

@export_range(0.0, 24.0, 0.1) var stroke_width := 2.5:
	set(v):
		stroke_width = v
		_apply_style()

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

@export_group("Style Override")

## Optional shared look. When assigned, it overrides every Wobble/Appearance
## value above (which grey out) so one .tres can drive many nodes. Leave empty to
## use this node's own values.
@export var style: WobbleStyle:
	set(v):
		style = v
		_ensure_body().set_style(v)
		notify_property_list_changed()      # refresh the read-only gating below


# --- API (external drivers) -------------------------------------------------

## Manual one-frame boil (back-compat).
func reseed(new_seed: int) -> void:
	_ensure_body().reseed(new_seed)


# --- Internal ----------------------------------------------------------------

## The native look exports, greyed out while a `style` override is assigned.
const _STYLE_PROPS := ["frequency", "wiggle", "smoothen", "seed",
		"fill_color", "stroke_color", "stroke_width"]

var _body: WobbleBody


func _ready() -> void:
	if not resized.is_connected(_on_resized):
		resized.connect(_on_resized)
	set_notify_transform(true)              # keep the clip outline overlay aligned
	_ensure_body().ready()
	if auto_play:
		playing = true


func _draw() -> void:
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


## Grey out the native look exports while a style override is active (the override
## supplies their values, so editing them here would have no effect).
func _validate_property(property: Dictionary) -> void:
	if style != null and property.name in _STYLE_PROPS:
		property.usage |= PROPERTY_USAGE_READ_ONLY


## Push this node's native look into the body. A no-op effect while a style
## override is assigned (the body resolves the override first), but kept in sync
## so clearing the override falls straight back to current values.
func _apply_style() -> void:
	_ensure_body().set_appearance(frequency, wiggle, smoothen, seed,
			fill_color, stroke_color, stroke_width)


func _ensure_body() -> WobbleBody:
	if _body == null:
		_body = WobbleBody.new(self)
		_body.set_appearance(frequency, wiggle, smoothen, seed,
				fill_color, stroke_color, stroke_width)
		if style != null:
			_body.set_style(style)
		_body.configure(animation_speed, wiggle_frequency)
	return _body
