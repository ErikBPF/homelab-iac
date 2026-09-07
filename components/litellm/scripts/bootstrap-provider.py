"""Prepare a dedicated provider identity; --apply reads the operator key on stdin."""
import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import urllib.error
import urllib.request

BASE = "https://litellm.homelab.pastelariadev.com"
IDENTITY = "svc-homelab-iac-litellm-control-plane-manager"
REQUEST = {
    "user_id": IDENTITY,
    "user_alias": IDENTITY,
    "user_role": "proxy_admin",
    "key_alias": IDENTITY,
    "duration": "30d",
    "auto_create_key": True,
    "metadata": {"purpose": "explicit-terraform-provider-workflow"},
}


class APIError(RuntimeError):
    def __init__(self, status):
        self.status = status
        super().__init__(f"LiteLLM API returned HTTP {status}")


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        raise RuntimeError("Credentialed API redirects are refused")


def api(path, token, body=None):
    request = urllib.request.Request(
        BASE + path,
        headers={"Authorization": "Bearer " + token, "Content-Type": "application/json"},
        data=None if body is None else json.dumps(body).encode(),
    )
    try:
        with urllib.request.build_opener(NoRedirect).open(request, timeout=20) as response:
            content = response.read()
            return json.loads(content) if content else {}
    except urllib.error.HTTPError as error:
        status = error.code
        error.close()
        if status == 404 and body is None:
            return None
        raise APIError(status) from None


def save_credentials(target, key, replace_key=None):
    if not isinstance(key, str) or not re.fullmatch(r"[A-Za-z0-9_.-]+", key):
        raise RuntimeError("Invalid provider credential format")
    original = target.read_bytes()
    plain = subprocess.check_output(
        ["sops", "-d", "--input-type", "dotenv", "--output-type", "dotenv", str(target)],
        stderr=subprocess.DEVNULL,
    ).decode()
    if replace_key is None:
        if any(line.startswith(("LITELLM_API_KEY=", "LITELLM_API_BASE=")) for line in plain.splitlines()):
            raise RuntimeError("Existing provider configuration must not be overwritten")
        plain = plain.rstrip("\n") + f"\nLITELLM_API_BASE={BASE}\nLITELLM_API_KEY={key}\n"
    else:
        expected = "LITELLM_API_KEY=" + replace_key
        if plain.splitlines().count(expected) != 1 or "LITELLM_API_BASE=" + BASE not in plain.splitlines():
            raise RuntimeError("Stored credential changed or endpoint does not match")
        plain = "\n".join("LITELLM_API_KEY=" + key if line == expected else line for line in plain.splitlines()) + "\n"
    encrypted = subprocess.check_output(
        ["sops", "--encrypt", "--input-type", "dotenv", "--output-type", "dotenv",
         "--filename-override", str(target.resolve()), "/dev/stdin"],
        input=plain.encode(), stderr=subprocess.DEVNULL,
    )
    verified = subprocess.check_output(
        ["sops", "-d", "--input-type", "dotenv", "--output-type", "dotenv", "/dev/stdin"],
        input=encrypted, stderr=subprocess.DEVNULL,
    )
    if verified.decode() != plain or target.read_bytes() != original:
        raise RuntimeError("SOPS verification or concurrent-edit check failed")
    with tempfile.NamedTemporaryFile(dir=target.parent, prefix=".provider-sops-", delete=False) as out:
        temporary = Path(out.name)
        try:
            out.write(encrypted)
            out.flush()
            os.fsync(out.fileno())
            os.replace(temporary, target)
        finally:
            temporary.unlink(missing_ok=True)


def bootstrap(operator, target):
    if not operator:
        raise RuntimeError("Operator credential required on stdin")
    if any(line.startswith(("LITELLM_API_KEY=", "LITELLM_API_BASE=")) for line in target.read_text().splitlines()):
        raise RuntimeError("Provider configuration already exists")
    existing = api("/user/info?user_id=" + IDENTITY, operator)
    if existing and existing.get("user_info"):
        raise RuntimeError("Provider identity already exists; use a reviewed rotation")
    created = api("/user/new", operator, REQUEST)
    key = created.get("key")
    if created.get("user_id") != IDENTITY or created.get("user_role") != "proxy_admin" or not key:
        raise RuntimeError("Unexpected creation response; inspect the named identity")
    try:
        save_credentials(target, key)
    except Exception:
        # Only this newly created identity is eligible for rollback.
        api("/key/delete", operator, {"keys": [key]})
        api("/user/delete", operator, {"user_ids": [IDENTITY]})
        raise RuntimeError("SOPS persistence failed; new identity removed") from None


def read_credentials(target):
    plain = subprocess.check_output(
        ["sops", "-d", "--input-type", "dotenv", "--output-type", "dotenv", str(target)],
        stderr=subprocess.DEVNULL,
    ).decode()
    values = dict(line.split("=", 1) for line in plain.splitlines() if line.startswith(("LITELLM_API_KEY=", "LITELLM_API_BASE=")))
    if values.get("LITELLM_API_BASE") != BASE or not values.get("LITELLM_API_KEY"):
        raise RuntimeError("Stored provider configuration is incomplete")
    return values["LITELLM_API_KEY"]


def rotate(operator, target):
    if not operator:
        raise RuntimeError("Operator credential required on stdin")
    old = read_credentials(target)
    user = api("/user/info?user_id=" + IDENTITY, operator)
    if not user or user.get("user_info", {}).get("user_role") != "proxy_admin":
        raise RuntimeError("Expected provider identity is absent or has changed role")
    created = api("/key/generate", operator, {
        "user_id": IDENTITY, "duration": "30d",
        "key_alias": IDENTITY + "-" + datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ"),
    })
    key = created.get("key")
    if not key or key == old:
        raise RuntimeError("Unexpected replacement credential")
    try:
        info = api("/key/info", key)
        if not info or info.get("info", {}).get("user_id") != IDENTITY:
            raise RuntimeError("Replacement does not authenticate as expected identity")
        save_credentials(target, key, replace_key=old)
    except Exception:
        api("/key/delete", operator, {"keys": [key]})
        raise RuntimeError("Replacement failed; old credential retained") from None
    # From here onward, failures retain the verified, persisted replacement.
    api("/key/delete", operator, {"keys": [old]})
    try:
        api("/key/info", old)
    except APIError as error:
        if error.status not in (401, 403):
            raise
    else:
        raise RuntimeError("Old credential still accepted; inspect its revocation")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--rotate", action="store_true")
    parser.add_argument("--sops-file", type=Path, default=Path(".env.sops"))
    args = parser.parse_args()
    if not args.apply:
        operation = {"rotate": {"user_id": IDENTITY, "duration": "30d", "order": ["create", "authenticate", "persist", "revoke previous"]}} if args.rotate else {"create": REQUEST}
        print(json.dumps({"endpoint": BASE, **operation, "store": str(args.sops_file)}, indent=2))
        return
    action = rotate if args.rotate else bootstrap
    action(sys.stdin.read().strip(), args.sops_file)
    print("Provider credential saved to encrypted dotenv; operation verified")


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, OSError, ValueError, subprocess.SubprocessError):
        print("Bootstrap failed; inspect the named identity and encrypted dotenv before retrying. No credentials printed.", file=sys.stderr)
        sys.exit(1)
