AWS Windows (RDP) variant

This variant launches an EC2 instance from a Windows AMI (e.g., Windows Server 2022), opens RDP (3389/TCP), and discovers the AMI from SSM by default.

Quickstart

```
cd terraform/aws-windows
terraform init
terraform apply \
  -var aws_region=us-west-2 \
  -var ssm_parameter_path=/images/windows2022/current
```

Notes

- Security group opens RDP (3389/TCP) from `rdp_ingress_cidr` (defaults to `0.0.0.0/0`). Tighten this in real environments.
- If your Windows AMI includes the Amazon SSM Agent (the provided Packer template ensures it runs), you can attach an instance profile with the `AmazonSSMManagedInstanceCore` policy to use Session Manager instead of RDP:
  - Create the role/profile once (see main README "Create SSM IAM Instance Profile").
  - Then pass it here: `-var iam_instance_profile=PackerSSMProfile`.
  - You may then set a restrictive `rdp_ingress_cidr` or remove RDP access entirely if you rely on Session Manager.
- If you need to use the classic Administrator password flow, specify an EC2 key pair on the instance and retrieve/decrypt the password from the AWS Console or CLI.
