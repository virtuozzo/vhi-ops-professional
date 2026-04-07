## Lab networks (fixed topology — not operator variables; must stay aligned with cloud-init IP plan)
resource "openstack_networking_network_v2" "lab-storage_net" {
  name = "lab-storage"
}

resource "openstack_networking_subnet_v2" "lab-storage_net-subnet" {
  name        = "lab-storage-subnet"
  network_id  = openstack_networking_network_v2.lab-storage_net.id
  cidr        = "10.0.100.0/24"
  ip_version  = 4
  enable_dhcp = false
  no_gateway  = true
}

resource "openstack_networking_network_v2" "lab-private_net" {
  name                  = "lab-private"
  port_security_enabled = false
}

resource "openstack_networking_subnet_v2" "lab-private_net-subnet" {
  name        = "lab-private_net-subnet"
  network_id  = openstack_networking_network_v2.lab-private_net.id
  cidr        = "10.0.101.0/24"
  ip_version  = 4
  no_gateway  = true
  enable_dhcp = false
}

resource "openstack_networking_network_v2" "lab-public_net" {
  name                  = "lab-public"
  port_security_enabled = false
}

resource "openstack_networking_subnet_v2" "lab-public_net-subnet" {
  name            = "lab-public_net-subnet"
  network_id      = openstack_networking_network_v2.lab-public_net.id
  cidr            = "10.0.102.0/24"
  dns_nameservers = ["8.8.8.8", "8.8.4.4"]
  ip_version      = 4
}

resource "openstack_networking_network_v2" "lab-vm_public_net" {
  count                 = local.enable_cluster_compute ? 1 : 0
  name                  = "lab-vm_public"
  port_security_enabled = false
}

resource "openstack_networking_subnet_v2" "lab-vm_public_net-subnet" {
  count       = local.enable_cluster_compute ? 1 : 0
  name        = "lab-vm_public_net-subnet"
  network_id  = openstack_networking_network_v2.lab-vm_public_net[0].id
  cidr        = "10.44.0.0/24"
  ip_version  = 4
  enable_dhcp = false
  gateway_ip  = "10.44.0.1"
}

### Router
resource "openstack_networking_router_v2" "lab-vrouter" {
  name                = "lab-vrouter"
  admin_state_up      = true
  external_network_id = data.openstack_networking_network_v2.lab-external_net.id
  enable_snat         = true
}

resource "openstack_networking_router_interface_v2" "lab-public_net-router-iface" {
  router_id  = openstack_networking_router_v2.lab-vrouter.id
  subnet_id  = openstack_networking_subnet_v2.lab-public_net-subnet.id
  depends_on = [openstack_networking_subnet_v2.lab-public_net-subnet]
}

resource "openstack_networking_router_interface_v2" "lab-vm_public_net-router-iface" {
  count      = local.enable_cluster_compute ? 1 : 0
  router_id  = openstack_networking_router_v2.lab-vrouter.id
  subnet_id  = openstack_networking_subnet_v2.lab-vm_public_net-subnet[0].id
  depends_on = [openstack_networking_router_interface_v2.lab-public_net-router-iface]
}