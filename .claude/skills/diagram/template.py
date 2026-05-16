#!/usr/bin/env python3
"""Generate a hub-and-spoke architecture SVG for the yai stack (ADLC-style)."""

W, H = 1760, 1260

PAL = {
    "ctrl": dict(c="#7c5cdb", tint="#efebfb", dark="#3f2d80"),
    "auto": dict(c="#e08a3c", tint="#fdf0e2", dark="#8a4f17"),
    "web":  dict(c="#3a9d6e", tint="#e7f5ee", dark="#1f6b48"),
    "llm":  dict(c="#2f95bf", tint="#e4f2f8", dark="#1d5e7c"),
    "data": dict(c="#4d8fd6", tint="#e9f1fb", dark="#2a5d96"),
    "obs":  dict(c="#d76b8a", tint="#fbe9ef", dark="#92364f"),
}

# group containers: key -> (x, y, w, h, label)
GROUPS = {
    "ctrl": (640, 110, 480, 160, "AI CONTROL PLANE"),
    "auto": (560, 370, 640, 160, "AUTOMATION  ENGINE"),
    "web":  (120, 400, 300, 420, "WEB  &  BROWSER"),
    "llm":  (1340, 400, 300, 420, "LLM  GATEWAY"),
    "data": (520, 680, 720, 170, "STORAGE"),
    "obs":  (140, 1010, 1480, 180, "OBSERVABILITY"),
}

# nodes: (group, title, sub, cx, cy, w, h)
NODES = [
    ("ctrl", "Claude Code / Codex", "skills + slash commands", 880, 212, 420, 96),
    ("auto", "n8n", "workflow automation", 740, 470, 262, 96),
    ("auto", "Windmill", "scripts & flows", 1020, 470, 262, 96),
    ("web", "Firecrawl", "web scraping", 270, 560, 240, 96),
    ("web", "Browserless", "browser automation", 270, 710, 240, 96),
    ("llm", "LiteLLM", "LLM gateway", 1490, 560, 240, 96),
    ("llm", "Langfuse", "traces & evals", 1490, 710, 240, 96),
    ("data", "Postgres", "data store", 660, 788, 210, 96),
    ("data", "Qdrant", "vector store", 880, 788, 210, 96),
    ("data", "MinIO", "file store", 1100, 788, 210, 96),
    ("obs", "Victoria Stack", "logs · metrics · traces", 700, 1118, 380, 100),
    ("obs", "Grafana", "dashboards", 1180, 1118, 300, 100),
]

def esc(s):
    return s.replace("&", "&amp;")

svg = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" '
       f'viewBox="0 0 {W} {H}" font-family="Helvetica, Arial, sans-serif">']

svg.append('<defs>'
           '<filter id="sh" x="-30%" y="-30%" width="160%" height="160%">'
           '<feDropShadow dx="0" dy="2" stdDeviation="3" flood-color="#1e293b" flood-opacity="0.12"/>'
           '</filter>'
           '<marker id="ar" viewBox="0 0 10 10" refX="8" refY="5" '
           'markerWidth="7.5" markerHeight="7.5" orient="auto-start-reverse">'
           '<path d="M0,0 L10,5 L0,10 z" fill="#8b96a5"/></marker>'
           '<marker id="art" viewBox="0 0 10 10" refX="8" refY="5" '
           'markerWidth="7.5" markerHeight="7.5" orient="auto-start-reverse">'
           '<path d="M0,0 L10,5 L0,10 z" fill="#cf8aa0"/></marker>'
           '<marker id="arfb" viewBox="0 0 10 10" refX="8" refY="5" '
           'markerWidth="7.5" markerHeight="7.5" orient="auto-start-reverse">'
           '<path d="M0,0 L10,5 L0,10 z" fill="#b9817a"/></marker>'
           '</defs>')

svg.append(f'<rect width="{W}" height="{H}" fill="#ffffff"/>')

svg.append(f'<text x="{W/2}" y="74" text-anchor="middle" font-size="38" '
           f'font-weight="700" fill="#1e293b">Ynfra | yAI</text>')

# group containers
for key, (x, y, w, h, label) in GROUPS.items():
    pal = PAL[key]
    svg.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="20" fill="none" '
               f'stroke="{pal["c"]}" stroke-width="1.6" stroke-dasharray="7 6" '
               f'stroke-opacity="0.55"/>')
    svg.append(f'<text x="{x+24}" y="{y+30}" font-size="14" font-weight="700" '
               f'letter-spacing="1.2" fill="{pal["c"]}">{esc(label)}</text>')

