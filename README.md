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
      * [Adjust SSH key path](#adjust-ssh-key-path)
      * [Adjust Bastion VM variables](#adjust-bastion-vm-variables)
        * [Bastion image name](#bastion-image-name)
        * [Bastion flavor](#bastion-flavor)
        * [Bastion storage policy](#bastion-storage-policy)
      * [Adjust VHI node variables](#adjust-vhi-node-variables)
        * [VHI Image name](#vhi-image-name)
        * [Main node flavor](#main-node-flavor)
        * [Worker node flavor](#worker-node-flavor)
        * [VHI node storage policy](#vhi-node-storage-policy)
      * [Adjust networking variables](#adjust-networking-variables)
    * [Step 4: Adjust and source the OpenStack credentials file](#step-4-adjust-and-source-the-openstack-credentials-file)
    * [Step 5: Provision the sandbox](#step-5-provision-the-sandbox)
  * [Verifying results](#verifying-results)
    * [Verify Bastion VM completed provisioning](#verify-bastion-vm-completed-provisioning)
    * [Verify that the nested VHI cluster is fully configured.](#verify-that-the-nested-vhi-cluster-is-fully-configured)
<!-- TOC -->

## Description

This repository contains code to automatically provision and configure a sandbox environment 
for students working on the VHI Operations Professional training course. 

This repository is intended for Virtuozzo Technical Trainers to provision a sandbox for students on top of
Virtuozzo Hybrid Infrastructure cloud. However, it can benefit anyone with access to an OpenStack
or Virtuozzo Hybrid Infrastructure project who wishes to complete the VHI Operations Professional course.

The resulting sandbox will consist of 5 VMs and pre-configured virtual network infrastructure.
Here is the diagram of the infrastructure of a sandbox students will work with:

<img alt="Diagram" src="readme/infra_diagram.png" title="Sandbox Infrastructure Diagram" width="500"/>

**_The Terraform plan will not provision `node5.lab` VM.
Deploying this VM is one of the exercises students will take during the course._**

## Structure and conventions

The repository contains:
- Terraform plan files, ending with `.tf` extension.
- Shell scripts, ending with `.sh` extension.
- Auxiliary files required for students to complete the course (.zip)

Terraform plan files follow this naming scheme:
- `00_vars_*.tf` files contain variables.
- `10_data_*.tf` files contain runtime data collection modules.
- `20_res_*.tf` files contain resource definitions.

## Pre-requisites

To use this automation, your environment must meet the requirements described below.

### Nested virtualization support
- The OpenStack or VHI cloud must support nested virtualization.

**How to test if nested virtualization is enabled.**

On Intel CPUs, you can test if the cloud supports nested virtualization by deploying a test VM
and executing the following command:

```# cat /proc/cpuinfo | grep vmx```

### Project resource quotas

The cloud project must provide the following resources:

- vCPU: 74 cores.
- RAM: 148 GiB.
- Disk space: 2000 GiB.
- Public IPs: 2.

### Images

The project you are working with must have the following images:

**VHI QCOW2 image.** 
- The image must have `cloud-init` installed.

_If you are not a Virtuozzo employee, request the appropriate image from your Onboarding Manager._

**Ubuntu 20.04 QCOW2 image.**
- The image must have `cloud-init` installed.
- The version must be 20.04. Other versions haven't been tested and will likely fail to configure.

> You can get the latest version of the image from the official Ubuntu website:
> 
> https://cloud-images.ubuntu.com/releases/focal/release/ubuntu-20.04-server-cloudimg-amd64.img


## Sandbox provisioning

To provision a sandbox, you will need to complete five steps:
1. Clone this repository to your workstation.
2. Install Terraform on your workstation.
3. Adjust Terraform variables.
4. Adjust and source the OpenStack credentials file.
5. Apply Terraform configuration.

### Step 1: Clone the repository

``` 
git clone https://github.com/virtuozzo/vhi-ops-professional
```
```
cd vhi-ops-professional
```

### Step 2: Install Terraform

Download and install Terraform for your operating system from 
[Terraform website](https://developer.hashicorp.com/terraform/downloads).

### Step 3: Adjust Terraform Variables

You will need to adjust four variable files: 
- `00_vars_access.tf` to set the SSH key path for the sandbox.
- `00_vars_bastion.tf` to set variables related to Bastion VM.
- `00_vars_network.tf` to set variables related to networking.
- `00_vars_vhi_cluster.tf` to set variables related to VHI nodes.

#### Adjust SSH key path

You need to set the `ssh_key` variable in the `00_vars_access.tf` file to point to the SSH key.
For example, if your SSH key is located in `~/.ssh/student.pub`, the variable should look like this:

```
## Bastion/Node access SSH key
variable "ssh-key" {
  type    = string
  default = "~/.ssh/student.pub" # Replace with the path to your public SSH key
}
```

#### Adjust Bastion VM variables 

You need to adjust three variables in `00_vars_bastion.tf` file:
1. Bastion image name.
2. Bastion flavor.
3. Bastion storage policy


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

#### Adjust VHI node variables

You need to adjust four variables in the `00_vars_vhi_cluster.tf` file:
1. VHI image name.
2. Main node flavor.
3. Worker node flavor.
4. VHI node storage policy

##### VHI Image name

You need to set the `vhi_image` variable to the name of the VHI image in your project.
For example, if in your cloud, the VHI image is named `VHI-latest.qcow2`, the variable should look like this:

```
## VHI image name
variable "vhi-image" {
  type = string
  default = "VHI-latest.qcow2" # If required, replace the image name with the one you have in the cloud
}

```

##### Main node flavor

You need to set the `flavor_main` variable to the flavor name that provides at least 16 CPU cores and 32 GiB RAM.
For example, if in your cloud such flavor is named `va-16-32`, the variable should look like this:

```
## Main node flavor name
variable "vhi-flavor_main" {
  type    = string
  default = "va-16-32"  # If required, replace the flavor name with the one you have in the cloud
}
```

##### Worker node flavor

You need to set the `flavor_worker` variable to the flavor name that provides at least 8 CPU cores and 16 GiB RAM.
For example, if in your cloud such flavor is named `va-8-16`, the variable should look like this:

```
## Worker node flavor name
variable "vhi-flavor_worker" {
  type    = string
  default = "va-8-16"   # If required, replace the flavor name with the one you have in the cloud
}
```

##### VHI node storage policy

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

You need to set the `external_network-name` variable in the `00_vars_networking.tf` file to point to the physical network with Internet access.
For example, if your physical network is called `public`, the variable should look like this:

```
## External network
variable "external_network-name" {
  type    = string
  default = "public"  # If required, replace the network name with the one you have in the cloud
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

Initialize Terraform in the directory and apply Terraform plan that will set up the sandbox:

```
terraform init && terraform apply
```

_**Wait at least 20 minutes before proceeding!
Terraform will configure all VMs at first boot, which can take some time depending on the cloud performance and internet connection speed.**_

## Verifying results

After applying the Terraform plan and waiting for scripts to complete the environment's configuration, you may proceed to verify the access.

_**If you are not a Virtuozzo employee, request Bastion VM credentials from your Onboarding Manager.**_

### Verify Bastion VM completed provisioning

Connect to Bastion VM using the remote console.
If Bastion VM is still being configured, you will see the following prompt:

<img alt="&quot;Customization in progress&quot; Prompt" src="readme/bastion_not_ready.png" title="Bastion VM is not ready" width="500"/>

Once the configuration of Bastion is complete, you should see the graphical login prompt:

<img alt="Ready state" src="readme/bastion_ready.png" title="Bastion VM is ready" width="500"/>

### Verify that the nested VHI cluster is fully configured.

Students are expected to work with their sandbox using an RDP connection to Bastion VM.
To verify that the nested VHI cluster is ready for students to begin training, do the following:

1. Connect to the Bastion VM using the RDP client on port `3390`.
2. Access nested VHI Admin Panel using desktop shortcut (username `admin`; password: `Lab_admin`):

<img alt="Bastion VM desktop shortcut" src="readme/bastion_desktop.png" title="Connecting to VHI Admin Panel" width="500"/>

3. Navigate to the Compute section in the left-hand menu:

<img alt="Admin Panel Compute" src="readme/admin_panel_compute.png" title="Navigating to Compute cluster overview screen in Admin Panel" width="500"/>

You should see the compute cluster deployment progress bar:

<img alt="Compute Deployment Progress Bar" src="readme/compute_progress_bar.png" title="Compute Cluster deployment in progress" width="500"/>

**_Once the compute cluster is deployed, the sandbox is ready for use._**
