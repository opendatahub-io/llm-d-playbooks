#!/bin/bash
# Automated installation of OCP accelerator operators.
#
# Usage:
#   ./install.sh --platform <bare-metal-ib|bare-metal-roce|ibm-cloud>
#
# This script applies the manifests in order, waits for readiness
# between steps, and skips steps that don't apply to the platform.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  echo "Usage: $0 --platform <bare-metal-ib|bare-metal-roce|ibm-cloud>"
  echo ""
  echo "Platforms:"
  echo "  bare-metal-ib    InfiniBand clusters (no SR-IOV)"
  echo "  bare-metal-roce  RoCE clusters (with SR-IOV)"
  echo "  ibm-cloud        IBM Cloud (host-device CNI, no SR-IOV)"
  exit 1
}

PLATFORM=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --platform) PLATFORM="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "Unknown option: $1"; usage ;;
  esac
done

if [ -z "$PLATFORM" ]; then
  echo "ERROR: --platform is required"
  usage
fi

case "$PLATFORM" in
  bare-metal-ib|bare-metal-roce|ibm-cloud) ;;
  *) echo "ERROR: Unknown platform '$PLATFORM'"; usage ;;
esac

echo "=========================================="
echo "OCP Accelerator Operators Installation"
echo "Platform: $PLATFORM"
echo "=========================================="
echo ""

apply_step() {
  local step_name="$1"
  local step_path="$2"
  echo "--- Step: $step_name ---"
  echo "  Applying: $step_path"
  oc apply -k "$step_path"
  echo "  Done."
  echo ""
}

