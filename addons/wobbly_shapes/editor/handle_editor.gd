@tool
extends RefCounted

## Draggable vertex handles for WobbleShape2D's `points`, drawn on the 2D
## viewport overlay and committed through EditorUndoRedoManager.
##
## Coordinate transform (confirmed Godot 4.2+; current target 4.6):
##   local -> overlay pixels = canvas_xf * node.get_global_transform()
##   overlay pixels -> local = that.affine_inverse() * pixel
## where canvas_xf = EditorInterface.get_editor_viewport_2d().global_canvas_transform.
##
## Hit-testing is done in PIXEL space so the grab radius stays constant
## regardless of editor zoom.

const HANDLE_RADIUS := 5.0
const GRAB_RADIUS := 10.0
const FILL := Color(1, 1, 1, 0.95)
const OUTLINE := Color(0.1, 0.1, 0.12, 1.0)
const HOVER := Color(0.4, 0.8, 1.0, 1.0)

var grab := -1
var _before := PackedVector2Array()


func _xform(node: CanvasItem) -> Transform2D:
	var canvas_xf: Transform2D = EditorInterface.get_editor_viewport_2d().global_canvas_transform
	return canvas_xf * node.get_global_transform()      # local -> overlay pixels


func draw(node: WobbleShape2D, overlay: Control) -> void:
	var xf := _xform(node)
	var pts := node.points
	for i in pts.size():
		var sp := xf * pts[i]
		var col := HOVER if i == grab else FILL
		overlay.draw_circle(sp, HANDLE_RADIUS + 1.0, OUTLINE)
		overlay.draw_circle(sp, HANDLE_RADIUS, col)


## Returns true to CONSUME the event (counter-intuitive but correct per Godot
## docs / issue #30712), false to let the editor handle it.
func gui_input(plugin: EditorPlugin, node: WobbleShape2D, event: InputEvent) -> bool:
	var xf := _xform(node)

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			grab = _hit_test(node.points, event.position, xf)
			if grab != -1:
				_before = node.points.duplicate()
				plugin.update_overlays()
				return true
		elif grab != -1:
			_commit(plugin, node)
			grab = -1
			plugin.update_overlays()
			return true

	elif event is InputEventMouseMotion and grab != -1:
		var pts := node.points
		pts[grab] = xf.affine_inverse() * event.position
		node.points = pts                                # live preview via setter
		plugin.update_overlays()
		return true

	return false


func _hit_test(pts: PackedVector2Array, mouse_px: Vector2, xf: Transform2D) -> int:
	for i in pts.size():
		if (xf * pts[i]).distance_to(mouse_px) <= GRAB_RADIUS:
			return i
	return -1


## One undo step per drag: snapshot at grab, diff and commit at release.
func _commit(plugin: EditorPlugin, node: WobbleShape2D) -> void:
	if node.points == _before:
		return
	var ur := plugin.get_undo_redo()
	ur.create_action("Move Wobble Vertex")
	ur.add_do_property(node, "points", node.points.duplicate())
	ur.add_undo_property(node, "points", _before)
	ur.commit_action()
