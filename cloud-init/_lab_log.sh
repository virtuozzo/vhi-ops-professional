#!/bin/bash
# Prepended to node/bastion cloud-init by Terraform (no templatefile — no ${} parsing).
# Defines lab_log for consistent timestamps and /var/log/deployment.log.

DEPLOYMENT_LOG=/var/log/deployment.log
mkdir -p "$(dirname "$DEPLOYMENT_LOG")"

lab_log() {
  local level="$1"
  shift
  local msg="$*"
  local ts
  ts=$(date +'%Y-%m-%d %H:%M:%S')
  printf '[%s] %s %s\n' "$level" "$ts" "$msg" | tee -a "$DEPLOYMENT_LOG"
}

# End of function definitions (this file only defines lab_log; Terraform joins node.sh or bastion.sh next).
