"""Import UNIDCOM part02 export: clusters, labs, objectives + richer projects.

Leaves import.py untouched but reuses its deterministic id scheme (same NS +
row_id) so projects merge onto the rows import.py already created, preserving
their project_outputs / project_members links.

  uv run import_part02.py            # dry run: self-check + scripts/out_part02/*.json
  uv run import_part02.py --load     # upsert into Supabase (needs migration applied)
"""

from __future__ import annotations

import argparse
import csv
import json
import os
import re
import sys
import unicodedata
import uuid
from pathlib import Path

DATA = Path(__file__).resolve().parent.parent / "RAW_DATA" / "part02"
CLUSTERS_CSV = "UNIDCOM Clusters 74a4236e5d7a4cf6963deff9ac41d073_all.csv"
LABS_CSV = "UNIDCOM Labs 2d49755618b24a6995b7532e0379c81d_all.csv"
OBJECTIVES_CSV = "UNIDCOM Objectives b0e4e26fef4e4d4a8a1f52b8365442c3_all.csv"
PROJECTS_CSV = "UNIDCOM Projects 55d40fc0b5ba4163b8a761d848811d1d_all.csv"
INTCOLAB_CSV = "UNIDCOM Internal Collaborations 077c7bbcd0ed46e3ab3d663e0285edc8_all.csv"

NS = uuid.UUID("3fc3e2b1-18c9-4834-b0b7-bcbb24ff419b")  # same as import.py

MONTHS = {m: i for i, m in enumerate(
    ["January", "February", "March", "April", "May", "June", "July",
     "August", "September", "October", "November", "December"], 1)}

STATUS = {
    "Ideia": "planned", "Em candidatura": "planned",
    "Em execução": "active", "Fechado": "completed",
}


def clean(value: str | None) -> str:
    return " ".join((value or "").strip().split())


def match_key(value: str | None) -> str:
    text = unicodedata.normalize("NFKD", clean(value).lower())
    return "".join(c for c in text if not unicodedata.combining(c))


def row_id(prefix: str, key: str) -> str:
    return str(uuid.uuid5(NS, f"{prefix}:{key}"))


def read_csv(path: Path) -> list[dict[str, str]]:
    with path.open(encoding="utf-8-sig", newline="") as f:
        return list(csv.DictReader(f))


def link_names(value: str | None) -> list[str]:
    """Notion relation cell -> list of referenced page titles (URLs stripped)."""
    value = re.sub(r"\s*\(https?://[^)]*\)", "", value or "")
    return [clean(name) for name in value.split(",") if clean(name)]


def parse_date(value: str | None) -> str | None:
    m = re.match(r"(\d{1,2})\s+([A-Za-z]+)\s+(\d{4})", clean(value))
    if not m or m.group(2) not in MONTHS:
        return None
    return f"{m.group(3)}-{MONTHS[m.group(2)]:02d}-{int(m.group(1)):02d}"


def load_env() -> tuple[str, str] | None:
    try:
        from dotenv import load_dotenv
        load_dotenv(Path(__file__).with_name(".env"))
    except ImportError:
        pass
    url = os.environ.get("SUPABASE_URL")
    key = os.environ.get("SUPABASE_SERVICE_KEY")
    if not url or not key:
        print("Missing SUPABASE_URL or SUPABASE_SERVICE_KEY", file=sys.stderr)
        return None
    return url, key


def fetch_people() -> dict[str, str]:
    """match_key(preferred_name) -> live person id. Authoritative for member links."""
    env = load_env()
    if not env:
        raise SystemExit(1)
    from supabase import create_client
    client = create_client(*env)
    rows = client.table("people").select("id,preferred_name").execute().data or []
    return {match_key(r["preferred_name"]): r["id"] for r in rows}


