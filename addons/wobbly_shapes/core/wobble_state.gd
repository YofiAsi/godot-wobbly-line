@tool
class_name WobbleState
extends RefCounted

## Per-node cache + dirty-flag bookkeeping shared by both wrapper nodes.
##
## Holds the rolled amplitudes and the last generated geometry, and decides
## when to re-roll (seed/frequency change) versus only re-process (resize,
## wiggle, smoothen, vertex drag). This is the "generate-once, rebuild lazily"
## logic from the prototype, factored out so the nodes stay thin.

var amplitudes: PackedFloat32Array = PackedFloat32Array()
var cache: PackedVector2Array = PackedVector2Array()
var stroke_cache: PackedVector2Array = PackedVector2Array()   # cache + wrap point when closed

var pattern_dirty := true        # topology changed -> re-roll amplitudes
var geometry_dirty := true       # positions changed -> re-process only

var _last_seed := 0
var _last_frequency := -1.0
var _fixed_count := 0            # K, fixed across resizes once first built


## Topology/seed/frequency changed: re-roll amplitudes on next build.
func mark_pattern_dirty() -> void:
	pattern_dirty = true
	geometry_dirty = true


## Positions changed but bump count is unchanged: re-process only (no twitch).
func mark_geometry_dirty() -> void:
	geometry_dirty = true


## Returns the cached wobbly geometry, rebuilding lazily. Re-rolls amplitudes
## only when the pattern is dirty or the seed/frequency actually changed.
func get_geometry(base: PackedVector2Array, closed: bool, style: WobbleStyle) -> PackedVector2Array:
	if style == null or base.size() < 2:
		return PackedVector2Array()

	var seed_changed := style.seed != _last_seed
	var freq_changed := not is_equal_approx(style.frequency, _last_frequency)
	if pattern_dirty or amplitudes.is_empty() or seed_changed or freq_changed:
		var perim := WobbleCore.perimeter(base, closed)
		_fixed_count = WobbleCore.point_count(perim, style.frequency, closed)
		amplitudes = WobbleCore.roll_amplitudes(_fixed_count, style.seed)
		_last_seed = style.seed
		_last_frequency = style.frequency
		pattern_dirty = false
		geometry_dirty = true

	if geometry_dirty or cache.is_empty():
		cache = WobbleCore.process(base, closed, amplitudes, style.wiggle, style.smoothen_passes())
		# Build the stroke polyline once per rebuild, not on every draw (the
		# stroke is drawn each frame, twice when the clip overlay is active).
		if closed and not cache.is_empty():
			stroke_cache = cache.duplicate()    # packed arrays share on assignment
			stroke_cache.append(cache[0])       # close the loop
		else:
			stroke_cache = cache
		geometry_dirty = false
	return cache


## "Boil" animation: re-roll amplitudes in place, keeping the bump count so the
## outline wobbles instead of popping. Does NOT touch the seed bookkeeping, so a
## later geometry rebuild won't overwrite the boiled amplitudes.
func reseed_amplitudes(new_seed: int) -> void:
	if amplitudes.is_empty():
		return
	amplitudes = WobbleCore.roll_amplitudes(amplitudes.size(), new_seed)
	geometry_dirty = true
