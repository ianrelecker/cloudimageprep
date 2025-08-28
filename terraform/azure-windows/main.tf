terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.100.0"
    }
    http = {
      source  = "hashicorp/http"
      version = ">= 3.4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.5.0"
    }
  }
}

provider "azurerm" {
  features {}
  use_cli         = true
  subscription_id = var.subscription_id != "" ? var.subscription_id : try(data.external.az_sub.result.subscription_id, null)
}

data "external" "az_sub" {
  program = [
    "bash",
    "-lc",
    "az account show --query '{subscription_id:id}' -o json 2>/dev/null || echo '{\"subscription_id\":\"\"}'"
  ]
}

data "http" "github_keys" {
  count = var.ssh_github_user != "" ? 1 : 0
  url   = "https://github.com/${var.ssh_github_user}.keys"
}

locals {
  github_keys        = var.ssh_github_user != "" && length(data.http.github_keys) > 0 ? compact(split("\n", trimspace(data.http.github_keys[0].response_body))) : []
  effective_password = var.admin_password != "" ? var.admin_password : (length(random_password.admin) > 0 ? random_password.admin[0].result : "")
}

resource "random_password" "admin" {
  count            = var.admin_password == "" ? 1 : 0
  length           = 20
  special          = true
  min_lower        = 1
  min_upper        = 1
  min_numeric      = 1
  min_special      = 1
  override_special = "!#$%&()*+,-.:;<=>?@[]^_{|}~"
}

resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = var.location
  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "azurerm_virtual_network" "this" {
  name                = "${var.project_name}-vnet"
  address_space       = [var.vnet_cidr]
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "azurerm_subnet" "this" {
  name                 = "${var.project_name}-subnet"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [var.subnet_cidr]
}

resource "azurerm_public_ip" "this" {
  name                = "${var.project_name}-pip"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "azurerm_network_security_group" "rdp" {
  name                = "${var.project_name}-rdp"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name

  security_rule {
    name                       = "RDP"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = var.rdp_ingress_cidr
    destination_address_prefix = "*"
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "azurerm_network_interface" "this" {
  name                = "${var.project_name}-nic"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name

  ip_configuration {
    name                          = "${var.project_name}-ipcfg"
    subnet_id                     = azurerm_subnet.this.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.this.id
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "azurerm_network_interface_security_group_association" "rdp" {
  network_interface_id      = azurerm_network_interface.this.id
  network_security_group_id = azurerm_network_security_group.rdp.id
}

data "azurerm_image" "this" {
  count               = var.managed_image_id == "" && var.managed_image_name != "" && var.managed_image_resource_group != "" ? 1 : 0
  name                = var.managed_image_name
  resource_group_name = var.managed_image_resource_group
}

locals {
  effective_image_id = var.managed_image_id != "" ? var.managed_image_id : (length(data.azurerm_image.this) > 0 ? data.azurerm_image.this[0].id : "")
}

resource "azurerm_windows_virtual_machine" "this" {
  name                = "${var.project_name}-winvm"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  size                = var.vm_size
  admin_username      = var.admin_username
  admin_password      = local.effective_password

  network_interface_ids = [azurerm_network_interface.this.id]

  source_image_id = local.effective_image_id

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    name                 = "${var.project_name}-osdisk"
  }

  enable_automatic_updates = true
  provision_vm_agent       = true

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }

  lifecycle {
    precondition {
      condition     = local.effective_image_id != ""
      error_message = "No managed image specified. Set managed_image_id, or managed_image_name + managed_image_resource_group."
    }
  }
}

