# Terraform outputs for the VHI sandbox environment

output "bastion_connection_info" {
  description = "Bastion VM connection details"
  value = {
    rdp_address = "${openstack_networking_floatingip_v2.bastion_float.address}:3390"
    username    = "student"
    password    = nonsensitive(random_password.bastion_student.result)
  }
}
