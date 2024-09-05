# This file contains variables describing Bastion VM
## Bastion image
variable "bastion-image" {
  type = string
  default = "Ubuntu-20.04" # If required, replace the image name with the one you have in the cloud
}

## Bastion flavor
variable "bastion-flavor" {
  type = string
  default = "va-2-4"      # If required, replace the flavor name with the one you have in the cloud
}

## Bastion storage policy
variable "bastion-storage_policy" {
  type    = string
  default = "standard"     # If required, replace the storage policy with the one you have in the cloud
}