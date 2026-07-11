include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_terragrunt_dir()}/tf"
}

locals {
  # OCI serial console connections require an RSA key (ed25519 is rejected with
  # 400-InvalidParameter). Dedicated key: ~/.ssh/oci-console-rsa(.pub).
  ssh_public_key = trimspace(run_cmd("sh", "-c", "cat \"$${OCI_CONSOLE_PUBKEY_FILE:-$HOME/.ssh/oci-console-rsa.pub}\""))
}

inputs = {
  # Current vanguard instance (cycle-3 box). Bump on reprovision.
  instance_id    = "ocid1.instance.oc1.sa-saopaulo-1.antxeljrxbqhvsic4mey4ragi3rqpep6ovbulyejm776dponra4cazm2j4ya"
  ssh_public_key = local.ssh_public_key
}
