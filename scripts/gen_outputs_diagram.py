"""Generate web/outputs.mmd (mermaid flowchart) from the output_taxonomy table.

Reads the seeded taxonomy via PostgREST (public read, so the anon key works) and
emits a left-to-right node-link tree. Run after editing the taxonomy and commit
web/outputs.mmd:

    uv run scripts/gen_outputs_diagram.py
    git add web/outputs.mmd && git commit
"""

from __future__ import annotations

import datetime
from pathlib import Path

import httpx

# Reuse the schema generator's env loader (same SUPABASE_URL / key handling).
from gen_schema_diagram import load_env

OUT = Path(__file__).resolve().parent.parent / "web" / "outputs.mmd"


def fetch_taxonomy(url: str, key: str) -> list[list[str]]:
    r = httpx.get(
        f"{url}/rest/v1/output_taxonomy",
        params={"select": "segments,sort_order", "order": "sort_order.asc"},
        headers={"apikey": key, "Authorization": f"Bearer {key}"},
        timeout=30,
    )
    r.raise_for_status()
    return [row["segments"] for row in r.json()]


def esc(label: str) -> str:
    # Labels are wrapped in double quotes; only " needs escaping (parens/accents ok).
    return label.replace('"', "#quot;")


def build_mmd(paths: list[list[str]]) -> str:
    ids: dict[tuple[str, ...], str] = {}
    nodes: list[str] = []          # node declarations, in first-seen order
    edges: list[str] = []          # parent --> child, deduped
    seen_edges: set[tuple[str, str]] = set()

    def node_id(prefix: tuple[str, ...]) -> str:
        if prefix not in ids:
            nid = f"n{len(ids)}"
            ids[prefix] = nid
            nodes.append(f'  {nid}["{esc(prefix[-1])}"]')
        return ids[prefix]

    for path in paths:
        for depth in range(1, len(path) + 1):
            child = tuple(path[:depth])
            cid = node_id(child)
            if depth > 1:
                pid = node_id(tuple(path[: depth - 1]))
                key = (pid, cid)
                if key not in seen_edges:
                    seen_edges.add(key)
                    edges.append(f"  {pid} --> {cid}")

    stamp = datetime.date.today().isoformat()
    body = "\n".join(nodes) + "\n\n" + "\n".join(edges)
    return (
        f"%% generated {stamp} by scripts/gen_outputs_diagram.py — do not edit by hand\n"
        f"graph LR\n{body}\n"
    )


def main() -> None:
    url, key = load_env()
    paths = fetch_taxonomy(url, key)
    mmd = build_mmd(paths)

    roots = {p[0] for p in paths}
    leaves = len(paths)
    node_count = sum(1 for line in mmd.splitlines() if line.strip().startswith("n") and '["' in line)
    edge_count = sum(1 for line in mmd.splitlines() if " --> " in line)
    assert len(roots) >= 11, f"only {len(roots)} category roots"
    assert leaves >= 74, f"only {leaves} leaf paths"
    assert node_count > leaves and edge_count > 0, f"nodes={node_count} edges={edge_count}"

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(mmd, encoding="utf-8")
    print(
        f"SELF-CHECK: PASS — {len(roots)} roots, {leaves} leaves, "
        f"{node_count} nodes, {edge_count} edges -> {OUT}"
    )


if __name__ == "__main__":
    main()
