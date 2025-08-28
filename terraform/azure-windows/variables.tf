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
  default     = "cloudprep-winvm"
}

variable "vnet_cidr" {
  description = "CIDR for the virtual network"
  type        = string
  default     = "10.20.0.0/16"
}

variable "subnet_cidr" {
  description = "CIDR for the subnet"
  type        = string
  default     = "10.20.1.0/24"
}

variable "vm_size" {
  description = "Azure VM size"
  type        = string
  default     = "Standard_D2s_v4"
}

variable "admin_username" {
  description = "Admin username for the Windows VM"
  type        = string
  default     = "winadmin"
}

variable "admin_password" {
  description = "Admin password for the Windows VM (leave empty to auto-generate)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "rdp_ingress_cidr" {
  description = "CIDR allowed to RDP into the VM"
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

variable "ssh_github_user" {
  description = "(Optional) GitHub username to fetch SSH keys; unused for Windows auth but kept for parity/logging"
  type        = string
  default     = ""
}

