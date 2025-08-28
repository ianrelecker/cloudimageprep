## Azure Windows VM (from Managed Image)

Deploy a Windows VM from an Azure Managed Image built by Packer (Windows 11 Enterprise multi-session 24H2 or Windows Server 2022).

### Prereqs
- Azure CLI logged in and correct subscription selected: `az login && az account set -s <subscription>`
- Managed Image exists (built via Packer) and you have its Resource ID (e.g., `/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.Compute/images/<name>`)

### Quickstart
1) (Optional) Build an image with Packer and capture its ID:
```
# Windows 11 Enterprise multi-session 24H2
cd packer
packer build -only='azure-windows-11-multisession.*' . | tee build.log
ID=$(awk -F= '/^MANAGED_IMAGE_ID=/{print $2}' build.log | tail -n1)

# OR Windows Server 2022 Datacenter Gen2
packer build -only='azure-windows-server-2022.*' . | tee build.log
ID=$(awk -F= '/^MANAGED_IMAGE_ID=/{print $2}' build.log | tail -n1)
```

2) Apply Terraform using the Managed Image ID:
```
cd terraform/azure-windows
terraform init
terraform apply \
  -var location=eastus2 \
  -var resource_group_name=cloudprep-winvm \
  -var managed_image_id="$ID" \
  -var rdp_ingress_cidr=0.0.0.0/0 \
  -var admin_username=winadmin
# You can also set -var admin_password="<YourStrong!Passw0rd>" to avoid auto-generation.
```

3) Outputs
- `public_ip`: Public IP for RDP
- `admin_username`: Username for RDP
- `admin_password`: Generated if you didn’t provide one (sensitive output)

### Alternatives
- If you don’t have the full image ID, you can provide:
  - `-var managed_image_name=<image-name>` and `-var managed_image_resource_group=<rg-name>`
- Restrict RDP access by setting a specific CIDR: `-var rdp_ingress_cidr=203.0.113.0/32`

### Notes
- This module uses `azurerm_windows_virtual_machine` with VM Agent and automatic updates enabled.
- Ensure the VM size you choose supports your image (Gen2, etc.).
