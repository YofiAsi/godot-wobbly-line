@tool
extends Node2D

## Demo glue: builds a Curve2D for the bezier shape (so the scene file stays
## free of hand-serialized curve data) and, at runtime only, drives a slow
## "boil" so the outlines wiggle like hand-drawn animation.

## Frames per second for the boil. ~8-12 reads as a classic hand-drawn boil.
@export_range(0.0, 24.0, 1.0) var boil_fps := 10.0:
	set(v):
		boil_fps = v
		_apply_boil_timer()

## Golden-ratio step. The RNG has no avalanche effect, so stepping the seed by
## a large constant (not 1, 2, 3) keeps consecutive frames visibly different.
const SEED_STEP := 0x9E3779B9

var _boil_seed := 1
var _timer: Timer


func _ready() -> void:
	_build_bezier()
	if not Engine.is_editor_hint():
		_timer = Timer.new()
		_timer.timeout.connect(_boil_tick)
		add_child(_timer)
		_apply_boil_timer()


func _build_bezier() -> void:
	var bz := get_node_or_null("Shapes/Bezier") as WobbleShape2D
	if bz == null or bz.shape_type != WobbleShape2D.Shape.BEZIER:
		return
	if bz.curve != null and bz.curve.point_count >= 2:
		return
	var c := Curve2D.new()
	# position, in-handle (relative), out-handle (relative)
	c.add_point(Vector2(-110, 30), Vector2.ZERO, Vector2(40, -90))
	c.add_point(Vector2(0, -50), Vector2(-60, 0), Vector2(60, 0))
	c.add_point(Vector2(110, 30), Vector2(-40, -90), Vector2.ZERO)
	bz.curve = c


func _apply_boil_timer() -> void:
	if _timer == null:
		return
	if boil_fps <= 0.0:
		_timer.stop()
		return
	_timer.wait_time = 1.0 / boil_fps
	_timer.start()


func _boil_tick() -> void:
	_boil_seed = (_boil_seed + SEED_STEP) & 0x7FFFFFFF
	for n in _wobble_nodes(self):
		n.reseed(_boil_seed)


func _wobble_nodes(root: Node) -> Array:
	var out: Array = []
	for child in root.get_children():
		if child.has_method("reseed"):
			out.append(child)
		out.append_array(_wobble_nodes(child))
	return out
