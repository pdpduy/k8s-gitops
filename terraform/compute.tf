locals {
  hosts_entries = join("\n", [
    for name, cfg in var.machines :
    "      ${cfg.private_ip}\t${name}.${var.domain_suffix} ${name}"
  ])
}

resource "azurerm_linux_virtual_machine" "this" {
  for_each = var.machines
  name                = each.key
  computer_name       = each.key
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  size                = each.value.size
  admin_username      = var.admin_username

  network_interface_ids = [
    azurerm_network_interface.this[each.key].id,
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = file(pathexpand(var.ssh_public_key_path))
  }

  identity {
    type = "SystemAssigned"
  }

  disable_password_authentication = true

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Debian"
    offer     = "debian-12"
    sku       = "12-gen2"
    version   = "latest"
  }

  custom_data = base64encode(templatefile("${path.module}/templates/cloud-init.tpl", {
    hostname       = each.key
    fqdn           = "${each.key}.${var.domain_suffix}"
    admin_username = var.admin_username
    hosts_entries  = local.hosts_entries
  }))
}

# Auto-generates the Kubespray inventory file based on Terraform state!
resource "local_file" "ansible_inventory" {
  filename = "${path.module}/inventory.ini"
  content  = <<-EOT
    [all]
    %{ for name, nic in azurerm_network_interface.this ~}
    %{ if name != "jumpbox" ~}
    ${name} ansible_host=${nic.private_ip_address} ip=${nic.private_ip_address}
    %{ endif ~}
    %{ endfor ~}

    [kube_control_plane]
    server

    [etcd]
    server

    [kube_node]
    %{ for name in keys(var.machines) ~}
    %{ if name != "jumpbox" && name != "server" ~}
    ${name}
    %{ endif ~}
    %{ endfor ~}

    [k8s_cluster:children]
    kube_control_plane
    kube_node
  EOT
}