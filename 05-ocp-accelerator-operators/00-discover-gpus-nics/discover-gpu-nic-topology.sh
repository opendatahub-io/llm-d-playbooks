#!/bin/bash
# Discover GPUs and RDMA NICs on cluster worker nodes.
#
# Probes sysfs directly via oc debug -- no operators need to be installed.
# Reports GPU models, NIC link types, SR-IOV capability, and NUMA topology
# to help select the right platform overlay.
#
# Usage:
#   ./discover-gpu-nic-topology.sh
#
# Requires: oc CLI with cluster-admin access
#
# Output: per-node details in /tmp/gpu-nic-probe/ and a summary
# recommending which platform overlay to use.

set -euo pipefail

PROBE_DIR="/tmp/gpu-nic-probe"
mkdir -p "$PROBE_DIR"

# PCI device ID → GPU model name lookup (portable, no associative arrays).
# Source: https://github.com/pciutils/pciids  (pci.ids)
gpu_model_lookup() {
  case "$1" in
    # Hopper (GH100) — H100 / H200 / H800
    2302) echo "GH100" ;;
    230c) echo "H20 NVL16" ;;
    230e) echo "H20 NVL16" ;;
    2313) echo "H100 CNX" ;;
    2321) echo "H100L 94GB" ;;
    2322) echo "H800 PCIe" ;;
    2324) echo "H800" ;;
    2328) echo "H20B" ;;
    2329) echo "H20" ;;
    232c) echo "H20 HBM3e" ;;
    2330) echo "H100 SXM5 80GB" ;;
    2331) echo "H100 PCIe" ;;
    2335) echo "H200 SXM 141GB" ;;
    2336) echo "H100" ;;
    2337) echo "H100 SXM5 64GB" ;;
    2338) echo "H100 SXM5 96GB" ;;
    2339) echo "H100 SXM5 94GB" ;;
    233a) echo "H800L 94GB" ;;
    233b) echo "H200 NVL" ;;
    233d) echo "H100 96GB" ;;
    2342) echo "GH200 120GB/480GB" ;;
    2348) echo "GH200 144GB HBM3e" ;;
    237e) echo "H100 GH3" ;;
    # Blackwell (GB100/GB102/GB110)
    2901) echo "B200" ;;
    2920) echo "B100" ;;
    2941) echo "HGX GB200" ;;
    29bc) echo "B100" ;;
    3182) echo "B300 SXM6" ;;
    31a1) echo "GB300 MaxQ" ;;
    31c2) echo "GB300" ;;
    # Ada Lovelace (AD102/AD104) — data center
    26b5) echo "L40" ;;
    26b8) echo "L40G" ;;
    26b9) echo "L40S" ;;
    26f5) echo "L40 CNX" ;;
    27b8) echo "L4" ;;
    # Ampere (GA100)
    20b0) echo "A100 SXM4 40GB" ;;
    20b1) echo "A100 PCIe 40GB" ;;
    20b2) echo "A100 SXM4 80GB" ;;
    20b3) echo "A100 SXM 64GB" ;;
    20b5) echo "A100 PCIe 80GB" ;;
    20b7) echo "A30 PCIe" ;;
    20b8) echo "A100X" ;;
    20b9) echo "A30X" ;;
    20bd) echo "A800 SXM4 40GB" ;;
    20f0) echo "A100 PG506-207" ;;
    20f1) echo "A100 PCIe 40GB" ;;
    20f3) echo "A800 SXM4 80GB" ;;
    20f5) echo "A800 80GB PCIe" ;;
    # Volta / Turing
    1db1) echo "V100 SXM2 32GB" ;;
    1db4) echo "V100 PCIe 16GB" ;;
    1db5) echo "V100 PCIe 32GB" ;;
    1db6) echo "V100 SXM2 16GB" ;;
    1df6) echo "V100 FHHL" ;;
    1eb8) echo "T4" ;;
    *) echo "unknown ($1)" ;;
  esac
}

echo "=========================================="
echo "GPU & NIC Discovery"
echo "=========================================="
echo ""

WORKER_NODES=$(oc get nodes -l node-role.kubernetes.io/worker -o jsonpath='{.items[*].metadata.name}')

if [ -z "$WORKER_NODES" ]; then
  echo "ERROR: No worker nodes found"
  exit 1
fi

NODE_COUNT=$(echo $WORKER_NODES | wc -w | tr -d ' ')
echo "Found $NODE_COUNT worker nodes"
echo ""

