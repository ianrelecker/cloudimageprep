output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.this.id
}

output "public_ip" {
  description = "Public IP of the EC2 instance"
  value       = aws_instance.this.public_ip
}

output "ami_id" {
  description = "AMI ID used for the instance"
  value       = local.effective_ami_id
}
