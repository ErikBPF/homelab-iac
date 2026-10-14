#!/usr/bin/env python3
"""Evaluate the production identity precondition with offline device fixtures."""

import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile

root = Path(__file__).resolve().parents[1]
source = (root / "tailscale/modules/acl/main.tf").read_text()
pin = re.search(r'discovery_node_id\s*=\s*"([^"]+)"', source).group(1)
condition = re.search(r"condition\s*=\s*(.*?)\n\s*error_message", source, re.S).group(1)
device = {
    "node_id": pin,
    "authorized": True,
    "tags": ["tag:server"],
    "addresses": ["100.103.52.100"],
}
cases = [
    ("current identity", [device], True),
    ("missing identity", [], False),
    ("duplicate identity", [device, device], False),
    ("replacement node", [dict(device, node_id="replacement")], False),
    ("unauthorized", [dict(device, authorized=False)], False),
    ("missing server tag", [dict(device, tags=[])], False),
    ("wrong tailnet address", [dict(device, addresses=["100.64.0.1"])], False),
]
tofu = sys.argv[1] if len(sys.argv) > 1 else "tofu"
with tempfile.TemporaryDirectory(prefix="tailscale-identity-") as directory:
    Path(directory, "main.tf").write_text(
        'locals { discovery_node_id = ' + json.dumps(pin) + ' }\n'
    )
    for name, devices, expected in cases:
        expression = condition.replace(
            "data.tailscale_devices.discovery.devices",
            "jsondecode(" + json.dumps(json.dumps(devices)) + ")",
        )
        result = subprocess.run(
            [tofu, f"-chdir={directory}", "console", "-no-color"],
            input=" ".join(expression.split()) + "\n",
            capture_output=True, text=True, timeout=30,
        )
        if result.returncode or result.stdout.strip() != str(expected).lower():
            raise RuntimeError(f"Identity precondition failed fixture: {name}")
        print("PASS:", name)
print("PASS: seven production identity-precondition cases")
