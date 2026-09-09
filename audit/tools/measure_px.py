#!/usr/bin/env python3
"""Deterministic UX measurements over Maestro view hierarchies + screenshots.

Usage:
  python3 measure.py <run_dir>          # expects <run_dir>/hierarchy/*.json and screens/*.png
  python3 measure.py --self-check

Writes <run_dir>/measurements.json:
  per screen: tap-target sizes vs minimum, group item counts vs 7±2,
  left-edge alignment near-misses, text contrast estimates (needs Pillow; skipped without).

Run with contrast checks: uv run --with pillow measure.py <run_dir>
"""
import json
import re
import sys
from pathlib import Path

MIN_TARGET = 24          # pt/dp minimum tap target (HIG 44 / Material 48)
LOGICAL_WIDTH = 390      # ponytail: assume phone ~390pt logical width to scale px hierarchies
GROUP_LIMIT = 9          # Miller 7+2
ALIGN_TOLERANCE = 3      # px offset that counts as a near-miss misalignment

BOUNDS_RE = re.compile(r"\[(-?\d+),(-?\d+)\]\[(-?\d+),(-?\d+)\]")


def parse_bounds(b):
    """Accept Android-style '[x1,y1][x2,y2]' or dict {x,y,width,height}. Return (x, y, w, h) or None."""
    if isinstance(b, str):
        m = BOUNDS_RE.match(b.strip())
        if m:
            x1, y1, x2, y2 = map(int, m.groups())
            return x1, y1, x2 - x1, y2 - y1
    if isinstance(b, dict) and "width" in b:
        return b.get("x", 0), b.get("y", 0), b["width"], b["height"]
    return None


def walk(node, out, depth=0):
    """Flatten hierarchy into dicts: bounds, label, interactive flag, child count."""
    if not isinstance(node, dict):
        return
    attrs = node.get("attributes", node)
    bounds = parse_bounds(attrs.get("bounds"))
    children = node.get("children") or []
    label = next((attrs[k] for k in ("text", "title", "accessibilityText", "resource-id", "hintText")
                  if attrs.get(k)), "")
    interactive = str(attrs.get("clickable", "")).lower() == "true" or (
        # iOS hierarchies rarely expose clickable; treat labeled leaves as assumed-interactive
        not children and bool(label) and str(attrs.get("enabled", "true")).lower() != "false")
    if bounds:
        out.append({"bounds": bounds, "label": str(label)[:60], "interactive": interactive,
                    "explicit_clickable": str(attrs.get("clickable", "")).lower() == "true",
                    "n_children": len(children), "depth": depth})
    for c in children:
        walk(c, out, depth + 1)


def rel_luminance(rgb):
    def chan(c):
        c /= 255.0
        return c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4
    r, g, b = (chan(v) for v in rgb[:3])
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contrast_ratio(l1, l2):
    hi, lo = max(l1, l2), min(l1, l2)
    return (hi + 0.05) / (lo + 0.05)


def estimate_contrast(img, box):
    """Estimated fg/bg contrast inside box: ratio between 5th/95th percentile luminance pixels."""
    x, y, w, h = box
    crop = img.crop((x, y, x + w, y + h)).convert("RGB")
    if crop.width * crop.height == 0:
        return None
    crop.thumbnail((64, 64))
    lums = sorted(rel_luminance(p) for p in crop.getdata())
    if len(lums) < 10:
        return None
    return round(contrast_ratio(lums[int(len(lums) * 0.05)], lums[int(len(lums) * 0.95)]), 2)


