## Bastion student password
resource "random_password" "bastion_student" {
  count   = local.deploy_bastion ? 1 : 0
  length  = 12
  special = false
}

## Bastion VM (count follows local.deploy_bastion from lab_track profile)
resource "openstack_compute_instance_v2" "bastion" {
  count     = local.deploy_bastion ? 1 : 0
  name      = "bastion.lab"
  flavor_id = data.openstack_compute_flavor_v2.bastion-flavor[0].id
  key_pair  = openstack_compute_keypair_v2.ssh_key.name

  block_device {
    uuid                  = data.openstack_images_image_v2.bastion-image[0].id
    volume_type           = var.bastion-storage_policy
    source_type           = "image"
    volume_size           = 10
    boot_index            = 0
    destination_type      = "volume"
    delete_on_termination = true
  }
  config_drive = true
  user_data = join("\n", [
    local.cloud_init_lab_log,
    templatefile(local.bastion_cloud_init_template, {
      student_password = random_password.bastion_student[0].result
      lab_track        = var.lab_track
    })
  ])

  network {
    name        = openstack_networking_network_v2.lab-public_net.name
    fixed_ip_v4 = "10.0.102.250"
  }
}

resource "openstack_networking_floatingip_v2" "bastion_float" {
  count = local.deploy_bastion ? 1 : 0
  pool  = var.external_network-name
}

resource "openstack_compute_floatingip_associate_v2" "bastion_float" {
  count       = local.deploy_bastion ? 1 : 0
  floating_ip = openstack_networking_floatingip_v2.bastion_float[0].address
  instance_id = openstack_compute_instance_v2.bastion[0].id
  fixed_ip    = openstack_compute_instance_v2.bastion[0].network[0].fixed_ip_v4
}
