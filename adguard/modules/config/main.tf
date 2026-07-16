resource "adguard_config" "this" {
  blocked_services                = var.config.blocked_services
  blocked_services_pause_schedule = var.config.blocked_services_pause_schedule
  dns                             = var.config.dns
  filtering                       = var.config.filtering
  parental_control                = var.config.parental_control
  querylog                        = var.config.querylog
  rewrites                        = var.config.rewrites
  safebrowsing                    = var.config.safebrowsing
  safesearch                      = var.config.safesearch
  stats                           = var.config.stats
}
