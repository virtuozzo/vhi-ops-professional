## VHI MN node instances
resource "openstack_compute_instance_v2" "vhi-mn_nodes" {
  count           = var.vhi-mn_count # default = 3
  name            = "node${count.index + 1}.lab"
  flavor_id       = data.openstack_compute_flavor_v2.vhi-flavor_main.id
  key_pair        = openstack_compute_keypair_v2.ssh_key.name
    block_device {
      uuid                  = local.vhi-image_id
      volume_type           = var.vhi-storage_policy
      source_type           = "image"
      volume_size           = 150
      boot_index            = 0
      destination_type      = "volume"
      delete_on_termination = true
    }

    block_device {
    volume_type           = var.vhi-storage_policy
    source_type           = "blank"
    destination_type      = "volume"
    volume_size           = 100
    boot_index            = 1
    delete_on_termination = true
    }

  block_device {
    volume_type           = var.vhi-storage_policy
    source_type           = "blank"
    destination_type      = "volume"
    volume_size           = 100
    boot_index            = 2
    delete_on_termination = true
    }

    network {
      name = var.storage_net-name
      fixed_ip_v4 = "10.0.100.1${count.index + 1}"
    }
    network {
      name = var.private_net-name
      fixed_ip_v4 = "10.0.101.1${count.index + 1}"
    }
    network {
      name = var.public_net-name
      fixed_ip_v4 = "10.0.102.1${count.index + 1}"
    }
    config_drive = true
    user_data = templatefile(
      "cloud-init/node.sh",
    {
        storage_ip      = "10.0.100.1${count.index + 1}",
        private_ip      = "10.0.101.1${count.index + 1}",
        public_ip       = "10.0.102.1${count.index + 1}",
        hostname        = "node${count.index + 1}.lab",
        mn_ip           = "10.0.101.11",
        ha_ip_public    = "10.0.102.10",
        ha_ip_private   = "10.0.101.10",
        password_root   = var.vhi-password_root,
        password_admin  = var.vhi-password_admin,
        cluster_name    = var.vhi-cluster_name
      } )

  depends_on = [
  openstack_networking_network_v2.lab-private_net,
  openstack_networking_network_v2.lab-storage_net,
  openstack_networking_network_v2.lab-public_net,
  ]  
}

## VHI worker node instances
resource "openstack_compute_instance_v2" "vhi-worker_nodes" {
  count           = var.vhi-worker_count # default = 1
  name            = "node${count.index + 4}.lab"
  flavor_id       = data.openstack_compute_flavor_v2.vhi-flavor_worker.id
  key_pair        = openstack_compute_keypair_v2.ssh_key.name
    block_device {
      uuid                  = local.vhi-image_id
      volume_type           = var.vhi-storage_policy
      source_type           = "image"
      volume_size           = 150
      boot_index            = 0
      destination_type      = "volume"
      delete_on_termination = true
    }

    block_device {
      volume_type           = var.vhi-storage_policy
      source_type           = "blank"
      destination_type      = "volume"
      volume_size           = 100
      boot_index            = 1
      delete_on_termination = true
    }

    block_device {
      volume_type           = var.vhi-storage_policy
      source_type           = "blank"
      destination_type      = "volume"
      volume_size           = 100
      boot_index            = 2
      delete_on_termination = true
    }

    network {
      name = var.storage_net-name
      fixed_ip_v4 = "10.0.100.1${count.index + 4}"
    }
    network {
      name = var.private_net-name
      fixed_ip_v4 = "10.0.101.1${count.index + 4}"
    }
    network {
      name = var.public_net-name
      fixed_ip_v4 = "10.0.102.1${count.index + 4}"
    }
    config_drive = true
    user_data = templatefile(
      "cloud-init/node.sh", 
      {
        storage_ip      = "10.0.100.1${count.index + 4}",
        private_ip      = "10.0.101.1${count.index + 4}",
        public_ip       = "10.0.102.1${count.index + 4}",
        hostname        = "node${count.index + 4}.lab",
        mn_ip           = "10.0.101.11",
        ha_ip_public    = "10.0.102.10",
        ha_ip_private   = "10.0.101.10",
        password_root   = var.vhi-password_root,
        password_admin  = var.vhi-password_admin,
        cluster_name    = var.vhi-cluster_name
      } )
  
  depends_on = [
  openstack_networking_network_v2.lab-private_net,
  openstack_networking_network_v2.lab-storage_net,
  openstack_networking_network_v2.lab-public_net,
  ]
}
