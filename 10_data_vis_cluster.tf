## VIS instances data (image / flavor from general variables in 00_vars_lab_track.tf)
data "openstack_images_image_v2" "vis-image" {
  count       = var.vis-image_isUUID ? 0 : 1
  name        = var.vis-image
  most_recent = true
}

locals {
  vis-image_id = var.vis-image_isUUID ? var.vis-image : data.openstack_images_image_v2.vis-image[0].id
}

data "openstack_compute_flavor_v2" "vis-flavor_main" {
  name = var.vis-flavor_main
}

data "openstack_compute_flavor_v2" "vis-flavor_worker" {
  name = var.vis-flavor_worker
}
