# This file contains variables describing networking required for cluster operation
## External network
variable "external_network-name" {
  type    = string
  default = "public"  # If required, replace the network name with the one you have in the cloud
}

# Do not change the variables below unless you know what you're doing
## Storage network
variable "storage_net-name" {
  description = "Storage network name"
  type        = string
  default     = "lab-storage"
}
variable "storage_net-cidr" {
  description = "Storage network name"
  type        = string
  default     = "10.0.100.0/24"
}

## Private network
variable "private_net-name" {
  description = "private network name"
  type        = string
  default = "lab-private"
}
variable "private_net-cidr" {
  description = "private network name"
  type        = string
  default     = "10.0.101.0/24"
}

## Public network
variable "public_net-name" {
  description = "public network name"
  type        = string
  default     = "lab-public"
}
variable "public_net-cidr" {
  description = "public network name"
  type        = string
  default     = "10.0.102.0/24"
}

## VM_Public network
variable "vm_public_net-name" {
  description = "vm_public network name"
  type        = string
  default = "lab-vm_public"
}
variable "vm_public_net-cidr" {
  description = "vm_public network name"
  type        = string
  default = "10.44.0.0/24"
}