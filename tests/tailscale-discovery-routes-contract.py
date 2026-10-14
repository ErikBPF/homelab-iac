#!/usr/bin/env python3
"""Keep subnet-route approval scoped to Discovery's existing node."""

from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]
source = (root / "tailscale/modules/acl/main.tf").read_text()
resource = re.search(
    r'resource "tailscale_device_subnet_routes" "discovery"\s*\{([^}]+)\}',
    source,
)
assert resource, "Discovery subnet-route approval resource is missing"
body = resource.group(1)
assert re.search(r'device_id\s*=\s*"nBNPLvBqRK11CNTRL"', body), "Wrong Discovery node"
routes = re.search(r"routes\s*=\s*\[([^]]+)\]", body)
assert routes, "Discovery routes are missing"
assert re.findall(r'"([^"]+)"', routes.group(1)) == [
    "192.168.10.1/32",
    "192.168.10.2/32",
    "192.168.10.4/32",
    "192.168.10.210/32",
], "Approval must contain only Discovery's four advertised host routes"
print("PASS: Discovery-only subnet-route approval contract")
