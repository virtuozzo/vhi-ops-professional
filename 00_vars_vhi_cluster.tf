# This file contains variables describing VHI cluster
### VHI image name
variable "vhi_image" {
  type = string
  default = "VHI-5.4" # If required, replace image name with the one you have present in the cloud
}

### Number of MN nodes
variable "mn_count" {
  type    = number
  default = 3
}

### Number of worker nodes
variable "worker_count" {
  type    = number
  default = 1
}

### Number of CS disks
variable "cs_count" {
  type    = number
  default = 2
}

### Main node flavor name
variable "flavor_main" {
  type    = string
  default = "vhi-main"
}

### Worker node flavor name
variable "flavor_worker" {
  type    = string
  default = "vhi-compute"
}

### Node root password
variable "password_root" {
  type = string
  default = "Lab_r00t"
}

### Admin panel password
variable "password_admin" {
  type = string
  default = "Lab_admin"
}

### Storage cluster name
variable "cluster_name" {
  type = string
  default = "lab"
}