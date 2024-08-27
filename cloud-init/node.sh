#!/bin/bash

# ATTENTION
# There are two types of variables in this script!
#
# Variables written as $variable are local bash variables,
# relevant in the local context of this script i.e.,
# for the fuctions and calls that are not unique.
#
# Variables written as $_{variable} are replaced with the
# data from Terraform templatefile function in instance
# code.

token=""

function get_token {
  local max_retries=5
  local retry_delay=10
  local count=1
  local cmd="vinfra --vinfra-password ${password_admin} node token show -f value -c token"
  
  while [ -z "$token" ] && [ $count -le $max_retries ]; do
    token=$(sshpass -p ${password_root} ssh -q -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@${mn_ip} "$cmd")

    if [ -z "$token" ]; then
      echo "Attempt $count/$max_retries: Token not received. Retrying in $retry_delay seconds..."
      count=$((count + 1))
      retry_delay=$((retry_delay * 1.5))
      sleep $retry_delay
    else
      echo "Token received on attempt $count."
    fi
  done

  if [ -z "$token" ]; then
    echo "Failed to obtain token after $max_retries attempts. Exiting."
    exit 1
  fi
}

function log_msg {
    message=$1
    echo "[DEBUG] $(date +'%Y-%m-%d %H:%M:%S,%3N') $message" >> "/tmp/deploy.log"
}

function retry {
  local retries=8
  local count=1
  local wait
  local cmd="$@"
  local error_output_file=$(mktemp)

  until { "$@" > >(tee >(cat)) 2> >(tee >(cat) >&2) ;} 1>"$error_output_file" ; do
    exit=$?
    case $count in
      1) wait=10 ;;
      2) wait=30 ;;
      3) wait=60 ;;
      4) wait=120 ;;
      5) wait=120 ;;
      6) wait=120 ;;
      7) wait=120 ;;
      8) wait=600 ;;
    esac
    if [ $count -le $retries ]; then
      log_msg "Retry $count/$retries of command '$cmd' exited $exit with error: '$(cat $error_output_file)' - retrying in $wait seconds..."
      sleep $wait
    else
      log_msg "Retry $count/$retries of command '$cmd' exited $exit with error: '$(cat $error_output_file)' - no more retries left. Exiting script."
      echo "Error: Command '$cmd' exited with error: '$(cat $error_output_file)'. Exiting script."
      exit $exit
    fi
    count=$(($count + 1))
  done

  rm -f $error_output_file
  return 0
}

function assign_iface {
  iface=$1
  infra_network=$2
  until vinfra --vinfra-password ${password_admin} node iface list --node $(hostname) | grep -q "$iface.*$infra_network"
  do
    log_msg "Assigning $iface to $infra_network network..."
    vinfra --vinfra-password ${password_admin} node iface set --network $infra_network $iface --node $(hostname) --wait
    sleep 10
  done
  log_msg "Assigning $iface to $infra_network network...done."
}

function remove_ipv4_from_iface {
  iface=$1
  node=$2
  log_msg "Removing temporary IP address from $iface interface of $node..."
  retry vinfra --vinfra-password ${password_admin} node iface set --ipv4 '' $iface --node $node --wait
  log_msg "Removing temporary IP address from $iface interface of $node... done."
}

function deploy_compute_addons {
  IFS=','
  for i in $1; do
    log_msg "Deploying $i compute addon"
    vinfra service compute set --enable-$i --wait --timeout 3600
    log_msg "Deployed $i compute addon"
  done
}

