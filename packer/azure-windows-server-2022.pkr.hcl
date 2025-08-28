// Azure Windows Server 2022 Datacenter (Gen2) managed image via azure-arm

source "azure-arm" "winserver2022" {
  use_azure_cli_auth = true

  location                          = var.azure_location
  vm_size                           = var.azure_vm_size
  managed_image_name                = "${var.azure_image_name_prefix}-winserver2022-{{timestamp}}"
  managed_image_resource_group_name = var.azure_image_resource_group

  os_type         = "Windows"
  image_publisher = "MicrosoftWindowsServer"
  image_offer     = "WindowsServer"
  # Gen2 SKU (verify availability in your region)
  image_sku       = "2022-datacenter-g2"

  azure_tags = {
    Project     = var.project_name,
    Environment = var.environment,
    ManagedBy   = "packer",
    OS          = "windows",
    Release     = "2022",
  }

  communicator   = "winrm"
  winrm_use_ssl  = true
  winrm_insecure = true
  winrm_timeout  = "30m"
  winrm_username = "packer"
  winrm_password = var.winrm_password
}

build {
  name    = "azure-windows-server-2022"
  sources = [
    "source.azure-arm.winserver2022",
  ]

  provisioner "windows-update" {
    search_criteria = "IsInstalled=0 and Type='Software'"
    filters         = [
      "exclude:$_.Title -like '*Preview*'",
    ]
    update_limit    = 25
    restart_timeout = "60m"
  }

  provisioner "powershell" {
    inline = [
      "Set-ExecutionPolicy Bypass -Scope LocalMachine -Force",
      "Enable-NetFirewallRule -DisplayGroup 'Remote Desktop'",
      "Set-ItemProperty -Path 'HKLM:\\System\\CurrentControlSet\\Control\\Terminal Server' -Name 'fDenyTSConnections' -Value 0",
      "Set-Service -Name WinRM -StartupType Automatic",
      "Restart-Service WinRM -ErrorAction SilentlyContinue",
    ]
  }

  post-processors {
    post-processor "shell-local" {
      inline = [
        "set -euo pipefail",
        "ART='{{ .ArtifactId }}'",
        "IMG_ID=$(echo \"$ART\" | grep -Eo '/subscriptions/[^ ]+' || true)",
        "[ -n \"$IMG_ID\" ] || IMG_ID=\"$ART\"",
        "echo Managed image resource ID: $IMG_ID",
        "echo MANAGED_IMAGE_ID=$IMG_ID",
      ]
    }
  }
}