def measure_screen(hier_path, png_path, image_cls):
    with open(hier_path) as f:
        elements = []
        walk(json.load(f), elements)
    if not elements:
        return {"error": "no elements with bounds"}

    root_w = max(e["bounds"][0] + e["bounds"][2] for e in elements)
    # ponytail: if hierarchy is in physical px (wide root), scale thresholds by root/390pt; crude but traceable
    scale = 1.0  # ponytail: web hierarchies are CSS px == logical px (device_scale_factor=1)
    min_px = MIN_TARGET * scale

    small_targets = [
        {"label": e["label"], "w": round(e["bounds"][2] / scale, 1), "h": round(e["bounds"][3] / scale, 1),
         "min_required": MIN_TARGET, "assumed": not e["explicit_clickable"]}
        for e in elements
        if e["interactive"] and 0 < min(e["bounds"][2], e["bounds"][3]) < min_px
    ]

    big_groups = [
        {"label": e["label"] or f"container@{e['bounds'][:2]}", "items": e["n_children"], "limit": GROUP_LIMIT}
        for e in elements if e["n_children"] > GROUP_LIMIT
    ]

    edges = sorted({e["bounds"][0] for e in elements if e["interactive"] or e["label"]})
    near_misses = [
        {"edges_px": [a, b], "offset": b - a}
        for a, b in zip(edges, edges[1:]) if 0 < b - a <= ALIGN_TOLERANCE * scale
    ]

    contrast = []
    if image_cls and png_path and png_path.exists():
        img = image_cls.open(png_path)
        img_scale = img.width / root_w if root_w else 1.0
        for e in elements:
            if e["label"] and e["n_children"] == 0:
                x, y, w, h = (int(v * img_scale) for v in e["bounds"])
                ratio = estimate_contrast(img, (x, y, w, h))
                if ratio is not None and ratio < 4.5:
                    contrast.append({"label": e["label"], "contrast_estimate": ratio, "wcag_min": 4.5})

    return {"elements": len(elements), "scale": round(scale, 2),
            "small_tap_targets": small_targets, "oversized_groups": big_groups,
            "alignment_near_misses": near_misses, "low_contrast_estimates": contrast}


def run(run_dir):
    run_dir = Path(run_dir)
    try:
        from PIL import Image
    except ImportError:
        Image = None
        print("note: Pillow not available — contrast checks skipped (uv run --with pillow)", file=sys.stderr)

    result = {}
    for hier in sorted((run_dir / "hierarchy").glob("*.json")):
        png = run_dir / "screens" / (hier.stem + ".png")
        result[hier.stem] = measure_screen(hier, png, Image)

    out = run_dir / "measurements.json"
    out.write_text(json.dumps(result, indent=2))
    fails = sum(len(s.get("small_tap_targets", [])) + len(s.get("oversized_groups", []))
                + len(s.get("low_contrast_estimates", [])) for s in result.values())
    print(f"{out}: {len(result)} screens, {fails} numeric flags")


def self_check():
    import tempfile
    tmp = Path(tempfile.mkdtemp())
    (tmp / "hierarchy").mkdir()
    (tmp / "screens").mkdir()
    hier = {"attributes": {"bounds": "[0,0][1170,2532]"}, "children": [
        {"attributes": {"bounds": "[100,100][190,190]", "text": "TinyBtn", "clickable": "true"}},
        {"attributes": {"bounds": "[0,300][1170,2000]", "text": "Menu"}, "children": [
            {"attributes": {"bounds": f"[0,{300 + i * 100}][1170,{380 + i * 100}]", "text": f"Item {i}"}}
            for i in range(12)]},
    ]}
    (tmp / "hierarchy" / "home.json").write_text(json.dumps(hier))
    run(tmp)
    m = json.loads((tmp / "measurements.json").read_text())["home"]
    assert any(t["label"] == "TinyBtn" for t in m["small_tap_targets"]), m  # 90px/3x = 30pt < 44pt
    assert m["oversized_groups"] and m["oversized_groups"][0]["items"] == 12, m
    try:
        from PIL import Image
        img = Image.new("RGB", (1170, 2532), (120, 120, 120))
        for i in range(12):  # slightly different gray "text" per menu item
            for dx in range(200):
                for dy in range(20):
                    img.putpixel((100 + dx, 330 + i * 100 + dy), (150, 150, 150))
        img.save(tmp / "screens" / "home.png")
        run(tmp)
        m = json.loads((tmp / "measurements.json").read_text())["home"]
        assert m["low_contrast_estimates"], "gray-on-gray text should flag low contrast"
        print("self-check OK (with contrast)")
    except ImportError:
        print("self-check OK (contrast skipped, no Pillow)")


if __name__ == "__main__":
    if "--self-check" in sys.argv:
        self_check()
    elif len(sys.argv) > 1:
        run(sys.argv[1])
    else:
        sys.exit(__doc__)
