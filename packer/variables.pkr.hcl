variable "project_name" {
  type        = string
  description = "Project or org name for tagging"
  default     = "cloudprep"
}

variable "environment" {
  type        = string
  description = "Environment tag (dev/stage/prod)"
  default     = "dev"
}

variable "aws_region" {
  type        = string
  description = "AWS region to build in"
  default     = "us-west-2"
}

variable "ubuntu_release" {
  type        = string
  description = "Ubuntu release codename"
  default     = "jammy"
}

variable "disk_size" {
  type        = number
  description = "OS disk size in GB"
  default     = 30
}

variable "ebs_type" {
  type        = string
  description = "AWS EBS volume type"
  default     = "gp3"
}

variable "ami_encrypted" {
  type        = bool
  description = "Encrypt EBS volumes for AMI"
  default     = true
}

variable "instance_type" {
  type        = string
  description = "Temporary builder instance type"
  default     = "t3.small"
}

variable "ssh_github_user" {
  type        = string
  description = "GitHub username to pull SSH keys from"
  default     = "ianrelecker"
}

variable "image_name_prefix" {
  type        = string
  description = "Prefix for image names"
  default     = "cloudprep"
}

variable "build_tags" {
  type = map(string)
  description = "Additional tags/labels to apply to images"
  default = {}
}

locals {
  common_tags = merge({
    Project     = var.project_name,
    Environment = var.environment,
    ManagedBy   = "packer",
    OS          = "ubuntu",
    Release     = var.ubuntu_release,
  }, var.build_tags)
}

// Azure-specific variables
variable "azure_location" {
  type        = string
  description = "Azure region to build in"
  default     = "eastus2"
}

variable "azure_image_resource_group" {
  type        = string
  description = "Resource group where the managed image will be stored"
  default     = "cloudprep-images"
}

variable "azure_vm_size" {
  type        = string
  description = "Temporary builder VM size"
  default     = "Standard_B2s"
}

variable "azure_image_name_prefix" {
  type        = string
  description = "Prefix for Azure managed image names"
  default     = "cloudprep"
}
