# Terraform: Launch EC2 from Published AMI

This Terraform config launches an EC2 instance using a CloudPrep AMI.

You can provide the AMI in two ways:
- From SSM Parameter Store at a path (default: `/images/ubuntu2204/current`).
- Directly via the `ami_id` variable (no SSM required).

## Prereqs
- Terraform >= 1.5
- AWS credentials configured (`AWS_PROFILE` or `aws configure`)
- AMI available (either publish to SSM or pass `-var ami_id=...`).

To publish to SSM after a local Packer build (replace `ami-xxxx`):

```
aws ssm put-parameter \
  --name /images/ubuntu2204/current \
  --type String \
  --overwrite \
  --value ami-xxxxxxxxxxxxxxxxx
```

## Usage

Option A — SSM Parameter
```
cd terraform
terraform init
terraform apply \
  -var aws_region=us-west-2 \
  -var ssm_parameter_path=/images/ubuntu2204/current
```

Option B — Direct AMI ID
```
cd terraform
terraform init
terraform apply \
  -var aws_region=us-west-2 \
  -var ami_id=ami-xxxxxxxxxxxxxxxxx
```

Variables you can override:
- `aws_region` (default `us-west-2`)
- `ssm_parameter_path` (default `/images/ubuntu2204/current`)
- `ami_id` (default empty; when set, skips SSM lookup)
- `instance_type` (default `t3.small`)
- `ssh_ingress_cidr` (default `0.0.0.0/0`)

Outputs:
- `instance_id`, `public_ip`, `ami_id`

Notes:
- If both `ami_id` and `ssm_parameter_path` are provided, `ami_id` takes precedence.
- Deploys into the default VPC and first available subnet; adjust as needed.
- Opens SSH (port 22) from `ssh_ingress_cidr` (defaults to `0.0.0.0/0`). Set this to your IP/CIDR in real use.

Troubleshooting:
- Error: `reading SSM Parameter ... couldn't find resource` — Either create the SSM parameter (see command above) or pass the AMI directly with `-var ami_id=...`.
