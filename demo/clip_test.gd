extends Node2D

## Visual regression test for issue #16 — "WobbleControl stroke overlay ignores
## ancestor clip_contents".
##
## A WobbleControl using clip_children = CLIP_CHILDREN_AND_DRAW is placed inside a
## Control with clip_contents = true, parked so its top half sits ABOVE the
## viewport's top edge (the flashcard "cover card above the fold" case). Before the
## fix the wobbly stroke was top_level and leaked into the band above the viewport;
## now it is parented into the clip ancestor and cut at the viewport edge.
##
## What to look for:
##   - The parked card's outline is clipped exactly at the viewport's top edge —
##     NOTHING is drawn in the hatched "leak zone" band above it.
##   - The fill, children and stroke all clip together; the stroke still sits crisp
##     on top of the card's own clipped children inside the viewport.
##   - "Scroll" slides the cards so the parked card crosses the edge — the stroke
##     stays cut at the boundary the whole way.
##   - "Free parked card" removes it with no leftover ghost outline (lifecycle /
##     teardown_overlay check).
##   - The reference card on the right has NO clip ancestor, so its stroke still
##     draws above its own clipped children (the unchanged top_level path).

const VIEWPORT_SIZE := Vector2(380, 280)
const LEAK_BAND := 120.0                 # empty space above the viewport
const CARD_SIZE := Vector2(300, 170)

const FILL := Color(0.99, 0.97, 0.90)
const STROKE := Color(0.15, 0.15, 0.18)
const CARD_A := Color(0.96, 0.55, 0.42)  # parked card body
const CARD_B := Color(0.36, 0.62, 0.55)  # visible card body

var _viewport: Control
var _parked: WobbleControl
var _scroll_tween: Tween
var _scroll_offset := 0.0


func _ready() -> void:
	_build()


func _build() -> void:
	var ui := CanvasLayer.new()
	ui.name = "UI"
	add_child(ui)

	var origin := Vector2(60, 60 + LEAK_BAND)

	_add_instructions(ui)
	_add_leak_band(ui, origin)
	_add_frame(ui, origin)

	# The clip ancestor: a plain Control with clip_contents on.
	_viewport = Control.new()
	_viewport.name = "ClippedViewport"
	_viewport.clip_contents = true
	_viewport.position = origin
	_viewport.size = VIEWPORT_SIZE
	ui.add_child(_viewport)

	# Card parked above the fold (negative y) + a fully visible card below it.
	_parked = _make_card(_viewport, "parked card\n(above the fold)",
			Vector2(40, -90), CARD_A)
	_make_card(_viewport, "visible card", Vector2(40, 90), CARD_B)

	# Reference: same node type + clip mode but with NO clip ancestor, so its
	# stroke must still draw above its own clipped children (top_level path).
	var ref := _make_card(ui, "no clip ancestor\n(stroke on top)",
			origin + Vector2(VIEWPORT_SIZE.x + 80.0, 40.0), CARD_B)
	ref.name = "ReferenceCard"

	_add_buttons(ui, origin)


## A WobbleControl card: clip_children on, a colored body + label as clipped
## children, boiling so the stroke animates while it crosses the clip edge.
func _make_card(parent: Node, text: String, pos: Vector2, body: Color) -> WobbleControl:
	var card := WobbleControl.new()
	card.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	card.position = pos
	card.size = CARD_SIZE
	card.corner_radius = 22.0
	card.stroke_width = 5.0
	card.fill_color = FILL
	card.stroke_color = STROKE
	card.playing = true
	parent.add_child(card)

	var bg := ColorRect.new()
	bg.color = body
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card.add_child(bg)

	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color.WHITE)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card.add_child(label)
	return card


## A panel behind the viewport so the clip rect is visible.
func _add_frame(ui: CanvasLayer, origin: Vector2) -> void:
	var frame := Panel.new()
	frame.name = "Frame"
	frame.position = origin - Vector2(3, 3)
	frame.size = VIEWPORT_SIZE + Vector2(6, 6)
	ui.add_child(frame)
	var label := Label.new()
	label.text = "clip_contents viewport"
	label.position = origin + Vector2(0, VIEWPORT_SIZE.y + 8.0)
	label.add_theme_color_override("font_color", Color.BLACK)
	ui.add_child(label)


## The band above the viewport where a leaking stroke would show up. Hatched with a
## tinted rect + label; with the fix this stays empty.
func _add_leak_band(ui: CanvasLayer, origin: Vector2) -> void:
	var band := ColorRect.new()
	band.name = "LeakZone"
	band.color = Color(0.85, 0.3, 0.3, 0.12)
	band.position = Vector2(origin.x, origin.y - LEAK_BAND)
	band.size = Vector2(VIEWPORT_SIZE.x, LEAK_BAND)
	ui.add_child(band)
	var label := Label.new()
	label.text = "leak zone — stays empty (issue #16)"
	label.position = band.position + Vector2(8, 6)
	label.add_theme_color_override("font_color", Color(0.6, 0.1, 0.1))
	ui.add_child(label)


func _add_instructions(ui: CanvasLayer) -> void:
	var label := Label.new()
	label.text = "Issue #16 — wobbly stroke must respect an ancestor clip_contents rect."
	label.position = Vector2(60, 24)
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color.BLACK)
	ui.add_child(label)


func _add_buttons(ui: CanvasLayer, origin: Vector2) -> void:
	var box := VBoxContainer.new()
	box.position = Vector2(origin.x, origin.y + VIEWPORT_SIZE.y + 40.0)
	ui.add_child(box)

	var scroll := Button.new()
	scroll.text = "Toggle scroll (cross the clip edge)"
	scroll.pressed.connect(_toggle_scroll)
	box.add_child(scroll)

	var free := Button.new()
	free.text = "Free parked card (no ghost outline)"
	free.pressed.connect(_free_parked)
	box.add_child(free)


## Slide both cards up/down so the parked card crosses the viewport's top edge and
## back, looping — the stroke must stay clipped at the boundary throughout.
func _toggle_scroll() -> void:
	if _scroll_tween != null and _scroll_tween.is_running():
		_scroll_tween.kill()
		_scroll_tween = null
		return
	_scroll_tween = _viewport.create_tween().set_loops().set_ease(Tween.EASE_IN_OUT)
	_scroll_tween.tween_method(_apply_scroll, _scroll_offset, 150.0, 1.2)
	_scroll_tween.tween_method(_apply_scroll, 150.0, 0.0, 1.2)


func _apply_scroll(offset: float) -> void:
	var delta := offset - _scroll_offset
	_scroll_offset = offset
	for child in _viewport.get_children():
		if child is WobbleControl:
			(child as WobbleControl).position.y += delta


func _free_parked() -> void:
	if _parked != null and is_instance_valid(_parked):
		_parked.queue_free()
		_parked = null
