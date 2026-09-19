# Fetch the existing Key Vault from the shared resource group
data "azurerm_key_vault" "shared" {
  name                = "kubelab-kv-7h8owi" # Paste the name from Step 1 here
  resource_group_name = "kubeadm-shared-rg"
}

# Grant the newly created VMs permission to read secrets from the persistent vault
resource "azurerm_role_assignment" "nodes_read" {
  for_each             = var.machines
  scope                = data.azurerm_key_vault.shared.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_virtual_machine.this[each.key].identity[0].principal_id
}