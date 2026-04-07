## Bastion data
data "openstack_images_image_v2" "bastion-image" {
  count = local.deploy_bastion ? 1 : 0
  name  = var.bastion-image
}
data "openstack_compute_flavor_v2" "bastion-flavor" {
  count = local.deploy_bastion ? 1 : 0
  name  = var.bastion-flavor
}
