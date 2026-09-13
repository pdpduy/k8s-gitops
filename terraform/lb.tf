resource "azurerm_public_ip" "lb" {
  name                = "${var.lb_name}-pip"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_lb" "this" {
  name                = var.lb_name
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "frontend"
    public_ip_address_id = azurerm_public_ip.lb.id
  }
}

resource "azurerm_lb_backend_address_pool" "workers" {
  loadbalancer_id = azurerm_lb.this.id
  name            = "backendpool"
}

locals {
  worker_nodes = {
    for name, cfg in var.machines : name => cfg
    if name != "jumpbox" && name != "server"
  }
}

resource "azurerm_network_interface_backend_address_pool_association" "workers" {
  for_each                = local.worker_nodes
  network_interface_id    = azurerm_network_interface.this[each.key].id
  ip_configuration_name   = "internal"
  backend_address_pool_id = azurerm_lb_backend_address_pool.workers.id
}

resource "azurerm_lb_probe" "http" {
  loadbalancer_id = azurerm_lb.this.id
  name            = "ingress-http"
  protocol        = "Tcp"
  port            = var.ingress_http_nodeport
}

resource "azurerm_lb_rule" "http" {
  loadbalancer_id                = azurerm_lb.this.id
  name                           = "http"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = var.ingress_http_nodeport
  frontend_ip_configuration_name = "frontend"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.workers.id]
  probe_id                       = azurerm_lb_probe.http.id
}

resource "azurerm_lb_probe" "https" {
  loadbalancer_id = azurerm_lb.this.id
  name            = "ingress-https"
  protocol        = "Tcp"
  port            = var.ingress_https_nodeport
}

resource "azurerm_lb_rule" "https" {
  loadbalancer_id                = azurerm_lb.this.id
  name                           = "https"
  protocol                       = "Tcp"
  frontend_port                  = 443
  backend_port                   = var.ingress_https_nodeport
  frontend_ip_configuration_name = "frontend"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.workers.id]
  probe_id                       = azurerm_lb_probe.https.id
}