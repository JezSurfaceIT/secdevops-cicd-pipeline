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

variable "tags" {
  description = "Resource tags"
  type        = map(string)
}

variable "jenkins_public_ip" {
  description = "Public IP of Jenkins VM for network rules"
  type        = string
}

variable "geo_replication_location" {
  description = "Location for geo-replication"
  type        = string
  default     = "northeurope"
}

variable "retention_days" {
  description = "Days to retain untagged images"
  type        = number
  default     = 30
}