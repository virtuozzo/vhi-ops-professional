locals {
  node_cloud_init_common = {
    lab_track              = var.lab_track
    enable_cluster_compute = tostring(local.enable_cluster_compute)
    mn_ip                  = "10.0.101.11"
    ha_ip_public           = "10.0.102.10"
    ha_ip_private          = "10.0.101.10"
    password_root          = var.vhi-password_root
    password_admin         = var.vhi-password_admin
    cluster_name           = local.cluster_name
  }
}

## VHI MN node instances
resource "openstack_compute_instance_v2" "vhi-mn_nodes" {
  count     = local.mn_count
  name      = "node${count.index + 1}.lab"
  flavor_id = data.openstack_compute_flavor_v2.vhi-flavor_main.id
  key_pair  = openstack_compute_keypair_v2.ssh_key.name
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
    uuid        = openstack_networking_network_v2.lab-storage_net.id
    fixed_ip_v4 = "10.0.100.1${count.index + 1}"
  }
  network {
    uuid        = openstack_networking_network_v2.lab-private_net.id
    fixed_ip_v4 = "10.0.101.1${count.index + 1}"
  }
  network {
    uuid        = openstack_networking_network_v2.lab-public_net.id
    fixed_ip_v4 = "10.0.102.1${count.index + 1}"
  }
  dynamic "network" {
    for_each = local.enable_cluster_compute ? [1] : []
    content {
      uuid        = openstack_networking_network_v2.lab-vm_public_net[0].id
      fixed_ip_v4 = "10.44.0.1${count.index + 1}"
    }
  }
  config_drive = true
  user_data = join("\n", [
    local.cloud_init_lab_log,
    templatefile(local.node_cloud_init_template,
      merge(
        local.node_cloud_init_common,
        {
          storage_ip   = "10.0.100.1${count.index + 1}"
          private_ip   = "10.0.101.1${count.index + 1}"
          public_ip    = "10.0.102.1${count.index + 1}"
          hostname     = "node${count.index + 1}.lab"
          vm_public_ip = local.enable_cluster_compute ? "10.100.0.1${count.index + 1}" : ""
        }
      )
    )
  ])
}

## VHI worker node instances (not created when lab_track = s3; see local.worker_node_count for operations/vzsup)
resource "openstack_compute_instance_v2" "vhi-worker_nodes" {
  count     = local.worker_node_count
  name      = "node${count.index + 4}.lab"
  flavor_id = data.openstack_compute_flavor_v2.vhi-flavor_worker.id
  key_pair  = openstack_compute_keypair_v2.ssh_key.name
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
    uuid        = openstack_networking_network_v2.lab-storage_net.id
    fixed_ip_v4 = "10.0.100.1${count.index + 4}"
  }
  network {
    uuid        = openstack_networking_network_v2.lab-private_net.id
    fixed_ip_v4 = "10.0.101.1${count.index + 4}"
  }
  network {
    uuid        = openstack_networking_network_v2.lab-public_net.id
    fixed_ip_v4 = "10.0.102.1${count.index + 4}"
  }
  dynamic "network" {
    for_each = local.enable_cluster_compute ? [1] : []
    content {
      uuid        = openstack_networking_network_v2.lab-vm_public_net[0].id
      fixed_ip_v4 = "10.44.0.1${count.index + 4}"
    }
  }
  config_drive = true
  user_data = join("\n", [
    local.cloud_init_lab_log,
    templatefile(local.node_cloud_init_template,
      merge(
        local.node_cloud_init_common,
        {
          storage_ip   = "10.0.100.1${count.index + 4}"
          private_ip   = "10.0.101.1${count.index + 4}"
          public_ip    = "10.0.102.1${count.index + 4}"
          hostname     = "node${count.index + 4}.lab"
          vm_public_ip = local.enable_cluster_compute ? "10.100.0.1${count.index + 4}" : ""
        }
      )
    )
  ])
}
