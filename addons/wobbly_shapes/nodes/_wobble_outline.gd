@tool
extends Node2D

## Internal — addon implementation. Draws ONLY the wobbly stroke, on top of (and
## unclipped by) the host's clipped children.
##
## Created and driven entirely by WobbleBody; users never place this node. It is
## `top_level` for two reasons: (1) the host's `clip_children` mask must NOT clip
## the outline (top_level renders at the canvas root, outside the clip group), and
## (2) it draws above the host's children. WobbleBody syncs this node's global
## transform to the host's, so the same host-local points line up exactly with the
## fill the host draws as the clip mask.

var _body: WobbleBody
var _line := PackedVector2Array()


func _ready() -> void:
	top_level = true


## Push the latest stroke polyline to draw (prebuilt, wrap point included for
## closed shapes). Called by WobbleBody on every host redraw, so the outline
## tracks the fill mask even while the shape boils.
func set_outline(body: WobbleBody, line: PackedVector2Array) -> void:
	_body = body
	_line = line
	queue_redraw()


func _draw() -> void:
	if _body == null or _line.size() < 2:
		return
	_body.draw_stroke(self, _line)
