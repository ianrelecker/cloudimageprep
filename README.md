# CloudPrep

Build and launch a hardened-ish Ubuntu 22.04 AMI on AWS using Packer + Ansible, and deploy an EC2 instance with Terraform. CI validates Packer templates on pull requests.

## Repo Layout
- `packer/`: Packer HCL templates, variables, versions.
- `ansible/`: Ansible playbook and roles used during the AMI build.
- `terraform/`: Terraform to launch an EC2 instance from the built AMI.
- `.github/workflows/packer-validate.yml`: GitHub Actions workflow to run `packer init` and `packer validate` on PRs.
- `ci/aws-oidc-trust-policy.json`: Example AWS IAM OIDC trust policy for GitHub Actions.
- `README_PACKER.md`: Additional Packer-focused documentation and tips.

## Quickstart

### Prerequisites
- AWS credentials with permissions to build AMIs and launch EC2.
- Packer >= 1.9 (install and run `packer init` before build).
- Ansible available locally (for the `ansible` provisioner):
  - macOS: `brew install ansible` or `pipx install ansible-core`.
- Terraform >= 1.5 (to launch an instance from the AMI).

### 1) Build the AMI with Packer
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

Optional: Publish the resulting AMI ID to SSM Parameter Store so Terraform can discover it by path:
```
aws ssm put-parameter \
  --name /images/ubuntu2204/current \
  --type String \
  --overwrite \
  --value ami-xxxxxxxxxxxxxxxxx
```

### 2) Launch an EC2 instance with Terraform
Pick one of the two options:

Option A — Use SSM Parameter path (default `/images/ubuntu2204/current`):
```
cd terraform
terraform init
terraform apply \
  -var aws_region=us-west-2 \
  -var ssm_parameter_path=/images/ubuntu2204/current
```

Option B — Pass the AMI directly (no SSM required):
```
cd terraform
terraform init
terraform apply \
  -var aws_region=us-west-2 \
  -var ami_id=ami-xxxxxxxxxxxxxxxxx
```

Outputs include the instance ID, public IP, and the AMI ID used. The stack deploys into the default VPC and opens SSH (22/TCP) from `ssh_ingress_cidr` (defaults to `0.0.0.0/0` — change this for real use).

## What Gets Baked Into the AMI
Provisioning is handled by Ansible roles in `ansible/roles`:
- `base` role: apt update/upgrade, common tools (`curl`, `jq`, `git`, etc.), adds GitHub public keys for the `ubuntu` user (`ssh_github_user` var), and tightens SSH (no root login, no password auth).
- `aws` role: installs and enables the Amazon SSM Agent via snap.

These defaults aim for secure-by-default access via SSM + SSH keys.

## Configuration and Customization
- Packer variables: see `packer/variables.pkr.hcl` and override via `PACKER_VAR_*` env vars or `-var` flags.
- Ansible: edit or add roles under `ansible/roles`, and update `ansible/site.yml` to include them.
- Terraform variables: see `terraform/variables.tf` (region, instance type, tags, SSM path, SSH CIDR, AMI override).

## CI: Packer Validate
- `.github/workflows/packer-validate.yml` runs on PRs that touch `packer/**` or `ansible/**`.
- It installs Packer + Ansible, runs `packer init` and `packer validate`.
- Use `ci/aws-oidc-trust-policy.json` as a starting point to allow GitHub Actions to assume an AWS role via OIDC if you add workflows that need cloud access.

## Notes
- Terraform state: `.gitignore` excludes `*.tfstate`, but `terraform/terraform.tfstate` and its backup are currently checked in. In real projects, remove them from version control and use a remote backend or keep state local and ignored.
- Clean up unused AMIs/snapshots to avoid charges when experimenting.

## More Docs
- Packer details and troubleshooting: see `README_PACKER.md`.
- Terraform usage notes: see `terraform/README.md`.
