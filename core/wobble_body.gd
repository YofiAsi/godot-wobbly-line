@tool
class_name WobbleBody
extends RefCounted

## Internal — addon implementation; the host nodes (WobbleItem and WobbleControl)
## interact with the wobbly-shapes pipeline through this component, never with the
## deeper helpers directly.
##
## A WobbleBody is the single home for everything a wobbly node needs but that is
## the same across the Node2D and Control hosts:
##   - holding the look parameters: the host's native per-node values plus an
##     OPTIONAL WobbleStyle override (and listening to its `changed` signal). The
##     "effective" value of each param is the override's when one is assigned, else
##     the native value pushed from the host (see the _eff_* getters),
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

## Maximum Chaikin passes at smoothen == 1.0. Convergence is essentially complete
## by ~4-5 passes and point count grows geometrically per pass.
const MAX_SMOOTHEN_PASSES := 5

# --- API (called by host nodes) ---------------------------------------------

## Animation knobs, mirrored from the host's exported properties.
var playing := false
var animation_speed := 10.0          ## boil ticks per second (0 => paused)
var wiggle_frequency := 1.0          ## multiplies SEED_STEP per tick (per-frame delta)


## Construct bound to its host. `host` is the Node2D/Control that owns this body.
func _init(host: CanvasItem) -> void:
	_host = host


## Mirror the host's native per-node look values. Used when no override resource
## is assigned (or for any param the override does not change — currently all or
## nothing). get_geometry detects the seed/frequency change itself, so marking the
## geometry dirty + redrawing is enough.
func set_appearance(p_frequency: float, p_wiggle: float, p_smoothen: float, p_seed: int,
		p_fill_color: Color, p_stroke_color: Color, p_stroke_width: float) -> void:
	frequency = p_frequency
	wiggle = p_wiggle
	smoothen = p_smoothen
	seed = p_seed
	fill_color = p_fill_color
	stroke_color = p_stroke_color
	stroke_width = p_stroke_width
	_state.mark_geometry_dirty()
	_host.queue_redraw()


## Assign the OPTIONAL look override, rewiring the `changed` connection. When set,
## its values win over the native ones (see _eff_*). Topology may depend on
## frequency, so this marks the pattern dirty and redraws. Pass null to clear.
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


## Call from the host's _ready(): sync processing to the current play state, and
## create the outline overlay up front (in the tree, before any _draw) so we never
## touch the scene tree from inside _draw().
func ready() -> void:
	_host.set_process(playing)
	_ensure_overlay()


## Call from the host's _draw(). `base` is the host-built base path; `closed`
## says whether it is a filled loop.
##
## When the host opts into Godot's own `clip_children = CLIP_CHILDREN_AND_DRAW`
## on a closed shape, split the draw into two passes so children clip to the
## wobbly silhouette with the outline kept crisp on top: the host draws only the
## FILL (which doubles as the clip mask), and the STROKE is drawn last on an
## unclipped top_level overlay (see _WobbleOutline). Any other clip mode falls
## through to the normal single-pass fill+stroke.
func draw(base: PackedVector2Array, closed: bool) -> void:
	if base.size() < 2:
		return
	var pts := _state.get_geometry(base, closed, _eff_seed(), _eff_frequency(),
			_eff_wiggle(), _smoothen_passes(_eff_smoothen()))
	if closed and _host.clip_children == CanvasItem.CLIP_CHILDREN_AND_DRAW:
		WobbleDraw.draw_fill(_host, pts, closed, _eff_fill_color())
		# Re-create lazily: teardown_overlay() on EXIT_TREE may have freed it, and
		# the host's _ready (which first ensures it) runs only once per lifetime.
		var overlay := _ensure_overlay()
		overlay.visible = true
		sync_overlay_transform()
		overlay.set_outline(self, _state.stroke_cache)
	else:
		if _overlay != null and is_instance_valid(_overlay):
			_overlay.visible = false
		WobbleDraw.draw_shape(_host, pts, _state.stroke_cache, closed,
				_eff_fill_color(), _eff_stroke_color(), _eff_stroke_width())


## Draw the filled silhouette only. Exposed so the overlay path stays in one place.
func draw_fill(ci: CanvasItem, pts: PackedVector2Array, closed: bool) -> void:
	WobbleDraw.draw_fill(ci, pts, closed, _eff_fill_color())


## Draw the outline only. Called by the overlay node so it can render the stroke
## on top of the host's clipped children. `line` is the prebuilt stroke polyline.
func draw_stroke(ci: CanvasItem, line: PackedVector2Array) -> void:
	WobbleDraw.draw_stroke(ci, line, _eff_stroke_color(), _eff_stroke_width())


## Keep the outline overlay aligned with the host when the host moves/rotates.
## The host calls this from its transform-changed notification: whether the overlay
## is top_level (no clip ancestor) or parented into a clip ancestor, it tracks the
## host by absolute transform rather than inheriting it. Guarded with is_inside_tree
## because reading global_transform before the host enters the tree throws.
func sync_overlay_transform() -> void:
	if _overlay == null or not is_instance_valid(_overlay):
		return
	if not _host.is_inside_tree():
		return
	_overlay.global_transform = _host.get_global_transform()
	if _clip_ancestor != null:
		_overlay.z_index = _host_effective_z_index()


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

