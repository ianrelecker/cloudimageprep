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
  }
}

provider "azurerm" {
  features {}
  # Prefer Azure CLI auth for local usage; override with subscription_id when needed
  use_cli         = true
  # Auto-detect subscription from Azure CLI if not provided explicitly
  subscription_id = var.subscription_id != "" ? var.subscription_id : try(data.external.az_sub.result.subscription_id, null)
}

# Fetch subscription ID from Azure CLI (no extra scripts; inline bash). Falls back to empty ID.
data "external" "az_sub" {
  program = [
    "bash",
    "-lc",
    # Outputs JSON like {"subscription_id":"<id>"} or empty string on failure
    "az account show --query '{subscription_id:id}' -o json 2>/dev/null || echo '{\"subscription_id\":\"\"}'"
  ]
}

# Optionally fetch GitHub public keys for the admin user
data "http" "github_keys" {
  count = var.ssh_github_user != "" ? 1 : 0
  url   = "https://github.com/${var.ssh_github_user}.keys"
}

locals {
  # Build list of public keys: prefer explicit key if provided, else GitHub keys; filter empties
  github_keys = var.ssh_github_user != "" && length(data.http.github_keys) > 0 ? compact(split("\n", trimspace(data.http.github_keys[0].response_body))) : []
  admin_keys  = var.admin_ssh_public_key != "" ? [var.admin_ssh_public_key] : local.github_keys
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

resource "azurerm_network_security_group" "ssh" {
  name                = "${var.project_name}-ssh"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name

  security_rule {
    name                       = "SSH"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.ssh_ingress_cidr
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

resource "azurerm_network_interface_security_group_association" "ssh" {
  network_interface_id      = azurerm_network_interface.this.id
  network_security_group_id = azurerm_network_security_group.ssh.id
}

data "azurerm_image" "this" {
  count               = var.managed_image_id == "" && var.managed_image_name != "" && var.managed_image_resource_group != "" ? 1 : 0
  name                = var.managed_image_name
  resource_group_name = var.managed_image_resource_group
}

locals {
  effective_image_id = var.managed_image_id != "" ? var.managed_image_id : (length(data.azurerm_image.this) > 0 ? data.azurerm_image.this[0].id : "")
}

resource "azurerm_linux_virtual_machine" "this" {
  name                  = "${var.project_name}-vm"
  location              = azurerm_resource_group.this.location
  resource_group_name   = azurerm_resource_group.this.name
  size                  = var.vm_size
  admin_username        = var.admin_username
  disable_password_authentication = true
  # Configure OS disk controller via variable to support both
  # SCSI (Gen2 images, most-compatible) and NVMe (required for Dv6/Dsv6 when image supports it)
  disk_controller_type  = var.disk_controller_type

  network_interface_ids = [azurerm_network_interface.this.id]

  source_image_id = local.effective_image_id

  dynamic "admin_ssh_key" {
    for_each = local.admin_keys
    content {
      username   = var.admin_username
      public_key = admin_ssh_key.value
    }
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    name                 = "${var.project_name}-osdisk"
  }

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
