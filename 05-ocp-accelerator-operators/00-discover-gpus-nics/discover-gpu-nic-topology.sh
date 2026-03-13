#!/bin/bash
# Discover GPUs and RDMA NICs on cluster worker nodes.
#
# Probes sysfs directly via oc debug -- no operators need to be installed.
# Reports GPU models, NIC link types, SR-IOV capability, and NUMA topology
# to help select the right platform overlay.
#
# Usage:
#   ./discover-nic-ports.sh
#
# Requires: oc CLI with cluster-admin access
#
# Output: per-node details in /tmp/gpu-nic-probe/ and a summary
# recommending which platform overlay to use.

set -euo pipefail

PROBE_DIR="/tmp/gpu-nic-probe"
mkdir -p "$PROBE_DIR"

# Known NVIDIA GPU PCI device IDs → model names
# Source: https://github.com/pciutils/pciids  (pci.ids)
# Add entries as needed for your hardware
declare -A GPU_MODELS=(
  # Hopper (GH100) — H100 / H200 / H800
  ["2302"]="GH100"
  ["230c"]="H20 NVL16"
  ["230e"]="H20 NVL16"
  ["2313"]="H100 CNX"
  ["2321"]="H100L 94GB"
  ["2322"]="H800 PCIe"
  ["2324"]="H800"
  ["2328"]="H20B"
  ["2329"]="H20"
  ["232c"]="H20 HBM3e"
  ["2330"]="H100 SXM5 80GB"
  ["2331"]="H100 PCIe"
  ["2335"]="H200 SXM 141GB"
  ["2336"]="H100"
  ["2337"]="H100 SXM5 64GB"
  ["2338"]="H100 SXM5 96GB"
  ["2339"]="H100 SXM5 94GB"
  ["233a"]="H800L 94GB"
  ["233b"]="H200 NVL"
  ["233d"]="H100 96GB"
  ["2342"]="GH200 120GB/480GB"
  ["2348"]="GH200 144GB HBM3e"
  ["237e"]="H100 GH3"
  # Blackwell (GB100/GB102/GB110)
  ["2901"]="B200"
  ["2920"]="B100"
  ["2941"]="HGX GB200"
  ["29bc"]="B100"
  ["3182"]="B300 SXM6"
  ["31a1"]="GB300 MaxQ"
  ["31c2"]="GB300"
  # Ada Lovelace (AD102/AD104) — data center
  ["26b5"]="L40"
  ["26b8"]="L40G"
  ["26b9"]="L40S"
  ["26f5"]="L40 CNX"
  ["27b8"]="L4"
  # Ampere (GA100)
  ["20b0"]="A100 SXM4 40GB"
  ["20b1"]="A100 PCIe 40GB"
  ["20b2"]="A100 SXM4 80GB"
  ["20b3"]="A100 SXM 64GB"
  ["20b5"]="A100 PCIe 80GB"
  ["20b7"]="A30 PCIe"
  ["20b8"]="A100X"
  ["20b9"]="A30X"
  ["20bd"]="A800 SXM4 40GB"
  ["20f0"]="A100 PG506-207"
  ["20f1"]="A100 PCIe 40GB"
  ["20f3"]="A800 SXM4 80GB"
  ["20f5"]="A800 80GB PCIe"
  # Volta / Turing
  ["1db1"]="V100 SXM2 32GB"
  ["1db4"]="V100 PCIe 16GB"
  ["1db5"]="V100 PCIe 32GB"
  ["1db6"]="V100 SXM2 16GB"
  ["1df6"]="V100 FHHL"
  ["1eb8"]="T4"
)

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
HAS_SRIOV=false
HAS_VF=false
HAS_GPU=false
ALL_GPU_MODELS=()  # array to preserve multi-word model names