# Housekeeping
timedatectl set-timezone UTC
rm -rf /root/.ssh/*

log_msg "Changing hostname..."
hostnamectl set-hostname "${hostname}"
log_msg "Changing hostname...done"

log_msg "Changing password..."
echo ${password_root} | passwd --stdin root
log_msg "Changed password to ${password_root}"

log_msg "Generating new host and machine ID..."
echo `/usr/bin/openssl rand -hex 8` > /etc/vstorage/host_id
echo `/usr/bin/openssl rand -hex 16` > /etc/machine-id
log_msg "Generating new host and machine ID...done"

log_msg "Fixing up iscsi initiatorname..."
hostid=$(cat /etc/vstorage/host_id | cut -c -12)
echo "InitiatorName=iqn.1994-05.com.redhat:$hostid" > /etc/iscsi/initiatorname.iscsi
log_msg "Fixing up iscsi initiatorname...done"

log_msg "Generating new vstorage-ui-agent UUID..."
systemctl restart systemd-journald  # restart journald after machine-id was changed
sed -i '/NODE_ID =/d' /etc/vstorage/vstorage-ui-agent.conf
echo "NODE_ID = '`/usr/bin/openssl rand -hex 16`'" >> /etc/vstorage/vstorage-ui-agent.conf
log_msg "Generating new vstorage-ui-agent UUID...done"

# Configuring network interfaces
log_msg "Applying interface configuration..."
cat > /etc/sysconfig/network-scripts/ifcfg-eth0 <<EOF
BOOTPROTO="static"
IPADDR="${storage_ip}"
PREFIX="24"
DEVICE="eth0"
ONBOOT="yes"
IPV6INIT="no"
TYPE="Ethernet"
EOF
log_msg "Configured storage interface eth0"

cat > /etc/sysconfig/network-scripts/ifcfg-eth1 <<EOF
BOOTPROTO="static"
IPADDR="${private_ip}"
PREFIX="24"
DEVICE="eth1"
IPV6INIT="no"
NAME="eth1"
ONBOOT="yes"
TYPE="Ethernet"
EOF
log_msg "Configured private interface eth1"

cat > /etc/sysconfig/network-scripts/ifcfg-eth2 <<EOF
BOOTPROTO="static"
IPADDR="${public_ip}"
PREFIX="24"
GATEWAY="10.0.102.1"
DEVICE="eth2"
IPV6INIT="no"
NAME="eth2"
ONBOOT="yes"
NAMESERVER="8.8.8.8"
TYPE="Ethernet"
EOF
log_msg "Configured public interface eth2"

cat > /etc/sysconfig/network-scripts/ifcfg-eth3 <<EOF
BOOTPROTO="none"
IPADDR="${vm_public_ip}"
PREFIX="24"
DEVICE="eth3"
IPV6INIT="no"
NAME="eth3"
ONBOOT="yes"
TYPE="Ethernet"
EOF
log_msg "Configured vm-public interface eth3"

log_msg "Applying interface configuration...done."

systemctl stop vstorage-ui-agent
log_msg "Stopped vstorage-ui-agent service"
sleep 3

for eth in eth0 eth1 eth2 eth3
do
  log_msg "Restarting $eth interface..."
  ifdown $eth
  ifup $eth
done
sleep 10 # Let network init
log_msg "Restarting interfaces...done."

# Find the disks to be used for Storage cluster deployment
mds_disk=$(lsblk -nbdo NAME,SIZE | awk '$2 > 150000000000 {print $1}' | head -n 1)
log_msg "Storage configuration. MDS disk found: $mds_disk"

cs_disk=$(lsblk -nbdo NAME,SIZE | awk '$2 < 150000000000 {print $1}' | head -n 1)
log_msg "Storage configuration. CS disk found: $cs_disk"

# If running on node1 - deploy Storage and Compute.
# If on any other node - join Storage and Compute
if [ "$(hostname)" = "node1.lab" ]
then ### Code running only on node1
    # Initiate backend
    log_msg "Starting vstorage-ui-agent service"
    systemctl start vstorage-ui-agent
    log_msg "Started vstorage-ui-agent service"

    log_msg "Starting vstorage-ui-backend service"
    systemctl start vstorage-ui-backend
    log_msg "Started vstorage-ui-backend service"

    log_msg "Configuring backend..."
    echo ${password_admin} | bash /usr/libexec/vstorage-ui-backend/bin/configure-backend.sh -x eth2 -i eth1
    log_msg "Configured backend... done."

    log_msg "Initializing backend..."
    /usr/libexec/vstorage-ui-backend/libexec/init-backend.sh
    log_msg "Initializing backend... done."

    log_msg "Restarting backend..."
    systemctl restart vstorage-ui-backend
    log_msg "Restarting backend... done."

    log_msg "Registering local node as MN..."
    retry /usr/libexec/vstorage-ui-agent/bin/register-storage-node.sh -m ${private_ip} -x eth2
    sleep 15 # let backend initialize completely
    log_msg "Backend node registered."

    # Get node ID
    node_id=`vinfra --vinfra-password ${password_admin} node list -f value -c id -c is_primary | sort -k 2 | tail -n 1 | cut -c1-36`

    # Create additional infrastructure networks
    log_msg "Creating additional infrastructure networks..."
    vinfra --vinfra-password ${password_admin} cluster network create Storage
    vinfra --vinfra-password ${password_admin} cluster network create VM_Public
    log_msg "Created Storage and VM_public network"

    # Attach node interfaces to new networks
    log_msg "Reassigning network interfaces to correct networks"
    assign_iface eth0 Storage
    assign_iface eth1 Private
    assign_iface eth2 Public
    assign_iface eth3 VM_Public

    # Configure traffic types for all networks
    log_msg "Configuring traffic types..."
    vinfra --vinfra-password ${password_admin} cluster network set-bulk \
    --network 'Private':'Backup (ABGW) private','Internal management','SNMP','SSH','VM private' \
    --network 'Public':'Backup (ABGW) public','Compute API','iSCSI','VM backups','NFS','S3 public','Self-service panel','SSH','Admin panel' \
    --network 'Storage':'Storage','OSTOR private' \
    --network 'VM_Public':'VM public' \
    --wait
    sleep 10
    log_msg "Configuring traffic types...done"

    # Wait until first node change status from "installing" to "unassigned"
    log_msg "Checking if local node is in installing state..."
    until vinfra node show node1 | grep -q is_installing.*False
      do
      log_msg "Waiting for local node to report installation complete..."
      sleep 10
      done
    log_msg "Local node is no longer in installing state."

    # Configure cluster DNS
    log_msg "Configuring cluster DNS settings..."
    vinfra --vinfra-password ${password_admin} cluster settings dns set --nameservers "8.8.8.8,1.1.1.1"

    # Deploying storage cluster
    log_msg "Deploying storage cluster..."
    retry vinfra --vinfra-password ${password_admin} cluster create \
    --disk $mds_disk:mds-system \
    --disk $cs_disk:cs:tier=0,journal-type=inner_cache \
    --node "$node_id" ${cluster_name} \
    --wait

    ## Check that storage cluster is present
    until vinfra --vinfra-password ${password_admin} cluster show | grep -q "name.*${cluster_name}"
    do
    log_msg "Waiting for storage cluster to initialize..."
    sleep 10
    done
    log_msg "Deploying storage cluster...done"

    # Wait until all new interfaces show up properly in MN database
    no_ip_interfaces=$(vinfra node iface list --all | grep -v eth3 | grep \\[\\] | wc -l)
    while [ "0" != "$no_ip_interfaces" ]
    do
    log_msg "There are $no_ip_interfaces with no IP addresses, waiting..."
    sleep 10
    no_ip_interfaces=$(vinfra node iface list --all | grep \\[\\] | wc -l)
    done

    # Wait until other nodes register in backend
    log_msg "Waiting for other nodes to register..."
    unassigned_nodes_count=$(vinfra --vinfra-password ${password_admin} node list -f value -c host -c is_assigned | grep -c False)
    while [ "0" != "$unassigned_nodes_count" ]
    do
    log_msg "There are $unassigned_nodes_count unassigned nodes left. waiting..."
    sleep 10
    unassigned_nodes_count=$(vinfra --vinfra-password ${password_admin} node list -f value -c host -c is_assigned | grep -c False)
    done 
    log_msg "Waiting for other nodes to register...done"

    # Remove temporay IP address from eth3 Public_VM virtual network
    remove_ipv4_from_iface eth3 "node1.vstoragedomain"
    remove_ipv4_from_iface eth3 "node2.vstoragedomain"
    remove_ipv4_from_iface eth3 "node3.vstoragedomain"
    remove_ipv4_from_iface eth3 "node4.vstoragedomain"

    # Assemble lists of compute and HA nodes
    compute_nodes=$(vinfra --vinfra-password ${password_admin} node list -f value -c host -c id | sort -k2 | awk '{print $1}' | tr '\n' ' ' | sed 's/.$//' | sed -e 's: :,:g')
    ha_nodes=node1,node2,node3

    log_msg "The list of nodes: $compute_nodes"
    log_msg "The list of HA nodes: $ha_nodes"

    # Deploying HA
    log_msg "Setting up HA..."
    retry vinfra --vinfra-password ${password_admin} cluster ha create --virtual-ip Public:${ha_ip_public} --virtual-ip Private:${ha_ip_private} --node $ha_nodes --force --timeout 3600

    ## Check that HA is ready
    until vinfra --vinfra-password ${password_admin} cluster ha show | grep -q ${ha_ip_private}
    do
    log_msg "Waiting for HA cluster to assemble..."
    sleep 30
    done
    sleep 5
    log_msg "Setting up HA...done"

    # Deploy compute cluster
    log_msg "Creating compute cluster..."
    retry vinfra --vinfra-password ${password_admin} \
    service compute create \
    --wait \
    --public-network=VM_Public \
    --subnet cidr="10.44.0.0/24",gateway="10.44.0.1",dhcp="enable",allocation-pool="10.44.0.100-10.44.0.199",dns-server="8.8.8.8" \
    --enable-k8saas \
    --enable-lbaas \
    --enable-metering \
    --node $compute_nodes \
    --force \
    --timeout 3600
    log_msg "Creating compute cluster...done"

### Code running on any node but node1
else
    # Begin registration procedure
    systemctl start vstorage-ui-agent
    log_msg "Started vstorage-ui-agent service"

    # Wait until backend initializes completely
    until curl -sk --fail -o /dev/null "https://${mn_ip}:8888/api/v2/login"
    do
    log_msg "Waiting for backend auth endpoint to become available..."
    sleep 10
    done
    log_msg "Backend authentication endpoint is available, waiting for restart."
    sleep 120 # backend service is restarting, no point in trying to get token

    # Get registration token from MN
    log_msg "Trying to get token from Management Node to perform registration"
    token=""
    get_token

    # Register in the backend
    log_msg "Registering in the cluster..."
    /usr/libexec/vstorage-ui-agent/bin/register-storage-node.sh -m ${mn_ip} -t "$token" -x eth2
    log_msg "Registering in the cluster...done"

    # Assign network interfaces to correct networks
    log_msg "Reassigning network interfaces to correct networks"
    assign_iface eth0 Storage
    assign_iface eth1 Private
    assign_iface eth2 Public
    assign_iface eth3 VM_Public
    log_msg "Waiting 15 seconds for DB to update"

    # Check that storage cluster is present
    until vinfra --vinfra-password ${password_admin} cluster show | grep -q "name.*${cluster_name}"
    do
    log_msg "Waiting for storage cluster to initialize..."
    sleep 10
    done
    log_msg "Waiting for storage cluster to initialize...done"

    # Join the storage cluster
    node_id=`hostname`
    log_msg "Joining the storage cluster..."
    retry sshpass -p ${password_root} ssh -o 'StrictHostKeyChecking=no' -o LogLevel=QUIET root@${mn_ip} \
      "vinfra --vinfra-password ${password_admin} node join \
      --disk $mds_disk:mds-system --disk $cs_disk:cs:tier=0,journal-type=inner_cache \
      $node_id --wait"
    log_msg "Joining the storage cluster...done"
fi