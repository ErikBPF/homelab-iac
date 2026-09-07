"""Prepare a dedicated provider identity; --apply reads the operator key on stdin."""
import argparse
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
        raise RuntimeError(f"LiteLLM API returned HTTP {status}") from None


def save_credentials(target, key):
    if not isinstance(key, str) or not re.fullmatch(r"[A-Za-z0-9_.-]+", key):
        raise RuntimeError("Invalid provider credential format")
    original = target.read_bytes()
    plain = subprocess.check_output(
        ["sops", "-d", "--input-type", "dotenv", "--output-type", "dotenv", str(target)],
        stderr=subprocess.DEVNULL,
    ).decode()
    if any(line.startswith(("LITELLM_API_KEY=", "LITELLM_API_BASE=")) for line in plain.splitlines()):
        raise RuntimeError("Existing provider configuration must not be overwritten")
    plain = plain.rstrip("\n") + f"\nLITELLM_API_BASE={BASE}\nLITELLM_API_KEY={key}\n"
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


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--sops-file", type=Path, default=Path(".env.sops"))
    args = parser.parse_args()
    if not args.apply:
        print(json.dumps({"endpoint": BASE, "create": REQUEST, "store": str(args.sops_file)}, indent=2))
        return
    bootstrap(sys.stdin.read().strip(), args.sops_file)
    print("Provider identity created; credential saved to encrypted dotenv")


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, OSError, ValueError, subprocess.SubprocessError):
        print("Bootstrap failed; inspect the named identity and encrypted dotenv before retrying. No credentials printed.", file=sys.stderr)
        sys.exit(1)
