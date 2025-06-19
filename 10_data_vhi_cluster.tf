## VHI instances data
# Image lookup only when using name
data "openstack_images_image_v2" "vhi-image" {
  count = var.vhi-image_isUUID ? 1 : 0
  name  = var.vhi-image
}
# Get the actual image ID based on the mode
locals {
  vhi-image_id = var.vhi-image_isUUID ? data.openstack_images_image_v2.vhi-image[0].id : var.vhi-image
}

data "openstack_compute_flavor_v2" "vhi-flavor_main" {
  name = var.vhi-flavor_main
}
data "openstack_compute_flavor_v2" "vhi-flavor_worker" {
  name = var.vhi-flavor_worker
}