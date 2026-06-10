# Wobbly Shapes — Godot 4.6 addon

Hand-drawn, animation-ready "wobbly" outlines for both UI (`Control`) and the
2D world (`Node2D`). One shared geometry core, a serializable look resource,
thin wrapper nodes, and live 2D editor handles.

This repo is a ready-to-open Godot 4.6 project. The addon itself lives in
`addons/wobbly_shapes/` and can be dropped into any other project.

## Quick start

1. Open the project in Godot 4.6 (the plugin is already enabled in
   `project.godot`).
2. Run the project (`F5`) to see the demo scene with all primitives, plus the
   slow "boil" animation that runs at runtime.
3. In a scene, **Add Node → `WobbleControl`** (UI panels) or **`WobbleShape2D`**
   (world shapes). Assign a **WobbleStyle** resource (one is auto-created) and
   tune it in the inspector.

## Architecture

A one-core / thin-wrapper design (no per-shape subclassing):

```
WobbleStyle (Resource, .tres)   authoring params; emit_changed() on every setter
WobblePath  (static)            primitive -> base PackedVector2Array
WobbleCore  (static)            resample -> jitter(seed) -> Chaikin; open/closed aware
WobbleState (RefCounted)        per-node amplitude cache + dirty flags
WobbleDraw  (static)            one fill + one stroke call
   |                                   |
WobbleShape2D (Node2D)          WobbleControl (Control)
   points / ellipse / bezier        size + corner_radius
   |
WobbleEditorPlugin              inspector widget + draggable vertex handles
```

### The pipeline

1. **Base path** from a `WobblePath` source (`rounded_rect`, `ellipse`,
   `bezier` via `Curve2D.tessellate()`, or explicit polygon/polyline points).
2. **Arc-length resample** to `K = round(frequency * perimeter / 100)` points.
   Closed paths wrap; open paths pin both endpoints.
3. **Jitter**: push each point along its normal by a *stable* per-bump
   amplitude (`wiggle`). Amplitudes are rolled once per seed/frequency change,
   so resizing or dragging never re-rolls them — no twitch. Open-path endpoints
   are pinned (amplitude 0).
4. **Chaikin** corner-cutting, `smoothen` (0–1) mapped to up to 5 passes.
   Closed rings cut every edge; open polylines keep their endpoints.
5. **Draw**: closed → filled polygon + closed antialiased stroke; open → stroke
   only.

## The `WobbleStyle` parameters (Figma "Dynamic stroke" analogues)

| Param | Meaning |
|---|---|
| `frequency` | bumps per 100 px of perimeter (bump count) |
| `wiggle` | jitter amplitude in px |
| `smoothen` | 0 = faceted, 1 = soft waves (Chaikin passes) |
| `seed` | deterministic randomness |
| `fill_color` / `stroke_color` / `stroke_width` | appearance |

## Editor authoring

- Select a `WobbleShape2D` set to **Polygon** or **Polyline**: white vertex
  handles appear in the 2D viewport. Drag to reshape (one undo step per drag,
  `Ctrl+Z` reverts).
- The inspector shows a **🎲 Randomize Seed** button for both node types.
- All nodes are `@tool`, so they preview live while editing.

## Animation: the "boil"

Call `reseed(new_seed)` on any wobble node each frame (≈8–12 fps) to re-roll
amplitudes while keeping the bump count — the outline wobbles in place like
hand-drawn animation. The demo's `demo_controller.gd` drives this at runtime.

Step the seed by a **large** constant (the demo uses the golden-ratio constant
`0x9E3779B9`), not by 1 — Godot's RNG has no avalanche effect, so consecutive
seeds look nearly identical.

## Files

```
addons/wobbly_shapes/
├── plugin.cfg / plugin.gd          EditorPlugin: inspector + 2D handles
├── core/
│   ├── wobble_core.gd              static pipeline (resample/jitter/chaikin)
│   ├── wobble_state.gd             per-node cache + dirty flags
│   ├── path_source.gd              primitive -> points (WobblePath)
│   └── draw_helper.gd              fill + stroke (WobbleDraw)
├── resources/wobble_style.gd       WobbleStyle (serializable params)
├── nodes/
│   ├── wobble_shape_2d.gd          WobbleShape2D (Node2D)
│   └── wobble_control.gd           WobbleControl (Control)
├── editor/
│   ├── wobble_inspector.gd         EditorInspectorPlugin
│   └── handle_editor.gd            vertex hit-test / drag / undo
└── icons/                          custom node + resource icons
```

## Notes / caveats

- Targets **Godot 4.6**. The editor overlay transform uses
  `EditorInterface.get_editor_viewport_2d().global_canvas_transform` (4.2+).
- 2D MSAA is enabled in `project.godot` for fill antialiasing
  (`draw_colored_polygon` has no AA arg; `draw_polyline` antialiases strokes).
- RNG output is not guaranteed stable across Godot versions; don't bake raw
  seed-derived output into saved assets expecting cross-version reproducibility.
