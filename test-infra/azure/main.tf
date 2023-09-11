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
}

locals {
  tags = {
    environment = "test"
  }

  master_count = 1
  worker_count = 1

  location = "Southeast Asia"
  prefix   = "test-infra"

  master_vm_size = "Standard_D2s_v3"
  worker_vm_size = "Standard_D2s_v3"

  vm_username = "azureuser"
  vm_password = "P@ssw0rd1234"
}

resource "azurerm_resource_group" "rg" {
  name     = "${local.prefix}-rg"
  location = local.location
}

resource "azurerm_virtual_network" "main" {
  name                = "main-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = local.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "subnet" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_network_interface" "master" {
  count               = local.master_count
  name                = "master-nic-${count.index}"
  location            = local.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
  }

  tags = local.tags
}

resource "azurerm_network_interface" "worker" {
  count               = local.worker_count
  name                = "worker-nic-${count.index}"
  location            = local.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
  }

  tags = local.tags
}

resource "azurerm_linux_virtual_machine" "master" {
  count                 = local.master_count
  name                  = "master-${count.index}"
  location              = local.location
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.master[count.index].id]
  size                  = local.master_vm_size

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  computer_name                   = "master-${count.index}"
  disable_password_authentication = false
  admin_username                  = local.vm_username
  admin_password                  = local.vm_password

  tags = local.tags
}

resource "azurerm_linux_virtual_machine" "worker" {
  count                 = local.worker_count
  name                  = "worker-${count.index}"
  location              = local.location
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.worker[count.index].id]
  size                  = local.worker_vm_size

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  computer_name                   = "worker-${count.index}"
  disable_password_authentication = false
  admin_username                  = local.vm_username
  admin_password                  = local.vm_password

  tags = local.tags
}

output "master_ips" {
  value       = [for nic in azurerm_network_interface.master : nic.ip_configuration[0].private_ip_address]
  description = "IP addresses of master nodes"
}

output "worker_ips" {
  value       = [for nic in azurerm_network_interface.worker : nic.ip_configuration[0].private_ip_address]
  description = "IP addresses of worker nodes"
}

resource "azurerm_public_ip" "gateway" {
  name                = "gateway-ip"
  location            = local.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = local.tags
}

resource "azurerm_subnet" "gateway" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_virtual_network_gateway" "gateway" {
  name                = "gateway"
  location            = local.location
  resource_group_name = azurerm_resource_group.rg.name
  type                = "Vpn"
  vpn_type            = "RouteBased"
  sku                 = "VpnGw1"
  active_active       = false

  ip_configuration {
    name                          = "gw-ipconfig"
    subnet_id                     = azurerm_subnet.gateway.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.gateway.id
  }

  vpn_client_configuration {
    address_space        = ["172.16.0.0/24"]
    vpn_client_protocols = ["IkeV2", "OpenVPN"]

    root_certificate {
      name             = "gateway-cert"
      public_cert_data = filebase64("${path.module}/certs/rootCert.pem")
    }
  }

  tags = local.tags
}