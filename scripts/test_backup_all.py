"""Offline checks: uv run --project scripts python -m unittest discover -s scripts -p test_backup_all.py."""
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import httpx

import backup_all as backup


class BackupTests(unittest.TestCase):
    def test_discovery_ignores_rpc_but_includes_views(self):
        schema = {"paths": {"/": {"get": {}}, "/new_table": {"get": {}},
                            "/a_view": {"get": {}}, "/rpc/danger": {"get": {}},
                            "/write_only": {"post": {}}}}
        self.assertEqual(backup.table_names(schema), ["a_view", "new_table"])

    def test_range_pagination_continues_after_server_cap(self):
        ranges = []

        def handle(request):
            start = int(request.headers["Range"].split("-")[0])
            ranges.append(start)
            return httpx.Response(200, json=[{"id": start}],
                                  headers={"Content-Range": f"{start}-{start}/3"})

        schema = {"definitions": {"new": {"properties": {"id": {"description": "<pk/>"}}}}}
        with httpx.Client(base_url="https://example.test", transport=httpx.MockTransport(handle)) as client:
            self.assertEqual(len(backup.table_rows(client, "new", schema)), 3)
        self.assertEqual(ranges, [0, 1, 2])

    def test_changed_table_count_fails(self):
        def handle(request):
            start = int(request.headers["Range"].split("-")[0])
            return httpx.Response(200, json=[{"id": start}],
                                  headers={"Content-Range": f"{start}-{start}/{3 + start}"})

        with httpx.Client(base_url="https://example.test", transport=httpx.MockTransport(handle)) as client:
            with self.assertRaises(backup.BackupError):
                backup.table_rows(client, "new", {})

    def test_storage_nested_paths_and_capped_pages(self):
        def handle(request):
            body = json.loads(request.content)
            if body["offset"]:
                return httpx.Response(200, json=[])
            if body["prefix"] == "":
                return httpx.Response(200, json=[{"name": "folder", "id": None, "metadata": None}])
            return httpx.Response(200, json=[{"name": "image.png", "id": "1", "metadata": {"size": 10}}])

        with httpx.Client(base_url="https://example.test", transport=httpx.MockTransport(handle)) as client:
            objects = backup.storage_objects(client, "images")
        self.assertEqual([obj["path"] for obj in objects], ["folder/image.png"])

    def test_sanity_stream_error_is_not_a_document(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "data.ndjson"
            path.write_text('{"_id":"one","_type":"page"}\n{"error":{"description":"failed"}}\n')
            with self.assertRaises(backup.BackupError):
                backup.ndjson_count(path)

    def test_auth_paging_continues_after_server_cap(self):
        def handle(request):
            page = int(request.url.params["page"])
            return httpx.Response(200, json={"users": [{"id": str(page)}] if page < 3 else []})

        with httpx.Client(base_url="https://example.test", transport=httpx.MockTransport(handle)) as client:
            self.assertEqual(len(backup.auth_users(client)), 2)

    def test_oversized_download_is_removed(self):
        def handle(request):
            return httpx.Response(200, content=b"too large")

        with tempfile.TemporaryDirectory() as directory:
            out = Path(directory)
            objects = [{"path": "../../outside", "metadata": {"size": 1}}]
            with httpx.Client(base_url="https://example.test", transport=httpx.MockTransport(handle)) as client:
                with patch.object(backup, "SMALL_OBJECT", 2):
                    with self.assertRaises(backup.BackupError):
                        backup.download_images(client, out, "site-images", objects)
            self.assertEqual([p for p in out.rglob("*") if p.is_file()], [])

    def test_destination_refuses_repository_and_symlink(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            with patch.object(Path, "home", return_value=home):
                (home / ".git").mkdir()
                with self.assertRaises(backup.BackupError):
                    backup.destination()
                (home / ".git").rmdir()
                (home / "Backups").rmdir()
                (home / "Backups").symlink_to(backup.REPO, target_is_directory=True)
                with self.assertRaises(backup.BackupError):
                    backup.destination()

    def test_errors_do_not_expose_response_or_credentials(self):
        def handle(request):
            return httpx.Response(403, text="secret-token private-email")

        with httpx.Client(base_url="https://example.test", transport=httpx.MockTransport(handle)) as client:
            with self.assertRaisesRegex(backup.BackupError, "^HTTP 403$"):
                backup.request(client, "GET", "/")


if __name__ == "__main__":
    unittest.main()