def build(people_by_name: dict[str, str]) -> dict[str, list[dict]]:
    warnings: list[str] = []

    def person(name: str) -> str | None:
        pid = people_by_name.get(match_key(name))
        if not pid:
            warnings.append(f"unknown person: {name}")
        return pid

    # collaboration registry (shared across labs/projects/intcolab)
    collabs: dict[str, dict] = {}
    lab_collaborations: list[dict] = []
    project_collaborations: list[dict] = []
    seen_lc: set[tuple[str, str]] = set()
    seen_pc: set[tuple[str, str]] = set()

    def collab(name: str, kind: str, notes: str | None = None) -> str:
        cid = row_id("collaborations", match_key(name))
        row = collabs.get(cid)
        if row is None:
            collabs[cid] = {"id": cid, "name": clean(name), "kind": kind, "notes": notes}
        else:
            if notes and not row["notes"]:
                row["notes"] = notes
            if kind == "internal":  # internal wins if a name shows up both ways
                row["kind"] = "internal"
        return cid

    # --- clusters
    clusters, cluster_by_name = [], {}
    for r in read_csv(DATA / CLUSTERS_CSV):
        code = clean(r["Código"])
        cid = row_id("clusters", code)
        clusters.append({"id": cid, "code": code, "name": clean(r["Cluster"]),
                         "concern": clean(r["Concern"]) or None,
                         "notes": clean(r["Notas"]) or None,
                         "source": clean(r["Fonte"]) or None})
        cluster_by_name[match_key(r["Cluster"])] = cid

    # --- objectives (+ objective_clusters)
    objectives, objective_by_name, objective_clusters = [], {}, []
    for r in read_csv(DATA / OBJECTIVES_CSV):
        code = clean(r["Código"])
        oid = row_id("objectives", code)
        objectives.append({"id": oid, "code": code, "name": clean(r["Objetivo"]),
                           "description": clean(r["Descrição"]) or None,
                           "kpis": clean(r["KPIs"]) or None, "source": clean(r["Fonte"]) or None})
        objective_by_name[match_key(r["Objetivo"])] = oid
        for cname in link_names(r["Clusters"]):
            cid = cluster_by_name.get(match_key(cname))
            if cid:
                objective_clusters.append({"objective_id": oid, "cluster_id": cid})
            else:
                warnings.append(f"objective {code}: unknown cluster {cname}")

    # --- labs (+ lab_members, lab_objectives, external collaborations)
    labs, lab_by_name, lab_members = [], {}, []
    lab_objective_pairs: set[tuple[str, str]] = set()
    for r in read_csv(DATA / LABS_CSV):
        code = clean(r["Código"])
        lid = row_id("labs", code)
        labs.append({"id": lid, "code": code, "name": clean(r["Lab"]),
                     "overview": clean(r["Overview"]) or None, "notes": clean(r["Notes"]) or None})
        lab_by_name[match_key(r["Lab"])] = lid
        coords = {match_key(n) for n in link_names(r["Coordenadination"])}
        seen = set()
        for name in link_names(r["Coordenadination"]) + link_names(r["Members"]):
            pid = person(name)
            if pid and pid not in seen:
                seen.add(pid)
                lab_members.append({"lab_id": lid, "person_id": pid,
                                    "is_coordinator": match_key(name) in coords})
        for oname in link_names(r["Objetives"]):
            oid = objective_by_name.get(match_key(oname))
            if oid:
                lab_objective_pairs.add((lid, oid))
            else:
                warnings.append(f"lab {code}: unknown objective {oname}")
        for cname in link_names(r["External collaborations"]):
            cid = collab(cname, "external")
            if (lid, cid) not in seen_lc:
                seen_lc.add((lid, cid))
                lab_collaborations.append({"lab_id": lid, "collaboration_id": cid})

    # lab_objectives also declared from the Objectives.Labs side — union both.
    for r in read_csv(DATA / OBJECTIVES_CSV):
        oid = objective_by_name.get(match_key(r["Objetivo"]))
        for lname in link_names(r["Labs"]):
            lid = lab_by_name.get(match_key(lname))
            if oid and lid:
                lab_objective_pairs.add((lid, oid))
    lab_objectives = [{"lab_id": lid, "objective_id": oid} for lid, oid in sorted(lab_objective_pairs)]

    # --- projects (merge onto import.py ids) + members + links
    # ponytail: no approval_status/public_visibility here — omitting them means the
    # idempotent upsert never resets an admin's approval on re-run.
    projects, project_members, project_clusters, project_labs, project_objectives = [], [], [], [], []
    project_by_title: dict[str, str] = {}
    seen_members: set[tuple[str, str]] = set()
    for r in read_csv(DATA / PROJECTS_CSV):
        title = clean(r["Project"])
        if not title:
            continue
        pid = row_id("projects", match_key(title))
        project_by_title[match_key(title)] = pid
        projects.append({
            "id": pid, "title": title,
            "description": clean(r["Abstract"]) or None,
            "status": STATUS.get(clean(r["Estado"]), "active"),
            "start_date": parse_date(r["Data início"]),
            "end_date": parse_date(r["Data fim"]),
            "funding": clean(r["Financiamento"]) or None,
            "category": clean(r["Categoria"]) or None,
            "notes": clean(r["Notas"]) or None,
            "risk": clean(r["Risco"]) or None,
        })
        for col, role in (("PI", "pi"), ("CO-PI", "co_pi"),
                          ("Responsáveis", "responsible"), ("Team", "member")):
            for name in link_names(r.get(col, "")):
                pers = person(name)
                if pers and (pid, pers) not in seen_members:
                    seen_members.add((pid, pers))
                    project_members.append({"project_id": pid, "person_id": pers, "role": role})
        for cname in link_names(r["Clusters"]):
            cid = cluster_by_name.get(match_key(cname))
            if cid:
                project_clusters.append({"project_id": pid, "cluster_id": cid})
        for lname in link_names(r["Labs"]):
            lid = lab_by_name.get(match_key(lname))
            if lid:
                project_labs.append({"project_id": pid, "lab_id": lid})
        for oname in link_names(r["Objetivos"]):
            oid = objective_by_name.get(match_key(oname))
            if oid:
                project_objectives.append({"project_id": pid, "objective_id": oid})
        for col, kind in (("External Collaborations", "external"),
                          ("Internal Collaborations", "internal")):
            for cname in link_names(r.get(col, "")):
                cid = collab(cname, kind)
                if (pid, cid) not in seen_pc:
                    seen_pc.add((pid, cid))
                    project_collaborations.append({"project_id": pid, "collaboration_id": cid})

    # --- internal collaboration entities (their own Notion table)
    for r in read_csv(DATA / INTCOLAB_CSV):
        name = clean(r["Internal Collaboration"])
        if not name:
            continue
        cid = collab(name, "internal", clean(r["Notas"]) or None)
        for lname in link_names(r["Labs"]):
            lid = lab_by_name.get(match_key(lname))
            if lid and (lid, cid) not in seen_lc:
                seen_lc.add((lid, cid))
                lab_collaborations.append({"lab_id": lid, "collaboration_id": cid})
        for pname in link_names(r["Projects"]):
            pid = project_by_title.get(match_key(pname))
            if pid and (pid, cid) not in seen_pc:
                seen_pc.add((pid, cid))
                project_collaborations.append({"project_id": pid, "collaboration_id": cid})

    for w in warnings:
        print(f"WARN: {w}", file=sys.stderr)

    return {
        "clusters": clusters, "labs": labs, "objectives": objectives,
        "lab_members": lab_members, "objective_clusters": objective_clusters,
        "lab_objectives": lab_objectives, "projects": projects,
        "project_members": project_members, "project_clusters": project_clusters,
        "project_labs": project_labs, "project_objectives": project_objectives,
        "collaborations": list(collabs.values()),
        "lab_collaborations": lab_collaborations,
        "project_collaborations": project_collaborations,
    }


