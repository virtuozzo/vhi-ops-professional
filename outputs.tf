# Terraform outputs for the VHI sandbox environment

output "bastion_connection_info" {
  description = "Bastion VM connection details (null when the lab_track profile sets deploy_bastion = false)."
  value = local.deploy_bastion ? {
    rdp_address = "${openstack_networking_floatingip_v2.bastion_float[0].address}:3390"
    username    = "student"
    password    = nonsensitive(random_password.bastion_student[0].result)
  } : null
}
