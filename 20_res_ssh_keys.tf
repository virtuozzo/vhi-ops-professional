## Teacher key
resource "openstack_compute_keypair_v2" "ssh_key" {
  name = "ssh-key"
  public_key = file(var.ssh-key)
}