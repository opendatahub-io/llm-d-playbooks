# Step 04: RDMA Networking

## Purpose

Configure RDMA networking (RoCE / InfiniBand) for optimal LLM performance.

## Overview

This step configures RDMA networking (RoCE / InfiniBand) components required for llm-d. Configuration differs by platform. Currently covered: OpenShift Container Platform on IBM Cloud and OpenShift Container Platform on Bare Metal with SR-IOV; other platforms (e.g. CKS, AKS) will be added later.

**InfiniBand + SR-IOV:** A kernel bug in certain RHEL 9.6 kernels (e.g. 5.14.0-570.76.1) breaks SR-IOV for InfiniBand—the SR-IOV Network Operator cannot discover IB PFs and pod networking fails. The fix is merged upstream; a backport to the RHEL 5.14.0-570.x series is requested. See [RHEL-145522](https://issues.redhat.com/browse/RHEL-145522).

## Structure

- [**OpenShift Container Platform (OCP)**](ocp/README.md) — Common OCP steps and platform-specific instructions:
  - [OCP on IBM Cloud](ocp/ibm-cloud/README.md) — Cluster network and validation for H100/H200 instances
  - [OCP on Bare Metal with SR-IOV](ocp/bare-metal/README.md) — NVIDIA Network Operator, SR-IOV operator, Mellanox RoCE
- [**Managed Kubernetes**](managed-k8s/README.md) — CKS, AKS (placeholder; to come later)

## Next Steps

After RDMA networking is configured, proceed to [Step 05: RDMA Network Validation](../05-rdma-network-validation/).
