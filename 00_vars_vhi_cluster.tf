# This file contains variables describing VHI cluster
## VHI image name/id
variable "vhi-image" {
  type    = string
  default = "d3695fd9-662a-4f22-8fa9-b5cc4f67e02a" #vzlinux-iso-hci-7.0.0-251-new
}
variable "vhi-image_isUUID" {
  type    = bool
  default = true # Set to true if vhi-image is UUID
}

## Main node flavor name
variable "vhi-flavor_main" {
  type    = string
  default = "va-4-24"  # If required, replace the flavor name with the one you have in the cloud
}

## Worker node flavor name
variable "vhi-flavor_worker" {
  type    = string
  default = "va-4-24"   # If required, replace the flavor name with the one you have in the cloud
}

## VHI node storage policy
variable "vhi-storage_policy" {
  type    = string
  default = "standard"   # If required, replace the storage policy with the one you have in the cloud
}

# Do not change the variables below unless you know what you're doing
## Number of MN nodes
variable "vhi-mn_count" {
  type    = number
  default = 3
}

## Number of worker nodes
variable "vhi-worker_count" {
  type    = number
  default = 0
}

## Storage cluster name
variable "vhi-cluster_name" {
  type = string
  default = "vhi-ops-pro-lab"
}

## Node root password
variable "vhi-password_root" {
  type = string
  default = "Lab_r00t"
}

## Admin panel password
variable "vhi-password_admin" {
  type = string
  default = "Lab_admin"
}