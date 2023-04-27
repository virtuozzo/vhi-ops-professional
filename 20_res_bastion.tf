resource "openstack_compute_instance_v2" "bastion" {
  name            = "bastion.lab"
  flavor_id       = data.openstack_compute_flavor_v2.bastion_flavor.id
  key_pair        = openstack_compute_keypair_v2.ssh_key.name

  block_device {
    uuid                  = data.openstack_images_image_v2.bastion_image.id
    source_type           = "image"
    volume_size           = 10
    boot_index            = 0
    destination_type      = "volume"
    delete_on_termination = true
  }
  config_drive = true
  user_data = file("cloud-init/bastion.sh")
  
  network {
    name = "${openstack_networking_network_v2.lab-public.name}"
    fixed_ip_v4 = "10.0.102.250"
  }
}

resource "openstack_networking_floatingip_v2" "bastion_float" {
  pool = "public"
}

resource "openstack_compute_floatingip_associate_v2" "bastion_float" {
  floating_ip = "${openstack_networking_floatingip_v2.bastion_float.address}"
  instance_id = "${openstack_compute_instance_v2.bastion.id}"
  fixed_ip    = "${openstack_compute_instance_v2.bastion.network.0.fixed_ip_v4}"
}