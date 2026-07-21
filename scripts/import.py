"""Import UNIDCOM Research Directory CSV exports."""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import os
import re
import sys
import unicodedata
import uuid
from pathlib import Path


DEFAULT_INPUT = Path("/Users/berloga/Documents/GitHub/IADEUNIDCOM/RAW_DATA/exportsfromnotoin")
PEOPLE_CSV = "UNIDCOM Researchers 082bff569c094748a845cf95464d85ab_all.csv"
OUTPUTS_CSV = "UNIDCOM Outputs e671e4a09c784dafb4cd1808e49fcb83_all.csv"
NS = uuid.UUID("3fc3e2b1-18c9-4834-b0b7-bcbb24ff419b")


def clean(value: str | None) -> str:
    return " ".join((value or "").strip().split())


def match_key(value: str | None) -> str:
    text = unicodedata.normalize("NFKD", clean(value).lower())
    return "".join(c for c in text if not unicodedata.combining(c))


def email_key(value: str | None) -> str:
    return clean(value).lower()


def email_hash(value: str) -> str:
    return hashlib.sha256(value.encode()).hexdigest()


def row_id(prefix: str, key: str) -> str:
    return str(uuid.uuid5(NS, f"{prefix}:{key}"))


def read_csv(path: Path) -> list[dict[str, str]]:
    with path.open(encoding="utf-8-sig", newline="") as f:
        return list(csv.DictReader(f))


class UnionFind:
    def __init__(self) -> None:
        self.parent: dict[str, str] = {}

    def find(self, item: str) -> str:
        self.parent.setdefault(item, item)
        if self.parent[item] != item:
            self.parent[item] = self.find(self.parent[item])
        return self.parent[item]

    def union(self, a: str, b: str) -> None:
        self.parent[self.find(b)] = self.find(a)


def membership_type(value: str) -> str | None:
    if "Integrado" in value:
        return "integrated"
    if "Investigador Colaborador" in value:
        return "collaborator"
    if "Externo" in value:
        return "external"
    if "Advisory Board" in value:
        return "advisory_board"
    if any(part in value for part in ("Gestão de Ciência", "Direção Executiva", "Coordenação")):
        return "staff"
    return None


def status(value: str) -> str:
    return {"Ativo": "active", "Inativo": "inactive"}.get(clean(value), "a_confirmar")


def parse_year(value: str) -> int | None:
    try:
        return int(clean(value))
    except ValueError:
        return None


def normalize_doi(value: str | None) -> str | None:
    m = re.search(r"10\.\d{4,9}/[^\s\"<>]+", value or "", re.I)
    return m.group(0).rstrip(").,;").lower() if m else None


def non_doi_url(value: str | None) -> str | None:
    value = clean(value)
    return value if value and value.startswith(("http://", "https://")) and not normalize_doi(value) else None


def author_names(value: str) -> list[str]:
    value = re.sub(r"\s*\(https?://[^)]*\)", "", value or "")
    return [clean(name) for name in value.split(", ") if clean(name)]


