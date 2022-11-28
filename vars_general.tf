# TEACHER VARS
## Teacher SSH key
variable "ssh-key" {
  type    = string
  default = file(access/teacher_rsa.pub)
}

# STUDENT VARS
## Bastion image
variable "bastion_image" {
  type = string
  default = "bastion"
}

## Bastion flavor
variable "flavor_bastion" {
  type = string
  default = "medium"
}