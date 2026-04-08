<!-- TOC -->
  * [Description](#description)
  * [Structure and conventions](#structure-and-conventions)
  * [Pre-requisites](#pre-requisites)
    * [Nested virtualization support](#nested-virtualization-support)
    * [Project resource quotas](#project-resource-quotas)
    * [Images](#images)
  * [Sandbox provisioning](#sandbox-provisioning)
    * [Step 1: Clone the repository](#step-1-clone-the-repository)
    * [Step 2: Install Terraform](#step-2-install-terraform)
    * [Step 3: Adjust Terraform Variables](#step-3-adjust-terraform-variables)
      * [Adjust Virtuozzo Infrastructure node variables](#adjust-virtuozzo-infrastructure-node-variables)
        * [Virtuozzo Infrastructure Image name](#virtuozzo-infrastructure-image-name)
        * [Main node flavor](#main-node-flavor)
        * [Worker node flavor](#worker-node-flavor)
        * [Virtuozzo Infrastructure node storage policy](#virtuozzo-infrastructure-node-storage-policy)
      * [Adjust networking variables](#adjust-networking-variables)
      * [Adjust Bastion VM variables](#adjust-bastion-vm-variables)
        * [Bastion image name](#bastion-image-name)
        * [Bastion flavor](#bastion-flavor)
        * [Bastion storage policy](#bastion-storage-policy)
      * [Adjust SSH key path](#adjust-ssh-key-path)
    * [Step 4: Adjust and source the OpenStack credentials file](#step-4-adjust-and-source-the-openstack-credentials-file)
    * [Step 5: Provision the sandbox](#step-5-provision-the-sandbox)
  * [Retrieving Bastion VM credentials](#retrieving-bastion-vm-credentials)
  * [Verifying results](#verifying-results)
    * [Verify Bastion VM completed provisioning](#verify-bastion-vm-completed-provisioning)
    * [Verify that the nested Virtuozzo Infrastructure cluster is fully configured.](#verify-that-the-nested-virtuozzo-infrastructure-cluster-is-fully-configured)
<!-- TOC -->

## Description

This repository provisions a nested Virtuozzo Infrastructure (VHI) sandbox for the **Virtuozzo Infrastructure Operations Professional** courses. **One codebase** supports multiple curricula via Terraform variable **`lab_track`** in [`00_vars_lab_track.tf`](00_vars_lab_track.tf):

**Do not change `lab_track` on an existing workspace** without destroying and recreating the environment: network layout and instance `user_data` differ by track.

The **operations** track is **five VMs** by default (bastion plus `node1.lab`–`node4.lab` with one worker per the profile). The **S3** track is **four VMs** (bastion plus **`node1.lab`–`node3.lab`** only). Virtual networks match the selected **`lab_track`**. Reference diagram:

<img alt="Diagram" src="readme/infra_diagram.png" title="Sandbox Infrastructure Diagram" width="500"/>

_If the diagram shows more cluster nodes, treat extras as **operations** context (`node4` / optional `node5.lab` exercise); **S3** uses three main nodes only._

## Structure and conventions

The repository contains:
- Terraform plan files, ending with `.tf` extension.
- Cloud-init scripts under [`cloud-init/`](cloud-init/): [`node.sh`](cloud-init/node.sh) and [`bastion.sh`](cloud-init/bastion.sh), with behavior gated by **`lab_track`** (Terraform also prepends [`_lab_log.sh`](cloud-init/_lab_log.sh) for shared logging).
- `openstack-creds.sh` for sourcing cloud credentials.
- Auxiliary files for students, including `WonderSI_Logos.zip`.

Terraform plan files follow this naming scheme:
- [`00_vars_lab_track.tf`](00_vars_lab_track.tf) — student/operator variables in file order: **`lab_track`**; VHI image, flavors, storage; **`external_network-name`**; bastion image, flavor, storage; **`ssh_key`**; then **`locals.lab_track_profiles`** at the bottom of the file.
- `10_data_*.tf` files contain runtime data collection modules.
- `20_res_*.tf` files contain resource definitions.

## Pre-requisites

To use this automation, your environment must meet the requirements described below.

### Nested virtualization support
- The OpenStack or Virtuozzo Infrastructure cloud must support nested virtualization.

**How to test if nested virtualization is enabled.**

Deploy a test VM and run the following on the guest (Intel exposes `vmx`, AMD exposes `svm`):

```bash
grep -E 'vmx|svm' /proc/cpuinfo
```

If this prints matching lines, the VM likely exposes hardware virtualization flags to the guest (nested virtualization may be available; the hypervisor and cloud policy still apply).

### Project resource quotas

You need **1 floating IP** for the bastion and **1 address** on the cloud external network for the lab router (SNAT).

#### Operations track (`lab_track = "operations"`)

Three main nodes and **`worker_node_count`** from **`lab_track_profiles`**, VM_Public, fourth NIC. Router SNAT and bastion FIP use **`external_network-name`** (default **`public`**).

Recommended minimums, **including** the extra worker students add as **`node5.lab`** (8 vCPU, 16 GiB RAM, 150 + 2×100 GiB volumes):

- vCPU: 68 cores.
- RAM: 132 GiB.
- Disk space: ~1760 GiB.

These are **not** only what the first `terraform apply` consumes; they reserve headroom for the lab exercise.

#### S3 track (`lab_track = "s3"`)

Aligned with default flavors after a single **`terraform apply`**: bastion (2 vCPU / 4 GiB) plus **three** main nodes (16 vCPU / 32 GiB each)—**no worker VMs**.

- vCPU: 50 cores.
- RAM: 100 GiB.
- Disk space: ~1060 GiB (bastion 10 GiB + three nodes × (150 + 2×100) GiB volumes).

### Images

The project you are working with must have the following images:

- Virtuozzo Infrastructure ISO image
  - https://repo.virtuozzo.com/vz-platform/releases/7.0/x86_64/iso/vz-platform-7.0.iso
- Virtuozzo Infrastructure QCOW2 image
  - https://downloads.virtuozzo.com/vzlinux-iso-hci-7.0.0-251.qcow2
- Ubuntu 20.04 QCOW2 image (for the **bastion** VM)
  - https://cloud-images.ubuntu.com/releases/focal/release/ubuntu-20.04-server-cloudimg-amd64.img

Please do not use other versions of Virtuozzo Infrastructure or Ubuntu images, as the deployment script will likely fail to configure them.

## Sandbox provisioning

To provision a sandbox, you will need to complete five steps:
1. Clone this repository to your workstation.
2. Install Terraform on your workstation.
3. Adjust Terraform variables.
4. Adjust and source the OpenStack credentials file.
5. Apply Terraform configuration.

### Step 1: Clone the repository

``` 
git clone https://github.com/virtuozzo/vi-sandbox
```
```
cd vi-sandbox
```

### Step 2: Install Terraform

Download and install Terraform for your operating system from [Terraform website](https://developer.hashicorp.com/terraform/downloads).

Use **Terraform 0.14.0 or newer** (see `required_version` in the root module). This configuration pins the **OpenStack** provider to **~> 1.48** and **random** to **~> 3.5**; run `terraform init` in the repository root so the correct provider versions are installed.

### Step 3: Adjust Terraform Variables

You will need to review and usually adjust variables in [`00_vars_lab_track.tf`](00_vars_lab_track.tf). They appear **in this order** in that file:

1. **`lab_track`** — **`operations`** or **`s3`**, depending on the course you are completing.
2. **Virtuozzo Infrastructure nodes:** **`vhi-image`**, **`vhi-image_isUUID`**, **`vhi-flavor_main`**, **`vhi-flavor_worker`**, **`vhi-storage_policy`**.
3. **Networking:** **`external_network-name`** (Neutron external network for the lab router SNAT and bastion floating IP when a bastion is deployed). Internal lab network names and CIDRs are fixed in [`20_res_network.tf`](20_res_network.tf).
4. **Bastion:** **`bastion-image`**, **`bastion-flavor`**, **`bastion-storage_policy`** (ignored when the selected profile sets **`deploy_bastion = false`**).
5. **`ssh_key`** — path to your public SSH key for the bastion and cluster nodes.
6. **`lab_track_profiles`** — at the **bottom** of the file, inside the `locals` block: per-track **`mn_count`**, **`worker_node_count`**, **`deploy_bastion`**, **`enable_cluster_compute`**, **`default_cluster_name`**. Normally you only set **`lab_track`**; change the profile map only if you know what you are doing.

The subsections below follow the same order (VHI → networking → bastion → SSH). **`lab_track`** and **`lab_track_profiles`** are summarized in the numbered list above.

#### Adjust Virtuozzo Infrastructure node variables

Adjust VHI node variables in [`00_vars_lab_track.tf`](00_vars_lab_track.tf), in file order:

1. Virtuozzo Infrastructure image name (`vhi-image`, `vhi-image_isUUID`).
2. Main node flavor.
3. Worker node flavor.
4. Virtuozzo Infrastructure node storage policy.

##### Virtuozzo Infrastructure Image name

You need to set the `vhi-image` variable to the name (or UUID—see below) of the Virtuozzo Infrastructure image in your project.
For example, if in your cloud, the Virtuozzo Infrastructure image is named `VHI-latest.qcow2`, the variable should look like this:

```
## VHI image name
variable "vhi-image" {
  type = string
  default = "VHI-latest.qcow2" # If required, replace the image name with the one you have in the cloud
}

```

**Name vs UUID:** Variable `vhi-image_isUUID` defaults to `false`. In that mode, Terraform looks up `vhi-image` by **image name** in Glance. If your cloud has images of different versions with the same name (e.g. `VHI-latest.qcow2`) set `vhi-image_isUUID` to `true` and set `vhi-image` to the UUID string (the name lookup is skipped).

```
## Set to true when vhi-image is a Glance image UUID, not a name
variable "vhi-image_isUUID" {
  type    = bool
  default = false
}
```

##### Main node flavor

You need to set the `vhi-flavor_main` variable to the flavor name that provides at least 16 CPU cores and 32 GiB RAM.
For example, if in your cloud such flavor is named `va-16-32`, the variable should look like this:

```
## Main node flavor name
variable "vhi-flavor_main" {
  type    = string
  default = "va-16-32"  # If required, replace the flavor name with the one you have in the cloud
}
```

##### Worker node flavor

For **`lab_track = "operations"`**, set the `vhi-flavor_worker` variable to the flavor name that provides at least 8 CPU cores and 16 GiB RAM. **S3 track** does not deploy workers; this variable is unused there.
For example, if in your cloud such flavor is named `va-8-16`, the variable should look like this:

```
## Worker node flavor name
variable "vhi-flavor_worker" {
  type    = string
  default = "va-8-16"   # If required, replace the flavor name with the one you have in the cloud
}
```

##### Virtuozzo Infrastructure node storage policy

You need to set the `vhi-storage_policy` variable to the storage policy with at least 1750GB of storage in the project's quota.
For example, if in your cloud such policy is named `default`, the variable should look like this:

```
## VHI node storage policy
variable "vhi-storage_policy" {
  type    = string
  default = "default"   # If required, replace the storage policy with the one you have in the cloud
}
```

#### Adjust networking variables

Set **`external_network-name`** in [`00_vars_lab_track.tf`](00_vars_lab_track.tf) to match your cloud.
For example, if your physical network is called `public`, the variable should look like this:

```
## External network
variable "external_network-name" {
  type    = string
  default = "public"  # If required, replace the network name with the one you have in the cloud
}
```

#### Adjust Bastion VM variables

Adjust bastion variables in [`00_vars_lab_track.tf`](00_vars_lab_track.tf):

1. Bastion image name.
2. Bastion flavor.
3. Bastion storage policy.

##### Bastion image name

You need to set the `bastion-image` variable to the name of the Bastion image in your project.
For example, if in your cloud Bastion image is named `Ubuntu-20.04`, the variable should look like this:

```
## Bastion image
variable "bastion-image" {
  type = string
  default = "Ubuntu-20.04" # If required, replace the image name with the one you have in the cloud
}
```

##### Bastion flavor

You need to set the `bastion-flavor` variable to the flavor name that provides at least 2 CPU cores and 4 GiB RAM.
For example, if in your cloud such flavor is named `va-2-4`, the variable should look like this:

```
## Bastion flavor
variable "bastion-flavor" {
  type = string
  default = "va-2-4"      # If required, replace the flavor name with the one you have in the cloud
}
```

##### Bastion storage policy

You need to set the `bastion-storage_policy` variable to the storage policy with at least 10GB of storage in the project's quota.
For example, if in your cloud such policy is named `default`, the variable should look like this:

```
## Bastion storage policy
variable "bastion-storage_policy" {
  type    = string
  default = "default"     # If required, replace the storage policy with the one you have in the cloud
}
```

#### Adjust SSH key path

Set the `ssh_key` variable in [`00_vars_lab_track.tf`](00_vars_lab_track.tf) to point to your public SSH key.
For example, if your SSH key is located in `~/.ssh/student.pub`, the variable should look like this:

```
## Bastion/Node access SSH key
variable "ssh_key" {
  type    = string
  default = "~/.ssh/student.pub" # Replace with the path to your public SSH key
}
```

### Step 4: Adjust and source the OpenStack credentials file

This repository contains an `openstack-creds.sh` file you can adjust to get a usable OpenStack credentials file.
In it, you will need to change some environmental variables related to your OpenStack credentials.

Follow the instructions in the file to get a usable OpenStack credentials file:
```
export OS_PROJECT_DOMAIN_NAME=vhi-ops           # replace "vhi-ops" with your domain name
export OS_USER_DOMAIN_NAME=vhi-ops              # replace "vhi-ops" with your domain name
export OS_PROJECT_NAME=student1                 # replace "student1" with your project name
export OS_USERNAME=user.name                    # replace "user.name" with your user name
export OS_PASSWORD=**********                   # replace "**********" with password of your user
export OS_AUTH_URL=https://mycloud.com:5000/v3  # replace "mycloud.com" with the base URL of your cloud panel (do not replace the ":5000/v3" part)
export OS_IDENTITY_API_VERSION=3
export OS_AUTH_TYPE=password
export OS_INSECURE=true
export PYTHONWARNINGS="ignore:Unverified HTTPS request is being made"
export NOVACLIENT_INSECURE=true
export NEUTRONCLIENT_INSECURE=true
export CINDERCLIENT_INSECURE=true
export OS_PLACEMENT_API_VERSION=1.22
export CLIFF_FIT_WIDTH=1
```

After you adjust the `openstack-creds.sh` file, source it in your terminal:

```
source openstack-creds.sh
```

### Step 5: Provision the sandbox

Initialize Terraform in the directory and apply the plan:

```
terraform init && terraform apply
```

**Changing `lab_track` after the fact** on the same state is not supported! Destroy the stack (or use a fresh project/state) before switching tracks.

_**Wait at least 20 minutes before proceeding!
Terraform will configure all VMs at first boot, which can take some time depending on the cloud performance and internet connection speed.**_

## Retrieving Bastion VM credentials

The Bastion VM `student` user password is **automatically generated** by Terraform during deployment.
After `terraform apply` completes, the connection details are displayed in the output:

```
bastion_connection_info = {
  "password"    = "xK#9mPq!2wLnR$vT"
  "rdp_address" = "203.0.113.45:3390"
  "username"    = "student"
}
```

To retrieve the credentials at any time, use one of the following commands:

**Display all connection info:**
```
terraform output bastion_connection_info
```

**Get JSON output (useful for scripting):**
```
terraform output -json bastion_connection_info
```

**Extract specific values with jq:**
```
terraform output -json bastion_connection_info | jq -r '.password'
terraform output -json bastion_connection_info | jq -r '.rdp_address'
```

## Verifying results

After applying the Terraform plan and waiting for scripts to complete the environment's configuration, you may proceed to verify the access.

### Verify Bastion VM completed provisioning

Connect to the Bastion VM using the remote console.
If Bastion VM is still being configured, you will see the following prompt:

<img alt="&quot;Customization in progress&quot; Prompt" src="readme/bastion_not_ready.png" title="Bastion VM is not ready" width="500"/>

Once the configuration of Bastion is complete, you should see the graphical login prompt:

<img alt="Ready state" src="readme/bastion_ready.png" title="Bastion VM is ready" width="500"/>

### Verify that the nested Virtuozzo Infrastructure cluster is fully configured.

Students typically use an **RDP** connection to the Bastion VM.

To verify that the nested Virtuozzo Infrastructure cluster is ready, do the following:

1. Connect to the Bastion VM using the RDP client. Use the address and credentials from `terraform output bastion_connection_info`.
2. Access nested Virtuozzo Infrastructure Admin Panel using the desktop shortcut and log in as **`admin`**:

<img alt="Bastion VM desktop shortcut" src="readme/bastion_desktop.png" title="Connecting to Virtuozzo Infrastructure Admin Panel" width="500"/>

**Operations track (`lab_track = "operations"`):** After the compute cluster starts deploying, expect **about an hour** before initialization finishes; wait until the Admin Panel shows that process complete before treating the environment as ready.

<img alt="Compute Deployment Progress Bar" src="readme/compute_progress_bar.png" title="Compute Cluster deployment in progress" width="500"/>

**S3 track (`lab_track = "s3"`):** Terraform and first-boot automation deploy **storage** and **HA** only—there is **no** automated compute cluster. Initialization is effectively done once the **storage** cluster is configured, which usually takes **about 20 minutes**. Confirm storage and HA in the Admin Panel.
