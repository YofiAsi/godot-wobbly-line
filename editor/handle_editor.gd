@tool
extends RefCounted

## Draggable vertex handles for a WobbleItem's `points`, drawn on the 2D viewport
## overlay and committed through EditorUndoRedoManager. Aims to feel like Godot's
## native Line2D/Polygon2D editor (which is C++ and not subclassable from
## GDScript), so the interactions are replicated here:
##   - drag an existing point
##   - click an edge to insert a point (then place it)
##   - click empty space near an endpoint of an OPEN line to extend it
##   - right-click / Delete a point to remove it
## Each gesture is one undo action.
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
const EDGE_GRAB := 8.0
const FILL := Color(1, 1, 1, 0.95)
const OUTLINE := Color(0.1, 0.1, 0.12, 1.0)
const HOVER := Color(0.4, 0.8, 1.0, 1.0)
const GHOST := Color(0.4, 0.8, 1.0, 0.7)

var grab := -1                       # index being dragged, -1 = none
var hover_point := -1                # point under cursor (highlight)
var hover_edge := -1                 # edge index under cursor (insert preview)
var _hover_edge_pos := Vector2.ZERO  # local insert position for the hovered edge
var _before := PackedVector2Array()  # snapshot for the active gesture's undo
var _action := ""                    # undo action label for the active gesture


func _xform(node: CanvasItem) -> Transform2D:
	var canvas_xf: Transform2D = EditorInterface.get_editor_viewport_2d().global_canvas_transform
	return canvas_xf * node.get_global_transform()      # local -> overlay pixels


func draw(node, overlay: Control) -> void:
	var xf := _xform(node)
	var pts: PackedVector2Array = node.points

	# Ghost insert handle on a hovered edge (only when not over a point).
	if hover_edge != -1 and hover_point == -1 and grab == -1:
		var gp := xf * _hover_edge_pos
		overlay.draw_circle(gp, HANDLE_RADIUS, GHOST)

	for i in pts.size():
		var sp := xf * pts[i]
		var col := FILL
		if i == grab or i == hover_point:
			col = HOVER
		overlay.draw_circle(sp, HANDLE_RADIUS + 1.0, OUTLINE)
		overlay.draw_circle(sp, HANDLE_RADIUS, col)


## Returns true to CONSUME the event (counter-intuitive but correct per Godot
## docs / issue #30712), false to let the editor handle it.
func gui_input(plugin: EditorPlugin, node, event: InputEvent) -> bool:
	var xf := _xform(node)

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			return _on_left_button(plugin, node, event, xf)
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			return _try_delete(plugin, node, _hit_point(node.points, event.position, xf))

	elif event is InputEventMouseMotion:
		if grab != -1:
			var pts: PackedVector2Array = node.points
			pts[grab] = xf.affine_inverse() * event.position
			node.points = pts                            # live preview via setter
			plugin.update_overlays()
			return true
		_update_hover(node, event.position, xf)
		plugin.update_overlays()
		return false                                     # don't consume passive hover

	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_DELETE or event.keycode == KEY_BACKSPACE:
			return _try_delete(plugin, node, hover_point)

	return false


# --- Left button: drag / insert / extend ------------------------------------

func _on_left_button(plugin: EditorPlugin, node, event: InputEventMouseButton, xf: Transform2D) -> bool:
	if event.pressed:
		# 1) existing point -> drag
		var hit := _hit_point(node.points, event.position, xf)
		if hit != -1:
			_begin(node, "Move Wobble Vertex")
			grab = hit
			plugin.update_overlays()
			return true

		# 2) edge -> insert a point there, then drag it
		var edge := _hit_edge(node.points, node.is_closed(), event.position, xf)
		var edge_index: int = edge["index"]
		if edge_index != -1:
			_begin(node, "Insert Wobble Vertex")
			var pts: PackedVector2Array = node.points
			pts.insert(edge_index + 1, edge["pos"])
			node.points = pts
			node.notify_topology_changed()
			grab = edge_index + 1
			plugin.update_overlays()
			return true

		# 3) open line: empty click near an endpoint -> extend
		if not node.is_closed():
			var idx := _extend_index(node.points, event.position, xf)
			if idx != -1:
				_begin(node, "Add Wobble Vertex")
				var pts2: PackedVector2Array = node.points
				pts2.insert(idx, xf.affine_inverse() * event.position)
				node.points = pts2
				node.notify_topology_changed()
				grab = idx
				plugin.update_overlays()
				return true
		return false

	# release: commit whatever gesture was in progress
	if grab != -1:
		_commit(plugin, node)
		grab = -1
		plugin.update_overlays()
		return true
	return false


