# CloudPrep

Build and launch a hardened-ish Ubuntu 22.04 image on AWS (AMI) or Azure (Managed Image) using Packer + Ansible. Optionally deploy an EC2 instance with Terraform. CI validates Packer templates on pull requests.

## Repo Layout
- `packer/`: Packer HCL templates, variables, versions (AWS and Azure).
- `ansible/`: Ansible playbook and roles used during the AMI build.
- `terraform/aws-linux`: Terraform to launch a Linux EC2 instance from the built AMI.
- `terraform/aws-windows`: Terraform to launch a Windows Server EC2 instance (from AMI/SSM path).
- `terraform/azure`: Terraform to launch an Azure Linux VM from the built Managed Image.
- `terraform/azure-windows`: Terraform to launch an Azure Windows VM from a Managed Image.
- `.github/workflows/packer-validate.yml`: GitHub Actions workflow to run `packer init` and `packer validate` on PRs.

## Quickstart

### Prerequisites
- AWS credentials with permissions to build AMIs and launch EC2.
- Packer >= 1.9 (install and run `packer init` before build).
- Ansible available locally (for the `ansible` provisioner).
- Terraform >= 1.5 (to launch an instance from the AMI).

### 1A) Build the AWS AMI with Packer
```
cd packer
packer init .
packer validate .

# Build (set your GitHub username to fetch your SSH keys into the ubuntu user)
PACKER_VAR_ssh_github_user=<your-github-username> \
  packer build -only='aws-ubuntu-2204.*' .
```
- The build uses the latest Canonical Ubuntu 22.04 (jammy) image as a base.
- Variables have sensible defaults in `packer/default.auto.pkrvars.hcl` (region, instance type, disk, encryption, tags).
- During provisioning, the `ansible/site.yml` playbook runs the `base` and `aws` roles.

Windows (Server 2022) build:
```
cd packer
packer init .
packer validate .

# Ensure the builder has an SSM-enabled IAM Instance Profile, then run:
packer build -var 'ssm_iam_instance_profile=PackerSSMProfile' -only='aws-windows-2022.*' .
```
- Uses the latest “Windows Server 2022 English Full Base” image as a parent.
 - By default, provisioning runs via AWS Systems Manager (SSM) instead of WinRM. The builder instance must have an IAM instance profile with the `AmazonSSMManagedInstanceCore` policy. See “Create SSM IAM Instance Profile” below.
- Windows Updates are applied using the SSM document `AWS-RunPatchBaseline` (Operation=Install, RebootIfNeeded); after updates, a small SSM PowerShell step enables the RDP firewall group and ensures the SSM Agent starts automatically.
- Consider publishing the resulting Windows AMI ID to a separate SSM path, e.g., `/images/windows2022/current`.
 - Automatic publish: set `PACKER_VAR_ssm_publish_path=/images/windows2022/current` to have the build publish the resulting AMI ID to SSM automatically.

Create SSM IAM Instance Profile (one-time):
```
# 1) Create role with EC2 trust policy
aws iam create-role --role-name PackerSSMRole \
  --assume-role-policy-document '{
    "Version":"2012-10-17",
    "Statement":[
      {
        "Effect":"Allow",
        "Principal":{"Service":"ec2.amazonaws.com"},
        "Action":"sts:AssumeRole"
      }
    ]
  }'

# 2) Attach managed SSM policy (AmazonSSMManagedInstanceCore)
aws iam attach-role-policy --role-name PackerSSMRole \
  --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore

# 3) Create instance profile and add the role to it
aws iam create-instance-profile --instance-profile-name PackerSSMProfile
aws iam add-role-to-instance-profile --instance-profile-name PackerSSMProfile --role-name PackerSSMRole

# 4) (Optional) Verify
aws iam get-role --role-name PackerSSMRole
aws iam list-attached-role-policies --role-name PackerSSMRole
aws iam get-instance-profile --instance-profile-name PackerSSMProfile

# 5) Build Windows image using the instance profile
cd packer
packer build -var 'ssm_iam_instance_profile=PackerSSMProfile' -only='aws-windows-2022.*' .

# 6) (Optional) Persist in packer/default.auto.pkrvars.hcl instead of -var flag
# ssm_iam_instance_profile = "PackerSSMProfile"
```

