# Exercise 2: add new node to the cluster

data "openstack_images_image_v2" "vhi_iso" {
  name = var.vhi_iso_name
}

resource "openstack_compute_instance_v2" "node6" {
  name = "node6.lab"
  flavor_id       = data.openstack_compute_flavor_v2.vhi-worker.id
  key_pair        = openstack_compute_keypair_v2.teacher_key.name
      block_device {
      uuid                  = data.openstack_images_image_v2.vhi_iso.id
      source_type           = "image"
      volume_size           = 250
      boot_index            = 0
      destination_type      = "volume"
      delete_on_termination = true
    }

    block_device {
      source_type           = "blank"
      destination_type      = "volume"
      volume_size           = 200
      boot_index            = 1
      delete_on_termination = true
    }

    block_device {
      source_type           = "blank"
      destination_type      = "volume"
      volume_size           = 200
      boot_index            = 2
      delete_on_termination = true
    }

    network {
      name = var.storage_net_name
      fixed_ip_v4 = "10.0.100.16"
    }
    network {
      name = var.private_net_name
      fixed_ip_v4 = "10.0.101.16"
    }
    network {
      name = var.public_net_name
      fixed_ip_v4 = "10.0.102.16"
    }
    network {
      name = var.vm_public_net_name
      fixed_ip_v4 = "10.44.0.16"
    }  
}