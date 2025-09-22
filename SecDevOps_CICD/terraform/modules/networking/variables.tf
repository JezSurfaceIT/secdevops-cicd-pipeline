variable "environment" {
  description = "Environment name"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "uksouth"
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
}

variable "admin_ip" {
  description = "Admin IP address for SSH and Jenkins access"
  type        = string
}