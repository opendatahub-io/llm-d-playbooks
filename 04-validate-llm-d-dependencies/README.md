# Chapter 04: Validate llm-d Dependencies

Validate that llm-d control plane dependencies are installed and healthy.

> **Status:** WIP -- content will be added in a later PR.

## Planned Content

- Validate required CRDs are present
- Validate pod network (non-RDMA) supports ~10 GiB cross-node bandwidth
- Operator health checks

## Validation Tooling

We are building [rhaii-cluster-validation](https://github.com/opendatahub-io/rhaii-cluster-validation), a hardware validation tool for GPU, RDMA, and network checks on Kubernetes clusters. It validates cluster readiness for llm-d / RHAII inference workloads and can automate the checks in this chapter.

## Next Steps

Proceed to [Chapter 05: OCP Accelerator Operators](../05-ocp-accelerator-operators/) (OCP only) or [Chapter 06: Validate GPU Readiness](../06-validate-gpu-readiness/).
