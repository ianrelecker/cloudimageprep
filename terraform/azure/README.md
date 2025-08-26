# Terraform (Azure): Launch VM from Managed Image

This Terraform config launches an Azure Linux VM using a Managed Image built by Packer.

You can provide the image in two ways:
- Direct `managed_image_id` (preferred and unambiguous).
- Or by `managed_image_name` + `managed_image_resource_group`.

## Prereqs
- Terraform >= 1.5
- Azure CLI authenticated (`az login`) and targeting the desired subscription (`az account set -s <subscription>`)
- A managed image available (see Packer build under `packer/azure-ubuntu-2204.pkr.hcl`).
- SSH access:
  - The image already includes GitHub public keys for the user specified during Packer build (`PACKER_VAR_ssh_github_user`) authorized for `azureuser`.
  - Azure requires at least one SSH public key be provided at VM creation when password auth is disabled. To satisfy the API without changing your intended access, provide the same key at apply time by passing your GitHub username (Terraform fetches your public keys) or a specific public key:
    - `-var ssh_github_user=<you>`
    - or `-var admin_ssh_public_key="$(cat ~/.ssh/id_rsa.pub)"`
  - This mirrors what’s already in the image. SSH as `azureuser` with your private key.
- Ensure the Packer managed image resource group exists before building (default `cloudprep-images`):
  - `az group create -n cloudprep-images -l eastus2`

## Usage
Option A — Managed Image ID
```
cd terraform/azure
terraform init
terraform apply \
  -var location=eastus2 \
  -var resource_group_name=cloudprep-vm \
  -var managed_image_id=/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.Compute/images/<image-name> \
  -var ssh_github_user=<your-github-username>
```

Option B — Managed Image by Name
```
cd terraform/azure
terraform init
terraform apply \
  -var location=eastus2 \
  -var resource_group_name=cloudprep-vm \
  -var managed_image_name=<image-name> \
  -var managed_image_resource_group=<image-rg> \
  -var ssh_github_user=<your-github-username>
```

Variables you can override:
- `subscription_id` (optional; auto-detected from Azure CLI when empty)
- `location` (default `eastus2`)
- `resource_group_name` (default `cloudprep-vm`)
- `vm_size` (default `Standard_D2s_v4`)
- `disk_controller_type` (default `SCSI`; set `NVMe` if your image supports NVMe OS disk and you're using Dv6/Dsv6)
- `ssh_ingress_cidr` (default `0.0.0.0/0`; restrict for real use)
- `admin_username` (default `azureuser`)
- `admin_ssh_public_key` (optional when `ssh_github_user` is set)
- `ssh_github_user` (GitHub username for auto key fetch)

Outputs:
- `vm_id`, `public_ip`, `image_id`

Notes:
- Creates its own VNet/Subnet, Public IP, NSG with SSH rule, NIC, and a Linux VM.
- Ensure the managed image exists. Packer stores the managed image in the image resource group configured via Packer (`azure_image_resource_group`, default `cloudprep-images`).
- The Terraform `resource_group_name` is separate: it is where the VM and network resources are created (default `cloudprep-vm`, created by Terraform).
- VM size vs image generation: Dv5/Dsv5/Dv6/Dsv6 families require Gen2 images. The provided Packer template builds a Gen2 managed image using Canonical's `22_04-lts-gen2` SKU. If you point Terraform at a Gen1 image, you'll see a Hypervisor Generation error.
 - Disk controller: Newer sizes (e.g., Dv6/Dsv6) may require `NVMe` OS disk controllers. Custom managed images often default to SCSI; if your image does not support NVMe OS disk you'll see an error. Use `-var disk_controller_type=SCSI` with v5 sizes, or rebuild/publish an NVMe-capable image and set `-var disk_controller_type=NVMe` for v6.
- If you still see a subscription error, verify your Azure CLI context:
  - `az account show` and `az account set -s <subscription>`
  - or set environment variable `ARM_SUBSCRIPTION_ID` before `terraform apply`.