def self_check(t: dict[str, list[dict]]) -> None:
    assert len(t["clusters"]) == 5, len(t["clusters"])
    assert len(t["labs"]) == 5, len(t["labs"])
    assert len(t["objectives"]) == 12, len(t["objectives"])
    assert len(t["projects"]) == 33, len(t["projects"])
    ids = {
        name: {r["id"] for r in t[name]}
        for name in ("clusters", "labs", "objectives", "projects", "collaborations")
    }
    checks = [
        ("lab_members", "lab_id", "labs"), ("lab_objectives", "lab_id", "labs"),
        ("lab_objectives", "objective_id", "objectives"),
        ("objective_clusters", "objective_id", "objectives"),
        ("objective_clusters", "cluster_id", "clusters"),
        ("project_clusters", "project_id", "projects"), ("project_clusters", "cluster_id", "clusters"),
        ("project_labs", "project_id", "projects"), ("project_labs", "lab_id", "labs"),
        ("project_objectives", "project_id", "projects"), ("project_objectives", "objective_id", "objectives"),
        ("project_members", "project_id", "projects"),
        ("lab_collaborations", "lab_id", "labs"),
        ("lab_collaborations", "collaboration_id", "collaborations"),
        ("project_collaborations", "project_id", "projects"),
        ("project_collaborations", "collaboration_id", "collaborations"),
    ]
    for table, fk, parent in checks:
        for row in t[table]:
            assert row[fk] in ids[parent], (table, fk, row[fk])
    assert all(m["person_id"] for m in t["lab_members"] + t["project_members"])
    assert any(m["is_coordinator"] for m in t["lab_members"]), "no coordinators"
    assert all(c["kind"] in ("external", "internal") for c in t["collaborations"])
    print("SELF-CHECK: PASS")


