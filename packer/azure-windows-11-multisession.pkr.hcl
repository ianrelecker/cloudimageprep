// Azure Windows 11 Enterprise multi-session managed image via azure-arm

source "azure-arm" "win11_multisession" {
  # Auth via Azure CLI context
  use_azure_cli_auth = true

  location                               = var.azure_location
  vm_size                                = var.azure_vm_size
  managed_image_name                     = "${var.azure_image_name_prefix}-win11-multisession-{{timestamp}}"
  managed_image_resource_group_name      = var.azure_image_resource_group

  # Base image: Windows 11 Enterprise multi-session (Azure Virtual Desktop)
  os_type         = "Windows"
  image_publisher = "MicrosoftWindowsDesktop"
  image_offer     = "windows-11"
  # 24H2 multi-session SKU (verify availability in your region)
  image_sku       = "win11-24h2-avd"

  # Tags specific to this image (don't reuse local.common_tags since it sets OS=ubuntu)
  azure_tags = {
    Project     = var.project_name,
    Environment = var.environment,
    ManagedBy   = "packer",
    OS          = "windows",
    Release     = "11-multisession",
  }

  # WinRM communicator for Windows provisioning
  communicator           = "winrm"
  winrm_use_ssl          = true
  winrm_insecure         = true
  winrm_timeout          = "30m"
  winrm_username         = "packer"
  winrm_password         = var.winrm_password

  # Sysprep is handled automatically by the azure-arm builder for Windows images.
}

build {
  name    = "azure-windows-11-multisession"
  sources = [
    "source.azure-arm.win11_multisession",
  ]

  # Apply Windows Updates (requires windows-update provisioner plugin)
  provisioner "windows-update" {
    search_criteria = "IsInstalled=0 and Type='Software'"
    filters = [
      "exclude:$_.Title -like '*Preview*'",
      "exclude:$_.Title -like '*Preview*'",
    ]
    update_limit = 25
    restart_timeout = "60m"
  }

  # Minimal hardening and RDP enable
  provisioner "powershell" {
    inline = [
      "Set-ExecutionPolicy Bypass -Scope LocalMachine -Force",
      "Enable-NetFirewallRule -DisplayGroup 'Remote Desktop'",
      "Set-ItemProperty -Path 'HKLM:\\System\\CurrentControlSet\\Control\\Terminal Server' -Name 'fDenyTSConnections' -Value 0",
      "Set-Service -Name WinRM -StartupType Automatic",
      "Restart-Service WinRM -ErrorAction SilentlyContinue",
    ]
  }

  # Output the managed image resource ID to the CLI (easy to parse)
  post-processors {
    post-processor "shell-local" {
      inline = [
        "set -euo pipefail",
        "ART='{{ .ArtifactId }}'",
        "# Try to extract ARM resource ID from ArtifactId; fallback to raw value",
        "IMG_ID=$(echo \"$ART\" | grep -Eo '/subscriptions/[^ ]+' || true)",
        "[ -n \"$IMG_ID\" ] || IMG_ID=\"$ART\"",
        "echo Managed image resource ID: $IMG_ID",
        "echo MANAGED_IMAGE_ID=$IMG_ID",
      ]
    }
  }
}
