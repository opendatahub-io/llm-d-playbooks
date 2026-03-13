# Chapter 06: Validate GPU Readiness

## Purpose

Verify that GPU resources are available on worker nodes and that the GPU operator is functioning correctly.

## Checks

```bash
# Check GPU resources on nodes
oc get nodes -o custom-columns=NAME:.metadata.name,GPU:.status.allocatable.nvidia\\.com/gpu

# Check GPU operator ClusterPolicy
oc get clusterpolicy

# Verify GPU pods
oc get pods -n nvidia-gpu-operator
```
