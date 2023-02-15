## Teacher key
resource "openstack_compute_keypair_v2" "teacher_key" {
  name = "teacher_key"
  public_key = file(var.ssh-key)
}