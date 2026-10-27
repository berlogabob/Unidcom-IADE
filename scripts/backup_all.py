"""Read-only API backup. Run: uv run --project scripts scripts/backup_all.py.

Private output is always ~/Backups/unidcom/<UTC timestamp>/, never a worktree.
OpenAPI is a schema description, not a pg_dump or a tested restore procedure.
"""
from __future__ import annotations

import hashlib
import importlib
import json
import os
import shutil
import subprocess
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import quote

import httpx

REPO = Path(__file__).resolve().parent.parent
PAGE = 1000
SMALL_OBJECT = 5 * 1024 * 1024
DOWNLOAD_BUDGET = 50 * 1024 * 1024


class BackupError(Exception):
    pass


def request(client, method, url, **kwargs):
    # Never include response bodies, URLs, headers or exception text in errors.
    try:
        response = client.request(method, url, **kwargs)
    except httpx.HTTPError as exc:
        raise BackupError(f"network error ({type(exc).__name__})") from None
    if not response.is_success:
        raise BackupError(f"HTTP {response.status_code}")
    return response


def write_json(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def destination():
    os.umask(0o077)
    root = Path.home() / "Backups"
    # Reject symlink redirection and any enclosing Git repository before writing.
    if root.is_symlink() or root.resolve().is_relative_to(REPO):
        raise BackupError("unsafe backup root")
    root.mkdir(mode=0o700, exist_ok=True)
    for parent in (root, *root.parents):
        if (parent / ".git").exists():
            raise BackupError("backup root is inside a Git working tree")
    probe = subprocess.run(["git", "-C", str(root), "rev-parse", "--show-toplevel"],
                           capture_output=True, check=False)
    if probe.returncode == 0:
        raise BackupError("backup root is inside a Git working tree")
    # Also prevents accidental addition if an ancestor becomes a repository later.
    ignore = root / ".gitignore"
    if ignore.is_symlink():
        raise BackupError("unsafe backup ignore file")
    if not ignore.exists() or "*" not in ignore.read_text().splitlines():
        with ignore.open("a", encoding="utf-8") as stream:
            stream.write("\n# Private backups: never add to Git.\n*\n")
    project = root / "unidcom"
    if project.is_symlink() or (project / ".git").exists():
        raise BackupError("unsafe backup project directory")
    project.mkdir(mode=0o700, exist_ok=True)
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S.%fZ")
    out = project / stamp
    out.mkdir(mode=0o700)
    return out


def table_names(schema):
    names = sorted(path[1:] for path, verbs in schema["paths"].items()
                   if path.startswith("/") and path != "/" and "/" not in path[1:]
                   and "get" in verbs)
    if not names:
        raise BackupError("OpenAPI contains no readable public tables")
    return names


def exact_count(response):
    total = response.headers.get("content-range", "").rsplit("/", 1)[-1]
    if not total.isdigit():
        raise BackupError("missing exact Content-Range count")
    return int(total)


def table_rows(client, name, schema):
    properties = schema.get("definitions", {}).get(name, {}).get("properties", {})
    keys = [key for key, prop in properties.items()
            if "<pk/>" in prop.get("description", "")]
    # Stable ordering for pagination; include all columns when no PK is exposed.
    columns = keys or list(properties)
    params = {"select": "*"}
    if columns:
        params["order"] = ",".join('"' + c.replace('"', '\\"') + '".asc' for c in columns)
    rows = []
    expected = None
    while True:
        response = request(client, "GET", "/rest/v1/" + quote(name, safe=""), params=params,
                           headers={"Range-Unit": "items", "Range": f"{len(rows)}-{len(rows) + PAGE - 1}",
                                    "Prefer": "count=exact", "Accept-Profile": "public"})
        total = exact_count(response)
        if expected is not None and expected != total:
            raise BackupError("table changed during pagination; rerun backup")
        expected = total
        page = response.json()
        if not isinstance(page, list) or (not page and len(rows) < total):
            raise BackupError("invalid or prematurely empty table page")
        rows.extend(page)
        if len(rows) >= total:
            if len(rows) != total:
                raise BackupError("table count mismatch")
            return rows


def auth_users(client):
    users = []
    page = 1
    while True:
        payload = request(client, "GET", "/auth/v1/admin/users",
                          params={"page": page, "per_page": PAGE}).json()
        batch = payload["users"]
        users.extend(batch)
        # Continue to empty page even when the server caps per_page below PAGE.
        if not batch:
            if len({user["id"] for user in users}) != len(users):
                raise BackupError("duplicate auth users across pages")
            return users
        page += 1


def storage_objects(client, bucket):
    objects = []
    folders = [""]
    visited = set()
    while folders:
        prefix = folders.pop()
        if prefix in visited:
            raise BackupError("duplicate storage folder")
        visited.add(prefix)
        offset = 0
        while True:
            # Supabase's list operation uses POST, but does not mutate storage.
            batch = request(client, "POST", "/storage/v1/object/list/" + quote(bucket, safe=""),
                            json={"prefix": prefix, "limit": PAGE, "offset": offset,
                                  "sortBy": {"column": "name", "order": "asc"}}).json()
            if not isinstance(batch, list):
                raise BackupError("invalid storage listing")
            if not batch:
                break
            for entry in batch:
                path = prefix + entry["name"]
                if entry.get("id") is None and entry.get("metadata") is None:
                    folders.append(path + "/")
                else:
                    objects.append({**entry, "path": path})
            offset += len(batch)
    if len({obj["path"] for obj in objects}) != len(objects):
        raise BackupError("duplicate storage objects across pages")
    return objects


def download_images(client, out, bucket, objects):
    budget = DOWNLOAD_BUDGET
    for obj in objects:
        obj["download"] = "not site-images"
        if bucket != "site-images":
            continue
        size = (obj.get("metadata") or {}).get("size")
        if not isinstance(size, int) or size < 0 or size > SMALL_OBJECT or size > budget:
            obj["download"] = "skipped: unknown size, over 5 MiB, or 50 MiB budget exhausted"
            continue
        # Hashed local names prevent object paths escaping the backup directory.
        relative = "storage/site-images/" + hashlib.sha256(obj["path"].encode()).hexdigest()
        target = out / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        url = "/storage/v1/object/" + quote(bucket, safe="") + "/" + quote(obj["path"], safe="/")
        try:
            with client.stream("GET", url) as response:
                if not response.is_success:
                    raise BackupError(f"HTTP {response.status_code}")
                written = 0
                with target.open("wb") as stream:
                    for chunk in response.iter_bytes():
                        written += len(chunk)
                        if written > min(SMALL_OBJECT, budget):
                            raise BackupError("object exceeded download size limit")
                        stream.write(chunk)
                if written != size:
                    raise BackupError("object size changed during download")
            budget -= written
            obj["download"] = relative
        except (httpx.HTTPError, BackupError):
            target.unlink(missing_ok=True)
            raise BackupError("site-images download failed") from None


def ndjson_count(path):
    count = 0
    ids = set()
    with path.open(encoding="utf-8") as stream:
        for line in stream:
            if not line.strip():
                continue
            doc = json.loads(line)
            if not isinstance(doc, dict) or "_id" not in doc or "_type" not in doc:
                raise BackupError("invalid document or error in Sanity export stream")
            if doc["_id"] in ids:
                raise BackupError("duplicate Sanity document")
            ids.add(doc["_id"])
            count += 1
    return count


def sanity_count(client):
    value = request(client, "GET", "/v2025-02-19/data/query/production",
                    params={"query": "count(*)", "perspective": "raw"}).json()["result"]
    if not isinstance(value, int) or value < 0:
        raise BackupError("invalid Sanity document count")
    return value


def export_sanity(client, path):
    expected = sanity_count(client)  # Detect private datasets before a misleading empty 200 export.
    partial = path.with_suffix(".ndjson.partial")
    try:
        with client.stream("GET", "/v2025-02-19/data/export/production") as response:
            if not response.is_success:
                raise BackupError(f"HTTP {response.status_code}")
            with partial.open("wb") as stream:
                for chunk in response.iter_bytes():
                    stream.write(chunk)
        count = ndjson_count(partial)
        if count != expected:
            raise BackupError("Sanity export count differs from initial API count")
        partial.rename(path)
        return count
    except httpx.HTTPError as exc:
        raise BackupError(f"network error ({type(exc).__name__})") from None


def main():
    env = importlib.import_module("import").load_env()
    if not env:
        return 1
    try:
        out = destination()
    except BackupError as exc:
        print(f"Backup refused: {exc}")
        return 1
    print(f"Backup: {out}", flush=True)
    manifest = {"timestamp": datetime.now(timezone.utc).isoformat(), "tables": {}, "sanity": {},
                "auth": {}, "storage": {}, "errors": [], "files": {},
                "limits": {"object_bytes": SMALL_OBJECT, "download_bytes": DOWNLOAD_BUDGET,
                           "schema": "PostgREST OpenAPI and local migrations; not a SQL dump",
                           "consistency": "API reads are not a cross-table transactional snapshot"}}

    def error(label, exc):
        # Unexpected exceptions may contain data or credentials; log only their type.
        detail = str(exc) if isinstance(exc, BackupError) else type(exc).__name__
        manifest["errors"].append({"source": label, "error": detail})
        print(f"FAILED {label}: {detail}", flush=True)

    url, key = env
    with httpx.Client(base_url=url.rstrip("/"), headers={"apikey": key, "Authorization": f"Bearer {key}"},
                      timeout=120) as client:
        try:
            schema = request(client, "GET", "/rest/v1/", headers={"Accept": "application/openapi+json",
                                                                       "Accept-Profile": "public"}).json()
            write_json(out / "supabase-openapi.json", schema)
            names = table_names(schema)
        except Exception as exc:
            error("table discovery", exc)
            names = []
        for name in names:
            entry = manifest["tables"][name] = {"status": "failed"}
            try:
                rows = table_rows(client, name, schema)
                filename = "public/" + quote(name, safe="") + ".json"
                (out / "public").mkdir(exist_ok=True)
                write_json(out / filename, rows)
                entry.update(status="exported", file=filename, row_count=len(rows))
                print(f"Exported table {name}: {len(rows)}", flush=True)
            except Exception as exc:
                error(f"table {name}", exc)
        try:
            users = auth_users(client)
            write_json(out / "auth-users.json", users)
            manifest["auth"] = {"status": "exported", "row_count": len(users)}
        except Exception as exc:
            error("auth users", exc)
        try:
            buckets = request(client, "GET", "/storage/v1/bucket").json()
            write_json(out / "storage-buckets.json", buckets)
            for bucket in buckets:
                name = bucket["id"]
                entry = manifest["storage"][name] = {"status": "failed", "name": bucket["name"]}
                try:
                    objects = storage_objects(client, name)
                    filename = "storage-" + quote(name, safe="") + ".json"
                    write_json(out / filename, objects)
                    download_images(client, out, name, objects)
                    write_json(out / filename, objects)
                    entry.update(status="exported", file=filename, object_count=len(objects),
                                 downloaded=sum(obj["download"].startswith("storage/") for obj in objects))
                except Exception as exc:
                    error(f"storage {name}", exc)
        except Exception as exc:
            error("storage buckets", exc)
        try:
            migrations = REPO / "supabase/migrations"
            shutil.copytree(migrations, out / "migrations")
            # copytree preserves source permissions; keep every backup file private.
            for path in (out / "migrations", *(out / "migrations").rglob("*")):
                path.chmod(0o700 if path.is_dir() else 0o600)
            write_json(out / "migrations-list.json", sorted(p.name for p in migrations.iterdir() if p.is_file()))
        except Exception as exc:
            error("migrations", exc)

        # Verify files independently after all Supabase exports have completed.
        for name, entry in manifest["tables"].items():
            if entry["status"] != "exported":
                continue
            try:
                file_count = len(json.loads((out / entry["file"]).read_text()))
                api_count = exact_count(request(client, "HEAD", "/rest/v1/" + quote(name, safe=""),
                                                headers={"Prefer": "count=exact", "Range": "0-0",
                                                         "Accept-Profile": "public"}))
                entry.update(file_count=file_count, api_count=api_count)
                if file_count != api_count or file_count != entry["row_count"]:
                    raise BackupError("file/API row count mismatch; data may have changed")
                entry["status"] = "verified"
            except Exception as exc:
                entry["status"] = "failed"
                error(f"verify table {name}", exc)
        try:
            file_users = json.loads((out / "auth-users.json").read_text())
            api_users = auth_users(client)
            manifest["auth"].update(file_count=len(file_users), api_count=len(api_users))
            if {u["id"] for u in file_users} != {u["id"] for u in api_users}:
                raise BackupError("auth user IDs differ from API")
            manifest["auth"]["status"] = "verified"
        except Exception as exc:
            manifest["auth"]["status"] = "failed"
            error("verify auth users", exc)
        try:
            current = request(client, "GET", "/storage/v1/bucket").json()
            saved = json.loads((out / "storage-buckets.json").read_text())
            if {b["id"] for b in current} != {b["id"] for b in saved}:
                raise BackupError("storage bucket IDs differ from API")
        except Exception as exc:
            error("verify storage buckets", exc)
        for name, entry in manifest["storage"].items():
            if entry["status"] != "exported":
                continue
            try:
                saved = json.loads((out / entry["file"]).read_text())
                current = storage_objects(client, name)
                entry.update(file_count=len(saved), api_count=len(current))
                if {o["path"] for o in saved} != {o["path"] for o in current}:
                    raise BackupError("storage object paths differ from API")
                entry["status"] = "verified"
            except Exception as exc:
                entry["status"] = "failed"
                error(f"verify storage {name}", exc)

    token = os.environ.get("SANITY_TOKEN")
    for project in ("vj0axykv", "ld5jhf23"):
        entry = manifest["sanity"][project] = {"dataset": "production", "status": "failed"}
        if project == "ld5jhf23" and not token:
            entry.update(status="skipped", reason="SANITY_TOKEN absent")
            print(f"SKIPPED Sanity {project}: SANITY_TOKEN absent", flush=True)
            continue
        # Prefer authenticated export when available to include drafts/private docs.
        modes = [token, None] if token and project == "vj0axykv" else [token]
        for index, credential in enumerate(modes):
            try:
                headers = {"Authorization": f"Bearer {credential}"} if credential else {}
                with httpx.Client(base_url=f"https://{project}.api.sanity.io", headers=headers, timeout=180) as client:
                    path = out / f"sanity-{project}.ndjson"
                    count = export_sanity(client, path)
                    file_count = ndjson_count(path)
                    api_count = sanity_count(client)
                    entry.update(doc_count=count, file_count=file_count, api_count=api_count,
                                 access="authenticated" if credential else "anonymous public documents only")
                    if count != file_count or count != api_count:
                        raise BackupError("Sanity file/API count mismatch; data may have changed")
                    entry["status"] = "verified"
                    break
            except Exception as exc:
                if index + 1 < len(modes) and isinstance(exc, BackupError) and str(exc) in ("HTTP 401", "HTTP 403"):
                    print(f"Sanity {project}: token lacks access; trying anonymous public export", flush=True)
                    continue
                error(f"Sanity {project}", exc)
                break

    for path in sorted(out.rglob("*")):
        if path.is_file():
            digest = hashlib.sha256()
            with path.open("rb") as stream:
                for chunk in iter(lambda: stream.read(1024 * 1024), b""):
                    digest.update(chunk)
            manifest["files"][str(path.relative_to(out))] = {"sha256": digest.hexdigest(), "bytes": path.stat().st_size}
    manifest["completed_at"] = datetime.now(timezone.utc).isoformat()
    manifest["status"] = "failed" if manifest["errors"] else "verified"
    # manifest cannot contain its own hash; every other file (even partials) is hashed.
    write_json(out / "manifest.json", manifest)
    print(f"\n{'Source':48} {'File':>8} {'API':>8}  Status")
    groups = [("public.", manifest["tables"]), ("Sanity ", manifest["sanity"]),
              ("Storage ", manifest["storage"]), ("", {"Auth users": manifest["auth"]})]
    for prefix, entries in groups:
        for name, entry in entries.items():
            print(f"{prefix + name:48} {str(entry.get('file_count', '-')):>8} "
                  f"{str(entry.get('api_count', '-')):>8}  {entry.get('status', 'failed')}")
    print(f"Manifest: {out / 'manifest.json'}")
    print(f"Result: {manifest['status']}; {len(manifest['errors'])} error(s)")
    return int(bool(manifest["errors"]))


if __name__ == "__main__":
    raise SystemExit(main())
