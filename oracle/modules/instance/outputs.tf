output "public_ip" {
  value       = try(oci_core_instance.voyager[0].public_ip, null)
  description = "Public IP — set this as ip_voyager in desktop-nixos/justfile, then `just deploy-voyager`. null until the instance is created (create_instance=true)."
}

output "private_ip" {
  value = try(oci_core_instance.voyager[0].private_ip, null)
}

output "instance_ocid" {
  value = try(oci_core_instance.voyager[0].id, null)
}
