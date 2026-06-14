@tool
@icon("res://addons/wobbly_shapes/icons/wobble_style.svg")
class_name WobbleStyle
extends Resource

## Optional, shareable override for the hand-drawn look. Every wobbly node owns
## these same parameters natively; assigning a WobbleStyle to a node's `style`
## slot makes this one "look" win over the node's own exports (Theme-style), so a
## single .tres can drive many shapes. Leave the slot empty to use per-node values.
##
## Figma "Dynamic stroke" analogues:
##   FREQUENCY -> number of bumps per 100 px of perimeter (bump count).
##   WIGGLE    -> amplitude in px of perpendicular jitter at each bump.
##   SMOOTHEN  -> 0..1, how many Chaikin passes round off the jagged bumps
##                (0 = faceted polygon, 1 = soft waves). The discrete pass count
##                is derived in WobbleBody (which also owns the per-node smoothen).
##
## A custom Resource does NOT emit `changed` automatically for script
## properties, so every setter calls emit_changed() to drive live preview.

@export_range(0.5, 20.0, 0.1) var frequency := 4.0:
	set(v):
		frequency = v
		emit_changed()

@export_range(0.0, 24.0, 0.1) var wiggle := 1.6:
	set(v):
		wiggle = v
		emit_changed()

@export_range(0.0, 1.0, 0.01) var smoothen := 0.6:
	set(v):
		smoothen = v
		emit_changed()

@export var seed := 12345:
	set(v):
		seed = v
		emit_changed()

@export var fill_color := Color(0.99, 0.97, 0.90):
	set(v):
		fill_color = v
		emit_changed()

@export var stroke_color := Color(0.15, 0.15, 0.18):
	set(v):
		stroke_color = v
		emit_changed()

@export_range(0.0, 24.0, 0.1) var stroke_width := 2.5:
	set(v):
		stroke_width = v
		emit_changed()
