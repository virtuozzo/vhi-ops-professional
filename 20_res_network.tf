### Networks
resource "openstack_networking_network_v2" "lab-storage" {
  name = var.storage_net_name
}

resource "openstack_networking_subnet_v2" "storage-subnet" {
  name       = "lab-storage-subnet"
  network_id = "${openstack_networking_network_v2.lab-storage.id}"
  cidr       = var.storage_net_cidr
  ip_version = 4
  enable_dhcp = false
  no_gateway = true
}

resource "openstack_networking_network_v2" "lab-private" {
  name = var.private_net_name
  port_security_enabled = false
}

resource "openstack_networking_subnet_v2" "lab-private-subnet" {
  name       = "lab-private-subnet"
  network_id = "${openstack_networking_network_v2.lab-private.id}"
  cidr       = var.private_net_cidr
  ip_version = 4
  no_gateway = true
  enable_dhcp = false
}

resource "openstack_networking_network_v2" "lab-public" {
  name = var.public_net_name
  port_security_enabled = "false"
}

resource "openstack_networking_subnet_v2" "lab-public-subnet" {
  name       = "lab-public-subnet"
  network_id = "${openstack_networking_network_v2.lab-public.id}"
  cidr       = var.public_net_cidr
  dns_nameservers = ["8.8.8.8", "8.8.4.4"]
  ip_version = 4
}

resource "openstack_networking_network_v2" "lab-vm_public" {
  name = var.vm_public_net_name
  port_security_enabled = "false"
}

resource "openstack_networking_subnet_v2" "lab-vm-public-subnet" {
  name        = "lab-vm-public-subnet"
  network_id  = "${openstack_networking_network_v2.lab-vm_public.id}"
  cidr        = var.vm_public_net_cidr
  ip_version  = 4
  enable_dhcp = false
  gateway_ip = "10.44.0.1"
}

### Router
resource "openstack_networking_router_v2" "lab-vrouter" {
  name                = "lab-vrouter"
  admin_state_up      = true
  external_network_id = "f52b050c-db9b-45ee-a51a-33ef2d1578ac"
  enable_snat = true
}

resource "openstack_networking_router_interface_v2" "lab-public-router-iface" {
  router_id = "${openstack_networking_router_v2.lab-vrouter.id}"
  subnet_id = "${openstack_networking_subnet_v2.lab-public-subnet.id}"
  depends_on = [
    openstack_networking_subnet_v2.lab-public-subnet,
    openstack_networking_subnet_v2.lab-vm-public-subnet
  ]
}

resource "openstack_networking_router_interface_v2" "lab-vm-public-router-iface" {
  router_id = "${openstack_networking_router_v2.lab-vrouter.id}"
  subnet_id = "${openstack_networking_subnet_v2.lab-vm-public-subnet.id}"
  
}