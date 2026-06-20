{ pkgs, lib, config, inputs, ... }:

{
  # Load .env (per-environment UniFi API keys) into the shell.
  dotenv.enable = true;

  # Terraform/OpenTofu environment variables
  env.TF_DATA_DIR = ".terraform";

  # Pin Terragrunt to OpenTofu. A system `terraform` binary exists and would
  # otherwise be picked up — but it cannot read OpenTofu-encrypted state.
  env.TG_TF_PATH = "${pkgs.opentofu}/bin/tofu";

  # https://devenv.sh/packages/
  packages = [
    pkgs.git
    pkgs.opentofu
    pkgs.terragrunt
    pkgs.tflint
    pkgs.jq
    pkgs.curl
  ];

  enterShell = ''
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