Optional: Publish the resulting AMI ID to SSM Parameter Store so Terraform can discover it by path:
```
aws ssm put-parameter \
  --name /images/ubuntu2204/current \
  --type String \
  --overwrite \
  --value ami-xxxxxxxxxxxxxxxxx
```

### 1B) Build the Azure Managed Image with Packer (Gen2)
Prereq: Azure CLI logged in to the target subscription (`az login` and `az account set -s <subscription>`).
```
cd packer
packer init .
packer validate .

# Build (set your GitHub username to fetch your SSH keys into the azureuser account)
PACKER_VAR_ssh_github_user=<your-github-username> \
  packer build -only='azure-ubuntu-2204.*' .
```

- Notes:
- The Azure builder uses Azure CLI auth (`use_azure_cli_auth = true`).
- The Azure image is built as Hyper-V Generation 2 and uses Canonical's Gen2 Ubuntu 22.04 LTS SKU (`22_04-lts-gen2`). This is required if you plan to run on newer VM families like Dv5/Dsv5/Dv6/Dsv6.
- Always run builds from the `packer/` folder with `.` (don’t pass a single `.pkr.hcl` file), so shared variables/locals are loaded.
- The managed image is created in the resource group set by `azure_image_resource_group` (default `cloudprep-images`). This resource group must exist before the build starts (Packer’s Azure builder does not create the managed image RG). Create it once in your subscription:
```
az group create -n cloudprep-images -l eastus2
```
- Alternatively, override the RG and/or location for the build:
```
PACKER_VAR_ssh_github_user=<you> \
  PACKER_VAR_azure_image_resource_group=<existing-rg> \
  PACKER_VAR_azure_location=<region> \
  packer build -only='azure-ubuntu-2204.*' .
```
SSH hardening and keys:
- During provisioning, the base role fetches GitHub public keys for `ssh_github_user` and authorizes them for the `azureuser` account (set via `target_ssh_user=azureuser`). After boot, SSH as `azureuser` using the private key corresponding to your GitHub public key.
- SSH password authentication is disabled and root login is prohibited, mirroring the AWS image configuration.
- Optional parity on Terraform: Azure Terraform can also fetch GitHub keys at apply time (`-var ssh_github_user=<you>`), but this is not required since keys are already baked into the image.
Note: This image resource group is separate from the Terraform Azure resource group (`resource_group_name`, default `cloudprep-vm`) where the VM and networking are created.

### 2A) Launch an EC2 instance with Terraform (AWS)
Pick one of the two options:

Option A — Use SSM Parameter path (default `/images/ubuntu2204/current`):
```
cd terraform/aws-linux
terraform init
terraform apply \
  -var aws_region=us-west-2 \
  -var ssm_parameter_path=/images/ubuntu2204/current
```

Option B — Pass the AMI directly (no SSM required):
```
cd terraform/aws-linux
terraform init
terraform apply \
  -var aws_region=us-west-2 \
  -var ami_id=ami-xxxxxxxxxxxxxxxxx
```

### 2B) Launch an Azure VM with Terraform (Azure)
```
cd terraform/azure-linux
terraform init
terraform apply \
  -var location=eastus2 \
  -var resource_group_name=cloudprep-vm \
  -var managed_image_id=/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.Compute/images/<image-name> \
  -var ssh_github_user=<your-github-username>
```

Outputs include the instance ID, public IP, and the AMI ID used. The stack deploys into the default VPC and opens SSH (22/TCP) from `ssh_ingress_cidr` (defaults to `0.0.0.0/0` — change this for real use).

For Windows instances, you will typically want to open RDP (3389/TCP) instead of SSH and use the `Administrator` account to log in. The provided Terraform module focuses on Linux; adapt the security group rule and AMI/SSM path when launching Windows.

