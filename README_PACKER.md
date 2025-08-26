# Packer Image: AWS (Ubuntu 22.04)

Build a hardened-ish Ubuntu 22.04 AMI for AWS using Packer + Ansible.

## Layout
- `packer/` — HCL template, variables, defaults
- `ansible/` — Ansible playbook and roles (base + aws)
- `.github/workflows/packer-validate.yml` — PR validation for Packer templates
- `ci/aws-packer-policy.json` — Example IAM policy for the GitHub Actions role

## Defaults
- Distro: Ubuntu 22.04 LTS (jammy), x86_64
- Region: AWS `us-west-2`
- Disk: 30GB (`gp3`)
- Provisioning: updates, SSH hardening, GitHub key for `ubuntu`, SSM Agent enabled

## Prereqs
- Packer >= 1.9 (run `packer init .` before validate/build)
- Ansible installed locally (host provisioner)
  - macOS: `brew install ansible`
  - Or `pipx install ansible-core` then `pipx ensurepath`
  - Verify: `ansible-playbook --version`
- AWS credentials with EC2 image build perms (see `ci/aws-packer-policy.json`)

## Build Locally
```
cd packer
packer init .
packer validate .

# Build (use glob or full build ID)
PACKER_VAR_ssh_github_user=ianrelecker \
  packer build -only='aws-ubuntu-2204.*' .
```

Tips:
- Full build ID: `aws-ubuntu-2204.amazon-ebs.ubuntu2204`
- Ensure AWS creds are set (e.g., `AWS_PROFILE=...` or `aws configure`).

Variables default to `packer/default.auto.pkrvars.hcl`. Override with env `PACKER_VAR_*` or `-var`.

## Use AMI with Terraform
Terraform config lives in `terraform/`. You can either:
- Pass the AMI directly: `terraform apply -var ami_id=ami-xxxxxxxxxxxxxxxxx`
- Or publish to SSM and have Terraform read that path.

To publish the AMI ID to AWS Systems Manager Parameter Store after a successful build:

```
aws ssm put-parameter \
  --name /images/ubuntu2204/current \
  --type String \
  --overwrite \
  --value ami-xxxxxxxxxxxxxxxxx
```

Replace the AMI value with the ID from your build. Then run Terraform from `terraform/`.

Troubleshooting
- If Terraform errors with `reading SSM Parameter ... couldn't find resource`, either publish the AMI to SSM as shown above or pass it directly via `-var ami_id=ami-xxxxxxxxxxxxxxxxx`.

## CI (GitHub Actions)
- `Packer Validate` runs on PRs touching `packer/**` or `ansible/**`.
- There is no automated build in CI. Images are built locally using the steps above.

Note on PRs from forks: for security, GitHub does not expose repository secrets to forked PRs. Validation does not require cloud credentials, but builds must be run locally by maintainers.

## Troubleshooting
- `No builds to run`: use `-only='aws-ubuntu-2204.*'` or the full ID.
- `ansible-playbook` not found: install Ansible, re-run `packer init` and `packer validate`.

## Using ansible-local (optional)
If you prefer not to install Ansible locally, change the provisioner in `packer/aws-ubuntu-2204.pkr.hcl` from:

```
provisioner "ansible" { ... }
```

to:

```
provisioner "ansible-local" {
  playbook_file = "../ansible/site.yml"
  extra_arguments = [
    "--extra-vars",
    "ssh_github_user=${var.ssh_github_user}",
  ]
}
```

Note: `ansible-local` runs inside the build VM, slightly increasing build time. Ansible itself is not baked into the final AMI unless added by a role.

## Clean Up
- Deregister AMIs and delete associated snapshots if not needed.
