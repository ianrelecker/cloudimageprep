variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-west-2"
}

variable "ssm_parameter_path" {
  description = "SSM Parameter Store path containing the AMI ID"
  type        = string
  default     = "/images/ubuntu2204/current"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.small"
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

variable "ssh_ingress_cidr" {
  description = "CIDR allowed to SSH into the instance"
  type        = string
  default     = "0.0.0.0/0"
}

variable "ami_id" {
  description = "Override AMI ID to use (skips SSM lookup when set)"
  type        = string
  default     = ""
}
