variable "environment" {
  description = "Environment name"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "subnet_id" {
  description = "ID of the subnet for the VM"
  type        = string
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
}

variable "ssh_public_key_path" {
  description = "Path to SSH public key file"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "vm_size" {
  description = "Size of the virtual machine"
  type        = string
  default     = "Standard_D4s_v3"
}

variable "backup_resource_group_name" {
  description = "Resource group name for backup vault"
  type        = string
  default     = ""
}

variable "recovery_vault_name" {
  description = "Name of the recovery vault"
  type        = string
  default     = ""
}

variable "backup_policy_id" {
  description = "ID of the backup policy"
  type        = string
  default     = ""
}