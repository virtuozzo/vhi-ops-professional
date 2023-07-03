## Bastion image
variable "bastion_image" {
  type = string
  default = "Ubuntu-20.04" # If required, replace image name with the one you have in the cloud
}

## Bastion flavor
variable "flavor_bastion" {
  type = string
  default = "va-2-4"      # If required, replace flavor name with the one you have in the cloud
}