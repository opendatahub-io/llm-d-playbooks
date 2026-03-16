#!/bin/bash
# Diagnostic script: dump all NIC-related info from a single GPU worker node
# to figure out why the main discovery script doesn't find NICs on IBM Cloud.
set -euo pipefail

# Pick the first worker node that has GPUs (skip storage/infra workers)
NODE="${1:-}"
if [ -z "$NODE" ]; then
  echo "Auto-selecting first GPU worker node..."
  WORKERS=$(oc get nodes -l node-role.kubernetes.io/worker -o jsonpath='{.items[*].metadata.name}')
  for W in $WORKERS; do
    has_gpu=$(oc debug node/$W --image=registry.access.redhat.com/ubi9/ubi:latest -- \
      bash -c 'chroot /host bash -c "ls /sys/bus/pci/devices/*/vendor 2>/dev/null | head -1 | xargs -I{} grep -l 0x10de {} 2>/dev/null | wc -l"' 2>/dev/null || echo 0)
    if [ "$has_gpu" != "0" ]; then
      NODE="$W"
      break
    fi
  done
  if [ -z "$NODE" ]; then
    echo "ERROR: No GPU worker found"
    exit 1
  fi
fi

echo "=========================================="
echo "NIC Diagnostic on node: $NODE"
echo "=========================================="
echo ""

oc debug node/$NODE --image=registry.access.redhat.com/ubi9/ubi:latest -- bash -c '
chroot /host bash -c "

echo \"=== 1. ALL network interfaces (ip link) ===\"
ip -o link show 2>/dev/null | awk \"{print \\\"  \\\", \\\$0}\"
echo \"\"

echo \"=== 2. Interfaces with IP addresses ===\"
ip -o addr show 2>/dev/null | grep \"inet \" | awk \"{print \\\"  \\\", \\\$0}\"
echo \"\"

echo \"=== 3. All /sys/class/net/* interfaces and their properties ===\"
for iface in /sys/class/net/*; do
  ifname=\$(basename \$iface)
  driver=\$(readlink -f \$iface/device/driver 2>/dev/null | xargs basename 2>/dev/null || echo none)
  pci_path=\$(readlink -f \$iface/device 2>/dev/null || echo none)
  pci=\$(basename \"\$pci_path\" 2>/dev/null || echo none)
  vendor=\$(cat \$iface/device/vendor 2>/dev/null || echo none)
  devid=\$(cat \$iface/device/device 2>/dev/null || echo none)
  operstate=\$(cat \$iface/operstate 2>/dev/null || echo unknown)
  has_ib_dir=no
  [ -d \"\$iface/device/infiniband\" ] && has_ib_dir=yes
  is_vf=no
  [ -L \"\$iface/device/physfn\" ] && is_vf=yes
  has_ip=\$(ip addr show \$ifname 2>/dev/null | grep -c \"inet \" || echo 0)
  echo \"  \$ifname  driver=\$driver  pci=\$pci  vendor=\$vendor  devid=\$devid  state=\$operstate  has_ib_sysfs=\$has_ib_dir  is_vf=\$is_vf  has_ip=\$has_ip\"
done
echo \"\"

echo \"=== 4. All Mellanox/NVIDIA-networking PCI devices (vendor 15b3) ===\"
for dev in /sys/bus/pci/devices/*; do
  vendor=\$(cat \$dev/vendor 2>/dev/null || echo none)
  if [ \"\$vendor\" = \"0x15b3\" ]; then
    pci=\$(basename \$dev)
    devid=\$(cat \$dev/device 2>/dev/null || echo unknown)
    class=\$(cat \$dev/class 2>/dev/null || echo unknown)
    driver=\$(readlink -f \$dev/driver 2>/dev/null | xargs basename 2>/dev/null || echo none)
    numa=\$(cat \$dev/numa_node 2>/dev/null || echo -1)
    has_ib=no
    [ -d \"\$dev/infiniband\" ] && has_ib=yes
    is_vf=no
    [ -L \"\$dev/physfn\" ] && is_vf=yes
    sriov_numvfs=\$(cat \$dev/sriov_numvfs 2>/dev/null || echo n/a)
    sriov_totalvfs=\$(cat \$dev/sriov_totalvfs 2>/dev/null || echo n/a)
    net_ifaces=\$(ls \$dev/net 2>/dev/null | tr '\n' ',' || echo none)
    echo \"  \$pci  devid=\$devid  class=\$class  driver=\$driver  numa=\$numa  ib_sysfs=\$has_ib  is_vf=\$is_vf  sriov=\$sriov_numvfs/\$sriov_totalvfs  net=\$net_ifaces\"
  fi
done
echo \"\"

echo \"=== 5. RDMA devices (/sys/class/infiniband/) ===\"
if [ -d /sys/class/infiniband ]; then
  for rd in /sys/class/infiniband/*; do
    rdname=\$(basename \$rd)
    pci_path=\$(readlink -f \$rd/device 2>/dev/null || echo none)
    pci=\$(basename \"\$pci_path\" 2>/dev/null || echo none)
    link_layer=\$(cat \$rd/ports/1/link_layer 2>/dev/null || echo unknown)
    state=\$(cat \$rd/ports/1/state 2>/dev/null || echo unknown)
    echo \"  \$rdname  pci=\$pci  link_layer=\$link_layer  port1_state=\$state\"
  done
else
  echo \"  /sys/class/infiniband does not exist\"
fi
echo \"\"

echo \"=== 6. Loaded Mellanox kernel modules ===\"
lsmod 2>/dev/null | grep -iE \"mlx|rdma|ib_\" | awk \"{print \\\"  \\\", \\\$0}\" || echo \"  lsmod not available\"
echo \"\"

echo \"=== 7. enp* interfaces (common IBM Cloud NIC naming) ===\"
for iface in /sys/class/net/enp*; do
  [ -e \"\$iface\" ] || { echo \"  no enp* interfaces found\"; break; }
  ifname=\$(basename \$iface)
  driver=\$(readlink -f \$iface/device/driver 2>/dev/null | xargs basename 2>/dev/null || echo none)
  pci_path=\$(readlink -f \$iface/device 2>/dev/null || echo none)
  pci=\$(basename \"\$pci_path\" 2>/dev/null || echo none)
  vendor=\$(cat \$iface/device/vendor 2>/dev/null || echo none)
  devid=\$(cat \$iface/device/device 2>/dev/null || echo none)
  operstate=\$(cat \$iface/operstate 2>/dev/null || echo unknown)
  is_vf=no
  [ -L \"\$iface/device/physfn\" ] && is_vf=yes
  carrier=\$(cat \$iface/carrier 2>/dev/null || echo 0)
  echo \"  \$ifname  driver=\$driver  pci=\$pci  vendor=\$vendor  devid=\$devid  state=\$operstate  is_vf=\$is_vf  carrier=\$carrier\"
done

"
' 2>&1 | grep -v "^Starting pod" | grep -v "^Removing debug pod" | grep -v "^To use host binaries" | grep -v "^E[0-9]"
