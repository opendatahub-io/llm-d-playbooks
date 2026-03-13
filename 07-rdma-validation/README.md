# Chapter 07: RDMA Validation

Validate RDMA network performance and connectivity after accelerator operators are deployed.

> **Status:** WIP -- content will be added in a later PR.

## Planned Content

- MOFED driver readiness checks
- RDMA connectivity validation (ping mesh)
- Bandwidth testing (`ib_write_bw`)
- Latency and stability checks

## Validation Tooling

We are building [rhaii-cluster-validation](https://github.com/opendatahub-io/rhaii-cluster-validation), a hardware validation tool for GPU, RDMA, and network checks on Kubernetes clusters. It runs per-node checks (GPU drivers, ECC, RDMA devices, NIC link state) and cross-node bandwidth tests (iperf3, `ib_write_bw`) to validate cluster readiness for llm-d / RHAII inference workloads.

## Success Criteria

- All nodes can communicate over the RDMA network
- Bandwidth meets minimum requirements for the NIC type
- No packet drops or errors
