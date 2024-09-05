## Network data
data "openstack_networking_network_v2" "lab-external_net" {
  name = var.external_network-name
}