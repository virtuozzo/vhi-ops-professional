## VHI instances data
# Image lookup only when using name
data "openstack_images_image_v2" "vhi-image" {
  count        = var.vhi-image_isUUID ? 0 : 1
  name         = var.vhi-image
  most_recent  = true
}
# Get the actual image ID based on the mode
locals {
  vhi-image_id = var.vhi-image_isUUID ? var.vhi-image : data.openstack_images_image_v2.vhi-image[0].id
}

data "openstack_compute_flavor_v2" "vhi-flavor_main" {
  name = var.vhi-flavor_main
}
data "openstack_compute_flavor_v2" "vhi-flavor_worker" {
  name = var.vhi-flavor_worker
}