#!/usr/bin/env python3
"""Run inside home LiteLLM: python - apply|remove. Dedicated Apollo dsx row."""
import json
import os
import re
import sys
import urllib.request
import uuid

NAME = "apollo-deepseek-v41-flash"
SERVED = "deepseek-v4.1-flash"
BASE = "http://100.77.14.27:11542/v1"
IDENT = str(uuid.uuid5(uuid.NAMESPACE_URL, "homelab:litellm:personal:" + NAME))
PAGE_SIZE = 100
PAYLOAD = {
    "model_name": NAME,
    "litellm_params": {
        "model": "openai/" + SERVED,
        "api_base": BASE,
        "api_key": "sk-no-key-required",
        "timeout": 1800,
        "max_tokens": 8192,
    },
    "model_info": {
        "id": IDENT,
        "mode": "chat",
        "max_input_tokens": 262144,
        "max_output_tokens": 8192,
        "input_cost_per_token": 0,
        "output_cost_per_token": 0,
        "supports_function_calling": True,
        "supports_vision": True,
    },
}


def request(path, payload=None, base="http://127.0.0.1:4000", auth=True):
    headers = {"Content-Type": "application/json"}
    if auth:
        headers["Authorization"] = "Bearer " + os.environ["LITELLM_MASTER_KEY"]
    req = urllib.request.Request(base + path, headers=headers,
        data=None if payload is None else json.dumps(payload).encode())
    with urllib.request.urlopen(req, timeout=120) as response:
        return json.load(response)


def list_keys():
    """Return every key hash and the reported total; /key/list pages at ten rows."""
    keys = []
    total = 0
    page = 1
    while True:
        body = request("/key/list?size=%d&page=%d" % (PAGE_SIZE, page))
        keys.extend(body.get("keys") or [])
        total = int(body.get("total_count") or len(keys))
        if page >= int(body.get("total_pages") or 1):
            return keys, total
        page += 1


def main(action):
    if action == "keys":
        keys, total = list_keys()
        for k in keys:
            info = request("/key/info?key=" + k)["info"]
            print(json.dumps({"alias": info.get("key_alias"), "hash": k,
                "models": info.get("models")}))
        print(json.dumps({"action": action, "listed": len(keys), "total_count": total}))
        return
    if action == "grant-all":
        keys, total = list_keys()
        changed = []
        for k in keys:
            info = request("/key/info?key=" + k)["info"]
            models = list(info["models"])
            # An empty list and "all-proxy-models" both mean unrestricted; adding a
            # model to either would narrow the key instead of widening it.
            if not models or "all-proxy-models" in models or NAME in models:
                continue
            models.append(NAME)
            request("/key/update", {"key": k, "models": models})
            if request("/key/info?key=" + k)["info"]["models"] != models:
                raise ValueError("Unexpected key state after grant")
            changed.append(info.get("key_alias"))
        print(json.dumps({"action": action, "model": NAME, "granted_to": changed,
                          "count": len(changed), "listed": len(keys),
                          "total_count": total}))
        return
    if action in ("grant", "revoke"):
        fingerprint = sys.argv[2]
        if not re.fullmatch("[0-9a-f]{64}", fingerprint):
            raise ValueError("Unexpected key fingerprint")
        info = request("/key/info?key=" + fingerprint)["info"]
        models = list(info["models"])
        before = list(models)
        # An empty list and "all-proxy-models" both mean unrestricted, so a model
        # list would narrow the key. Revoking from one is a no-op the note cannot
        # claim, so it fails instead of reporting success.
        if not models or "all-proxy-models" in models:
            if action == "revoke":
                raise ValueError("Refusing to revoke from an unrestricted key; "
                                 "narrow it through the key workflow first")
            print(json.dumps({"action": action, "alias": info["key_alias"],
                "models_before": before, "models": before,
                "note": "key is unrestricted; a model list would narrow it"}))
            return
        if action == "grant" and NAME not in models:
            models.append(NAME)
        if action == "revoke":
            models = [m for m in models if m != NAME]
            # Reading the same rows back would pass, so an empty result is
            # refused before the write rather than widening the key.
            if not models:
                raise ValueError("Refusing an empty model list; the key would "
                                 "become unrestricted. Disable or delete the key instead")
        request("/key/update", {"key": fingerprint, "models": models})
        if request("/key/info?key=" + fingerprint)["info"]["models"] != models:
            raise ValueError("Unexpected route or key state")
        print(json.dumps({"action": action, "alias": info["key_alias"],
                          "models_before": before, "models": models}))
        return
    if action not in ("apply", "remove"):
        raise ValueError("Unexpected route state")
    rows = [r for r in request("/v2/model/info")["data"] if r["model_name"] == NAME]
    if not (len(rows) <= 1 and all(r["model_info"]["id"] == IDENT for r in rows)):
        raise ValueError("Unexpected existing route")
    if action == "remove":
        if rows:
            request("/model/delete", {"id": IDENT})
    else:
        probe = request("/chat/completions", {
            "model": SERVED,
            "messages": [{"role": "user", "content": "Reply exactly APOLLO_READY"}],
            "max_tokens": 32, "temperature": 0}, base=BASE, auth=False)
        content = probe["choices"][0]["message"].get("content") or ""
        if content.strip() != "APOLLO_READY":
            raise ValueError("Unexpected route state: engine did not answer APOLLO_READY")
        request("/model/update" if rows else "/model/new", PAYLOAD)
    current = [r for r in request("/v2/model/info")["data"] if r["model_name"] == NAME]
    if len(current) != (1 if action == "apply" else 0):
        raise ValueError("Unexpected route or key state")
    if current and current[0]["litellm_params"]["api_base"] != BASE:
        raise ValueError("Unexpected route or key state")
    print(json.dumps({"action": action, "model": NAME, "id": IDENT, "api_base": BASE}))


if __name__ == "__main__":
    main(sys.argv[1])
