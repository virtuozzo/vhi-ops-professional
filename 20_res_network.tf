## Lab networks
resource "openstack_networking_network_v2" "lab-storage_net" {
  name = var.storage_net-name
}

resource "openstack_networking_subnet_v2" "lab-storage_net-subnet" {
  name       = "lab-storage-subnet"
  network_id = openstack_networking_network_v2.lab-storage_net.id
  cidr       = var.storage_net-cidr
  ip_version = 4
  enable_dhcp = false
  no_gateway = true
}

resource "openstack_networking_network_v2" "lab-private_net" {
  name = var.private_net-name
  port_security_enabled = false
}

resource "openstack_networking_subnet_v2" "lab-private_net-subnet" {
  name       = "lab-private_net-subnet"
  network_id = openstack_networking_network_v2.lab-private_net.id
  cidr       = var.private_net-cidr
  ip_version = 4
  no_gateway = true
  enable_dhcp = false
}

resource "openstack_networking_network_v2" "lab-public_net" {
  name = var.public_net-name
  port_security_enabled = "false"
}

resource "openstack_networking_subnet_v2" "lab-public_net-subnet" {
  name       = "lab-public_net-subnet"
  network_id = openstack_networking_network_v2.lab-public_net.id
  cidr       = var.public_net-cidr
  dns_nameservers = ["8.8.8.8", "8.8.4.4"]
  ip_version = 4
}

resource "openstack_networking_network_v2" "lab-vm_public_net" {
  name = var.vm_public_net-name
  port_security_enabled = "false"
}

resource "openstack_networking_subnet_v2" "lab-vm_public_net-subnet" {
  name        = "lab-vm_public_net-subnet"
  network_id  = openstack_networking_network_v2.lab-vm_public_net.id
  cidr        = var.vm_public_net-cidr
  ip_version  = 4
  enable_dhcp = false
  gateway_ip = "10.44.0.1"
}

### Router
resource "openstack_networking_router_v2" "lab-vrouter" {
  name                = "lab-vrouter"
  admin_state_up      = true
  external_network_id = data.openstack_networking_network_v2.lab-external_net.id
  enable_snat = true
}

resource "openstack_networking_router_interface_v2" "lab-public_net-router-iface" {
  router_id = openstack_networking_router_v2.lab-vrouter.id
  subnet_id = openstack_networking_subnet_v2.lab-public_net-subnet.id
  depends_on = [
    openstack_networking_subnet_v2.lab-public_net-subnet,
    openstack_networking_subnet_v2.lab-vm_public_net-subnet
  ]
}

resource "openstack_networking_router_interface_v2" "lab-vm_public_net-router-iface" {
  router_id = openstack_networking_router_v2.lab-vrouter.id
  subnet_id = openstack_networking_subnet_v2.lab-vm_public_net-subnet.id
  
}