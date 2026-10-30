#!/usr/bin/env python3
"""Keep subnet-route approval scoped to Discovery's existing node."""

from pathlib import Path
from ipaddress import ip_network
import json
import re

root = Path(__file__).resolve().parents[1]
source = (root / "tailscale/modules/acl/main.tf").read_text()
resource = re.search(
    r'resource "tailscale_device_subnet_routes" "discovery"\s*\{([^}]+)\}',
    source,
)
assert resource, "Discovery subnet-route approval resource is missing"
body = resource.group(1)
assert re.search(r'discovery_node_id\s*=\s*"nBNPLvBqRK11CNTRL"', source), "Wrong Discovery node pin"
assert re.search(r"device_id\s*=\s*local\.discovery_node_id", body), "Approval must use the pin, not live selection"
routes = re.search(r"routes\s*=\s*\[([^]]+)\]", body)
assert routes, "Discovery routes are missing"
assert re.findall(r'"([^"]+)"', routes.group(1)) == [
    "192.168.10.1/32",
    "192.168.10.2/32",
    "192.168.10.4/32",
    "192.168.10.210/32",
], "Approval must contain only Discovery's four advertised host routes"
assert 'data "tailscale_devices" "discovery"' in source, "Discovery lookup must retain duplicate matches"
assert re.search(r'name\s*=\s*"hostname"\s+values\s*=\s*\["discovery"\]', source), "Discovery lookup must match hostname exactly"
assert "precondition {" in body, "Identity mismatch must block route approval"
for guard in [
    "length(data.tailscale_devices.discovery.devices) == 1",
    "alltrue([",
    "for device in data.tailscale_devices.discovery.devices :",
    "device.node_id == local.discovery_node_id",
    "device.authorized",
    'contains(device.tags, "tag:server")',
    'contains(device.addresses, "100.103.52.100")',
]:
    assert guard in body, f"Discovery identity guard is missing: {guard}"

# HuJSON adds comments and trailing commas to JSON. Preserve quoted strings
# while removing those two extensions; leave syntax validation to json.loads.
policy = (root / "tailscale/acl/policy.hujson").read_text()
quoted = r'"(?:\\.|[^"\\])*"'
policy = re.sub(
    rf'({quoted})|//[^\n]*|/\*.*?\*/',
    lambda match: match.group(1) or " ", policy, flags=re.S,
)
policy = re.sub(
    rf'({quoted})|,(?=\s*[}}\]])',
    lambda match: match.group(1) or "", policy,
)


def unique_keys(pairs):
    result = {}
    for key, value in pairs:
        assert key not in result, "Duplicate policy key makes route ownership ambiguous"
        result[key] = value
    return result


policy = json.loads(policy, object_pairs_hook=unique_keys)
protected_routes = [ip_network(route) for route in re.findall(r'"([^"]+)"', routes.group(1))]
auto_routes = policy.get("autoApprovers", {}).get("routes", {})
assert isinstance(auto_routes, dict), "Route auto-approvers must be a mapping"
for route, approvers in auto_routes.items():
    assert isinstance(approvers, list), "Route auto-approvers must be lists"
    try:
        network = ip_network(route, strict=False)
    except ValueError:
        raise AssertionError("Route auto-approval must use a valid CIDR") from None
    assert not approvers or not any(
        network.version == protected.version and network.overlaps(protected)
        for protected in protected_routes
    ), "Route auto-approval overlaps Discovery's managed routes"
print("PASS: Discovery-only subnet-route approval contract")
