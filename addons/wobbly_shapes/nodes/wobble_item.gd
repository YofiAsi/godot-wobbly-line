@tool
@icon("res://addons/wobbly_shapes/icons/wobble_shape_2d.svg")
class_name WobbleItem
extends Node2D

## Base class for the 2D wobbly shapes (WobblePolygon, WobbleLine, WobbleShape).
## A bare CanvasItem has no transform, so the base is a Node2D.
##
## This class is intentionally thin: it declares the shared exported properties
## (the native look + the boil animation controls) and delegates ALL behaviour to
## a WobbleBody component. Subclasses only supply geometry by overriding the
## "Subclass contract" virtuals below.

# --- Exposed properties (shared by every 2D shape) --------------------------

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

## When true, the outline "boils" (re-rolls its wobble each tick). Previews live
## in the editor too. Set automatically on _ready when `auto_play` is on.
@export var playing := false:
	set(v):
		playing = v
		_ensure_body().set_playing(v)

## Begin playing automatically when the node enters the tree.
@export var auto_play := false

## Boil ticks per second.
@export_range(0.0, 60.0, 0.5) var animation_speed := 10.0:
	set(v):
		animation_speed = v
		_ensure_body().configure(animation_speed, wiggle_frequency)

## How much the outline shifts each tick (small = subtle drift, large = jumpy).
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


# --- Subclass contract (override these) -------------------------------------

## The base path in local space, before wobbling. Default: empty (draws nothing).
func _base_path() -> PackedVector2Array:
	return PackedVector2Array()


## Whether the shape is a filled, closed loop (vs. an open stroke).
func is_closed() -> bool:
	return false


## Whether the shape exposes draggable `points` for the 2D viewport gizmo.
func editable_points() -> bool:
	return false


# --- API (editor / external drivers) ----------------------------------------

## Manual one-frame boil (the demo / tests may call this directly).
func reseed(new_seed: int) -> void:
	_ensure_body().reseed(new_seed)


## Positions changed but the bump count is unchanged: re-process only.
func mark_geometry_dirty() -> void:
	_ensure_body().mark_geometry_dirty()


## The handle editor calls this after insert/add/delete so the bump count re-rolls.
func notify_topology_changed() -> void:
	_ensure_body().notify_topology_changed()


# --- Internal ----------------------------------------------------------------

## The native look exports, greyed out while a `style` override is assigned.
const _STYLE_PROPS := ["frequency", "wiggle", "smoothen", "seed",
		"fill_color", "stroke_color", "stroke_width"]

var _body: WobbleBody


func _ready() -> void:
	set_notify_transform(true)              # keep the clip outline overlay aligned
	_ensure_body().ready()
	if auto_play:
		playing = true


func _draw() -> void:
	_ensure_body().draw(_base_path(), is_closed())


func _process(delta: float) -> void:
	_ensure_body().process(delta)


## The clip outline overlay is top_level, so it must be repositioned by hand when
## this node moves (see WobbleBody / _WobbleOutline).
func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED and _body != null:
		_body.sync_overlay_transform()


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
