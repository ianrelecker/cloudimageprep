output "vm_id" {
  description = "ID of the Azure VM"
  value       = azurerm_linux_virtual_machine.this.id
}

output "public_ip" {
  description = "Public IP address of the VM"
  value       = azurerm_public_ip.this.ip_address
}

output "image_id" {
  description = "Managed image ID used for the VM"
  value       = local.effective_image_id
}

