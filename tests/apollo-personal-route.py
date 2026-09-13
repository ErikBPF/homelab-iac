#!/usr/bin/env python3
"""Exercise grant boundaries without credentials, HTTP, or live mutation."""
import contextlib
import importlib.util
import io
from pathlib import Path
import sys
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("route", Path(__file__).resolve().parents[1] / "scripts/apollo-personal-route.py")
route = importlib.util.module_from_spec(spec)
spec.loader.exec_module(route)

class GrantBoundary(unittest.TestCase):
    def test_revoke_never_creates_unrestricted_key(self):
        for models, expected in [([route.NAME], None), (["other", route.NAME], ["other"]), ([], None), (["all-proxy-models"], None)]:
            with self.subTest(models=models):
                writes = []
                state = {"key_alias": "opencode-20260713", "models": list(models)}
                def request(path, payload=None):
                    if payload is not None:
                        writes.append(payload)
                        state["models"] = payload["models"]
                    return {"info": state}
                with patch.object(route, "request", request), patch.object(sys, "argv", ["route", "revoke", "a" * 64]), contextlib.redirect_stdout(io.StringIO()):
                    if expected is None:
                        with self.assertRaises(ValueError): route.main("revoke")
                        self.assertEqual(writes, [])
                    else:
                        route.main("revoke")
                        self.assertEqual(writes, [{"key": "a" * 64, "models": expected}])

if __name__ == "__main__": unittest.main()
