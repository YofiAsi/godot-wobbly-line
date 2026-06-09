@tool
extends EditorInspectorPlugin

## Adds a "Randomize Seed" convenience button at the top of the inspector for
## both wrapper nodes. Plain @export vars on WobbleStyle already render and
## serialize, so this is the only custom widget we need.

func _can_handle(object: Object) -> bool:
	return object is WobbleShape2D or object is WobbleControl


func _parse_begin(object: Object) -> void:
	var btn := Button.new()
	btn.text = "🎲  Randomize Seed"
	btn.tooltip_text = "Roll a new random seed on this node's WobbleStyle."
	btn.pressed.connect(_on_randomize.bind(object))
	add_custom_control(btn)


func _on_randomize(object: Object) -> void:
	if object == null:
		return
	var style: WobbleStyle = object.style
	if style == null:
		return
	style.seed = randi()
