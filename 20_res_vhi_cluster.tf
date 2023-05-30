## VHI MN node instances
resource "openstack_compute_instance_v2" "vhi_mn_nodes" {
  count           = var.mn_count # default = 3
  name            = "node${count.index + 1}.lab"
  flavor_id       = data.openstack_compute_flavor_v2.vhi-main.id
  key_pair        = openstack_compute_keypair_v2.ssh_key.name
    block_device {
      uuid                  = data.openstack_images_image_v2.vhi_image.id
      source_type           = "image"
      volume_size           = 150
      boot_index            = 0
      destination_type      = "volume"
      delete_on_termination = true
    }

    block_device {
    source_type           = "blank"
    destination_type      = "volume"
    volume_size           = 100
    boot_index            = 1
    delete_on_termination = true
    }

  block_device {
    source_type           = "blank"
    destination_type      = "volume"
    volume_size           = 100
    boot_index            = 2
    delete_on_termination = true
    }

    network {
      name = var.storage_net_name
      fixed_ip_v4 = "10.0.100.1${count.index + 1}"
    }
    network {
      name = var.private_net_name
      fixed_ip_v4 = "10.0.101.1${count.index + 1}"
    }
    network {
      name = var.public_net_name
      fixed_ip_v4 = "10.0.102.1${count.index + 1}"
    }
    network {
      name = var.vm_public_net_name
      fixed_ip_v4 = "10.44.0.1${count.index + 1}"
    }
    config_drive = true
    user_data = templatefile(
      "cloud-init/node.sh",
    {
        storage_ip      = "10.0.100.1${count.index + 1}",
        private_ip      = "10.0.101.1${count.index + 1}",
        public_ip       = "10.0.102.1${count.index + 1}",
        vm_public_ip    = "10.100.0.1${count.index + 1}",
        hostname        = "node${count.index + 1}.lab",
        mn_ip           = "10.0.101.11",
        ha_ip_public    = "10.0.102.10",
        ha_ip_private   = "10.0.101.10",
        password_root   = var.password_root,
        password_admin  = var.password_admin,
        cluster_name    = var.cluster_name
      } )

  depends_on = [
  openstack_networking_network_v2.lab-private,
  openstack_networking_network_v2.lab-storage,
  openstack_networking_network_v2.lab-public,
  openstack_networking_network_v2.lab-vm_public
  ]  
}

## VHI worker node instances
resource "openstack_compute_instance_v2" "vhi_worker_nodes" {
  count           = var.worker_count # default = 1
  name            = "node${count.index + 4}.lab"
  flavor_id       = data.openstack_compute_flavor_v2.vhi-worker.id
  key_pair        = openstack_compute_keypair_v2.ssh_key.name
    block_device {
      uuid                  = data.openstack_images_image_v2.vhi_image.id
      source_type           = "image"
      volume_size           = 150
      boot_index            = 0
      destination_type      = "volume"
      delete_on_termination = true
    }

    block_device {
      source_type           = "blank"
      destination_type      = "volume"
      volume_size           = 100
      boot_index            = 1
      delete_on_termination = true
    }

    block_device {
      source_type           = "blank"
      destination_type      = "volume"
      volume_size           = 100
      boot_index            = 2
      delete_on_termination = true
    }

    network {
      name = var.storage_net_name
      fixed_ip_v4 = "10.0.100.1${count.index + 4}"
    }
    network {
      name = var.private_net_name
      fixed_ip_v4 = "10.0.101.1${count.index + 4}"
    }
    network {
      name = var.public_net_name
      fixed_ip_v4 = "10.0.102.1${count.index + 4}"
    }
    network {
      name = var.vm_public_net_name
      fixed_ip_v4 = "10.44.0.1${count.index + 4}"
    }
    config_drive = true
    user_data = templatefile(
      "cloud-init/node.sh", 
      {
        storage_ip      = "10.0.100.1${count.index + 4}",
        private_ip      = "10.0.101.1${count.index + 4}",
        public_ip       = "10.0.102.1${count.index + 4}",
        vm_public_ip    = "10.100.0.1${count.index + 4}",
        hostname        = "node${count.index + 4}.lab",
        mn_ip           = "10.0.101.11",
        ha_ip_public    = "10.0.102.10",
        ha_ip_private   = "10.0.101.10",
        password_root   = var.password_root,
        password_admin  = var.password_admin,
        cluster_name    = var.cluster_name
      } )
  
  depends_on = [
  openstack_networking_network_v2.lab-private,
  openstack_networking_network_v2.lab-storage,
  openstack_networking_network_v2.lab-public,
  openstack_networking_network_v2.lab-vm_public
  ]
}