# Runtime data collection

data "openstack_images_image_v2" "vhi_image" {
  name = var.vhi_image
}
data "openstack_compute_flavor_v2" "vhi-main" {
  name = var.flavor_main
}
data "openstack_compute_flavor_v2" "vhi-worker" {
  name = var.flavor_worker
}

resource "openstack_compute_keypair_v2" "teacher_key" {
  name = "teacher_key"
  public_key = file(var.ssh-key)
}