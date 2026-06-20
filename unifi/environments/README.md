# Environments

Each environment (`home`, `lab`) is a UniFi controller. Layout:

```
environments/<env>/
├── env.hcl              # env name, api_url, site  (non-secret)
└── <stack>/
    └── terragrunt.hcl   # includes root, sources modules/<stack>, sets inputs
```

Stacks mirror `../modules/`: `network`, `wlan`, `firewall`, `port-forward`,
`dns`, `reservations`.

## Adding a stack to an environment

Copy an existing unit (e.g. `home/network/terragrunt.hcl`), point `source` at the
matching module, and fill `inputs`. The root `../terragrunt.hcl` supplies the
provider, versions, backend, and the per-env API key automatically.

## Per-environment secret

`env.hcl` holds only the non-secret `api_url`. The API key comes from the shell:
`UNIFI_API_KEY_<env>` in `.env` (see `../../.env.example`). The root config reads
`get_env("UNIFI_API_KEY_${env}")` and injects it as a sensitive input.

## Run a stack

```
cd environments/home/network
terragrunt plan      # never apply over Wi-Fi — use a wired connection
terragrunt apply
```

Run a whole environment at once with `terragrunt run-all plan` from
`environments/home/`.
