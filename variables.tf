variable "ssh_username" {
  type = string
}

variable "ssh_password" {
  type = string
}

variable "ssh_public_key_path" {
  type = string
}

variable "resource_location" {
  type    = string
  default = "France Central"
}

variable "azure_subscription_id" {
  type = string
}

variable "azure_tenant_id" {
  type = string
}

variable "azure_client_id" {
  type = string
}

variable "azure_client_secret" {
  type = string
}

variable "github_organization" {
  type    = string
  default = "InferenceFailed"
}

variable "github_repository" {
  type    = string
  default = "wireguard-server"
}

variable "github_pat" {
  type      = string
  sensitive = true
}