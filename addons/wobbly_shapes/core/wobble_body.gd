@tool
class_name WobbleBody
extends RefCounted

## Internal — addon implementation; the host nodes (WobbleItem and WobbleControl)
## interact with the wobbly-shapes pipeline through this component, never with the
## deeper helpers directly.
##
## A WobbleBody is the single home for everything a wobbly node needs but that is
## the same across the Node2D and Control hosts:
##   - holding the WobbleStyle (and listening to its `changed` signal),
##   - the WobbleState cache + dirty-flag bookkeeping,
##   - the self-contained "boil" animation (a deterministic seed stepped over time),
##   - the draw pipeline (geometry -> WobbleDraw).
##
## The host owns the @export declarations (they must live on the node to serialize)
## and forwards each into its body. The body holds a back-reference to the host
## CanvasItem so it can queue_redraw()/set_process()/draw on it.

# Golden-ratio step. The RNG has no avalanche effect, so stepping the seed by a
# large constant (not 1, 2, 3) keeps consecutive boil frames visibly different.
const SEED_STEP := 0x9E3779B9
const _MAX_CATCHUP := 4              # cap boil steps per frame after an editor stall

# --- API (called by host nodes) ---------------------------------------------

## Animation knobs, mirrored from the host's exported properties.
var playing := false
var animation_speed := 10.0          ## boil ticks per second (0 => paused)
var wiggle_frequency := 1.0          ## multiplies SEED_STEP per tick (per-frame delta)


## Construct bound to its host. `host` is the Node2D/Control that owns this body.
func _init(host: CanvasItem) -> void:
	_host = host


## Assign the look resource, rewiring the `changed` connection. Topology may
## depend on style.frequency, so this marks the pattern dirty and redraws.
func set_style(v: WobbleStyle) -> void:
	if style != null and style.changed.is_connected(_on_style_changed):
		style.changed.disconnect(_on_style_changed)
	style = v
	if style != null and not style.changed.is_connected(_on_style_changed):
		style.changed.connect(_on_style_changed)
	_state.mark_pattern_dirty()
	_host.queue_redraw()


## Update the boil rate / per-frame delta from the host's exported values.
func configure(speed: float, freq: float) -> void:
	animation_speed = speed
	wiggle_frequency = freq


## Start/stop the boil. Gates the host's _process so idle nodes cost nothing.
func set_playing(v: bool) -> void:
	playing = v
	_accum = 0.0
	_host.set_process(v)


## Call from the host's _ready(): sync processing to the current play state.
## (The host is responsible for ensuring its own `style` export is non-null.)
func ready() -> void:
	_host.set_process(playing)


## Call from the host's _draw(). `base` is the host-built base path; `closed`
## says whether it is a filled loop.
func draw(base: PackedVector2Array, closed: bool) -> void:
	if style == null or base.size() < 2:
		return
	var pts := _state.get_geometry(base, closed, style)
	WobbleDraw.draw_shape(_host, pts, closed, style)


## Call from the host's _process(delta). Advances the boil at `animation_speed`
## ticks/sec regardless of frame rate, re-rolling amplitudes in place (keeps the
## bump count, so the outline wobbles instead of popping) and redrawing.
func process(delta: float) -> void:
	if not playing or animation_speed <= 0.0:
		return
	_accum += delta
	var step_len := 1.0 / animation_speed
	var steps := 0
	while _accum >= step_len and steps < _MAX_CATCHUP:
		_accum -= step_len
		_seed = (_seed + int(SEED_STEP * wiggle_frequency)) & 0x7FFFFFFF
		steps += 1
	if _accum > step_len:
		_accum = step_len                       # clamp after a long stall
	if steps > 0:
		_state.reseed_amplitudes(_seed)
		_host.queue_redraw()


## Manual one-frame boil (back-compat for any external driver / tests).
func reseed(new_seed: int) -> void:
	_seed = new_seed
	_state.reseed_amplitudes(new_seed)
	_host.queue_redraw()


## A host's geometry export (points, size, radius...) changed but the bump count
## is unchanged: re-process only, no re-roll (smooth, no twitch).
func mark_geometry_dirty() -> void:
	_state.mark_geometry_dirty()


## Topology changed (point count, open/closed, shape kind): re-roll on next build.
func mark_pattern_dirty() -> void:
	_state.mark_pattern_dirty()


## The editor calls this (via the host) after insert/add/delete so the bump count
## re-rolls to match the new point count.
func notify_topology_changed() -> void:
	_state.mark_pattern_dirty()
	_host.queue_redraw()


# --- Internal ----------------------------------------------------------------

var _host: CanvasItem
var style: WobbleStyle
var _state := WobbleState.new()
var _seed := 1
var _accum := 0.0


func _on_style_changed() -> void:
	_state.mark_geometry_dirty()
	_host.queue_redraw()
