## Bastion data
data "openstack_images_image_v2" "bastion_image" {
  name = var.bastion_image
}
data "openstack_compute_flavor_v2" "bastion_flavor" {
  name = var.flavor_bastion
}