# Chapter 00: Prerequisites

## Purpose

Prepare the cluster for llm-d deployment by cleaning up prior installations and labeling nodes.

## Steps

### 00-cleanup

Clear out operators and dependencies from prior installations.

- [00-cleanup/](00-cleanup/)

### 01-node-preparation

Label worker nodes and configure master nodes to exclude GPU/MOFED workloads.

- [01-node-preparation/](01-node-preparation/)

```bash
oc apply -f 00-pre/01-node-preparation/node-label-taint-job.yaml
```

This job:
- Labels worker-only nodes with `fab-rig-deployer=true`
- Disables GPU operands on master/control-plane nodes
- Disables MOFED driver on master/control-plane nodes
