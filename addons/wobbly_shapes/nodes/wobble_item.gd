@tool
@icon("res://addons/wobbly_shapes/icons/wobble_shape_2d.svg")
class_name WobbleItem
extends Node2D

## Base class for the 2D wobbly shapes (WobblePolygon, WobbleLine, WobbleShape).
## A bare CanvasItem has no transform, so the base is a Node2D.
##
## This class is intentionally thin: it declares the shared exported properties
## (style + the boil animation controls) and delegates ALL behaviour to a
## WobbleBody component. Subclasses only supply geometry by overriding the
## "Subclass contract" virtuals below.

# --- Exposed properties (shared by every 2D shape) --------------------------

## The look (fill/stroke/wobble parameters). Created on demand if left null.
@export var style: WobbleStyle:
	set(v):
		style = v
		_ensure_body().set_style(v)

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

var _body: WobbleBody


func _ready() -> void:
	_ensure_style()
	_ensure_body().ready()
	if auto_play:
		playing = true


func _draw() -> void:
	_ensure_style()
	_ensure_body().draw(_base_path(), is_closed())


func _process(delta: float) -> void:
	_ensure_body().process(delta)


## Keep the `style` export non-null so it is visible, editable, and serialized
## (an auto-created style would otherwise live only inside the body).
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
