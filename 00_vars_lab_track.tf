# Course variant: one codebase for operations (default) and S3 tracks.
variable "lab_track" {
  type        = string
  default     = "s3"
  description = "operations = VM_Public lab network and 4 NICs; s3 = three NICs, WonderSI bootstrap in cloud-init."

  validation {
    condition     = contains(["operations", "s3"], var.lab_track)
    error_message = "lab_track must be \"operations\" or \"s3\"."
  }
}

locals {
  enable_vm_public   = var.lab_track == "operations"
  cluster_name       = var.vhi-cluster_name != "" ? var.vhi-cluster_name : (var.lab_track == "s3" ? "vhi-s3-ops-lab" : "vhi-ops-pro-lab")
  node_cloud_init    = "${path.module}/cloud-init/node.${var.lab_track == "s3" ? "s3" : "operations"}.sh"
  bastion_cloud_init = "${path.module}/cloud-init/bastion.${var.lab_track == "s3" ? "s3" : "operations"}.sh"
  # S3 track uses only main nodes (node1–node3 by default); workers are not deployed.
  worker_node_count = var.lab_track == "s3" ? 0 : var.vhi-worker_count
}
