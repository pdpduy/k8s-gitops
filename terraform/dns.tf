locals {
  # Assuming your base Cloudflare zone is "nexusworkspace.cloud"
  dns_records = ["argocd.lab", "grafana.lab", "prometheus.lab"]
}

resource "cloudflare_record" "ingress_records" {
  for_each = toset(local.dns_records)
  
  zone_id  = var.cloudflare_zone_id
  name     = each.key
  value    = azurerm_public_ip.lb.ip_address
  type     = "A"
  proxied  = false # Set to true if you want to use Cloudflare's proxy/CDN
  ttl      = 120
}