project_name       = "cloudprep"
environment        = "dev"
aws_region         = "us-west-2"
ubuntu_release     = "jammy"
disk_size          = 30
ebs_type           = "gp3"
ami_encrypted      = true
instance_type      = "t3.small"
ssh_github_user    = "ianrelecker"
image_name_prefix  = "cloudprep"

# Azure defaults
azure_location              = "eastus2"
azure_image_resource_group  = "cloudprep-images"
azure_vm_size               = "Standard_B2s"
azure_image_name_prefix     = "cloudprep"
