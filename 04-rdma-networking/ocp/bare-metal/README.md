# OCP on Bare Metal: RDMA Networking (SR-IOV)

This section covers OpenShift networking for RoCE on bare metal using the NVIDIA Network Operator (Mellanox driver only) and the SR-IOV Operator. The SR-IOV Operator handles RoCE network connectivity; the NVIDIA network operator deploys only the Mellanox driver.

Manifests and scripts are in [apply/](apply/).

**Alternative: automated deployment.** The [Infrabric-deployer](https://github.com/bbenshab/Infrabric-deployer/tree/main) project provides ArgoCD-based automation for this kind of configuration. It is experimental and still evolving; if you consider using it, review its scope and assumptions against your environment and this playbook’s manual steps.

---

## NVIDIA Network Operator

Apply the NicClusterPolicy to deploy the Mellanox (OFED) driver:

- **[apply/nic-cluster-policy.yaml](apply/nic-cluster-policy.yaml)** — Mellanox driver image and upgrade policy

---

## SR-IOV Operator

### Step 1: Deploy SR-IOV Operator

1. Create the operator namespace:

   ```shell
   oc create namespace openshift-sriov-network-operator
   ```

2. Create the OperatorGroup and Subscription from [apply/](apply/):

   ```shell
   oc create -f apply/sriov-operator-group.yaml
   oc create -f apply/sriov-subscription.yaml
   ```

Wait for the operator to be ready.

### Step 2: Hardware discovery and identification

Before configuring policies, identify which network interfaces are on your nodes and their hardware attributes (Vendor ID, Device ID, interface names). The SR-IOV Operator creates a **SriovNetworkNodeState** custom resource per node, which is the source of truth; you can also run the discovery script.

Use the script in [apply/list-mellanox-nics.sh](apply/list-mellanox-nics.sh) to list Mellanox NICs (PCI vendor 15b3) on each worker node:

```shell
./apply/list-mellanox-nics.sh
# Optional: include devices with no network interface
./apply/list-mellanox-nics.sh --all
```

From the output, note:

- **interfaceName** — OS name (e.g. `eno5np0`, `enp3s0np0`)
- **deviceID** — Model identifier (e.g. 1021 for ConnectX-7, 101f for ConnectX-6)
- **vendor** — Mellanox is always `15b3`

### Step 3: Node policy (SriovNetworkNodePolicy)

The node policy tells the kernel to create Virtual Functions (VFs) on the selected physical devices.

Important fields:

- **resourceName** — Label used by the SriovNetwork (e.g. `mellanox_cx7`)
- **numVfs** — Number of VFs per physical device
- **nicSelector** — Filter by vendor, deviceID, and `pfNames` (interface names from Step 2)
- **deviceType** — Typically `netdevice` (or `vfio-pci` for DPDK)

Apply the policy or policies that match your hardware:

- **[apply/policy-cx7-highspeed.yaml](apply/policy-cx7-highspeed.yaml)** — ConnectX-7 (device ID 1021). Adjust `nicSelector.pfNames` to match your nodes (e.g. `eno5np0`, `enp3s0np0`).
- **[apply/policy-cx6-std.yaml](apply/policy-cx6-std.yaml)** — ConnectX-6 (device ID 101f). Adjust `nicSelector.pfNames` (e.g. `eno2np0`).

### Step 4: Logical network (SriovNetwork)

Define a logical network so pods can request a VF and get IPAM. The `resourceName` must match the SriovNetworkNodePolicy.

- **[apply/network-cx7.yaml](apply/network-cx7.yaml)** — Network for ConnectX-7 (Whereabouts IPAM 192.168.100.0/24)
- **[apply/network-cx6.yaml](apply/network-cx6.yaml)** — Network for ConnectX-6 (VLAN 10, Whereabouts 192.168.20.0/24)

Apply the network(s) you need:

```shell
oc apply -f apply/network-cx7.yaml
# and/or
oc apply -f apply/network-cx6.yaml
```

### Step 5: Consuming the network in a pod

Attach a pod to the SR-IOV network using the `k8s.v1.cni.cncf.io/networks` annotation and request the corresponding resource.

Example for ConnectX-7: **[apply/sample-pod-cx7.yaml](apply/sample-pod-cx7.yaml)**. The pod requests one VF from the `mellanox_cx7` pool and attaches to `network-cx7`.
