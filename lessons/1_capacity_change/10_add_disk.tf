# Exercise 1: assign new disk to storage

### Create volumes for CS exercise
resource "openstack_blockstorage_volume_v3" "cs_exercise" {
  count   = (var.worker_count + var.mn_count)
  name    = "cs_exercise_${count.index}"
  size    = var.cs_exercise_size
  depends_on = [
    openstack_compute_instance_v2.vhi_mn_nodes,
    openstack_compute_instance_v2.vhi_worker_nodes
  ]
}

### Attach exercise CS volumes to main nodes
resource "openstack_compute_volume_attach_v2" "cs_attach_main" {
  count = var.mn_count
  instance_id = openstack_compute_instance_v2.vhi_mn_nodes[count.index].id
  volume_id   = "${openstack_blockstorage_volume_v3.cs_exercise.*.id[count.index]}"
  depends_on = [
    openstack_blockstorage_volume_v3.cs_exercise
  ]
}

### Attach exercise CS volumes to worker nodes
resource "openstack_compute_volume_attach_v2" "cs_attach_worker" {
  count = var.worker_count
  instance_id = openstack_compute_instance_v2.vhi_worker_nodes[count.index].id
  volume_id   = "${openstack_blockstorage_volume_v3.cs_exercise.*.id[count.index + 3]}"
  depends_on = [
    openstack_blockstorage_volume_v3.cs_exercise
  ]
}