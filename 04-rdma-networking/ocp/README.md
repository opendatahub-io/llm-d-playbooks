# OpenShift Container Platform: RDMA Networking

Platform-specific instructions:

- **[OCP on IBM Cloud](ibm-cloud/README.md)** — High-speed secondary (cluster) network for H100/H200 instances
- **[OCP on Bare Metal with SR-IOV](bare-metal/README.md)** — Mellanox RoCE via NVIDIA Network Operator and SR-IOV Operator

---

## Common steps for all OCP platforms

The following extend the GPU operator configuration from [Step 02: Operators](../../02-operators/README.md). Ensure these are in place for RDMA (RoCE/InfiniBand) support.

### Node Feature Discovery operator

Install the Node Feature Discovery operator and create the NodeFeatureDiscovery custom resource. See the official Red Hat [documentation for the Node Feature Discovery operator](https://docs.redhat.com/en/documentation/openshift_container_platform/4.20/html/specialized_hardware_and_driver_enablement/psap-node-feature-discovery-operator). The default NodeFeatureDiscovery object is usually sufficient for llm-d.

### NVIDIA GPU Operator (ClusterPolicy and driver ConfigMap)

Install the [NVIDIA GPU Operator](https://docs.nvidia.com/datacenter/cloud-native/openshift/24.9.2/install-gpu-ocp.html) first (see [Step 02: Operators](../../02-operators/README.md)). Then apply the RDMA-ready ClusterPolicy and the ConfigMap it references. Both live in [apply/](apply/):

1. **Apply the ConfigMap** (required by the ClusterPolicy for DeepEP driver settings):

   - **[apply/configmap-nvidia-kmod-params.yaml](apply/configmap-nvidia-kmod-params.yaml)** — ConfigMap `kernel-module-params` with `nvidia.conf` entries for DeepEP (`NVreg_EnableStreamMemOPs=1`, `NVreg_RegistryDwords="PeerMappingOverride=1;"`). The ClusterPolicy’s `spec.driver.kernelModuleConfig.name` must match this ConfigMap name.

    ```bash
    oc apply -f apply/configmap-nvidia-kmod-params.yaml
    ```

2. **Apply the ClusterPolicy**:

   - **[apply/gpu-cluster-policy.yaml](apply/gpu-cluster-policy.yaml)** — Full ClusterPolicy used for RDMA: `spec.driver.rdma.enabled: true` (nvidia-peermem), `spec.driver.rdma.useHostMofed: false` (NVIDIA Network Operator manages mofed on bare metal; see [Bare Metal](bare-metal/README.md)), `spec.gdrcopy.enabled: true`, device plugin enabled. Adjust licensing and other settings for your environment (e.g. `nvidia-licensing-config`) before applying.

    ```bash
    oc apply -f apply/gpu-cluster-policy.yaml
    ```

Apply in this order: ConfigMap first, then ClusterPolicy. See the [GPU operator custom driver params docs](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/custom-driver-params.html) for how the ConfigMap is used.

Validation of RDMA networking (including GPU operator driver and nvidia-peermem) is covered in [Step 05: RDMA Network Validation](../../05-rdma-network-validation/).

---

## Troubleshooting

### PCI vendor labels (NFD)

The NVIDIA GPU operator relies on NFD to label nodes with `feature.node.kubernetes.io/pci-10de.present: "true"`. The NVIDIA network operator schedules the mofed driver and RDMA pods based on labels such as `feature.node.kubernetes.io/pci-15b3.present: "true"` for Mellanox. If GPU or Mellanox pods are not scheduled, confirm that NFD has created the expected labels on the nodes.

For InfiniBand you may need to add device class IDs (0207 for IB, 02 for network controller) to the NodeFeatureDiscovery operator `sources.pci.deviceClassWhitelist` under `spec.workerConfig.configData`.