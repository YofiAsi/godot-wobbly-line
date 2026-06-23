@tool
extends Node2D

## Internal — addon implementation. Draws ONLY the wobbly stroke, on top of (and
## unclipped by) the host's clipped children.
##
## Created and driven entirely by WobbleBody; users never place this node. WobbleBody
## decides where it lives and sets `top_level` accordingly (see WobbleBody._mount_overlay):
##   - No clip_contents ancestor: parented under the host with `top_level = true`, so
##     the outline renders at the canvas root — escaping the host's own `clip_children`
##     mask and drawing above the host's children.
##   - A clip_contents ancestor exists: parented INTO that ancestor with `top_level = false`,
##     so the outline is clipped by the ancestor's rect (issue #16) instead of leaking out.
## Either way WobbleBody syncs this node's global transform to the host's, so the same
## host-local points line up exactly with the fill the host draws as the clip mask.

var _body: WobbleBody
var _line := PackedVector2Array()


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
