# Wobbly Shapes — Godot 4.6 addon

Hand-drawn, animation-ready "wobbly" outlines for both UI (`Control`) and the
2D world (`Node2D`). One shared geometry core, a serializable look resource, a
small family of shape nodes, self-contained "boil" animation, and live 2D
editor handles.

This repo is a ready-to-open Godot 4.6 project. The addon itself lives in
`addons/wobbly_shapes/` and can be dropped into any other project.

## Quick start

1. Open the project in Godot 4.6 (the plugin is already enabled in
   `project.godot`).
2. Run the project (`F5`) to see the demo scene with all primitives, plus the
   slow "boil" animation (the nodes drive it themselves via `auto_play`).
3. In a scene, **Add Node →** one of `WobblePolygon`, `WobbleLine`,
   `WobbleBezier`, `WobbleShape` (world shapes) or `WobbleControl` (UI panels).
   Assign a **WobbleStyle** resource (one is auto-created) and tune it in the
   inspector.

## Architecture

A shared geometry core, a shared component, and thin nodes:

```
WobbleStyle (Resource, .tres)   authoring params; emit_changed() on every setter
WobblePath  (static)            primitive -> base PackedVector2Array
WobbleCore  (static)            resample -> jitter(seed) -> Chaikin; open/closed aware
WobbleState (RefCounted)        per-node amplitude cache + dirty flags
WobbleDraw  (static)            one fill + one stroke call
WobbleBody  (RefCounted)        shared component: style + state + boil + draw
   |                                   |
WobbleItem (Node2D, base)       WobbleControl (Control)
 ├ WobblePolygon  (closed)         size + corner_radius
 ├ WobbleLine     (open/closed)
 ├ WobbleBezier   (Curve2D)     both hosts hold a WobbleBody and forward to it
 └ WobbleShape    (rect/circle)
   |
WobbleEditorPlugin              draggable / insert / delete vertex handles
```

Each node owns the exported properties (style + the `playing` / `auto_play` /
`animation_speed` / `wiggle_frequency` animation controls) and delegates the
actual style wiring, caching, boil, and drawing to a `WobbleBody`, so the
Node2D and Control hosts share one implementation without sharing a base class.

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

- Select a `WobblePolygon` or `WobbleLine`: white vertex handles appear in the
  2D viewport, replicating the feel of Godot's native Line2D/Polygon2D editor —
  - **drag** a handle to move a point,
  - **click an edge** to insert a point and place it,
  - on an open `WobbleLine`, **click near an end** to extend the line,
  - **right-click** (or `Delete`) a handle to remove it.

  Each gesture is one undo step (`Ctrl+Z` reverts).
- All nodes are `@tool`, so they preview live — including the boil — while editing.

## Animation: the "boil"

Every shape node and `WobbleControl` animates itself. In the inspector's
**Animation** group:

| Property | Meaning |
|---|---|
| `playing` | run the boil now (previews live in the editor) |
| `auto_play` | start playing automatically when the node enters the tree |
| `animation_speed` | boil ticks per second |
| `wiggle_frequency` | how much the outline shifts each tick (subtle drift ↔ jumpy) |

Under the hood each node steps a deterministic seed and re-rolls its wobble
amplitudes while keeping the bump count, so the outline wobbles in place like
hand-drawn animation. The seed is stepped by a **large** constant (the
golden-ratio constant `0x9E3779B9`), not by 1 — Godot's RNG has no avalanche
effect, so consecutive seeds look nearly identical. `reseed(new_seed)` is still
available for manual/external driving.

## Files

```
addons/wobbly_shapes/
├── plugin.cfg / plugin.gd          EditorPlugin: 2D vertex handles
├── core/
│   ├── wobble_core.gd              static pipeline (resample/jitter/chaikin)
│   ├── wobble_state.gd             per-node cache + dirty flags
│   ├── wobble_body.gd              shared component: style + state + boil + draw
│   ├── path_source.gd              primitive -> points (WobblePath)
│   └── draw_helper.gd              fill + stroke (WobbleDraw)
├── resources/wobble_style.gd       WobbleStyle (serializable params)
├── nodes/
│   ├── wobble_item.gd              WobbleItem (Node2D base)
│   ├── wobble_polygon.gd           WobblePolygon (closed)
│   ├── wobble_line.gd              WobbleLine (open / closed)
│   ├── wobble_bezier.gd            WobbleBezier (Curve2D)
│   ├── wobble_shape.gd             WobbleShape (rectangle / circle)
│   └── wobble_control.gd           WobbleControl (Control)
├── editor/
│   └── handle_editor.gd            vertex hit-test / drag / insert / delete / undo
└── icons/                          custom node + resource icons
```

## Notes / caveats

- Targets **Godot 4.6**. The editor overlay transform uses
  `EditorInterface.get_editor_viewport_2d().global_canvas_transform` (4.2+).
- 2D MSAA is enabled in `project.godot` for fill antialiasing
  (`draw_colored_polygon` has no AA arg; `draw_polyline` antialiases strokes).
- RNG output is not guaranteed stable across Godot versions; don't bake raw
  seed-derived output into saved assets expecting cross-version reproducibility.