def build_people(rows: list[dict[str, str]]) -> tuple[list[dict], dict[str, str]]:
    uf = UnionFind()
    row_nodes: list[str] = []
    for i, row in enumerate(rows):
        node = f"row:{i}"
        row_nodes.append(node)
        name = match_key(row["Pessoa"])
        email = email_key(row["Email"])
        if name:
            uf.union(node, f"name:{name}")
        if email:
            uf.union(node, f"email:{email}")

    for name in ("Emília Duarte", "Ana Marques", "Diamantino Abreu", "Dilay Kocogullari", "Vasco Milne"):
        uf.union(f"known:{match_key(name)}", f"name:{match_key(name)}")
    for row in rows:
        email = email_key(row["Email"])
        if email_hash(email) in {
            "3359e96204494021a42d55ee013b916aa9c7e08fabdf52c52d85fe95a6ee43d1",
            "33cf131fd36d6856341fc357d9abdda121c2faa18a9617465316e6d9601f6258",
            "d79c0ae5589ca68f20c1f10fe4f0c7a999d13873ecf02292d8fc477cf430879b",
            "f9209e658f77bcb738c3e28155eb8461c2e8342b6f4af759dfad74c3cb188e19",
        }:
            uf.union(f"known:{email_hash(email)}", f"email:{email}")

    groups: dict[str, list[dict[str, str]]] = {}
    for node, row in zip(row_nodes, rows):
        groups.setdefault(uf.find(node), []).append(row)

    people: list[dict] = []
    person_by_name: dict[str, str] = {}
    for group in groups.values():
        names = [clean(r["Pessoa"]) for r in group if clean(r["Pessoa"])]
        emails = [email_key(r["Email"]) for r in group if email_key(r["Email"])]
        preferred = max(names, key=lambda n: (len(n), n))
        key = emails[0] if emails else match_key(preferred)
        person = {
            "id": row_id("people", key),
            "preferred_name": preferred,
            "legal_name": None,
            "bio": None,
            "photo_url": None,
            "membership_type": next((membership_type(r["Papel"]) for r in group if membership_type(r["Papel"])), None),
            "status": next((status(r["Estado"]) for r in group if clean(r["Estado"])), "a_confirmar"),
            "email": emails[0] if emails else None,
            "orcid": None,
            "ciencia_id": None,
            "profile_status": "draft",
            "public_visibility": False,
        }
        people.append(person)
        for name in names:
            person_by_name[match_key(name)] = person["id"]
    people.sort(key=lambda p: p["preferred_name"])
    return people, person_by_name


def ensure_person(name: str, people: list[dict], person_by_name: dict[str, str]) -> str:
    key = match_key(name)
    if key not in person_by_name:
        person_by_name[key] = row_id("people", key)
        people.append(
            {
                "id": person_by_name[key],
                "preferred_name": name,
                "legal_name": None,
                "bio": None,
                "photo_url": None,
                "membership_type": None,
                "status": "a_confirmar",
                "email": None,
                "orcid": None,
                "ciencia_id": None,
                "profile_status": "draft",
                "public_visibility": False,
            }
        )
    return person_by_name[key]


def build_outputs(rows: list[dict[str, str]], people: list[dict], person_by_name: dict[str, str]) -> tuple[list[dict], list[dict]]:
    outputs_by_key: dict[str, dict] = {}
    authors_by_output: dict[str, list[dict]] = {}
    seen_author_links: set[tuple[str, str]] = set()

    for row in rows:
        doi = normalize_doi(row["URL/DOI"])
        key = f"doi:{doi}" if doi else f"title:{match_key(row['Produção'])}"
        if key not in outputs_by_key:
            output_id = row_id("outputs", key)
            outputs_by_key[key] = {
                "id": output_id,
                "title": clean(row["Produção"]),
                "reporting_year": parse_year(row["Ano"]),
                "type": clean(row["Tipo"]) or None,
                "subtype": clean(row["Subtipo"]) or None,
                "category_path": clean(row["Categoria (caminho)"]) or None,
                "doi": doi,
                "url": non_doi_url(row["URL/DOI"]),
                "approval_status": "pending",
            }
            authors_by_output[output_id] = []
        output_id = outputs_by_key[key]["id"]
        for name in author_names(row["Investigador"]):
            person_id = ensure_person(name, people, person_by_name)
            link_key = (output_id, person_id)
            if link_key in seen_author_links:
                continue
            seen_author_links.add(link_key)
            authors_by_output[output_id].append(
                {
                    "output_id": output_id,
                    "person_id": person_id,
                    "role": clean(row["Papel"]) or None,
                    "author_position": len(authors_by_output[output_id]) + 1,
                    "raw_name": name,
                }
            )

    outputs = sorted(outputs_by_key.values(), key=lambda o: (o["reporting_year"] or 0, o["title"]))
    authors = [a for output_id in sorted(authors_by_output) for a in authors_by_output[output_id]]
    people.sort(key=lambda p: p["preferred_name"])
    return outputs, authors


