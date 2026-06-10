@tool
extends EditorPlugin

## Wobbly Shapes editor plugin.
##
## The node/resource types register themselves globally via `class_name` +
## `@icon`, so they appear in the Add Node dialog and in typed code even when
## this plugin is disabled. This plugin only adds editor authoring: the 2D
## viewport vertex handles for the editable shapes (WobblePolygon / WobbleLine).

const HandleEditor := preload("res://addons/wobbly_shapes/editor/handle_editor.gd")

var _handle_editor
var _edited: WobbleItem = null


func _enter_tree() -> void:
	_handle_editor = HandleEditor.new()


func _exit_tree() -> void:
	_handle_editor = null
	_edited = null


# --- 2D canvas handle editing (WobbleItem vertices) -------------------------

func _handles(object: Object) -> bool:
	# MUST return true for the edited type or the forward methods may not fire.
	# Any WobbleItem that exposes editable points (polygon / line) qualifies.
	var item := object as WobbleItem
	return item != null and item.editable_points()


func _edit(object: Object) -> void:
	_edited = object as WobbleItem


func _make_visible(visible: bool) -> void:
	if not visible:
		_edited = null
		update_overlays()


func _forward_canvas_gui_input(event: InputEvent) -> bool:
	if _edited == null or not is_instance_valid(_edited) or not _edited.editable_points():
		return false
	return _handle_editor.gui_input(self, _edited, event)


func _forward_canvas_draw_over_viewport(overlay: Control) -> void:
	if _edited == null or not is_instance_valid(_edited) or not _edited.editable_points():
		return
	_handle_editor.draw(_edited, overlay)
