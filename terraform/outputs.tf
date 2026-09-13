output "jumpbox_public_ip" {
  description = "Public IP of the jumpbox - your only external entry point."
  value       = azurerm_public_ip.jumpbox.ip_address
}

output "private_ips" {
  description = "Private IPs of every machine in the lab."
  value = {
    for name, cfg in var.machines : name => cfg.private_ip
  }
}

output "ssh_jumpbox" {
  description = "Command to SSH into the jumpbox."
  value       = "ssh ${var.admin_username}@${azurerm_public_ip.jumpbox.ip_address}"
}

output "ssh_from_jumpbox_examples" {
  description = "Commands to run FROM the jumpbox to reach the other machines as root."
  value = {
    for name, cfg in var.machines : name => "ssh root@${cfg.private_ip}"
    if name != "jumpbox"
  }
}

output "ingress_lb_public_ip" {
  description = "Public IP of the Ingress Load Balancer."
  value       = azurerm_public_ip.lb.ip_address
}