Windows variant of Terraform (AWS):
```
cd terraform/aws-windows
terraform init
terraform apply \
  -var aws_region=us-west-2 \
  -var ssm_parameter_path=/images/windows2022/current
```
This opens RDP (3389/TCP) and launches from the Windows AMI ID found at the provided SSM path. Optionally set `-var key_name=<ec2-keypair>` if you plan to retrieve the Windows password via the AWS console/CLI.

## What Gets Baked Into the Image
Provisioning is handled by Ansible roles in `ansible/roles`:
- `base` role: apt update/upgrade, common tools (`curl`, `jq`, `git`, etc.), adds GitHub public keys for the target SSH user (`target_ssh_user`, set by Packer), and tightens SSH (no root login, no password auth).
- `aws` role: installs and enables the Amazon SSM Agent via snap. This runs only when `cloud_provider=aws` (automatically set by the Packer templates). It is skipped for Azure builds.

These defaults aim for secure-by-default access via SSM + SSH keys.

Windows AMI specifics:
- Packer variables: same as Linux for region, instance type, disk, encryption, and tags. Provisioning is orchestrated via SSM using local AWS CLI.
- Parent image: Windows Server 2022 English Full Base (most recent) filtered by name; the owner account ID is specified in the template and may vary by region — adjust if `packer build` fails to find an AMI.
- Windows Updates: executed during build with the SSM document `AWS-InstallWindowsUpdates`.

## Configuration and Customization
- Packer variables: see `packer/variables.pkr.hcl` and override via `PACKER_VAR_*` env vars or `-var` flags.
- Ansible: edit or add roles under `ansible/roles`, and update `ansible/site.yml` to include them.
- Terraform variables: see `terraform/aws-linux/variables.tf` and `terraform/azure-linux/variables.tf`.

Tip (image generation vs VM size): If you get an error like “cannot boot Hypervisor Generation '1'”, it means the managed image is Gen1 but the selected VM size only supports Gen2. Either rebuild the image as Gen2 (the provided Packer template does this by default), or choose a Gen1-compatible VM size.

## CI: Packer Validate
- `.github/workflows/packer-validate.yml` runs on PRs that touch `packer/**` or `ansible/**`.
- It installs Packer + Ansible, runs `packer init` and `packer validate`.
- If you plan to run cloud actions from CI, configure an AWS IAM role with GitHub OIDC trust in your account. Reference AWS docs for the trust policy; no example file is included in this repo.

## Troubleshooting
- AWS Packer: “No builds to run” — include `-only='aws-ubuntu-2204.*'` or the full build ID.
- Azure Packer: Make sure `az account show` returns the intended subscription and you have permission to create managed images in the target resource group.

## Azure Windows 11 Enterprise multi-session (24H2)

Build a Windows 11 Enterprise multi-session (Azure Virtual Desktop) managed image using the provided Packer template `packer/azure-windows-11-multisession.pkr.hcl`.

Prereqs:
- Azure CLI logged in and correct subscription selected: `az login && az account set -s <subscription>`
- Accept Marketplace image terms (one-time per subscription). Use the proper flags; note that `-o` is the output flag in `az`, not “offer”.

Accept image terms:
```
# By fields
az vm image terms accept \
  --publisher MicrosoftWindowsDesktop \
  --offer windows-11 \
  --sku win11-24h2-avd

# Or via URN
az vm image terms accept --urn MicrosoftWindowsDesktop:windows-11:win11-24h2-avd:latest
```

Discover available SKUs in your region (if 24H2 isn’t available):
```
az vm image list-skus \
  -l <region> \
  -f windows-11 \
  -p MicrosoftWindowsDesktop \
  --all -o table
```

Build the image:
```
cd packer
packer init .
packer validate .
packer build -only='azure-windows-11-multisession.*' .
```

The build prints the managed image resource ID as `MANAGED_IMAGE_ID=...` for easy parsing.

