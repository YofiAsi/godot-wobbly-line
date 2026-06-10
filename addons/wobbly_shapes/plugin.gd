@tool
extends EditorPlugin

## Wobbly Shapes editor plugin.
##
## The node/resource types register themselves globally via `class_name` +
## `@icon`, so they appear in the Add Node dialog and in typed code even when
## this plugin is disabled. This plugin only adds editor authoring: the
## inspector convenience widget and the 2D viewport vertex handles.

const HandleEditor := preload("res://addons/wobbly_shapes/editor/handle_editor.gd")
const WobbleInspector := preload("res://addons/wobbly_shapes/editor/wobble_inspector.gd")

var _inspector: EditorInspectorPlugin
var _handle_editor
var _edited: WobbleShape2D = null


func _enter_tree() -> void:
	_inspector = WobbleInspector.new()
	add_inspector_plugin(_inspector)
	_handle_editor = HandleEditor.new()


func _exit_tree() -> void:
	if _inspector != null:
		remove_inspector_plugin(_inspector)
		_inspector = null
	_handle_editor = null
	_edited = null


# --- 2D canvas handle editing (WobbleShape2D vertices) ----------------------

func _handles(object: Object) -> bool:
	# MUST return true for the edited type or the forward methods may not fire.
	return object is WobbleShape2D


func _edit(object: Object) -> void:
	_edited = object as WobbleShape2D


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
