resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_virtual_network" "this" {
  name                = "${var.resource_group_name}-vnet"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  address_space       = var.vnet_address_space
}

resource "azurerm_subnet" "this" {
  name                 = "${var.resource_group_name}-subnet"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = var.subnet_address_prefixes
}

resource "azurerm_network_security_group" "this" {
  name                = "${var.resource_group_name}-nsg"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location

  security_rule {
    name                       = "allow-ssh"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-K8S-Ingress"
    priority                   = 300
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = [tostring(var.ingress_http_nodeport), tostring(var.ingress_https_nodeport)]
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "this" {
  subnet_id                 = azurerm_subnet.this.id
  network_security_group_id = azurerm_network_security_group.this.id
}

resource "azurerm_public_ip" "jumpbox" {
  name                = "jumpbox-public-ip"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "this" {
  for_each            = var.machines
  name                = "${each.key}-nic"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.this.id
    private_ip_address_allocation = "Static"
    private_ip_address            = each.value.private_ip
    public_ip_address_id          = each.value.public_ip ? azurerm_public_ip.jumpbox.id : null
  }
}