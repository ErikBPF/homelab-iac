include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_terragrunt_dir()}/tf"
}

inputs = {
  instance_id = "ocid1.instance.oc1.sa-saopaulo-1.antxeljrxbqhvsic4mey4ragi3rqpep6ovbulyejm776dponra4cazm2j4ya"
}
