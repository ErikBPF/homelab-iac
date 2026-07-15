{ pkgs, lib, config, inputs, ... }:

{
  # Load .env (per-environment UniFi API keys) into the shell.
  dotenv.enable = true;

  # Terraform/OpenTofu environment variables
  env.TF_DATA_DIR = ".terraform";

  # Pin Terragrunt to OpenTofu. A system `terraform` binary exists and would
  # otherwise be picked up — but it cannot read OpenTofu-encrypted state.
  env.TG_TF_PATH = "${pkgs.opentofu}/bin/tofu";

  # Shared provider plugin cache — one download instead of one per unit
  # (OpenTofu 1.12 made the shared cache lockfile-safe).
  env.TF_PLUGIN_CACHE_DIR = "${config.devenv.root}/.terraform.d/plugin-cache";

  # https://devenv.sh/packages/
  packages = [
    pkgs.git
    pkgs.opentofu
    pkgs.terragrunt
    pkgs.jq
    pkgs.curl
    pkgs.sops
    pkgs.age
    pkgs.bats
    pkgs.shellcheck
    pkgs.go
  ];

  enterShell = ''
    mkdir -p "$TF_PLUGIN_CACHE_DIR"
    # Decrypt the sops-managed secrets into the dotenv-loaded .env if missing.
    if [ ! -f .env ] && [ -f .env.sops ]; then
      sops -d --input-type dotenv --output-type dotenv .env.sops > .env
    fi
    # State backend is MinIO (S3). OpenTofu's s3 backend reads AWS_*; our creds
    # live as MINIO_TFSTATE_* in .env. Map them so plan/apply reach the bucket.
    export AWS_ACCESS_KEY_ID="''${MINIO_TFSTATE_ROOT_USER:-}"
    export AWS_SECRET_ACCESS_KEY="''${MINIO_TFSTATE_ROOT_PASSWORD:-}"
    echo "homelab-iac devenv"
    tofu version | head -1
    terragrunt --version | head -1
  '';

  # Pre-commit hygiene. Fast formatters on commit; tflint catches syntax /
  # provider-rule issues. https://devenv.sh/git-hooks/
  git-hooks.hooks = {
    tofu-fmt = {
      enable         = true;
      name           = "tofu fmt";
      entry          = "${pkgs.opentofu}/bin/tofu fmt -recursive -check";
      files          = "\\.tf$";
      pass_filenames = false;
    };
    terragrunt-hclfmt = {
      enable         = true;
      name           = "terragrunt hcl format";
      entry          = "${pkgs.terragrunt}/bin/terragrunt hcl format --check --diff";
      files          = "\\.hcl$";
      pass_filenames = false;
    };
    tflint = {
      enable         = true;
      name           = "tflint";
      entry          = "${pkgs.tflint}/bin/tflint --recursive";
      files          = "\\.tf$";
      pass_filenames = false;
    };
  };

  # See full reference at https://devenv.sh/reference/options/
}
