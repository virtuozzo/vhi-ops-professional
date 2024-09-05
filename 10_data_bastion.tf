## Bastion data
data "openstack_images_image_v2" "bastion-image" {
  name = var.bastion-image
}
data "openstack_compute_flavor_v2" "bastion-flavor" {
  name = var.bastion-flavor
}
