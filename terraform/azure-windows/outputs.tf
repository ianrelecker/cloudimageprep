output "vm_id" {
  description = "ID of the Azure Windows VM"
  value       = azurerm_windows_virtual_machine.this.id
}

output "public_ip" {
  description = "Public IP address of the VM"
  value       = azurerm_public_ip.this.ip_address
}

output "image_id" {
  description = "Managed image ID used for the VM"
  value       = local.effective_image_id
}

output "admin_username" {
  description = "Admin username for RDP"
  value       = var.admin_username
}

output "admin_password" {
  description = "Admin password (generated if not provided)"
  value       = local.effective_password
  sensitive   = true
}

