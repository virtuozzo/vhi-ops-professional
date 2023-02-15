# NETWORK VARS
## Storage network
variable "storage_net_name" {
  description = "Storage network name"
  type        = string
  default     = "lab-storage"
}
variable "storage_net_cidr" {
  description = "Storage network name"
  type        = string
  default     = "10.0.100.0/24"
}

## Private network
variable "private_net_name" {
  description = "private network name"
  type        = string
  default = "lab-private"
}
variable "private_net_cidr" {
  description = "private network name"
  type        = string
  default     = "10.0.101.0/24"
}

## Public network
variable "public_net_name" {
  description = "public network name"
  type        = string
  default     = "lab-public"
}
variable "public_net_cidr" {
  description = "public network name"
  type        = string
  default     = "10.0.102.0/24"
}
variable "public_net_dns" {
  description = "DNS servers for public network"
  type        = list
  default     = ["8.8.8.8", "8.8.4.4"]
}

## VM_Public network
variable "vm_public_net_name" {
  description = "vm_public network name"
  type        = string
  default = "lab-vm_public"
}
variable "vm_public_net_cidr" {
  description = "vm_public network name"
  type        = string
  default = "10.44.0.0/24"
}