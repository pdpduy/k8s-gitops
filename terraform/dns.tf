locals {
  dns_records = ["argocd.lab", "grafana.lab", "prometheus.lab", "alertmanager.lab", "keycloak.lab"]
}

resource "cloudflare_dns_record" "ingress_records" {
  for_each = toset(local.dns_records)
  
  zone_id = var.cloudflare_zone_id
  name    = each.key
  content = azurerm_public_ip.lb.ip_address # Replaced 'value' with 'content'
  type    = "A"
  proxied = false
  ttl     = 120
}

resource "cloudflare_dns_record" "jumpbox" {
  zone_id = var.cloudflare_zone_id
  name    = "jumpbox.lab"
  content = azurerm_public_ip.jumpbox.ip_address # Points to the jumpbox IP
  type    = "A"
  proxied = false
  ttl     = 120
}