def write_json(tables: dict[str, list[dict]]) -> None:
    out = Path(__file__).with_name("out_part02")
    out.mkdir(parents=True, exist_ok=True)
    for name, rows in tables.items():
        (out / f"{name}.json").write_text(json.dumps(rows, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def load(t: dict[str, list[dict]]) -> None:
    env = load_env()
    if not env:
        raise SystemExit(1)
    from supabase import create_client
    client = create_client(*env)
    # Entities first (parents), then projects (merge), then join tables.
    client.table("clusters").upsert(t["clusters"], on_conflict="id").execute()
    client.table("labs").upsert(t["labs"], on_conflict="id").execute()
    client.table("objectives").upsert(t["objectives"], on_conflict="id").execute()
    client.table("projects").upsert(t["projects"], on_conflict="id").execute()
    client.table("collaborations").upsert(t["collaborations"], on_conflict="id").execute()
    for name, conflict in [
        ("lab_members", "lab_id,person_id"),
        ("objective_clusters", "objective_id,cluster_id"),
        ("lab_objectives", "lab_id,objective_id"),
        ("project_clusters", "project_id,cluster_id"),
        ("project_labs", "project_id,lab_id"),
        ("project_objectives", "project_id,objective_id"),
        ("project_members", "project_id,person_id"),
        ("lab_collaborations", "lab_id,collaboration_id"),
        ("project_collaborations", "project_id,collaboration_id"),
    ]:
        if t[name]:
            client.table(name).upsert(t[name], on_conflict=conflict).execute()
    print("LOAD: PASS")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--load", action="store_true")
    args = parser.parse_args()
    people = fetch_people() if args.load else load_people_offline()
    tables = build(people)
    self_check(tables)
    write_json(tables)
    print("DRY-RUN COUNTS: " + " ".join(f"{k}={len(v)}" for k, v in tables.items()))
    if args.load:
        load(tables)


def load_people_offline() -> dict[str, str]:
    """Dry run without DB creds: use import.py's out/people.json if present, else DB."""
    path = Path(__file__).with_name("out") / "people.json"
    if path.exists():
        return {match_key(p["preferred_name"]): p["id"] for p in json.loads(path.read_text())}
    return fetch_people()


if __name__ == "__main__":
    main()
