terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

variable "cloudflare_api_token" {
  description = "Cloudflare API Token"
  type        = string
  sensitive   = true
}

data "azurerm_client_config" "current" {}

# Dedicated resource group for persistent items
resource "azurerm_resource_group" "shared" {
  name     = "kubeadm-shared-rg"
  location = "southeastasia"
}

# Key Vaults require globally unique names, so we add a random suffix
resource "random_string" "kv_suffix" {
  length  = 6
  special = false
  upper   = false
}

resource "azurerm_key_vault" "shared" {
  name                       = "kubelab-kv-${random_string.kv_suffix.result}"
  location                   = azurerm_resource_group.shared.location
  resource_group_name        = azurerm_resource_group.shared.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  rbac_authorization_enabled  = true
}

# Grant your personal Azure CLI account permission to write secrets
resource "azurerm_role_assignment" "tf_admin" {
  scope                = azurerm_key_vault.shared.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id
}

# Store the token
resource "azurerm_key_vault_secret" "cloudflare" {
  name         = "cloudflare-api-token"
  value        = var.cloudflare_api_token
  key_vault_id = azurerm_key_vault.shared.id
  depends_on   = [azurerm_role_assignment.tf_admin]
}

output "key_vault_name" {
  description = "Use this in your main lab data block"
  value       = azurerm_key_vault.shared.name
}

output "key_vault_url" {
  description = "Use this in your GitOps secret-store.yaml"
  value       = azurerm_key_vault.shared.vault_uri
}