def arrow(pts, color="#8b96a5", marker="ar", dash=None, width=2.4):
    d = f' stroke-dasharray="{dash}"' if dash else ''
    path = "M" + " L".join(f"{x:.0f},{y:.0f}" for x, y in pts)
    return (f'<path d="{path}" fill="none" stroke="{color}" stroke-width="{width}"'
            f'{d} marker-end="url(#{marker})"/>')

def curve(x1, y1, x2, y2, color="#8b96a5", marker="ar", dash=None):
    d = f' stroke-dasharray="{dash}"' if dash else ''
    mx, my = (x1 + x2) / 2, (y1 + y2) / 2
    if abs(x1 - x2) < abs(y1 - y2):
        c = f"M{x1:.0f},{y1:.0f} C{x1:.0f},{my:.0f} {x2:.0f},{my:.0f} {x2:.0f},{y2:.0f}"
    else:
        c = f"M{x1:.0f},{y1:.0f} C{mx:.0f},{y1:.0f} {mx:.0f},{y2:.0f} {x2:.0f},{y2:.0f}"
    return (f'<path d="{c}" fill="none" stroke="{color}" stroke-width="2.4"'
            f'{d} marker-end="url(#{marker})"/>')

def pill(x, y, text, color="#475569", rot=0):
    w = 14 + len(text) * 7.3
    g0 = f'<g transform="rotate({rot} {x} {y})">' if rot else ''
    g1 = '</g>' if rot else ''
    return (f'{g0}<rect x="{x-w/2:.0f}" y="{y-13:.0f}" width="{w:.0f}" height="26" rx="13" '
            f'fill="#ffffff" stroke="#e2e8f0"/>'
            f'<text x="{x:.0f}" y="{y+5:.0f}" text-anchor="middle" font-size="13" '
            f'font-weight="600" fill="{color}">{esc(text)}</text>{g1}')

# ---- arrows (drawn under nodes) ----
# Claude -> Automation
svg.append(arrow([(880, 270), (880, 370)]))
svg.append(pill(880, 320, "drives"))
# Automation -> Web / LLM (side spokes)
svg.append(curve(560, 470, 420, 560, marker="ar"))
svg.append(pill(490, 505, "scrape / browse"))
svg.append(curve(1200, 470, 1340, 560, marker="ar"))
svg.append(pill(1270, 505, "inference"))
# Automation -> Storage
svg.append(arrow([(880, 530), (880, 680)]))
svg.append(pill(880, 605, "reads / writes"))
# Web -> Storage  &  LLM -> Storage
svg.append(curve(420, 710, 520, 770, marker="ar"))
svg.append(pill(470, 740, "persist"))
svg.append(curve(1340, 710, 1240, 770, marker="ar"))
svg.append(pill(1290, 740, "persist"))
# telemetry: every group -> Observability (dashed)
TCOL = "#cf8aa0"
for tx, ty in [(270, 820), (880, 850), (1490, 820)]:
    svg.append(arrow([(tx, ty), (tx, 1010)], color=TCOL, marker="art", dash="6 5"))
svg.append(pill(880, 930, "telemetry · logs · metrics · traces", "#a85d52"))
# Victoria Stack -> Grafana
svg.append(arrow([(890, 1118), (1030, 1118)]))
# feedback: Grafana -> Claude (dashed, right gutter)
fb_x = 1700
svg.append(arrow([(1330, 1118), (fb_x, 1118), (fb_x, 190), (1120, 190)],
                 color="#b9817a", marker="arfb", dash="6 5"))
svg.append(pill(fb_x, 645, "observability informs design", "#a85d52", rot=90))

# ---- nodes (on top) ----
for (gkey, title, sub, cx, cy, w, h) in NODES:
    pal = PAL[gkey]
    x, y = cx - w / 2, cy - h / 2
    svg.append(f'<rect x="{x:.0f}" y="{y:.0f}" width="{w}" height="{h}" rx="14" '
               f'fill="{pal["tint"]}" stroke="{pal["c"]}" stroke-width="2" '
               f'filter="url(#sh)"/>')
    svg.append(f'<text x="{cx:.0f}" y="{cy-7:.0f}" text-anchor="middle" font-size="22" '
               f'font-weight="700" fill="{pal["dark"]}">{esc(title)}</text>')
    svg.append(f'<text x="{cx:.0f}" y="{cy+19:.0f}" text-anchor="middle" '
               f'font-size="14.5" fill="{pal["c"]}">{esc(sub)}</text>')

svg.append('</svg>')

with open("/tmp/yai-arch.svg", "w") as f:
    f.write("\n".join(svg))
print("wrote /tmp/yai-arch.svg")
