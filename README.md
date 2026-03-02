# LLM-D Deployment Playbooks

## Overview

This repository contains playbooks for deploying and validating [llm-d](https://github.com/llm-d/llm-d) across multiple Kubernetes platforms.

## Tested Platforms

| Platform | Documentation |
|----------|--------------|
| OpenShift Container Platform | [Installation overview](https://docs.redhat.com/en/documentation/openshift_container_platform/4.20/html/installation_overview/ocp-installation-overview) |
| Azure Kubernetes Service (AKS) | [AKS quickstart](https://learn.microsoft.com/en-us/azure/aks/learn/quick-kubernetes-deploy-portal) |
| CoreWeave Kubernetes Service (CKS) | [CKS introduction](https://docs.coreweave.com/products/cks) |

## Deployment Steps

| Directory | Purpose |
|-----------|---------|
| [01-cluster-bring-up/](01-cluster-bring-up/) | Install and bootstrap a Kubernetes cluster on one of the tested platforms. |
| [02-operators/](02-operators/) | Install the operators required for llm-d (cert-manager, service mesh, KServe, LeaderWorkerSet, etc.). |
| [03-control-plane-readiness/](03-control-plane-readiness/) | Validate that all required CRDs are present, operators are healthy, and the cluster is ready for llm-d. |
| [04-rdma-networking/](04-rdma-networking/) | Configure RDMA networking (RoCE / InfiniBand) for prefill-decode disaggregation and multi-node inference. |
| [05-rdma-network-validation/](05-rdma-network-validation/) | Validate RDMA network connectivity, bandwidth, and latency. |
| [06-llm-d-deploy/](06-llm-d-deploy/) | Deploy llm-d and benchmark tools (GuideLLM). |
| [07-llm-deployment-validation/](07-llm-deployment-validation/) | Validate the deployment through functional and performance tests. |

## Shared Resources

Common scripts and assets are located in the [shared/](shared/) directory.
