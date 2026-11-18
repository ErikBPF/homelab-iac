# Apollo dsx LiteLLM route

The Apollo runtime now serves DeepSeek-V4.1-Flash through dsx on
`http://100.77.14.27:11542/v1` (desktop-nixos PR #477). This row replaces the
vLLM-era `apollo-qwen38-27b` route.

Alias `apollo-deepseek-v41-flash`, served model `deepseek-v4.1-flash`, context
262,144, vision and function calling enabled. The row is API-created, like the
route it replaces, so it is not Terraform-managed.

Apply from this checkout:

```sh
ssh -p 2222 erik@192.168.10.210 'docker exec -i litellm python - apply' < scripts/apollo-dsx-route.py
```

The script probes the engine directly and requires the reply `APOLLO_READY`
before it creates or updates the row; it then reads the row back.

`grant` and `revoke` take the SHA256 fingerprint of an existing key and change
only that key's membership of this alias. `keys` prints the aliases, hashes and
allowed models so a fingerprint can be chosen without reading any secret value.

Rollback: `remove` deletes the row; revoke memberships first if a key should not
keep the model. The engine itself is stopped on the host, not here.

Machine identity: unattended consumers should use a dedicated nonhuman key named
`<identity-type>-<controller>-<target>-<capability>`, not a human or shared key.
