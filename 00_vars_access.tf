# This file contains variables defining access credentials
## Bastion/Node access SSH key
variable "ssh_key" {
  type    = string
  default = "~/.ssh/student.pub" # Replace with the path to your public SSH key
}