## Customizing Templates

- Packer — Azure Windows (Win11/Win2022):
  - Edit the `provisioner "windows-update"` and `provisioner "powershell"` inline steps in:
    - `packer/azure-windows-11-multisession.pkr.hcl`
    - `packer/azure-windows-server-2022.pkr.hcl`
  - Change base image via `image_publisher`, `image_offer`, `image_sku`.
  - The `post-processors` block prints `MANAGED_IMAGE_ID=...` — extend if you need more output.

- Packer — AWS Windows 2022:
  - Update the two `provisioner "shell-local"` blocks in `packer/aws-windows-2022.pkr.hcl`:
    - First: waits for SSM and runs `AWS-RunPatchBaseline` (Windows Update).
    - Second: runs your PowerShell commands through `AWS-RunPowerShellScript`.
  - For complex PowerShell, prefer a script file under `packer/scripts/` to avoid escaping issues.

- Packer — Ubuntu (AWS/Azure):
  - Provisioning via Ansible: change `ansible/site.yml` and roles under `ansible/roles/**`.
  - Templates: `packer/azure-ubuntu-2204.pkr.hcl`, `packer/aws-ubuntu-2204.pkr.hcl`.

- Packer — Shared config:
  - Variables: `packer/variables.pkr.hcl` and local defaults in `packer/default.auto.pkrvars.hcl`.
  - Plugin versions: `packer/versions.pkr.hcl`.

- Terraform — Azure Windows:
  - Module: `terraform/azure-windows/`.
  - Edit networking (NSG/VNet/subnet/PIP) and VM settings in `main.tf`.
  - Provide `managed_image_id` or `managed_image_name` + `managed_image_resource_group`.

- Terraform — AWS Windows:
  - Module: `terraform/aws-windows/`.
  - Edit instance type, RDP security group, optional `key_name` and `iam_instance_profile` in `main.tf`.
  - Provide `ami_id` or `ssm_parameter_path`.

- Validate after edits:
  - Packer: `cd packer && packer init . && packer validate .`
  - Terraform: `cd terraform/<module> && terraform init -backend=false && terraform validate`

## Azure Windows Server 2022

Build a Windows Server 2022 Datacenter Gen2 managed image, then launch a VM from it.

Accept image terms (one-time per subscription):
```
az vm image terms accept --publisher MicrosoftWindowsServer --offer WindowsServer --sku 2022-datacenter-g2
```

Build the image:
```
cd packer
packer init .
packer validate .
packer build -only='azure-windows-server-2022.*' .
```

Grab the managed image ID from output `MANAGED_IMAGE_ID=...` and launch a Windows VM with Terraform:
```
cd terraform/azure-windows
terraform init
terraform apply \
  -var location=eastus2 \
  -var resource_group_name=cloudprep-winvm \
  -var managed_image_id="/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.Compute/images/<image-name>"

# Terraform outputs the VM public IP, admin username, and a generated admin password (unless you supply one).
```
- Ansible not found: install Ansible locally, then re-run `packer init` and `packer validate`.

## Using ansible-local (optional)
If you prefer not to install Ansible locally, change the provisioner in the Packer templates from:

```
provisioner "ansible" { ... }
```

to:

```
provisioner "ansible-local" {
  playbook_file = "../ansible/site.yml"
  extra_arguments = [
    "--extra-vars",
    "ssh_github_user=${var.ssh_github_user} cloud_provider=<aws|azure>",
  ]
}
```

Note: `ansible-local` runs inside the build VM, slightly increasing build time. Ansible itself is not baked into the final image unless added by a role.

## Notes
- Terraform state: `.gitignore` excludes `*.tfstate`, but `terraform/terraform.tfstate` and its backup are currently checked in. In real projects, remove them from version control and use a remote backend or keep state local and ignored.
- Clean up unused AMIs/snapshots to avoid charges when experimenting.

## More Docs
- Terraform usage notes: see `terraform/aws-linux/README.md` and `terraform/azure-linux/README.md`.
