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

resource "azurerm_public_ip" "master" {
  count               = local.master_count
  name                = "master-public-ip-${count.index}"
  location            = local.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
}

resource "azurerm_public_ip" "worker" {
  count               = local.worker_count
  name                = "worker-public-ip-${count.index}"
  location            = local.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
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
    public_ip_address_id          = azurerm_public_ip.master[count.index].id
  }

  tags = local.tags
}

resource "azurerm_network_security_group" "nsg" {
  name                = "${local.prefix}-nsg"
  location            = local.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "SSHAccess"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "KubernetesAPI"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "6443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = local.tags
}

resource "azurerm_subnet_network_security_group_association" "subnet_nsg_association" {
  subnet_id                 = azurerm_subnet.subnet.id
  network_security_group_id = azurerm_network_security_group.nsg.id
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
    public_ip_address_id          = azurerm_public_ip.worker[count.index].id
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

output "master_public_ips" {
  value       = [for ip in azurerm_public_ip.master : ip.ip_address]
  description = "Public IP addresses of master nodes"
}

output "worker_public_ips" {
  value       = [for ip in azurerm_public_ip.worker : ip.ip_address]
  description = "Public IP addresses of worker nodes"
}