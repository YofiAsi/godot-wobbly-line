extends Node2D

## Stress test for the wobbly_shapes addon — a worst-case mix of everything
## that made issue #8 drop frames: many size-tweening WobbleControls (the
## "card height tween" case), clip_children panels (overlay + backbuffer
## path), and a field of moving, boiling 2D shapes. Watch the FPS/frame-time
## readout in the corner while tweaking the knobs below.
##
## Run with user args `++ --report` to also write a FPS summary to
## res://demo/_stress_report.txt on quit (pairs with --quit-after N).

@export var panel_count := 12          ## size-tweening UI panels (cards)
@export var clipped_panel_count := 2   ## of which: clip_children + child content
@export var shape_count := 24          ## moving Node2D shapes
@export var resizing_shape_count := 2  ## extra size-tweened rectangles

const PANEL_SIZE := Vector2(190, 130)
const CARD_SIZE := Vector2(520, 380)   # big like the issue #8 card: ~75+ bumps
const TWEEN_DUR := 0.3                 # mirrors the card tween from issue #8
const WARMUP_FRAMES := 120

var _orbiters: Array[Dictionary] = []
var _fps_label: Label
var _time := 0.0

var _report := OS.get_cmdline_user_args().has("--report")
var _frames := 0
var _delta_sum := 0.0
var _delta_max := 0.0


func _ready() -> void:
	if _report:
		# Uncapped frame rate so the report measures real throughput.
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_spawn_panels()
	_spawn_shapes()
	_make_hud()


func _process(delta: float) -> void:
	_time += delta
	for o in _orbiters:
		var n: Node2D = o.node
		n.position = o.center + Vector2.RIGHT.rotated(_time * o.speed + o.phase) * o.radius
	var process_ms: float = Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	_fps_label.text = "FPS: %d    process: %.2f ms" % [Engine.get_frames_per_second(), process_ms]
	if _report:
		_frames += 1
		if _frames > WARMUP_FRAMES:
			_delta_sum += delta
			_delta_max = maxf(_delta_max, delta)


func _exit_tree() -> void:
	if not _report or _frames <= WARMUP_FRAMES:
		return
	var sampled := _frames - WARMUP_FRAMES
	var f := FileAccess.open("res://demo/_stress_report.txt", FileAccess.WRITE)
	if f != null:
		f.store_string("frames: %d  avg fps: %.1f  avg frame: %.2f ms  worst frame: %.2f ms\n" % [
				sampled, float(sampled) / _delta_sum,
				_delta_sum / float(sampled) * 1000.0, _delta_max * 1000.0])
		f.close()


## A grid of card-like panels, each looping a 0.3s ease-out resize tween (the
## exact pattern from issue #8), out of phase so resizes happen every frame.
func _spawn_panels() -> void:
	var ui := CanvasLayer.new()
	ui.name = "UI"
	add_child(ui)
	var cols := 4
	for i in panel_count:
		var jumbo := i < clipped_panel_count    # card-sized + clipped: the issue #8 case
		var base_size := CARD_SIZE if jumbo else PANEL_SIZE
		var panel := WobbleControl.new()
		panel.name = "Panel%d" % i
		if jumbo:
			panel.position = Vector2(40 + i * 560, 230)
		else:
			var j := i - clipped_panel_count
			panel.position = Vector2(40 + (j % cols) * 240, 30 + floori(float(j) / float(cols)) * 210)
		panel.size = base_size
		panel.playing = true
		ui.add_child(panel)
		if jumbo:
			panel.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
			var bg := ColorRect.new()
			bg.color = Color(0.32, 0.62, 0.96)
			bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			panel.add_child(bg)
			var label := Label.new()
			label.text = "clipped card"
			label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
			panel.add_child(label)
		var dur := TWEEN_DUR + float(i) * 0.03
		var grow := 70.0 + float(i % 3) * 20.0
		var tw := panel.create_tween().set_loops().set_ease(Tween.EASE_OUT)
		tw.tween_property(panel, "size:y", base_size.y + grow, dur)
		tw.tween_property(panel, "size:y", base_size.y, dur)
		var tw2 := panel.create_tween().set_loops().set_ease(Tween.EASE_OUT)
		tw2.tween_property(panel, "size:x", base_size.x + grow, dur * 1.37)
		tw2.tween_property(panel, "size:x", base_size.x, dur * 1.37)


## A field of orbiting shapes (movement exercises the transform-changed /
## overlay-sync path) plus a couple of size-tweened rectangles (the Node2D
## resize path).
func _spawn_shapes() -> void:
	var field := Node2D.new()
	field.name = "Shapes"
	add_child(field)
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var view := get_viewport_rect().size
	for i in shape_count:
		var node: Node2D
		match i % 3:
			0:
				var s := WobbleShape.new()
				s.kind = WobbleShape.Kind.CIRCLE if i % 2 == 0 else WobbleShape.Kind.RECTANGLE
				s.size = Vector2(110, 80)
				s.radius = Vector2(50, 35)
				node = s
			1:
				var p := WobblePolygon.new()
				p.points = PackedVector2Array([Vector2(0, -45), Vector2(43, -14),
						Vector2(26, 36), Vector2(-26, 36), Vector2(-43, -14)])
				node = p
			_:
				var l := WobbleLine.new()
				l.points = PackedVector2Array([Vector2(-60, 25), Vector2(-30, -25),
						Vector2(0, 25), Vector2(30, -25), Vector2(60, 25)])
				node = l
		node.name = "Shape%d" % i
		node.playing = true
		var center := Vector2(rng.randf_range(80.0, view.x - 80.0),
				rng.randf_range(view.y * 0.55, view.y - 60.0))
		node.position = center
		field.add_child(node)
		_orbiters.append({
			node = node,
			center = center,
			radius = rng.randf_range(20.0, 60.0),
			speed = rng.randf_range(0.6, 2.2),
			phase = rng.randf_range(0.0, TAU),
		})
	for i in resizing_shape_count:
		var s := WobbleShape.new()
		s.name = "ResizingShape%d" % i
		s.kind = WobbleShape.Kind.RECTANGLE
		s.size = Vector2(140, 90)
		s.playing = true
		s.position = Vector2(250 + i * 350, view.y * 0.5)
		field.add_child(s)
		var dur := TWEEN_DUR + float(i) * 0.07
		var tw := s.create_tween().set_loops().set_ease(Tween.EASE_OUT)
		tw.tween_property(s, "size", Vector2(240, 160), dur)
		tw.tween_property(s, "size", Vector2(140, 90), dur)


func _make_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "HUD"
	layer.layer = 10
	add_child(layer)
	_fps_label = Label.new()
	_fps_label.position = Vector2(12, 6)
	_fps_label.add_theme_font_size_override("font_size", 20)
	_fps_label.add_theme_color_override("font_color", Color.BLACK)
	layer.add_child(_fps_label)
