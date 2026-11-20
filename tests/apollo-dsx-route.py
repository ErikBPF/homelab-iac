#!/usr/bin/env python3
"""Exercise listing and revoke boundaries without credentials, HTTP, or live mutation."""
import contextlib
import importlib.util
import io
import json
from pathlib import Path
import re
import sys
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("route", Path(__file__).resolve().parents[1] / "scripts/apollo-dsx-route.py")
route = importlib.util.module_from_spec(spec)
spec.loader.exec_module(route)

HASHES = ["a" * 64, "b" * 64]


def page_request(pages, state=None, writes=None):
    """Fake gateway: paginated /key/list, /key/info reads, /key/update writes."""
    def request(path, payload=None):
        if path.startswith("/key/list"):
            page = int(re.search(r"page=(\d+)", path).group(1))
            return {"keys": pages[page - 1], "current_page": page,
                    "total_pages": len(pages),
                    "total_count": sum(len(p) for p in pages)}
        if path.startswith("/key/info"):
            key = path.split("key=")[1]
            return {"info": {"key_alias": key, "models": list(state[key])}}
        writes.append(payload)
        state[payload["key"]] = list(payload["models"])
        return {}
    return request


class KeyListing(unittest.TestCase):
    def test_listing_walks_every_page(self):
        state = {h: ["other"] for h in HASHES}
        seen = []

        def request(path, payload=None):
            if path.startswith("/key/list"):
                seen.append(path)
            return page_request([HASHES[:1], HASHES[1:]], state)(path, payload)

        with patch.object(route, "request", request), contextlib.redirect_stdout(io.StringIO()) as out:
            route.main("keys")
        self.assertEqual(len(seen), 2, "listing must walk every page")
        rows = [json.loads(line) for line in out.getvalue().splitlines()]
        self.assertEqual([r["hash"] for r in rows[:-1]], HASHES)
        self.assertEqual(rows[-1]["total_count"], len(HASHES))

    def test_grant_all_reaches_keys_on_later_pages(self):
        state = {h: ["other"] for h in HASHES}
        writes = []
        with patch.object(route, "request", page_request([HASHES[:1], HASHES[1:]], state, writes)), \
                contextlib.redirect_stdout(io.StringIO()) as out:
            route.main("grant-all")
        self.assertEqual([w["key"] for w in writes], HASHES)
        self.assertEqual(state[HASHES[1]], ["other", route.NAME])
        self.assertEqual(json.loads(out.getvalue().splitlines()[-1])["total_count"], len(HASHES))


class RevokeBoundary(unittest.TestCase):
    def test_revoke_never_creates_unrestricted_key(self):
        for models, expected in [([route.NAME], None), (["other", route.NAME], ["other"]),
                                 ([], None), (["all-proxy-models"], None)]:
            with self.subTest(models=models):
                writes = []
                state = {HASHES[0]: list(models)}
                request = page_request([HASHES[:1]], state, writes)
                with patch.object(route, "request", request), \
                        patch.object(sys, "argv", ["route", "revoke", HASHES[0]]), \
                        contextlib.redirect_stdout(io.StringIO()):
                    if expected is None:
                        with self.assertRaises(ValueError):
                            route.main("revoke")
                        self.assertEqual(writes, [])
                    else:
                        route.main("revoke")
                        self.assertEqual(writes, [{"key": HASHES[0], "models": expected}])


if __name__ == "__main__":
    unittest.main()
