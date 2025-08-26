variable "subscription_id" {
  description = "Azure subscription ID to deploy into (uses Azure CLI auth)"
  type        = string
  default     = ""
}

variable "location" {
  description = "Azure location/region"
  type        = string
  default     = "eastus2"
}

variable "resource_group_name" {
  description = "Resource group to create for the VM and network"
  type        = string
  default     = "cloudprep-vm"
}

variable "vnet_cidr" {
  description = "CIDR for the virtual network"
  type        = string
  default     = "10.10.0.0/16"
}

variable "subnet_cidr" {
  description = "CIDR for the subnet"
  type        = string
  default     = "10.10.1.0/24"
}

variable "vm_size" {
  description = "Azure VM size"
  type        = string
  # Default to DSv4 family for SCSI-compatible Gen2 images
  default     = "Standard_D2s_v4"
}

variable "disk_controller_type" {
  description = "OS disk controller type for the VM (SCSI or NVMe)"
  type        = string
  default     = "SCSI"
  validation {
    condition     = contains(["SCSI", "NVMe"], var.disk_controller_type)
    error_message = "disk_controller_type must be either 'SCSI' or 'NVMe'."
  }
}

variable "admin_username" {
  description = "Admin username for the VM (should match image's SSH user)"
  type        = string
  default     = "azureuser"
}

variable "admin_ssh_public_key" {
  description = "SSH public key for admin user (contents of id_rsa.pub). Optional if ssh_github_user is set."
  type        = string
  default     = ""
}

variable "ssh_github_user" {
  description = "GitHub username whose public SSH keys will be fetched and authorized for admin user"
  type        = string
  default     = ""
}

variable "ssh_ingress_cidr" {
  description = "CIDR allowed to SSH into the VM"
  type        = string
  default     = "0.0.0.0/0"
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

variable "managed_image_id" {
  description = "ID of the managed image to use for the VM (preferred)"
  type        = string
  default     = ""
}

variable "managed_image_name" {
  description = "Name of the managed image (if not passing ID)"
  type        = string
  default     = ""
}

variable "managed_image_resource_group" {
  description = "Resource group of the managed image (if using name)"
  type        = string
  default     = ""
}