def self_check(people: list[dict], outputs: list[dict], authors: list[dict]) -> None:
    assert 180 <= len(people) <= 186, len(people)
    assert 355 <= len(outputs) <= 371, len(outputs)
    people_by_id = {p["id"]: p for p in people}
    for doi, wanted in {
        "10.1007/978-3-031-93861-0_20": {"Hande Ayanoglu", "Joaquim Casaca"},
        "10.1109/access.2025.3560547": {"Miguel Boavida", "João Dias"},
    }.items():
        matches = [o for o in outputs if o["doi"] == doi]
        assert len(matches) == 1, (doi, len(matches))
        names = {people_by_id[a["person_id"]]["preferred_name"] for a in authors if a["output_id"] == matches[0]["id"]}
        assert len(names) >= 2 and wanted <= names, (doi, names)
    print("SELF-CHECK: PASS")


def write_json(out_dir: Path, people: list[dict], outputs: list[dict], authors: list[dict]) -> None:
    out_dir.mkdir(parents=True, exist_ok=True)
    for name, rows in (("people", people), ("outputs", outputs), ("output_authors", authors)):
        (out_dir / f"{name}.json").write_text(json.dumps(rows, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def load_env() -> tuple[str, str] | None:
    try:
        from dotenv import load_dotenv
    except ImportError:
        load_dotenv = None
    if load_dotenv:
        load_dotenv(Path(__file__).with_name(".env"))
    url = os.environ.get("SUPABASE_URL")
    key = os.environ.get("SUPABASE_SERVICE_KEY")
    if not url or not key:
        print("Missing SUPABASE_URL or SUPABASE_SERVICE_KEY in env or scripts/.env", file=sys.stderr)
        return None
    return url, key


def update_or_insert(table, row: dict, existing_id: str | None = None) -> str:
    if existing_id:
        table.update(row).eq("id", existing_id).execute()
        return existing_id
    table.insert(row).execute()
    return row["id"]


def load_supabase(people: list[dict], outputs: list[dict], authors: list[dict]) -> None:
    env = load_env()
    if not env:
        raise SystemExit(1)
    from supabase import create_client

    client = create_client(*env)
    existing_people = client.table("people").select("id,email").execute().data or []
    people_by_email = {p["email"]: p["id"] for p in existing_people if p.get("email")}
    people_by_id = {p["id"]: p["id"] for p in existing_people}
    person_ids = {}
    for person in people:
        existing_id = people_by_email.get(person["email"]) or people_by_id.get(person["id"])
        person_ids[person["id"]] = update_or_insert(client.table("people"), {**person, "id": existing_id or person["id"]}, existing_id)

    existing_outputs = client.table("outputs").select("id,doi").execute().data or []
    outputs_by_doi = {o["doi"]: o["id"] for o in existing_outputs if o.get("doi")}
    outputs_by_id = {o["id"]: o["id"] for o in existing_outputs}
    output_ids = {}
    for output in outputs:
        existing_id = outputs_by_doi.get(output["doi"]) or outputs_by_id.get(output["id"])
        output_ids[output["id"]] = update_or_insert(client.table("outputs"), {**output, "id": existing_id or output["id"]}, existing_id)

    rows = [{k: v for k, v in a.items() if k != "raw_name"} for a in authors]
    rows = [{**a, "output_id": output_ids[a["output_id"]], "person_id": person_ids[a["person_id"]]} for a in rows]
    client.table("output_authors").upsert(rows, on_conflict="output_id,person_id").execute()


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path, default=DEFAULT_INPUT)
    parser.add_argument("--load", action="store_true")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    people_rows = read_csv(args.input / PEOPLE_CSV)
    output_rows = read_csv(args.input / OUTPUTS_CSV)
    people, person_by_name = build_people(people_rows)
    outputs, authors = build_outputs(output_rows, people, person_by_name)
    self_check(people, outputs, authors)
    write_json(Path(__file__).with_name("out"), people, outputs, authors)
    print(f"DRY-RUN COUNTS: people={len(people)} outputs={len(outputs)} author_links={len(authors)}")
    if args.load:
        load_supabase(people, outputs, authors)
        print("LOAD: PASS")


if __name__ == "__main__":
    main()
