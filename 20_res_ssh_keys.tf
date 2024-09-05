## SSH key
resource "openstack_compute_keypair_v2" "ssh_key" {
  name = "ssh_key"
  public_key = file(var.ssh_key)
}