const _WobbleOutline := preload("res://addons/wobbly_shapes/nodes/_wobble_outline.gd")

var _host: CanvasItem

# Native per-node look, mirrored from the host's exports. Defaults MUST match the
# host exports (and WobbleStyle) so a body that is never pushed still draws right.
var frequency := 4.0
var wiggle := 1.6
var smoothen := 0.6
var seed := 12345
var fill_color := Color(0.99, 0.97, 0.90)
var stroke_color := Color(0.15, 0.15, 0.18)
var stroke_width := 2.5

var style: WobbleStyle               ## optional override; when set, its values win
var _state := WobbleState.new()
var _seed := 1
var _accum := 0.0
var _overlay: Node2D
var _clip_ancestor: Control          ## nearest clip_contents ancestor, else null


# --- Effective look (override-vs-native resolution) --------------------------
# Whole-resource override: if a WobbleStyle is assigned, every param comes from it.

func _eff_frequency() -> float:
	return style.frequency if style != null else frequency

func _eff_wiggle() -> float:
	return style.wiggle if style != null else wiggle

func _eff_smoothen() -> float:
	return style.smoothen if style != null else smoothen

func _eff_seed() -> int:
	return style.seed if style != null else seed

func _eff_fill_color() -> Color:
	return style.fill_color if style != null else fill_color

func _eff_stroke_color() -> Color:
	return style.stroke_color if style != null else stroke_color

func _eff_stroke_width() -> float:
	return style.stroke_width if style != null else stroke_width


## Discrete Chaikin pass count derived from the continuous smoothen knob.
func _smoothen_passes(s: float) -> int:
	return int(round(clampf(s, 0.0, 1.0) * float(MAX_SMOOTHEN_PASSES)))


func _on_style_changed() -> void:
	_state.mark_geometry_dirty()
	_host.queue_redraw()


## Lazily create the stroke overlay as an INTERNAL node (never serialized into the
## user's scene, hidden from the editor tree). Mounting is deferred: calling
## add_child() synchronously while many WobbleControl nodes initialise in the same
## frame can hit "Parent node is busy setting up children".
func _ensure_overlay() -> Node2D:
	if _overlay == null or not is_instance_valid(_overlay):
		_overlay = _WobbleOutline.new()
		_overlay.name = "_WobbleOutline"
	if _overlay.get_parent() == null:
		_mount_overlay.call_deferred()
	return _overlay


## Pick where the overlay lives so the stroke escapes the host's OWN clip mask yet
## still respects ancestor clip_contents rects (issue #16):
##   - With a clip_contents ancestor: parent INTO that ancestor (INTERNAL_MODE_FRONT,
##     so it draws above sibling content) and drop top_level. The overlay then sits
##     inside the ancestor's clip group and is clipped by its rect, while its
##     absolute transform (synced each redraw) keeps it pinned to the host. z_index
##     is set to the host's effective depth so the stroke stacks with the host.
##   - With no clip ancestor: original behaviour — INTERNAL_MODE_BACK under the host
##     with top_level, lifting the stroke to the canvas root above clipped children.
func _mount_overlay() -> void:
	if _overlay == null or not is_instance_valid(_overlay):
		return
	if not _host.is_inside_tree():
		return
	_clip_ancestor = _find_clip_ancestor(_host)
	if _overlay.get_parent() != null:
		_overlay.get_parent().remove_child(_overlay)
	if _clip_ancestor != null:
		_clip_ancestor.add_child(_overlay, false, Node.INTERNAL_MODE_FRONT)
		_overlay.top_level = false
		_overlay.z_as_relative = false
		_overlay.z_index = _host_effective_z_index()
	else:
		_host.add_child(_overlay, false, Node.INTERNAL_MODE_BACK)
		_overlay.top_level = true
	sync_overlay_transform()


## Walk up from the host, returning the nearest Control with clip_contents on (the
## boundary the stroke must stay inside), or null when there is none.
func _find_clip_ancestor(host: Node) -> Control:
	var node := host.get_parent()
	while node != null:
		if node is Control and (node as Control).clip_contents:
			return node as Control
		node = node.get_parent()
	return null


## The host's z_index relative to the clip ancestor: sum the z_index of every
## CanvasItem from the host up to (not including) the ancestor, so a stroke parented
## directly under the ancestor draws at the same depth as the host's fill.
func _host_effective_z_index() -> int:
	var z := 0
	var node: Node = _host
	while node != null and node != _clip_ancestor:
		if node is CanvasItem:
			z += (node as CanvasItem).z_index
		node = node.get_parent()
	return z


## Free the overlay and forget the resolved clip ancestor. The host calls this on
## NOTIFICATION_EXIT_TREE: when the overlay is parented to a clip ancestor it is NOT
## an internal child of the host, so freeing the host alone would orphan it (a ghost
## stroke that keeps drawing). The next clipped draw() re-creates it via
## _ensure_overlay(), which also re-resolves the clip ancestor if the host moved.
func teardown_overlay() -> void:
	if _overlay != null and is_instance_valid(_overlay):
		# queue_free() detaches and frees on its own — don't remove_child() here,
		# this often runs during the host's EXIT_TREE while the tree is mid-removal
		# ("Parent node is busy adding/removing children").
		_overlay.queue_free()
	_overlay = null
	_clip_ancestor = null
