terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.0.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.azure_subscription_id
  tenant_id       = var.azure_tenant_id
  client_id       = var.azure_client_id
  client_secret   = var.azure_client_secret
}


resource "azurerm_resource_group" "wire-guard-rg" {
  name     = "wire-guard-resources"
  location = var.resource_location
  tags = {
    environment = "dev"
  }
}

resource "azurerm_virtual_network" "wireguard-vnet" {
  name                = "wire-guard-vn"
  resource_group_name = azurerm_resource_group.wire-guard-rg.name
  location            = azurerm_resource_group.wire-guard-rg.location
  address_space       = ["10.0.0.0/16"] # 255.255.0.0
}

resource "azurerm_subnet" "wireguard-subnet" {
  name                 = "wg-subnet"
  resource_group_name  = azurerm_resource_group.wire-guard-rg.name
  virtual_network_name = azurerm_virtual_network.wireguard-vnet.name
  address_prefixes     = ["10.0.0.0/24"] # 255.255.255.0
}

resource "azurerm_network_security_group" "wireguard-securitygroup" {
  name                = "wg-nsg"
  resource_group_name = azurerm_resource_group.wire-guard-rg.name
  location            = azurerm_resource_group.wire-guard-rg.location
  security_rule {
    name                       = "AllWireGuardPorts"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_ranges    = ["22", "80", "443", "51820"]
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "wg-subnet-nsg" {
  subnet_id                 = azurerm_subnet.wireguard-subnet.id
  network_security_group_id = azurerm_network_security_group.wireguard-securitygroup.id
}

resource "azurerm_public_ip" "wireguard-publicip" {
  name                = "wireguardip"
  resource_group_name = azurerm_resource_group.wire-guard-rg.name
  location            = azurerm_resource_group.wire-guard-rg.location
  allocation_method   = "Dynamic"
}

resource "azurerm_network_interface" "wireguard-ni" {
  name                = "wireguard-ni"
  resource_group_name = azurerm_resource_group.wire-guard-rg.name
  location            = azurerm_resource_group.wire-guard-rg.location
  ip_configuration {
    name                          = "wg-ip-config"
    subnet_id                     = azurerm_subnet.wireguard-subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.wireguard-publicip.id
  }
}

resource "azurerm_linux_virtual_machine" "wireguard-vm" {
  name                            = "wireguard-vm"
  resource_group_name             = azurerm_resource_group.wire-guard-rg.name
  location                        = azurerm_resource_group.wire-guard-rg.location
  size                            = "Standard_B1s"
  admin_username                  = var.ssh_username
  admin_password                  = var.ssh_password
  disable_password_authentication = false
  network_interface_ids = [
    azurerm_network_interface.wireguard-ni.id,
  ]

  admin_ssh_key {
    username   = var.ssh_username
    public_key = file(var.ssh_public_key_path)
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
  # custom_data = filebase64("scripts/cloud-init.sh")
}
