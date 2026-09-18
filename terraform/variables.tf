variable "resource_group_name" {
  description = "Name of the Azure resource group to create."
  type        = string
  default     = "kubeadm-lab-rg"
}

variable "location" {
  description = "Azure region to deploy into."
  type        = string
  default     = "southeastasia"
}

variable "admin_username" {
  description = "Linux admin username created on every VM."
  type        = string
  default     = "debian"
}

variable "ssh_public_key_path" {
  description = "Path to your SSH public key."
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "domain_suffix" {
  description = "Domain suffix used for each machine's FQDN."
  type        = string
  default     = "kubernetes.local"
}

variable "vnet_address_space" {
  type    = list(string)
  default = ["10.240.0.0/24"]
}

variable "subnet_address_prefixes" {
  type    = list(string)
  default = ["10.240.0.0/24"]
}

variable "machines" {
  description = "Map of machines to create."
  type = map(object({
    size       = string
    private_ip = string
    public_ip  = bool
  }))
  default = {
    jumpbox = { size = "Standard_B2s", private_ip = "10.240.0.10", public_ip = true }
    server  = { size = "Standard_B2s", private_ip = "10.240.0.11", public_ip = false }
    "node-0" = { size = "Standard_B1ms", private_ip = "10.240.0.20", public_ip = false }
    "node-1" = { size = "Standard_B1ms", private_ip = "10.240.0.21", public_ip = false }
  }
}

variable "lb_name" {
  type    = string
  default = "kubeadm-lb"
}

variable "ingress_http_nodeport" {
  type    = number
  default = 31529
}

variable "ingress_https_nodeport" {
  type    = number
  default = 32264
}

variable "cloudflare_api_token" {
  description = "API Token for Cloudflare"
  type        = string
  sensitive   = true
}

variable "cloudflare_zone_id" {
  description = "The Zone ID of your domain in Cloudflare (found on the overview page)"
  type        = string
}