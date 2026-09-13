# Apollo personal LiteLLM route

User-authorized running experiment. Alias `apollo-qwen38-27b` points to
`http://100.77.14.27:11542/v1`, served model `qwen38-27b-nvfp4`.
Dedicated deployment ID `0efc99cb-3547-5977-9efe-8b18eb13c7e3`; no existing
deployment changed. This API-created experimental row is not Terraform-managed.

Apply from this checkout:

```sh
ssh -o Hostname=192.168.10.210 discovery 'docker exec -i litellm python - apply' < scripts/apollo-personal-route.py
```

The script validates direct inference before registration and checks the exact
row afterward. It consumes the existing gateway admin credential only inside
the LiteLLM process; it never prints it. The backend uses authenticated
Tailscale transport plus an Apollo firewall rule allowing only Discovery.

`grant`/`revoke` take the SHA256 fingerprint of the existing personal OpenCode
key as the second argument. They verify alias `opencode-20260713`, change only
this model's membership and read back the result. Existing key value, budgets,
other allowed models and all other clients remain unchanged. No key rotation.

Rollback: revoke that membership, then run the same entry point with `remove`.
The workload owner is homelab-gitops `apps/homelab/apollo-qwen27b`; stop the
backend only after removing its route. Do not reconcile or delete unrelated
legacy LiteLLM rows as part of this experiment.

Revoke refuses to remove the final allowed model: LiteLLM interprets an empty
allowlist as unrestricted access. Disable or delete a dedicated key through the
existing key-management workflow instead. Safety checks remain active under
Python optimization. Local regression: `python3 -O tests/apollo-personal-route.py`.
