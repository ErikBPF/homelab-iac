#!/usr/bin/env bats

@test "Authentik runtime values use the existing write-only OpenBao module" {
  unit=components/openbao/environments/home/authentik-runtime/terragrunt.hcl
  test -f "$unit"
  grep -Fq 'modules//kv-secret' "$unit"
  grep -Eq 'name[[:space:]]*=[[:space:]]*"platform/authentik"' "$unit"
  grep -Fq 'AUTHENTIK_SECRET_KEY' "$unit"
  grep -Fq 'AUTHENTIK_POSTGRESQL__PASSWORD' "$unit"
  grep -Fq 'get_env("AUTHENTIK_SECRET_KEY")' "$unit"
  grep -Fq 'get_env("AUTHENTIK_POSTGRESQL_PASSWORD")' "$unit"
  grep -Fq 'write_version = 1' "$unit"
}

@test "Authentik runtime values remain ephemeral and absent from outputs" {
  grep -Fq 'data_json_wo' components/openbao/modules/kv-secret/main.tf
  grep -Fq 'ephemeral = true' components/openbao/modules/kv-secret/variables.tf
  ! grep -R -q 'output ' components/openbao/modules/kv-secret
  ! grep -R -E -q 'AUTHENTIK_(SECRET_KEY|POSTGRESQL_PASSWORD)[[:space:]]*=[[:space:]]*"[^$]' \
    components/openbao/environments/home/authentik-runtime
}

@test "Authentik writer access is limited to its exact KV path" {
  policy=components/openbao/modules/runtime-secret-foundation/main.tf
  grep -Fq 'path \"secret/data/platform/authentik\" { capabilities = [\"create\", \"update\", \"read\"] }' "$policy"
  grep -Fq 'path \"secret/metadata/platform/authentik\" { capabilities = [\"read\"] }' "$policy"
  ! grep -Fq 'secret/data/platform/*' "$policy"
}