HAS_IB=false
HAS_ROCE=false
HAS_VF=false
HAS_GPU=false
IS_VM=false
ALL_GPU_MODELS=""

for NODE in $WORKER_NODES; do
  echo "--- Node: $NODE ---"

  oc debug node/$NODE --image=registry.access.redhat.com/ubi9/ubi:latest -- bash -c '
    chroot /host bash -c "
      # --- VM detection (run first so NIC probe can use it) ---
      is_vm=false
      if ls /sys/bus/virtio/devices/* 1>/dev/null 2>&1; then
        is_vm=true
      fi
      echo \"---VM_START---\"
      echo \"VM|\$is_vm\"
      echo \"---VM_END---\"

      # --- NICs ---
      # Detect RDMA NICs via /sys/class/infiniband/ (always present
      # regardless of whether a netdev interface exists on the host).
      echo \"---NIC_START---\"
      if ls /sys/class/infiniband/*/ports 1>/dev/null 2>&1; then
        for rd in /sys/class/infiniband/*; do
          rdma_dev=\$(basename \$rd)
          pci_path=\$(readlink -f \$rd/device 2>/dev/null || echo unknown)
          pci=\$(basename \$pci_path)
          link_layer=\$(cat \$rd/ports/1/link_layer 2>/dev/null || echo unknown)
          numa=\$(cat \$rd/device/numa_node 2>/dev/null || echo -1)
          device_id=\$(cat \$rd/device/device 2>/dev/null || echo unknown)
          device_id=\${device_id#0x}
          sriov_capable=false
          sriov_totalvfs=0
          if [ -f \"\$rd/device/sriov_totalvfs\" ]; then
            sriov_capable=true
            sriov_totalvfs=\$(cat \$rd/device/sriov_totalvfs 2>/dev/null || echo 0)
          fi
          is_vf=false
          if [ -L \"\$rd/device/physfn\" ]; then
            is_vf=true
          elif [ \"\$is_vm\" = true ] && [ ! -f \"\$rd/device/sriov_totalvfs\" ]; then
            # On a VM, absence of sriov_totalvfs means this is a
            # passthrough VF (on bare metal it may just mean SR-IOV
            # is disabled, so we only apply this heuristic in VMs)
            is_vf=true
          fi
          state=\$(cat \$rd/ports/1/state 2>/dev/null || echo unknown)
          carrier=0
          echo \"\$state\" | grep -q ACTIVE && carrier=1
          netdev=\$(ls \$rd/device/net 2>/dev/null | head -1)
          if [ -z \"\$netdev\" ]; then
            netdev=\"--\"
          fi
          echo \"NIC|\$rdma_dev|\$pci|\$link_layer|\$sriov_capable|\$sriov_totalvfs|\$carrier|\$numa|\$rdma_dev|\$device_id|\$is_vf|\$netdev\"
        done
      fi
      echo \"---NIC_END---\"

      # --- GPUs ---
      echo \"---GPU_START---\"
      for dev in /sys/bus/pci/devices/*; do
        vendor=\$(cat \$dev/vendor 2>/dev/null || echo none)
        if [ \"\$vendor\" = \"0x10de\" ]; then
          class=\$(cat \$dev/class 2>/dev/null || echo 0x000000)
          # 0x030000 = VGA, 0x030200 = 3D controller (compute GPUs)
          case \$class in
            0x030000|0x030200|0x030200*)
              pci=\$(basename \$dev)
              device_id=\$(cat \$dev/device 2>/dev/null || echo unknown)
              # Strip 0x prefix
              device_id=\${device_id#0x}
              numa=\$(cat \$dev/numa_node 2>/dev/null || echo -1)
              echo \"GPU|\$pci|\$device_id|\$numa\"
              ;;
          esac
        fi
      done
      echo \"---GPU_END---\"
    "
  ' 2>&1 | grep -v "^Starting pod" | grep -v "^Removing debug pod" | grep -v "^To use host binaries" | grep -v "^E[0-9]" > "$PROBE_DIR/${NODE}-raw.txt" || true

  # --- Parse and display NIC results ---
  nic_lines=$(sed -n '/^---NIC_START---$/,/^---NIC_END---$/p' "$PROBE_DIR/${NODE}-raw.txt" | grep "^NIC|" || true)
  if [ -n "$nic_lines" ]; then
    echo ""
    echo "  NICs:"
    echo "  $(printf '%-10s %-14s %-12s %-6s %-5s %-7s %-12s %s' 'RDMA_DEV' 'PCI' 'LINK_LAYER' 'NUMA' 'IS_VF' 'CARRIER' 'NETDEV' 'STATE')"
    while IFS='|' read -r _ ifname pci link_layer sriov_capable sriov_totalvfs carrier numa rdma_dev device_id is_vf netdev; do
      if [ "$carrier" = "1" ]; then state="up"; else state="down"; fi
      echo "  $(printf '%-10s %-14s %-12s %-6s %-5s %-7s %-12s %s' "$rdma_dev" "$pci" "$link_layer" "$numa" "$is_vf" "$carrier" "$netdev" "$state")"
      if [ "$link_layer" = "InfiniBand" ]; then HAS_IB=true; fi
      if [ "$link_layer" = "Ethernet" ]; then HAS_ROCE=true; fi
      if [ "$is_vf" = "true" ]; then HAS_VF=true; fi
    done <<< "$nic_lines"
  else
    echo "  NICs: none detected"
  fi

  # --- Parse and display GPU results ---
  gpu_lines=$(sed -n '/^---GPU_START---$/,/^---GPU_END---$/p' "$PROBE_DIR/${NODE}-raw.txt" | grep "^GPU|" || true)
  if [ -n "$gpu_lines" ]; then
    HAS_GPU=true
    echo ""
    echo "  GPUs:"
    echo "  $(printf '%-14s %-8s %-6s %s' 'PCI' 'DEV_ID' 'NUMA' 'MODEL')"
    while IFS='|' read -r _ pci device_id numa; do
      model=$(gpu_model_lookup "$device_id")
      ALL_GPU_MODELS="${ALL_GPU_MODELS}${ALL_GPU_MODELS:+$'\n'}${model}"
      echo "  $(printf '%-14s %-8s %-6s %s' "$pci" "$device_id" "$numa" "$model")"
    done <<< "$gpu_lines"
  else
    echo "  GPUs: none detected"
  fi

  # --- Parse VM detection ---
  vm_line=$(sed -n '/^---VM_START---$/,/^---VM_END---$/p' "$PROBE_DIR/${NODE}-raw.txt" | grep "^VM|" || true)
  if echo "$vm_line" | grep -q "VM|true"; then
    IS_VM=true
  fi

  # --- Save structured JSON for this node ---
  {
    echo "{"
    echo "  \"node\": \"$NODE\","

    echo "  \"nics\": ["
    first=true
    if [ -n "$nic_lines" ]; then
      while IFS='|' read -r _ ifname pci link_layer sriov_capable sriov_totalvfs carrier numa rdma_dev device_id is_vf netdev; do
        [ "$first" = true ] && first=false || echo ","
        printf '    {"rdma_dev":"%s","pci":"%s","link_layer":"%s","numa":%s,"sriov_capable":%s,"is_vf":%s,"carrier":"%s","netdev":"%s"}' \
          "$rdma_dev" "$pci" "$link_layer" "$numa" "$sriov_capable" "$is_vf" "$carrier" "$netdev"
      done <<< "$nic_lines"
    fi
    echo ""
    echo "  ],"

    echo "  \"gpus\": ["
    first=true
    if [ -n "$gpu_lines" ]; then
      while IFS='|' read -r _ pci device_id numa; do
        model=$(gpu_model_lookup "$device_id")
        [ "$first" = true ] && first=false || echo ","
        printf '    {"pci":"%s","device_id":"%s","numa":%s,"model":"%s"}' \
          "$pci" "$device_id" "$numa" "$model"
      done <<< "$gpu_lines"
    fi
    echo ""
    echo "  ]"

    echo "}"
  } > "$PROBE_DIR/${NODE}.json"

  echo ""
done

# --- NUMA Topology ---
echo "=========================================="
echo "NUMA Topology (GPU ↔ NIC affinity)"
echo "=========================================="
echo ""
for NODE in $WORKER_NODES; do
  nic_lines=$(sed -n '/^---NIC_START---$/,/^---NIC_END---$/p' "$PROBE_DIR/${NODE}-raw.txt" | grep "^NIC|" || true)
  gpu_lines=$(sed -n '/^---GPU_START---$/,/^---GPU_END---$/p' "$PROBE_DIR/${NODE}-raw.txt" | grep "^GPU|" || true)

  if [ -z "$gpu_lines" ] && [ -z "$nic_lines" ]; then continue; fi

  echo "  Node: $NODE"

  # Collect NUMA data into temp files (portable — no associative arrays)
  numa_tmp="$PROBE_DIR/${NODE}-numa"
  rm -f "${numa_tmp}"-gpu-* "${numa_tmp}"-nic-*

  if [ -n "$gpu_lines" ]; then
    while IFS='|' read -r _ pci device_id numa; do
      model=$(gpu_model_lookup "$device_id")
      echo "$pci($model)" >> "${numa_tmp}-gpu-${numa}"
    done <<< "$gpu_lines"
  fi

  if [ -n "$nic_lines" ]; then
    while IFS='|' read -r _ ifname pci link_layer sriov_capable sriov_totalvfs carrier numa rdma_dev device_id is_vf netdev; do
      echo "$rdma_dev($netdev)" >> "${numa_tmp}-nic-${numa}"
    done <<< "$nic_lines"
  fi

  # Gather unique NUMA IDs from the temp file names
  all_numas=$( (ls "${numa_tmp}"-gpu-* "${numa_tmp}"-nic-* 2>/dev/null || true) \
    | sed 's/.*-gpu-//; s/.*-nic-//' | sort -un )

  for n in $all_numas; do
    echo "    NUMA $n:"
    if [ -f "${numa_tmp}-gpu-${n}" ]; then
      echo "      GPUs: $(tr '\n' ' ' < "${numa_tmp}-gpu-${n}")"
    fi
    if [ -f "${numa_tmp}-nic-${n}" ]; then
      echo "      NICs: $(tr '\n' ' ' < "${numa_tmp}-nic-${n}")"
    fi
  done

  rm -f "${numa_tmp}"-gpu-* "${numa_tmp}"-nic-*
  echo ""
done

# --- Summary ---
echo "=========================================="
echo "Summary"
echo "=========================================="
echo ""
echo "  InfiniBand detected: $HAS_IB"
echo "  RoCE detected:       $HAS_ROCE"
echo "  NICs are VFs:        $HAS_VF"
echo "  NVIDIA GPUs:         $HAS_GPU"
echo "  Virtual machine:     $IS_VM"

# Deduplicate GPU models
if [ -n "$ALL_GPU_MODELS" ]; then
  unique_models=$(echo "$ALL_GPU_MODELS" | sort -u | tr '\n' ',' | sed 's/,$//' | sed 's/,/, /g')
  echo "  GPU models:          $unique_models"
fi
echo ""

echo "=========================================="
echo "Recommended Platform Overlay"
echo "=========================================="
echo ""

if [ "$IS_VM" = true ] && [ "$HAS_GPU" = true ]; then
  echo "  -> ibm-cloud"
  echo ""
  echo "  Your cluster is running on virtual machines with GPU passthrough."
  echo "  SR-IOV operator is not applicable; use host-device CNI for RDMA NICs."
  echo "  Use: ./05-ocp-accelerator-operators/install.sh --platform ibm-cloud"
elif [ "$HAS_IB" = true ] && [ "$HAS_ROCE" = false ]; then
  echo "  -> bare-metal-ib"
  echo ""
  echo "  Your cluster has InfiniBand NICs on physical functions."
  echo "  Use: ./05-ocp-accelerator-operators/install.sh --platform bare-metal-ib"
elif [ "$HAS_IB" = true ] && [ "$HAS_ROCE" = true ]; then
  echo "  -> bare-metal-ib  (likely — mixed link layers detected)"
  echo ""
  echo "  Your cluster has both InfiniBand and Ethernet-mode RDMA ports."
  echo "  This is common with dual-port ConnectX cards where one port is IB"
  echo "  and the other is Ethernet (management/storage). If RDMA traffic uses"
  echo "  InfiniBand, use bare-metal-ib. If your RDMA fabric is RoCE, use"
  echo "  bare-metal-roce."
elif [ "$HAS_ROCE" = true ]; then
  echo "  -> bare-metal-roce"
  echo ""
  echo "  Your cluster has RoCE NICs on physical functions."
  echo "  Use: ./05-ocp-accelerator-operators/install.sh --platform bare-metal-roce"
elif [ "$HAS_GPU" = true ]; then
  echo "  -> ibm-cloud (or similar cloud environment)"
  echo ""
  echo "  Your cluster has GPUs but no RDMA NICs detected."
  echo "  Use: ./05-ocp-accelerator-operators/install.sh --platform ibm-cloud"
else
  echo "  -> No GPU or RDMA hardware detected."
fi

echo ""
echo "Probe results saved to: $PROBE_DIR/"