for NODE in $WORKER_NODES; do
  echo "--- Node: $NODE ---"

  oc debug node/$NODE --image=registry.access.redhat.com/ubi9/ubi:latest -- bash -c '
    chroot /host bash -c "
      # --- NICs ---
      echo \"---NIC_START---\"
      for iface in /sys/class/net/*; do
        ifname=\$(basename \$iface)

        has_ip=\$(ip addr show \$ifname 2>/dev/null | grep -c \"inet \" || echo 0)
        [ \"\$has_ip\" -gt 0 ] && continue
        [[ \$ifname =~ ^(br-|veth|ovn|genev|vlan|bond|team|lo) ]] && continue

        if [ -d \"/sys/class/net/\$ifname/device/infiniband\" ]; then
          pci_path=\$(readlink -f /sys/class/net/\$ifname/device 2>/dev/null || echo unknown)
          pci=\$(basename \$pci_path)
          numa=\$(cat /sys/class/net/\$ifname/device/numa_node 2>/dev/null || echo -1)
          rdma_dev=\$(ls /sys/class/net/\$ifname/device/infiniband 2>/dev/null | head -1)
          link_layer=unknown
          if [ -n \"\$rdma_dev\" ] && [ -f \"/sys/class/infiniband/\$rdma_dev/ports/1/link_layer\" ]; then
            link_layer=\$(cat /sys/class/infiniband/\$rdma_dev/ports/1/link_layer 2>/dev/null || echo unknown)
          fi
          sriov_capable=false
          sriov_totalvfs=0
          if [ -f \"/sys/class/net/\$ifname/device/sriov_numvfs\" ]; then
            sriov_capable=true
            sriov_totalvfs=\$(cat /sys/class/net/\$ifname/device/sriov_totalvfs 2>/dev/null || echo 0)
          fi
          is_vf=false
          if [ -L \"/sys/class/net/\$ifname/device/physfn\" ]; then
            is_vf=true
          fi
          carrier=\$(cat /sys/class/net/\$ifname/carrier 2>/dev/null || echo 0)
          device_id=\$(cat /sys/class/net/\$ifname/device/device 2>/dev/null || echo unknown)
          echo \"NIC|\$ifname|\$pci|\$link_layer|\$sriov_capable|\$sriov_totalvfs|\$carrier|\$numa|\$rdma_dev|\$device_id|\$is_vf\"
        fi
      done
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
    echo "  $(printf '%-14s %-14s %-12s %-6s %-8s %-7s %-5s %-10s %s' 'INTERFACE' 'PCI' 'LINK_LAYER' 'NUMA' 'SR-IOV' 'VFs' 'IS_VF' 'CARRIER' 'RDMA_DEV')"
    while IFS='|' read -r _ ifname pci link_layer sriov_capable sriov_totalvfs carrier numa rdma_dev device_id is_vf; do
      echo "  $(printf '%-14s %-14s %-12s %-6s %-8s %-7s %-5s %-10s %s' "$ifname" "$pci" "$link_layer" "$numa" "$sriov_capable" "$sriov_totalvfs" "$is_vf" "$carrier" "$rdma_dev")"
      if [ "$link_layer" = "InfiniBand" ]; then HAS_IB=true; fi
      if [ "$link_layer" = "Ethernet" ]; then HAS_ROCE=true; fi
      if [ "$sriov_capable" = "true" ]; then HAS_SRIOV=true; fi
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
      model="${GPU_MODELS[$device_id]:-unknown ($device_id)}"
      ALL_GPU_MODELS+=("$model")
      echo "  $(printf '%-14s %-8s %-6s %s' "$pci" "$device_id" "$numa" "$model")"
    done <<< "$gpu_lines"
  else
    echo "  GPUs: none detected"
  fi

  # --- Save structured JSON for this node ---
  {
    echo "{"
    echo "  \"node\": \"$NODE\","

    echo "  \"nics\": ["
    first=true
    if [ -n "$nic_lines" ]; then
      while IFS='|' read -r _ ifname pci link_layer sriov_capable sriov_totalvfs carrier numa rdma_dev device_id is_vf; do
        [ "$first" = true ] && first=false || echo ","
        printf '    {"ifname":"%s","pci":"%s","link_layer":"%s","numa":%s,"sriov_capable":%s,"sriov_totalvfs":%s,"is_vf":%s,"carrier":"%s","rdma_dev":"%s"}' \
          "$ifname" "$pci" "$link_layer" "$numa" "$sriov_capable" "$sriov_totalvfs" "$is_vf" "$carrier" "$rdma_dev"
      done <<< "$nic_lines"
    fi
    echo ""
    echo "  ],"

    echo "  \"gpus\": ["
    first=true
    if [ -n "$gpu_lines" ]; then
      while IFS='|' read -r _ pci device_id numa; do
        model="${GPU_MODELS[$device_id]:-unknown}"
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

  # Collect NUMA nodes
  declare -A NUMA_GPUS=()
  declare -A NUMA_NICS=()

  if [ -n "$gpu_lines" ]; then
    while IFS='|' read -r _ pci device_id numa; do
      model="${GPU_MODELS[$device_id]:-$device_id}"
      NUMA_GPUS[$numa]="${NUMA_GPUS[$numa]:-} $pci($model)"
    done <<< "$gpu_lines"
  fi

  if [ -n "$nic_lines" ]; then
    while IFS='|' read -r _ ifname pci link_layer sriov_capable sriov_totalvfs carrier numa rdma_dev device_id is_vf; do
      NUMA_NICS[$numa]="${NUMA_NICS[$numa]:-} $ifname($rdma_dev)"
    done <<< "$nic_lines"
  fi

  # Get sorted unique NUMA nodes
  all_numas=$(echo "${!NUMA_GPUS[@]} ${!NUMA_NICS[@]}" | tr ' ' '\n' | sort -un)
  for n in $all_numas; do
    echo "    NUMA $n:"
    if [ -n "${NUMA_GPUS[$n]:-}" ]; then
      echo "      GPUs:${NUMA_GPUS[$n]}"
    fi
    if [ -n "${NUMA_NICS[$n]:-}" ]; then
      echo "      NICs:${NUMA_NICS[$n]}"
    fi
  done

  unset NUMA_GPUS NUMA_NICS
  echo ""
done

# --- Summary ---
echo "=========================================="
echo "Summary"
echo "=========================================="
echo ""
echo "  InfiniBand detected: $HAS_IB"
echo "  RoCE detected:       $HAS_ROCE"
echo "  SR-IOV capable:      $HAS_SRIOV"
echo "  NICs are VFs:        $HAS_VF"
echo "  NVIDIA GPUs:         $HAS_GPU"

# Deduplicate GPU models
if [ ${#ALL_GPU_MODELS[@]} -gt 0 ]; then
  unique_models=$(printf '%s\n' "${ALL_GPU_MODELS[@]}" | sort -u | paste -sd ', ')
  echo "  GPU models:          $unique_models"
fi
echo ""

echo "=========================================="
echo "Recommended Platform Overlay"
echo "=========================================="
echo ""

if [ "$HAS_VF" = true ] && [ "$HAS_GPU" = true ]; then
  echo "  -> ibm-cloud"
  echo ""
  echo "  Your NICs are SR-IOV Virtual Functions (VMs with passthrough NICs)."
  echo "  SR-IOV operator cannot be used; host-device CNI will attach NICs to pods."
  echo "  Use: ./05-ocp-accelerator-operators/install.sh --platform ibm-cloud"
elif [ "$HAS_IB" = true ] && [ "$HAS_ROCE" = false ]; then
  echo "  -> bare-metal-ib"
  echo ""
  echo "  Your cluster has InfiniBand NICs on physical functions."
  echo "  Use: ./05-ocp-accelerator-operators/install.sh --platform bare-metal-ib"
elif [ "$HAS_ROCE" = true ] && [ "$HAS_IB" = false ]; then
  echo "  -> bare-metal-roce"
  echo ""
  echo "  Your cluster has RoCE NICs on physical functions."
  echo "  Use: ./05-ocp-accelerator-operators/install.sh --platform bare-metal-roce"
elif [ "$HAS_IB" = true ] && [ "$HAS_ROCE" = true ]; then
  echo "  -> bare-metal-ib  (likely — mixed link layers detected)"
  echo ""
  echo "  Your cluster has both InfiniBand and Ethernet-mode RDMA ports."
  echo "  This is common with dual-port ConnectX cards where one port is IB"
  echo "  and the other is Ethernet (management/storage). If RDMA traffic uses"
  echo "  InfiniBand, use bare-metal-ib. If your RDMA fabric is RoCE, use"
  echo "  bare-metal-roce."
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
