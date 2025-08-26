// AWS Ubuntu 22.04 (jammy) AMI via amazon-ebs

source "amazon-ebs" "ubuntu2204" {
  region        = var.aws_region
  instance_type = var.instance_type
  ssh_username  = "ubuntu"

  ami_name        = "${var.image_name_prefix}-ubuntu2204-{{timestamp}}"
  ami_description = "${var.project_name} Ubuntu 22.04 LTS (jammy)"

  tags = merge(local.common_tags, {
    Name = "${var.image_name_prefix}-ubuntu2204"
  })

  run_tags = local.common_tags

  source_ami_filter {
    filters = {
      name                = "ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    owners      = ["099720109477"] // Canonical
    most_recent = true
  }

  launch_block_device_mappings {
    device_name = "/dev/sda1"
    volume_type = var.ebs_type
    volume_size = var.disk_size
    delete_on_termination = true
    encrypted   = var.ami_encrypted
  }
}

build {
  name    = "aws-ubuntu-2204"
  sources = [
    "source.amazon-ebs.ubuntu2204",
  ]

  provisioner "ansible" {
    playbook_file = "../ansible/site.yml"
    user          = "ubuntu"
    extra_arguments = [
      "--extra-vars",
      "ssh_github_user=${var.ssh_github_user} cloud_provider=aws target_ssh_user=ubuntu",
    ]
  }
}