# --- Delete ------------------------------------------------------------------

func _try_delete(plugin: EditorPlugin, node, idx: int) -> bool:
	if idx < 0:
		return false
	var floor_count := 3 if node.is_closed() else 2
	if node.points.size() <= floor_count:
		return false
	_begin(node, "Delete Wobble Vertex")
	var pts: PackedVector2Array = node.points
	pts.remove_at(idx)
	node.points = pts
	node.notify_topology_changed()
	grab = -1
	hover_point = -1
	_commit(plugin, node)
	plugin.update_overlays()
	return true


# --- Hit-testing -------------------------------------------------------------

func _hit_point(pts: PackedVector2Array, mouse_px: Vector2, xf: Transform2D) -> int:
	for i in pts.size():
		if (xf * pts[i]).distance_to(mouse_px) <= GRAB_RADIUS:
			return i
	return -1


## Nearest edge within EDGE_GRAB of the cursor. Returns {index, pos} where `pos`
## is the projected insertion point in LOCAL space, or {index = -1}.
func _hit_edge(pts: PackedVector2Array, closed: bool, mouse_px: Vector2, xf: Transform2D) -> Dictionary:
	var n := pts.size()
	if n < 2:
		return {"index": -1}
	var best := EDGE_GRAB
	var best_index := -1
	var best_pos := Vector2.ZERO
	var limit := n if closed else n - 1
	for i in limit:
		var a_local := pts[i]
		var b_local := pts[(i + 1) % n]
		var a := xf * a_local
		var b := xf * b_local
		var ab := b - a
		var len_sq := ab.length_squared()
		if len_sq <= 0.0001:
			continue
		var t := clampf((mouse_px - a).dot(ab) / len_sq, 0.0, 1.0)
		var proj := a + ab * t
		var d := proj.distance_to(mouse_px)
		if d < best:
			best = d
			best_index = i
			best_pos = a_local.lerp(b_local, t)
	return {"index": best_index, "pos": best_pos}


## For an OPEN line, decide where an empty-space click should extend it: append
## after the last point or prepend before the first, whichever endpoint is
## nearer. Returns the insertion index, or -1 if the click is far from both.
func _extend_index(pts: PackedVector2Array, mouse_px: Vector2, xf: Transform2D) -> int:
	var n := pts.size()
	if n < 1:
		return 0
	var first := xf * pts[0]
	var last := xf * pts[n - 1]
	var d_first := first.distance_to(mouse_px)
	var d_last := last.distance_to(mouse_px)
	var nearest: float = minf(d_first, d_last)
	# Only extend when the click is reasonably close to an end (avoid hijacking
	# far-away marquee selections).
	if nearest > 120.0:
		return -1
	return 0 if d_first < d_last else n


func _update_hover(node, mouse_px: Vector2, xf: Transform2D) -> void:
	hover_point = _hit_point(node.points, mouse_px, xf)
	if hover_point != -1:
		hover_edge = -1
		return
	var edge := _hit_edge(node.points, node.is_closed(), mouse_px, xf)
	hover_edge = edge["index"]
	if hover_edge != -1:
		_hover_edge_pos = edge["pos"]


# --- Undo plumbing -----------------------------------------------------------

## Snapshot the points and remember the action label for the gesture in progress.
func _begin(node, action: String) -> void:
	_before = node.points.duplicate()
	_action = action


## One undo step per gesture: do = current points, undo = the pre-gesture snapshot.
func _commit(plugin: EditorPlugin, node) -> void:
	if node.points == _before:
		return
	var ur := plugin.get_undo_redo()
	ur.create_action(_action)
	ur.add_do_property(node, "points", node.points.duplicate())
	ur.add_undo_property(node, "points", _before)
	# Re-roll the wobble pattern on both directions when the count changed.
	if node.points.size() != _before.size():
		ur.add_do_method(node, "notify_topology_changed")
		ur.add_undo_method(node, "notify_topology_changed")
	ur.commit_action()
