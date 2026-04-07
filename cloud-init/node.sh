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
#
# lab_log is defined in the prepended _lab_log.sh fragment.

LAB_TRACK="${lab_track}"
ENABLE_CLUSTER_COMPUTE="${enable_cluster_compute}"

track_is_s3() { [[ "$LAB_TRACK" == "s3" ]]; }
# Non-S3 tracks share the same storage / VM_Public / compute layout (operations, vzsup).
track_is_not_s3() { [[ "$LAB_TRACK" != "s3" ]]; }
cluster_compute_enabled() { [[ "$ENABLE_CLUSTER_COMPUTE" == "true" ]]; }

token=""

get_token() {
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

retry() {
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
      lab_log WARN "Retry $count/$retries of command '$cmd' exited $exit with error: '$(cat $error_output_file)' - retrying in $wait seconds..."
      sleep $wait
    else
      lab_log ERROR "Retry $count/$retries of command '$cmd' exited $exit with error: '$(cat $error_output_file)' - no more retries left. Exiting script."
      echo "Error: Command '$cmd' exited with error: '$(cat $error_output_file)'. Exiting script."
      exit $exit
    fi
    count=$(($count + 1))
  done

  rm -f $error_output_file
  return 0
}

assign_iface() {
  iface=$1
  infra_network=$2
  until vinfra --vinfra-password ${password_admin} node iface list --node $(hostname) | grep -q "$iface.*$infra_network"
  do
    lab_log DEBUG "Assigning $iface to $infra_network network..."
    vinfra --vinfra-password ${password_admin} node iface set --network $infra_network $iface --node $(hostname) --wait
    sleep 10
  done
  lab_log INFO "Assigning $iface to $infra_network network...done."
}

remove_ipv4_from_iface() {
  iface=$1
  node=$2
  lab_log INFO "Removing temporary IP address from $iface interface of $node..."
  retry vinfra --vinfra-password ${password_admin} node iface set --ipv4 '' $iface --node $node --wait
  lab_log INFO "Removing temporary IP address from $iface interface of $node... done."
}

housekeeping_host() {
  timedatectl set-timezone UTC
  rm -rf /root/.ssh/*

  lab_log INFO "Changing hostname..."
  hostnamectl set-hostname "${hostname}"
  lab_log INFO "Changing hostname...done"

  lab_log INFO "Changing password..."
  echo ${password_root} | passwd --stdin root
  lab_log INFO "Changed password to ${password_root}"

  lab_log INFO "Generating new host and machine ID..."
  echo `/usr/bin/openssl rand -hex 8` > /etc/vstorage/host_id
  echo `/usr/bin/openssl rand -hex 16` > /etc/machine-id
  lab_log INFO "Generating new host and machine ID...done"

  lab_log INFO "Fixing up iscsi initiatorname..."
  hostid=$(cat /etc/vstorage/host_id | cut -c -12)
  echo "InitiatorName=iqn.1994-05.com.redhat:$hostid" > /etc/iscsi/initiatorname.iscsi
  lab_log INFO "Fixing up iscsi initiatorname...done"

  lab_log INFO "Generating new vstorage-ui-agent UUID..."
  systemctl restart systemd-journald
  sed -i '/NODE_ID =/d' /etc/vstorage/vstorage-ui-agent.conf
  echo "NODE_ID = '`/usr/bin/openssl rand -hex 16`'" >> /etc/vstorage/vstorage-ui-agent.conf
  lab_log INFO "Generating new vstorage-ui-agent UUID...done"
}

write_ifcfg_eth012() {
  lab_log INFO "Applying interface configuration..."
  cat > /etc/sysconfig/network-scripts/ifcfg-eth0 <<EOF
BOOTPROTO="static"
IPADDR="${storage_ip}"
PREFIX="24"
DEVICE="eth0"
ONBOOT="yes"
IPV6INIT="no"
TYPE="Ethernet"
EOF
  lab_log INFO "Configured storage interface eth0"

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
  lab_log INFO "Configured private interface eth1"

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
  lab_log INFO "Configured public interface eth2"
}

write_ifcfg_eth3_vm_public() {
  if ! cluster_compute_enabled; then
    lab_log INFO "Applying interface configuration...done."
    return 0
  fi
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
  lab_log INFO "Configured vm-public interface eth3"
  lab_log INFO "Applying interface configuration...done."
}

restart_network_ifaces() {
  systemctl stop vstorage-ui-agent
  lab_log INFO "Stopped vstorage-ui-agent service"
  sleep 3

  local eths="eth0 eth1 eth2"
  cluster_compute_enabled && eths="$eths eth3"
  for eth in $eths
  do
    lab_log DEBUG "Restarting $eth interface..."
    ifdown $eth
    ifup $eth
  done
  sleep 10
  lab_log INFO "Restarting interfaces...done."
}

discover_disks_mds_cs() {
  mds_disk=$(lsblk -nbdo NAME,SIZE | awk '$2 > 150000000000 {print $1}' | head -n 1)
  lab_log INFO "Storage configuration. MDS disk found: $mds_disk"
  if track_is_s3; then
    cs_disk=$(lsblk -nbdo NAME,SIZE | grep -v sr | awk '$2 < 150000000000 {print $1}' | head -n 1)
    cs_disk_2=$(lsblk -nbdo NAME,SIZE | grep -v sr | awk '$2 < 150000000000 {print $1}' | tail -n 1)
    lab_log INFO "Storage configuration. CS disk found: $cs_disk"
    lab_log INFO "Storage configuration. Second CS disk found: $cs_disk_2"
  else
    cs_disk=$(lsblk -nbdo NAME,SIZE | awk '$2 < 150000000000 {print $1}' | grep -v sr | head -n 1)
    lab_log INFO "Storage configuration. CS disk found: $cs_disk"
  fi
}

node1_start_backend_register() {
  lab_log INFO "Starting vstorage-ui-agent service"
  systemctl start vstorage-ui-agent
  lab_log INFO "Started vstorage-ui-agent service"

  lab_log INFO "Starting vstorage-ui-backend service"
  systemctl start vstorage-ui-backend
  lab_log INFO "Started vstorage-ui-backend service"

  lab_log INFO "Configuring backend..."
  echo ${password_admin} | bash /usr/libexec/vstorage-ui-backend/bin/configure-backend.sh -x eth2 -i eth1
  lab_log INFO "Configured backend... done."

  lab_log INFO "Initializing backend..."
  /usr/libexec/vstorage-ui-backend/libexec/init-backend.sh
  lab_log INFO "Initializing backend... done."

  lab_log INFO "Restarting backend..."
  systemctl restart vstorage-ui-backend
  lab_log INFO "Restarting backend... done."

  lab_log INFO "Registering local node as MN..."
  retry /usr/libexec/vstorage-ui-agent/bin/register-storage-node.sh -m ${private_ip} -x eth2
  sleep 15
  lab_log INFO "Backend node registered."

  node_id=`vinfra --vinfra-password ${password_admin} node list -f value -c id -c is_primary | sort -k 2 | tail -n 1 | cut -c1-36`
}

node1_cluster_networks_and_traffic() {
  lab_log INFO "Creating additional infrastructure networks..."
  if track_is_not_s3; then
    vinfra --vinfra-password ${password_admin} cluster network create Storage
    vinfra --vinfra-password ${password_admin} cluster network create VM_Public
    lab_log INFO "Created Storage and VM_public network"
  else
    vinfra --vinfra-password ${password_admin} cluster network create Storage
    lab_log INFO "Created Storage network"
  fi

  lab_log INFO "Reassigning network interfaces to correct networks"
  assign_iface eth0 Storage
  assign_iface eth1 Private
  assign_iface eth2 Public
  cluster_compute_enabled && assign_iface eth3 VM_Public

  lab_log INFO "Configuring traffic types..."
  if track_is_not_s3; then
    vinfra --vinfra-password ${password_admin} cluster network set-bulk \
    --network 'Private':'Backup (ABGW) private','Internal management','SNMP','SSH','VM private' \
    --network 'Public':'Backup (ABGW) public','Compute API','iSCSI','VM backups','NFS','S3 public','Self-service panel','SSH','Admin panel' \
    --network 'Storage':'Storage','OSTOR private' \
    --network 'VM_Public':'VM public' \
    --wait
  else
    vinfra --vinfra-password ${password_admin} cluster network set-bulk \
    --network 'Private':'Backup (ABGW) private','Internal management','SNMP','SSH','VM private' \
    --network 'Public':'Backup (ABGW) public','Compute API','iSCSI','VM backups','NFS','Self-service panel','SSH','Admin panel','VM public' \
    --network 'Storage':'Storage' \
    --wait
  fi
  sleep 10
  lab_log INFO "Configuring traffic types...done"
}

node1_wait_installing_dns_sleep() {
  lab_log INFO "Checking if local node is in installing state..."
  until vinfra node show node1 | grep -q is_installing.*False
    do
    lab_log DEBUG "Waiting for local node to report installation complete..."
    sleep 10
    done
  lab_log INFO "Local node is no longer in installing state."

  lab_log INFO "Configuring cluster DNS settings..."
  vinfra --vinfra-password ${password_admin} cluster settings dns set --nameservers "8.8.8.8,1.1.1.1"

  if track_is_not_s3; then
    lab_log INFO "Waiting 120 sec. for disks to initialize before deploying storage cluster."
    sleep 120
  else
    sleep 120
  fi
}

node1_create_storage_cluster() {
  lab_log INFO "Deploying storage cluster..."
  if track_is_not_s3; then
    retry vinfra --vinfra-password ${password_admin} cluster create \
    --disk $mds_disk:mds-system \
    --disk $cs_disk:cs:tier=0,journal-type=inner_cache \
    --node "$node_id" ${cluster_name} \
    --wait
  else
    retry vinfra --vinfra-password ${password_admin} cluster create \
    --disk $mds_disk:mds-system \
    --disk $cs_disk:cs:tier=0,journal-type=inner_cache \
    --disk $cs_disk_2:cs:tier=1,journal-type=inner_cache \
    --node "$node_id" ${cluster_name} \
    --wait
  fi

  until vinfra --vinfra-password ${password_admin} cluster show | grep -q "name.*${cluster_name}"
  do
  lab_log DEBUG "Waiting for storage cluster to initialize..."
  sleep 10
  done
  lab_log INFO "Deploying storage cluster...done"
}

node1_wait_ifaces_ready() {
  if track_is_not_s3; then
    no_ip_interfaces=$(vinfra node iface list --all | grep -v eth3 | grep \\[\\] | wc -l)
    while [ "0" != "$no_ip_interfaces" ]
    do
    lab_log DEBUG "There are $no_ip_interfaces with no IP addresses, waiting..."
    sleep 10
    no_ip_interfaces=$(vinfra node iface list --all | grep \\[\\] | wc -l)
    done
  else
    no_ip_interfaces=$(vinfra node iface list --all | grep \\[\\] | wc -l)
    while [ "0" != "$no_ip_interfaces" ]
    do
    lab_log DEBUG "There are $no_ip_interfaces with no IP addresses, waiting..."
    sleep 10
    no_ip_interfaces=$(vinfra node iface list --all | grep \\[\\] | wc -l)
    done
  fi
}

node1_wait_unassigned_zero() {
  lab_log INFO "Waiting for other nodes to register..."
  unassigned_nodes_count=$(vinfra --vinfra-password ${password_admin} node list -f value -c host -c is_assigned | grep -c False || true)
  while [ "0" != "$${unassigned_nodes_count:-0}" ]
  do
  lab_log DEBUG "There are $unassigned_nodes_count unassigned nodes left. waiting..."
  sleep 10
  unassigned_nodes_count=$(vinfra --vinfra-password ${password_admin} node list -f value -c host -c is_assigned | grep -c False || true)
  done
  lab_log INFO "Waiting for other nodes to register...done"
}

node1_post_storage_extras() {
  if track_is_not_s3; then
    remove_ipv4_from_iface eth3 "node1.vstoragedomain"
    remove_ipv4_from_iface eth3 "node2.vstoragedomain"
    remove_ipv4_from_iface eth3 "node3.vstoragedomain"
    remove_ipv4_from_iface eth3 "node4.vstoragedomain"
  else
    vinfra --vinfra-password ${password_admin} \
            domain create --description "autocreated for lab env" --enable "WonderSI" -f value
    lab_log INFO "Creating Domain so that you don't have to..."

    vinfra --vinfra-password ${password_admin} \
      domain project create --description "autocreated for lab env" --enable --domain "WonderSI" "MyProject" -f value
    lab_log INFO "Creating Project so that you don't have to..."

    echo ${password_admin} | vinfra --vinfra-password ${password_admin} \
            domain user create domainadmin --domain "WonderSI" --assign "MyProject" project_admin --domain-permissions domain_admin --enable -f value
    lab_log INFO "Creating Domain User so that you don't have to..."
  fi
}

node1_ha_setup() {
  ha_nodes=node1,node2,node3
  cluster_nodes=$(vinfra --vinfra-password ${password_admin} node list -f value -c host -c id | sort -k2 | awk '{print $1}' | tr '\n' ' ' | sed 's/.$//' | sed -e 's: :,:g')

  lab_log INFO "The list of cluster nodes: $cluster_nodes"
  lab_log INFO "The list of HA nodes: $ha_nodes"

  lab_log INFO "Setting up HA..."
  retry vinfra --vinfra-password ${password_admin} cluster ha create --virtual-ip Public:${ha_ip_public} --virtual-ip Private:${ha_ip_private} --node $ha_nodes --force --timeout 3600

  until vinfra --vinfra-password ${password_admin} cluster ha show | grep -q ${ha_ip_private}
  do
  lab_log DEBUG "Waiting for HA cluster to assemble..."
  sleep 30
  done
  sleep 5
  lab_log INFO "Setting up HA...done"
}

node1_compute_setup() {
  compute_nodes=$(vinfra --vinfra-password ${password_admin} node list -f value -c host -c id | sort -k2 | awk '{print $1}' | tr '\n' ' ' | sed 's/.$//' | sed -e 's: :,:g')
  lab_log INFO "The list of compute cluster nodes: $compute_nodes"

  lab_log INFO "Creating compute cluster..."
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
  lab_log INFO "Creating compute cluster...done"
}

node1_main() {
  discover_disks_mds_cs
  node1_start_backend_register
  node1_cluster_networks_and_traffic
  node1_wait_installing_dns_sleep
  node1_create_storage_cluster
  node1_wait_ifaces_ready
  node1_wait_unassigned_zero
  node1_post_storage_extras
  node1_ha_setup
  cluster_compute_enabled && node1_compute_setup
}

join_node_register_and_assign() {
  systemctl start vstorage-ui-agent
  lab_log INFO "Started vstorage-ui-agent service"

  until curl -sk --fail -o /dev/null "https://${mn_ip}:8888/api/v2/login"
  do
  lab_log DEBUG "Waiting for backend auth endpoint to become available..."
  sleep 10
  done
  lab_log INFO "Backend authentication endpoint is available, waiting for restart."
  sleep 120

  lab_log INFO "Trying to get token from Management Node to perform registration"
  token=""
  get_token

  lab_log INFO "Registering in the cluster..."
  /usr/libexec/vstorage-ui-agent/bin/register-storage-node.sh -m ${mn_ip} -t "$token" -x eth2
  lab_log INFO "Registering in the cluster...done"

  lab_log INFO "Reassigning network interfaces to correct networks"
  assign_iface eth0 Storage
  assign_iface eth1 Private
  assign_iface eth2 Public
  cluster_compute_enabled && assign_iface eth3 VM_Public
  lab_log DEBUG "Waiting 15 seconds for DB to update"
}

join_node_wait_and_join() {
  until vinfra --vinfra-password ${password_admin} cluster show | grep -q "name.*${cluster_name}"
  do
  lab_log DEBUG "Waiting for storage cluster to initialize..."
  sleep 10
  done
  lab_log INFO "Waiting for storage cluster to initialize...done"

  lab_log INFO "Waiting 120 sec. for disks to initialize before joining storage cluster."
  sleep 120
  node_id=`hostname`
  lab_log INFO "Joining the storage cluster..."
  if track_is_not_s3; then
    retry sshpass -p ${password_root} ssh -o 'StrictHostKeyChecking=no' -o LogLevel=QUIET root@${mn_ip} \
      "vinfra --vinfra-password ${password_admin} node join \
      --disk $mds_disk:mds-system --disk $cs_disk:cs:tier=0,journal-type=inner_cache \
      $node_id --wait"
  else
    retry sshpass -p ${password_root} ssh -o 'StrictHostKeyChecking=no' -o LogLevel=QUIET root@${mn_ip} \
      "vinfra --vinfra-password ${password_admin} node join \
      --disk $mds_disk:mds-system --disk $cs_disk:cs:tier=0,journal-type=inner_cache \
      --disk $cs_disk_2:cs:tier=1,journal-type=inner_cache \
      $node_id --wait"
  fi
  lab_log INFO "Joining the storage cluster...done"
}

join_node_main() {
  discover_disks_mds_cs
  join_node_register_and_assign
  join_node_wait_and_join
}

# -----------------------------------------------------------------------------
# End of function definitions.
# Main: order of operations — runs on every node; branches to node1 vs join.
# -----------------------------------------------------------------------------
housekeeping_host
write_ifcfg_eth012
write_ifcfg_eth3_vm_public
restart_network_ifaces

if [ "$(hostname)" = "node1.lab" ]; then
  node1_main
else
  join_node_main
fi
