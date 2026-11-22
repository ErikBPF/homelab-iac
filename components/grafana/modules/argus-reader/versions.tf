terraform {
  required_version = ">= 1.11.0"

  required_providers {
    grafana = {
      source  = "grafana/grafana"
      version = "4.55.0"
    }
  }
}
