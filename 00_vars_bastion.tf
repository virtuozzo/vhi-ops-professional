## Bastion image
variable "bastion_image" {
  type = string
  default = "Ubuntu-20.04" # Replace with the name of Ubuntu 20.04 image available in your project
}

## Bastion flavor
variable "flavor_bastion" {
  type = string
  default = "medium"
}