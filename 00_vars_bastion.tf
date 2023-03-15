## Bastion image
variable "bastion_image" {
  type = string
  default = "Ubuntu20.04-blk"
}

## Bastion flavor
variable "flavor_bastion" {
  type = string
  default = "medium"
}