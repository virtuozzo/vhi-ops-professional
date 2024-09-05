## VHI instances data
data "openstack_images_image_v2" "vhi-image" {
  name = var.vhi-image
}
data "openstack_compute_flavor_v2" "vhi-flavor_main" {
  name = var.vhi-flavor_main
}
data "openstack_compute_flavor_v2" "vhi-flavor_worker" {
  name = var.vhi-flavor_worker
}