# Chapter 05: OCP Accelerator Operators

Install and configure GPU, RDMA, and networking operators on OpenShift Container Platform.

This chapter covers NFD (Node Feature Discovery), NVIDIA GPU Operator, NVIDIA Network Operator, and SR-IOV / host-device networking depending on platform. These operators are required on OCP but not on managed Kubernetes platforms (AKS, CKS).

## Prerequisites

- OpenShift Container Platform >= 4.19
- Cluster-admin access via `oc` CLI
- Worker nodes with NVIDIA GPUs
- For RDMA: Mellanox/NVIDIA ConnectX NICs (InfiniBand or RoCE)

## Platform Selection

| Platform | Description | Steps |
|----------|-------------|-------|
| `bare-metal-ib` | Bare-metal with InfiniBand | 00, 01, 02, 11, 13, 14, 20, 21 |
| `bare-metal-roce` | Bare-metal with RoCE (SR-IOV) | 00, 01, 02, 10, 11, 12, 13, 14, 20, 21 |
| `ibm-cloud` | IBM Cloud VMs (host-device + NADs) | 01, 02, 14, 15, 20, 21 |

If you already know your platform (e.g. IBM Cloud), skip ahead to [Step 01](#step-01-operator-subscriptions). Otherwise, start with [Step 00](#step-00-discover-gpus--nics) to detect your hardware.

## Quick Start (automated)

### Shell Script

```bash
./05-ocp-accelerator-operators/install.sh --platform <bare-metal-ib|bare-metal-roce|ibm-cloud>
```

### ArgoCD (GitOps)

See [argocd/README.md](argocd/README.md) for setup. In short:

```bash
# 1. Install the OpenShift GitOps operator
# 2. Edit argocd/bootstrap/root-app.yaml to point to your platform overlay
# 3. Apply the bootstrap:
oc apply -k argocd/bootstrap/
```

---

## Manual Steps

Follow each step below in order, skipping any marked **skip** for your platform.

### Step 00: Discover GPUs & NICs

| bare-metal-ib | bare-metal-roce | ibm-cloud |
|:-:|:-:|:-:|
| apply | apply | **skip** (you already know your platform) |

Standalone script that probes cluster nodes for RDMA NICs and GPUs via sysfs -- no operators need to be installed yet. For each node it reports:
- **GPUs**: model (H100, A100, L40S, ...), PCI address, NUMA node
- **NICs**: interface name, link type (InfiniBand / Ethernet/RoCE), SR-IOV capability, NUMA node
- **NUMA topology**: which GPUs and NICs share the same NUMA node (important for optimal RDMA performance)

```bash
./05-ocp-accelerator-operators/00-discover-gpus-nics/discover-gpu-nic-topology.sh
```

Example output:

```
--- Node: worker-0 ---

  NICs:
  INTERFACE      PCI            LINK_LAYER   NUMA   SR-IOV   VFs     CARRIER    RDMA_DEV
  ib_nic0        0000:86:00.0   InfiniBand   1      false    0       1          mlx5_0

  GPUs:
  PCI            DEV_ID   NUMA   MODEL
  0000:85:00.0   2330     1      H100 80GB HBM3 (SXM)

NUMA Topology (GPU <-> NIC affinity)
  Node: worker-0
    NUMA 1:
      GPUs: 0000:85:00.0(H100 80GB HBM3 (SXM))
      NICs: ib_nic0(mlx5_0)

Summary
  InfiniBand detected: true
  RoCE detected:       false
  SR-IOV capable:      false
  NVIDIA GPUs:         true
  GPU models:          H100 80GB HBM3 (SXM)

Recommended Platform Overlay
  -> bare-metal-ib
```

### Step 01: Operator Subscriptions

| bare-metal-ib | bare-metal-roce | ibm-cloud |
|:-:|:-:|:-:|
| apply | apply | apply |

Install three core operators via OLM: Node Feature Discovery (NFD), NVIDIA GPU Operator, and NVIDIA Network Operator. Each gets its own namespace, OperatorGroup, and Subscription.

| Operator | Namespace | Source |
|----------|-----------|--------|
| NFD | `openshift-nfd` | `redhat-operators` |
| GPU Operator | `nvidia-gpu-operator` | `certified-operators` |
| Network Operator | `nvidia-network-operator` | `certified-operators` |

```bash
oc apply -k 05-ocp-accelerator-operators/01-operators-nfd-gpu/base/

# Wait for the subscriptions to resolve
oc get subscriptions -A | grep -E 'nfd|gpu|nvidia-network'
oc get csv -n openshift-nfd
oc get csv -n nvidia-gpu-operator
oc get csv -n nvidia-network-operator
```

### Step 02: NFD Operands

| bare-metal-ib | bare-metal-roce | ibm-cloud |
|:-:|:-:|:-:|
| apply | apply | apply |

Deploy `NodeFeatureDiscovery` and `NodeFeatureRule` custom resources. These label nodes with hardware features (NVIDIA GPUs via PCI vendor `10de`, Mellanox NICs via `15b3`, SR-IOV capability, RDMA modules).

```bash
oc apply -k 05-ocp-accelerator-operators/02-nfd-operands/base/

# Verify labels appear on GPU nodes (may take ~60s)
oc get nodes -l feature.node.kubernetes.io/pci-10de.present=true
oc get nodes -l feature.node.kubernetes.io/pci-15b3.present=true
```

### Step 10: SR-IOV Operator

| bare-metal-ib | bare-metal-roce | ibm-cloud |
|:-:|:-:|:-:|
| **skip** | apply | **skip** |

Install the SR-IOV Network Operator for RoCE VF management. InfiniBand devices don't use SR-IOV; they are handled by the NVIDIA Network Operator's RDMA shared device plugin.

```bash
oc apply -k 05-ocp-accelerator-operators/10-sriov-operator/base/

oc get csv -n openshift-sriov-network-operator
oc get pods -n openshift-sriov-network-operator
```

### Step 11: IB Interface Normalization

| bare-metal-ib | bare-metal-roce | ibm-cloud |
|:-:|:-:|:-:|
| apply | apply | **skip** |

Generate udev rules for consistent RDMA interface naming (`ib_nic0`, `ib_nic1`, ...) via a MachineConfig. **This triggers worker node reboots.**

```bash
oc apply -k 05-ocp-accelerator-operators/11-ib-interface-normalization/base/

# Watch the job
oc logs job/generate-ib-udev-rules -n default -f

# Wait for MachineConfigPool to finish (nodes will reboot)
oc get mcp worker -w
```

### Step 12: SR-IOV VF Config

| bare-metal-ib | bare-metal-roce | ibm-cloud |
|:-:|:-:|:-:|
| **skip** | apply | **skip** |

Generate `SriovNetworkNodePolicy` and `SriovNetwork` resources from discovered hardware. RoCE devices get SR-IOV VF policies; InfiniBand device data is exported as a ConfigMap for step 14.

```bash
oc apply -k 05-ocp-accelerator-operators/12-sriov-vf-config/base/

oc get sriovnetworknodepolicy -n openshift-sriov-network-operator
oc get sriovnetwork -n openshift-sriov-network-operator
```

### Step 13: NIC Discovery

| bare-metal-ib | bare-metal-roce | ibm-cloud |
|:-:|:-:|:-:|
| apply | apply | **skip** |

DaemonSet that discovers RDMA-capable NICs on every node -- PCI addresses, device IDs, link type (IB vs RoCE), carrier status. Results are written to `/var/lib/nic-discovery/` on each node.

```bash
oc apply -k 05-ocp-accelerator-operators/13-nic-discovery/base/

oc get pods -l app=nic-port-discovery -o wide

# View discovery results from a node
oc exec -n default $(oc get pods -l app=nic-port-discovery -o name | head -1) \
  -c pause -- cat /discovery/ports.json
```

### Step 14: NVIDIA Network Operator Config

| bare-metal-ib | bare-metal-roce | ibm-cloud |
|:-:|:-:|:-:|
| apply (base) | apply (base) | apply (ibm-cloud overlay) |

Deploy `NicClusterPolicy` to configure MOFED drivers. The bare-metal base also auto-discovers the OFED driver version and generates RDMA shared device plugin config. IBM Cloud uses a simpler overlay with just MOFED drivers (no SR-IOV device plugin, since VMs already have VFs from the hypervisor).

```bash
# Bare metal
oc apply -k 05-ocp-accelerator-operators/14-nvidia-network-operator/base/

# IBM Cloud
oc apply -k 05-ocp-accelerator-operators/14-nvidia-network-operator/overlays/ibm-cloud/

# Verify
oc get nicclusterpolicy
oc get pods -n nvidia-network-operator -l nvidia.com/ofed-driver -w
```

### Step 15: IBM Cloud Networking

| bare-metal-ib | bare-metal-roce | ibm-cloud |
|:-:|:-:|:-:|
| **skip** | **skip** | apply |

Configure secondary high-speed networking using the host-device CNI plugin. On IBM Cloud, nodes are VMs where SR-IOV is at the hypervisor level, so we attach full NIC interfaces directly to pods via NetworkAttachmentDefinitions (NADs).

This step applies:
- **MachineConfig** enabling `iommu=pt` on H100 nodes (`gx3d-160x1792x8h100`)
- **sbr-custom DaemonSet** for source-based routing (required for WideEP / NVSHMEM cross-subnet traffic)
- **8 NADs** (one per NIC) using host-device with DHCP IPAM

**Before applying**, review `15-ibm-cloud-networking/base/network-attachment-definitions.yaml` and adjust device names, gateway IPs, and target namespace to match your cluster network configuration. The defaults are for `gx3d-160x1792x8h100` instances with devices `enp163s0`...`enp233s0` and gateways `10.0.0.1`...`10.7.0.1`.

```bash
oc apply -k 05-ocp-accelerator-operators/15-ibm-cloud-networking/base/

# Wait for MachineConfigPool (nodes may reboot)
oc get mcp gpu-h100 -w

# Verify
oc get ds cni-sbr-custom-plugin -n openshift-multus
oc get net-attach-def
```

### Step 20: Operator Readiness

| bare-metal-ib | bare-metal-roce | ibm-cloud |
|:-:|:-:|:-:|
| apply | apply | apply |

Readiness gate jobs that wait for the NVIDIA Network Operator and MOFED drivers to be fully ready before deploying the GPU ClusterPolicy. The GPU Operator with `rdma.enabled=true` requires MOFED to be loaded first.

```bash
oc apply -k 05-ocp-accelerator-operators/20-operators-gpu-readiness/base/

# Watch readiness jobs
oc logs job/wait-for-network-operator-ready -n default -f
oc logs job/wait-for-mofed-ready -n nvidia-network-operator -f
```

### Step 21: GPU Operands

| bare-metal-ib | bare-metal-roce | ibm-cloud |
|:-:|:-:|:-:|
| apply | apply | apply |

Deploy the GPU Operator `ClusterPolicy`, which triggers deployment of GPU drivers, device plugin, DCGM monitoring, GDRCopy, nvidia-peermem, and container toolkit.

```bash
oc apply -k 05-ocp-accelerator-operators/21-gpu-operands/base/

# Check ClusterPolicy status
oc get clusterpolicy gpu-cluster-policy -o jsonpath='{.status.state}'

# Wait for GPU operator pods
oc get pods -n nvidia-gpu-operator -w

# Verify GPU resources on nodes
oc get nodes -o custom-columns=NAME:.metadata.name,GPU:.status.allocatable.nvidia\\.com/gpu
```

---

## Verification

After all steps complete:

```bash
# GPU operator
oc get clusterpolicy
oc get pods -n nvidia-gpu-operator

# Network operator
oc get nicclusterpolicy
oc get pods -n nvidia-network-operator

# GPU resources on nodes
oc get nodes -o custom-columns=NAME:.metadata.name,GPU:.status.allocatable.nvidia\\.com/gpu

# IBM Cloud only: networking resources
oc get mcp gpu-h100
oc get ds cni-sbr-custom-plugin -n openshift-multus
oc get net-attach-def
```

Proceed to [06-validate-gpu-readiness](../06-validate-gpu-readiness/).
