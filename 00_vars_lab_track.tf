# =============================================================================
# Student / operator configuration
#
# - Lab track: which curriculum profile (operations, s3, vzsup).
# - General: image, flavor, storage, passwords, external network, bastion, SSH — set
#   to match your OpenStack project (typically the same regardless of track).
#   Internal lab network names/CIDRs are fixed in 20_res_network.tf.
# - Per-track profile (locals.lab_track_profiles): only counts, feature flags,
#   and default storage cluster name for that curriculum.
# =============================================================================

# --- Lab track ---

variable "lab_track" {
  type        = string
  default     = "s3"
  description = "Curriculum profile; selects one block from local.lab_track_profiles."

  validation {
    condition     = contains(["operations", "s3", "vzsup"], var.lab_track)
    error_message = "lab_track must be \"operations\", \"s3\", or \"vzsup\"."
  }
}

# --- VHI cluster (general; applies to all tracks) ---

variable "vhi-image" {
  type        = string
  default     = "VHI-7.0.0-251.qcow2"
  description = "Virtuozzo Infrastructure QCOW2 image name or UUID (see vhi-image_isUUID)."
}

variable "vhi-image_isUUID" {
  type        = bool
  default     = false
  description = "If true, vhi-image is a Glance UUID; if false, lookup by image name."
}

variable "vhi-flavor_main" {
  type        = string
  default     = "va-16-32"
  description = "Flavor for main (MN) cluster nodes."
}

variable "vhi-flavor_worker" {
  type        = string
  default     = "va-8-16"
  description = "Flavor for worker nodes (unused when the selected track has worker_node_count = 0)."
}

variable "vhi-storage_policy" {
  type        = string
  default     = "default"
  description = "Cinder volume type for VHI node volumes."
}

variable "vhi-password_root" {
  type        = string
  default     = "Lab_r00t"
  description = "Root password on VHI nodes (cloud-init)."
}

variable "vhi-password_admin" {
  type        = string
  default     = "Lab_admin"
  description = "Admin panel password (cloud-init / vinfra)."
}

# --- Networking (general) ---

variable "external_network-name" {
  type        = string
  default     = "public"
  description = "Neutron external network for lab router SNAT and bastion floating IP pool (when deploy_bastion is true)."
}

# --- Bastion (general; resources skipped when profile deploy_bastion = false) ---

variable "bastion-image" {
  type        = string
  default     = "Ubuntu-20.04"
  description = "Bastion image name in Glance."
}

variable "bastion-flavor" {
  type        = string
  default     = "va-2-4"
  description = "Bastion flavor name."
}

variable "bastion-storage_policy" {
  type        = string
  default     = "default"
  description = "Cinder volume type for the bastion boot volume."
}

# --- Access ---

variable "ssh_key" {
  type        = string
  default     = "~/.ssh/id_rsa.pub"
  description = "Path to your public SSH key for bastion and cluster nodes."
}

# =============================================================================
# Per-track profile: counts, feature flags, default cluster name only.
# =============================================================================

locals {
  lab_track_profiles = {
    operations = {
      enable_cluster_compute = true
      default_cluster_name   = "vhi-ops-pro-lab"
      mn_count               = 3
      worker_node_count      = 1
      deploy_bastion         = true
    }
    s3 = {
      enable_cluster_compute = false
      default_cluster_name   = "vhi-s3-ops-lab"
      mn_count               = 3
      worker_node_count      = 0
      deploy_bastion         = true
    }
    vzsup = {
      enable_cluster_compute = true
      default_cluster_name   = "vhi-vzsup-lab"
      mn_count               = 3
      worker_node_count      = 0
      deploy_bastion         = false
    }
  }

  lab = local.lab_track_profiles[var.lab_track]

  enable_cluster_compute = local.lab.enable_cluster_compute
  cluster_name           = local.lab.default_cluster_name
  mn_count               = local.lab.mn_count
  worker_node_count      = local.lab.worker_node_count
  deploy_bastion         = local.lab.deploy_bastion

  cloud_init_lab_log          = file("${path.module}/cloud-init/_lab_log.sh")
  node_cloud_init_template    = "${path.module}/cloud-init/node.sh"
  bastion_cloud_init_template = "${path.module}/cloud-init/bastion.sh"
}
