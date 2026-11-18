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
        "max_tokens": 262144,
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


def main(action):
    if action == "keys":
        for k in request("/key/list")["keys"]:
            info = request("/key/info?key=" + k)["info"]
            print(json.dumps({"alias": info.get("key_alias"), "hash": k,
                "models": info.get("models")}))
        return
    if action in ("grant", "revoke"):
        fingerprint = sys.argv[2]
        if not re.fullmatch("[0-9a-f]{64}", fingerprint):
            raise ValueError("Unexpected key fingerprint")
        info = request("/key/info?key=" + fingerprint)["info"]
        models = list(info["models"])
        if "all-proxy-models" in models:
            print(json.dumps({"action": action, "alias": info["key_alias"],
                "note": "key already allows every model"}))
            return
        if action == "grant" and NAME not in models:
            models.append(NAME)
        if action == "revoke":
            models = [m for m in models if m != NAME]
        request("/key/update", {"key": fingerprint, "models": models})
        if request("/key/info?key=" + fingerprint)["info"]["models"] != models:
            raise ValueError("Unexpected route or key state")
        print(json.dumps({"action": action, "alias": info["key_alias"], "models": models}))
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
