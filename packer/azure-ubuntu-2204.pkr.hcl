// Azure Ubuntu 22.04 (jammy) managed image via azure-arm

source "azure-arm" "ubuntu2204" {
  # Auth: use Azure CLI logged-in context
  use_azure_cli_auth = true

  location              = var.azure_location
  vm_size               = var.azure_vm_size
  managed_image_name    = "${var.azure_image_name_prefix}-ubuntu2204-{{timestamp}}"
  managed_image_resource_group_name = var.azure_image_resource_group

  # Base image (Ubuntu 22.04 LTS)
  azure_tags = local.common_tags

  os_type           = "Linux"
  image_publisher   = "Canonical"
  image_offer       = "0001-com-ubuntu-server-jammy"
  # Use Gen2 base image so resulting managed image is Gen2-compatible (required for Dsv5/Dsv6 families)
  image_sku         = "22_04-lts-gen2"

  # SSH settings
  ssh_username = "azureuser"
}

build {
  name    = "azure-ubuntu-2204"
  sources = [
    "source.azure-arm.ubuntu2204",
  ]

  provisioner "ansible" {
    playbook_file = "../ansible/site.yml"
    user          = "azureuser"
    extra_arguments = [
      "--extra-vars",
      "ssh_github_user=${var.ssh_github_user} cloud_provider=azure target_ssh_user=azureuser",
    ]
  }
}
