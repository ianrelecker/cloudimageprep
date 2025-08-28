terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_ssm_parameter" "ami" {
  count = var.ami_id == "" ? 1 : 0
  name  = var.ssm_parameter_path
}

locals {
  effective_ami_id = var.ami_id != "" ? var.ami_id : data.aws_ssm_parameter.ami[0].value
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

resource "aws_security_group" "rdp" {
  name        = "${var.project_name}-rdp"
  description = "Allow RDP access"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "RDP"
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = [var.rdp_ingress_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_instance" "this" {
  ami                    = local.effective_ami_id
  instance_type          = var.instance_type
  subnet_id              = data.aws_subnets.default.ids[0]
  vpc_security_group_ids = [aws_security_group.rdp.id]

  # Optionally specify a key pair if you intend to fetch the Windows password
  key_name = var.key_name

  # Optionally attach an IAM instance profile (e.g., for SSM Session Manager)
  iam_instance_profile = var.iam_instance_profile

  tags = {
    Name        = "${var.project_name}-ec2-windows"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}
