# Apollo dsx LiteLLM route

The Apollo runtime now serves DeepSeek-V4.1-Flash through dsx on
`http://100.77.14.27:11542/v1` (desktop-nixos PR #477). This row replaces the
vLLM-era `apollo-qwen38-27b` route.

Alias `apollo-deepseek-v41-flash`, served model `deepseek-v4.1-flash`, context
262,144, vision and function calling enabled.

The row is API-created, like the route it replaces, so it is not
Terraform-managed. The production manifest still declares the vLLM-era Apollo
aliases (`qwen-chat`, `qwen3.8-27b`) against this endpoint and does not declare
this row, so an apply or a restore would reinstate a dead upstream and drop this
alias. Issue #175 owns that reconciliation; it moves the manifest, the S05 alias
fixture and the key allowlists in one change.

Apply from this checkout:

```sh
ssh -p 2222 erik@192.168.10.210 'docker exec -i litellm python - apply' < scripts/apollo-dsx-route.py
```

The script probes the engine directly and requires the reply `APOLLO_READY`
before it creates or updates the row; it then reads the row back.

`keys` reads every `/key/list` page and prints each alias with its hash and
allowed models, then the total count, so a fingerprint can be chosen without
reading any secret value and a truncated listing is visible.

`grant` and `revoke` take the SHA256 fingerprint of an existing key, change only
that key's membership of this alias, and print the list before and after. A key
whose model list is empty or holds `all-proxy-models` is unrestricted: `grant`
leaves it alone and says so, and `revoke` fails, because writing a list back
would narrow the key instead of removing one alias. `revoke` also fails when this
alias is the key's only allowed model, because an empty list means unrestricted.
Disable or delete such a key through the key workflow instead.

Rollback: `remove` deletes the row; revoke memberships first if a key should not
keep the model. The engine itself is stopped on the host, not here.

Machine identity: unattended consumers should use a dedicated nonhuman key named
`<identity-type>-<controller>-<target>-<capability>`, not a human or shared key.

Local regression: `python3 -O tests/apollo-dsx-route.py`.
