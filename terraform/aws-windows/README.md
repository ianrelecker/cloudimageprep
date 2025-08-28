## AWS Windows Server VM (from AMI)

Launch a Windows Server EC2 instance using either an AMI ID or an SSM Parameter Store path that contains the AMI ID (e.g., published by your Packer build).

### Prereqs
- AWS credentials configured (e.g., via `aws configure` or environment vars)
- Target VPC has a default subnet (module uses the default VPC + first subnet)

### Option A — Use SSM Parameter path (recommended)
```
cd terraform/aws-windows
terraform init
terraform apply \
  -var aws_region=us-west-2 \
  -var ssm_parameter_path=/images/windows2022/current
```

### Option B — Pass AMI ID directly
```
cd terraform/aws-windows
terraform init
terraform apply \
  -var aws_region=us-west-2 \
  -var ami_id=ami-xxxxxxxxxxxxxxxxx
```

### Useful variables
- `instance_type`: EC2 type (default `t3.large`).
- `rdp_ingress_cidr`: CIDR allowed for RDP (default `0.0.0.0/0`; restrict in real use).
- `key_name`: Optional EC2 key pair to allow retrieving the Windows password.
- `iam_instance_profile`: Optional profile to enable SSM Session Manager, etc.

### Retrieve Windows password (if `key_name` set)
- Console: Select the instance → Connect → RDP client → Get password → upload your private key.
- CLI example:
```
aws ec2 get-password-data \
  --region us-west-2 \
  --instance-id <i-xxxx> \
  --priv-launch-key /path/to/your-private-key.pem \
  --query PasswordData \
  --output text
```

### Outputs
- `instance_id`: EC2 instance ID
- `public_ip`: Public IP for RDP (3389)
- `ami_id`: AMI ID used

