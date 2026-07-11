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

output "reserved_public_ip" {
  value       = try(oci_core_public_ip.voyager[0].ip_address, null)
  description = "The RESERVED public IP (survives recreate). null until reserve_public_ip=true is applied. Set this as the relay/relay2 A-record target in cloudflare/dns once known."
}
