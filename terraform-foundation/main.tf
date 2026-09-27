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
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5"
    }
  }
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

provider "azurerm" {
  features {}
}

variable "cloudflare_zone_id" {
  description = "The Zone ID of your domain in Cloudflare"
  type        = string
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

# 1. Provision the Azure Static Web App
resource "azurerm_static_web_app" "interview_docs" {
  name                = "aswa-interview-docs"
  resource_group_name = azurerm_resource_group.shared.name
  location            = "eastasia" # Nearest supported ASWA free-tier region to southeastasia
  sku_tier            = "Free"
  sku_size            = "Free"
}

# 2. Create the DNS CNAME Record via Cloudflare
resource "cloudflare_dns_record" "interview_docs_cname" {
  zone_id = var.cloudflare_zone_id
  name    = "interview.lab"
  content = azurerm_static_web_app.interview_docs.default_host_name
  type    = "CNAME"
  proxied = false
  ttl     = 120
}

# 3. Bind the Custom Domain to the Static Web App
resource "azurerm_static_web_app_custom_domain" "interview_docs_domain" {
  static_web_app_id = azurerm_static_web_app.interview_docs.id
  domain_name       = "interview.lab.nexusworkspace.cloud"
  validation_type   = "cname-delegation"
  
  # Tell Azure to wait for the sleep timer, not just the DNS record creation
  depends_on = [time_sleep.wait_for_dns]
}

# 4. Output the Deployment Token for GitHub Actions
output "static_web_app_api_token" {
  description = "Save this as AZURE_STATIC_WEB_APPS_API_TOKEN in GitHub Secrets"
  value       = azurerm_static_web_app.interview_docs.api_key
  sensitive   = true
}

# Wait 60 seconds for Cloudflare DNS propagation
resource "time_sleep" "wait_for_dns" {
  depends_on      = [cloudflare_dns_record.interview_docs_cname]
  create_duration = "60s"
}

