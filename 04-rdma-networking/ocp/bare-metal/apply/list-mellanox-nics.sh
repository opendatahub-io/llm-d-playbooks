#!/bin/bash
# Lists Mellanox NICs on each worker node (PCI 15b3). Run from a machine with oc.
# Usage: ./list-mellanox-nics.sh [--all|-a]
#   --all, -a: Include devices with no network interface

SHOW_ALL=0
while [[ $# -gt 0 ]]; do
  case $1 in
    --all|-a)
      SHOW_ALL=1
      shift
      ;;
    *)
      echo "Usage: $0 [--all|-a]"
      echo "  --all, -a: Include devices with no network interface"
      exit 1
      ;;
  esac
done

# Get worker nodes
WORKER_NODES=$(oc get nodes --selector='node-role.kubernetes.io/worker' -o name )

# Check if any worker node was found
if [ -z "$WORKER_NODES" ]; then
  echo "No worker nodes found."
  exit 1
fi

# Run on each node
COMMAND='for d in $(lspci -Dn -d 15b3: | cut -d" " -f1); do
  device_info=$(lspci -nn -s $d | grep -i mellanox)
  if [ -n "$device_info" ]; then
    if [ -d /sys/bus/pci/devices/$d/net ]; then
      for iface in /sys/bus/pci/devices/$d/net/*; do
        echo "$d -> $(basename $iface) -> $device_info"
      done
    else
      if [ '"$SHOW_ALL"' -eq 1 ]; then
        echo "$d -> No network interface -> $device_info"
      fi
    fi
  fi
done'

# Loop through each worker node and execute the command
for NODE in $WORKER_NODES; do
  echo "=== Running on $NODE ==="
  # Use oc debug to run the command in a chrooted environment
  oc debug $NODE -- chroot /host /bin/bash -c "$COMMAND" 2>/dev/null
  if [ $? -ne 0 ]; then
    echo "Error running command on $NODE"
  fi
  echo ""
done