wait_for_csv() {
  local namespace="$1"
  local name_pattern="$2"
  local timeout="${3:-600}"

  echo "  Waiting for CSV matching '$name_pattern' in $namespace..."
  local elapsed=0
  while [ $elapsed -lt $timeout ]; do
    local csv_phase
    csv_phase=$(oc get csv -n "$namespace" -o jsonpath="{.items[?(@.metadata.name=='$name_pattern')].status.phase}" 2>/dev/null || echo "")
    if [ -z "$csv_phase" ]; then
      csv_phase=$(oc get csv -n "$namespace" -o json 2>/dev/null | python3 -c "
import json,sys
data=json.load(sys.stdin)
for item in data.get('items',[]):
    if '$name_pattern' in item['metadata']['name']:
        print(item.get('status',{}).get('phase',''))
        break
" 2>/dev/null || echo "")
    fi
    if [ "$csv_phase" = "Succeeded" ]; then
      echo "  CSV ready."
      return 0
    fi
    sleep 10
    elapsed=$((elapsed + 10))
  done
  echo "  WARNING: CSV not ready after ${timeout}s, continuing..."
}

wait_for_subscription() {
  local namespace="$1"
  local name="$2"
  local timeout="${3:-300}"

  echo "  Waiting for subscription '$name' in $namespace..."
  local elapsed=0
  while [ $elapsed -lt $timeout ]; do
    local state
    state=$(oc get subscription.operators.coreos.com "$name" -n "$namespace" -o jsonpath='{.status.state}' 2>/dev/null || echo "")
    if [ "$state" = "AtLatestKnown" ]; then
      echo "  Subscription ready."
      return 0
    fi
    sleep 10
    elapsed=$((elapsed + 10))
  done
  echo "  WARNING: Subscription not ready after ${timeout}s, continuing..."
}

# Step 00: Discover GPUs & NICs (informational)
if [ "$PLATFORM" != "ibm-cloud" ]; then
  echo "--- Step: 00-discover-gpus-nics ---"
  echo "  Running hardware probe..."
  bash "$SCRIPT_DIR/00-discover-gpus-nics/discover-gpu-nic-topology.sh" || true
  echo ""
fi

# Step 01: Install NFD, GPU, and Network Operator subscriptions
apply_step "01-operators-nfd-gpu" "$SCRIPT_DIR/01-operators-nfd-gpu/base"

echo "Waiting for operator subscriptions to install..."
wait_for_subscription "openshift-nfd" "nfd" 300
wait_for_subscription "nvidia-gpu-operator" "gpu-operator-certified" 300
wait_for_subscription "nvidia-network-operator" "nvidia-network-operator" 300

# Step 02: Deploy NFD operands
apply_step "02-nfd-operands" "$SCRIPT_DIR/02-nfd-operands/base"

# Step 10: SR-IOV operator (RoCE only)
if [ "$PLATFORM" = "bare-metal-roce" ]; then
  apply_step "10-sriov-operator" "$SCRIPT_DIR/10-sriov-operator/base"
  wait_for_subscription "openshift-sriov-network-operator" "sriov-network-operator-subscription" 300
fi

# Step 11: IB interface normalization (bare metal only)
if [ "$PLATFORM" = "bare-metal-ib" ] || [ "$PLATFORM" = "bare-metal-roce" ]; then
  apply_step "11-ib-interface-normalization" "$SCRIPT_DIR/11-ib-interface-normalization/base"
  echo "  Waiting for MachineConfigPool to update (nodes may reboot)..."
  oc wait mcp worker --for=condition=Updated --timeout=1800s 2>/dev/null || echo "  MCP wait timed out or not applicable"
  echo ""
fi

# Step 12: SR-IOV VF config (RoCE only)
if [ "$PLATFORM" = "bare-metal-roce" ]; then
  apply_step "12-sriov-vf-config" "$SCRIPT_DIR/12-sriov-vf-config/base"
fi

# Step 13: NIC discovery (bare metal only)
if [ "$PLATFORM" = "bare-metal-ib" ] || [ "$PLATFORM" = "bare-metal-roce" ]; then
  apply_step "13-nic-discovery" "$SCRIPT_DIR/13-nic-discovery/base"
  echo "  Waiting for discovery DaemonSet to complete..."
  sleep 60
fi

# Step 14: NVIDIA network operator config
if [ "$PLATFORM" = "ibm-cloud" ]; then
  apply_step "14-nvidia-network-operator (ibm-cloud)" "$SCRIPT_DIR/14-nvidia-network-operator/overlays/ibm-cloud"
else
  apply_step "14-nvidia-network-operator" "$SCRIPT_DIR/14-nvidia-network-operator/base"
fi

# Step 15: IBM Cloud networking (host-device NADs, MachineConfig, sbr-custom)
if [ "$PLATFORM" = "ibm-cloud" ]; then
  apply_step "15-ibm-cloud-networking" "$SCRIPT_DIR/15-ibm-cloud-networking/base"
  echo "  Waiting for MachineConfigPool to update (nodes may reboot)..."
  oc wait mcp gpu-h100 --for=condition=Updated --timeout=1800s 2>/dev/null || echo "  MCP wait timed out or not applicable"
  echo ""
fi

# Step 20: Wait for operator readiness
apply_step "20-operators-gpu-readiness" "$SCRIPT_DIR/20-operators-gpu-readiness/base"
echo "  Waiting for readiness jobs to complete..."
oc wait --for=condition=complete job/wait-for-network-operator-ready -n default --timeout=1800s 2>/dev/null || true
oc wait --for=condition=complete job/wait-for-mofed-ready -n nvidia-network-operator --timeout=1800s 2>/dev/null || true

# Step 21: Deploy GPU operands
apply_step "21-gpu-operands" "$SCRIPT_DIR/21-gpu-operands/base"

echo "=========================================="
echo "Installation Complete"
echo "=========================================="
echo ""
echo "Verify GPU operator status:"
echo "  oc get clusterpolicy"
echo "  oc get pods -n nvidia-gpu-operator"
echo ""
echo "Verify network operator status:"
echo "  oc get nicclusterpolicy"
echo "  oc get pods -n nvidia-network-operator"
if [ "$PLATFORM" = "ibm-cloud" ]; then
  echo ""
  echo "Verify IBM Cloud networking:"
  echo "  oc get mcp gpu-h100"
  echo "  oc get ds cni-sbr-custom-plugin -n openshift-multus"
  echo "  oc get net-attach-def"
fi
