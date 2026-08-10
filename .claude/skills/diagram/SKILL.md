---
name: diagram
description: Generate clean architecture / flow diagrams as PNG+SVG for the yai stack. Hand-laid-out Python→SVG→PNG pipeline (no Mermaid auto-layout). Auto-load when asked to create, update, or render an architecture diagram, flow chart, system diagram, or "draw the stack".
when_to_use: Load when the user wants to visualize the yai stack architecture, create a flow diagram, update an existing diagram, or render any system or component diagram as a PNG or SVG file.
---

# diagram

Produce publication-quality architecture diagrams with deterministic,
hand-controlled layout. **Do not use Mermaid** for these — its auto-layout
crosses edges and looks messy. Instead generate SVG from a small Python
script with explicit coordinates, then rasterize.

## Pipeline

```bash
python3 gen.py                                   # writes the .svg
rsvg-convert -z 2 out.svg -o out.png             # rasterize at 2x
```

`rsvg-convert` is preinstalled (`/opt/homebrew/bin/rsvg-convert`). If a
diagram is needed quickly, copy `template.py` from this skill folder, edit
the `GROUPS` / `NODES` / arrow section, and run it.

The canonical, maintained example lives at **`docs/architecture.py`** in the
repo root (the yai stack architecture itself). `template.py` here is a
frozen copy of that generator — use it as the starting point.

## Style contract (the "ADLC" look)

- **White background**, bold dark title at top, no clutter.
- **Nodes**: rounded rect (`rx=14`), light pastel `tint` fill, 2px colored
  `border`, bold dark title + smaller colored subtitle. Soft drop shadow.
- **Groups**: dashed rounded rect (`rx=20`, `stroke-dasharray="7 6"`,
  `stroke-opacity≈0.55`) with an UPPERCASE letter-spaced label in the
  top-left corner. Leave ~40px between the label and the first node.
- **Arrows**: solid gray (`#8b96a5`) for primary flow; dashed colored for
  feedback / telemetry loops. Curved Bézier connectors, arrowhead markers.
- **Edge labels**: white rounded "pill" with a 1px light border, centered
  on the arrow. Rotate 90° when riding a vertical gutter line.
- **Palette**: one hue per group — keep `c` (border/text), `tint` (fill),
  `dark` (title) as a triple. See `PAL` in the template.

## Layout rules

- Pick a layout that fits the *meaning*, not just stacked bands:
  hub-and-spoke when one component orchestrates others; left-to-right for
  pipelines; layered only for strict tiers.
- Route long-haul arrows (feedback loops, layer-skipping flows) through the
  left/right **gutters** — reserve margin width for them — so they never
  cross node boxes.
- Coordinates are explicit integers. After editing, re-render and *look at
  the PNG* with the Read tool; nudge overlaps by hand.

## Deliverables

Save all three next to each other (the repo uses `docs/`):
`architecture.png` (raster), `architecture.svg` (vector), `architecture.py`
(generator — so the diagram stays editable).

Regenerate after edits:
`python3 docs/architecture.py && rsvg-convert -z 2 docs/architecture.svg -o docs/architecture.png`

## Gotchas

- Escape `&` to `&amp;` in **every** text string (titles, labels, subtitles)
  or `rsvg-convert` fails with `xmlParseEntityRef`.
- Draw order: background → group containers → arrows → nodes → title. Nodes
  last so their borders stay crisp over arrowheads.
