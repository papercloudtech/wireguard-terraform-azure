variable "ssh_username" {
  type = string
}

variable "ssh_password" {
  type      = string
  sensitive = true
}

variable "ssh_public_key_path" {
  type = string
}

variable "resource_location" {
  type    = string
  default = "Israel Central"

  validation {
    condition     = contains(["Australia Central", "Australia East", "Australia Southeast", "Canada Central", "Canada East", "Central India", "East Asia", "East US", "East US 2", "France Central", "Germany West Central", "Israel Central", "Italy North", "North Europe", "Norway East", "Poland Central", "South Africa North", "Sweden Central", "Switzerland North", "UAENorth", "UK South", "West US", "West US 3"], var.resource_location)
    error_message = "The location must be one of the specified Azure regions."
  }
}
# Recommended size - Standard_D2s_v3 for wireguard server Development
variable "vm_size" {
  type    = string
  default = "Standard_B1s"
}

variable "azure_subscription_id" {
  type      = string
  sensitive = true
  default   = null
}

variable "azure_tenant_id" {
  type      = string
  sensitive = true
  default   = null
}

variable "azure_client_id" {
  type      = string
  sensitive = true
  default   = null
}

variable "azure_client_secret" {
  type      = string
  sensitive = true
  default   = null
}

variable "github_organization" {
  type    = string
  default = "papercloudtech"
}

variable "github_repository" {
  type    = string
  default = "wireguard-server"
}

