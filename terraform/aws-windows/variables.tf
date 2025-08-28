variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-west-2"
}

variable "ssm_parameter_path" {
  description = "SSM Parameter Store path containing the Windows AMI ID"
  type        = string
  default     = "/images/windows2022/current"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.large"
}

variable "project_name" {
  description = "Project name for tagging"
  type        = string
  default     = "cloudprep"
}

variable "environment" {
  description = "Environment tag (dev/stage/prod)"
  type        = string
  default     = "dev"
}

variable "rdp_ingress_cidr" {
  description = "CIDR allowed to RDP into the instance"
  type        = string
  default     = "0.0.0.0/0"
}

variable "ami_id" {
  description = "Override AMI ID to use (skips SSM lookup when set)"
  type        = string
  default     = ""
}

variable "key_name" {
  description = "Optional EC2 key pair name for retrieving the Windows password"
  type        = string
  default     = null
}

variable "iam_instance_profile" {
  description = "Optional IAM instance profile name to attach (e.g., enables AWS SSM Session Manager)"
  type        = string
  default     = null
}
