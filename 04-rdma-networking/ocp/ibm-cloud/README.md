# OCP on IBM Cloud: RDMA Networking

This section covers configuring the high-speed secondary network (“cluster network”) for H100 or H200 instances on OpenShift Container Platform on IBM Cloud.

## Supported instance types and regions

Cluster networks and supported instance types vary by region. For the latest list of supported regions and instance types, see the IBM Cloud documentation:

- [Planning cluster networks — Supported regions](https://cloud.ibm.com/docs/vpc?topic=vpc-planning-cluster-network#cn-supported-regions)

As of this writing, the **Hopper-1** cluster network type supports:

| Cluster network type | Instance types | Region | Zone(s) |
|----------------------|----------------|--------|---------|
| hopper-1 | gx3d-160x1792x8h100, gx3d-160x1792x8h200 | Frankfurt (eu-de) | eu-de-2, eu-de-fra02-a |
| hopper-1 | gx3d-160x1792x8h100, gx3d-160x1792x8h200 | Washington DC (us-east) | us-east-3 |

Confirm current offerings in the link above before provisioning.

---

## Configuring high-speed secondary network for H100 instances (“Cluster network”)

After creating H100 or H200 instances, create a **cluster network** of the **Hopper-1** cluster network type and attach 8 interfaces to each instance.

**Note:** The Hopper-1 cluster network type must be used to enable routing across subnets as required by NVSHMEM. The deprecated “h100” cluster network type does not support this.

Refer to the [IBM Cloud documentation on creating a cluster network](https://cloud.ibm.com/docs/vpc?topic=vpc-create-cluster-network&interface=ui) for the exact steps.

- Each instance has 8 NICs corresponding to the 8 GPUs. Create the cluster network with **8 subnets** so that each NIC is attached to one subnet.
- Attach each instance to each of the subnets. The instance must be **stopped** temporarily to add attachments.
- A common naming convention is `psap-gpu-cna-x-y`, where `x` is the node index and `y` is the subnet index.
- After attaching each instance to the cluster network, verify all attachments appear under the cluster network.
- **Start the nodes** once configuration is complete.

---

## Validating secondary network is visible on nodes

Before continuing, confirm that the interfaces are visible on the nodes:

```shell
oc debug node/<node-name>
# In the debug shell:
chroot /host
ip addr
```

You should see the cluster network interfaces (e.g. multiple `enp*` interfaces with addresses in the subnet ranges you configured). Then exit the debug session.
