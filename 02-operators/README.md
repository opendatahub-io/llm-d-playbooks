# Step 02: Operator Installation

## Purpose

Install the operators and platform dependencies required for llm-d deployment.

## Overview

The required operators differ by platform. Operator installation is documented in external guides — refer to the appropriate guide for your platform below.

## Platform Guides

| Platform | Guide |
|----------|-------|
| OpenShift Container Platform | [llm-d-playbook](https://github.com/llm-d/llm-d-playbook) |
| Managed Kubernetes (AKS / CKS) | [Deploying Red Hat AI Inference Server on Managed Kubernetes](https://opendatahub-io.github.io/rhaii-on-xks/deploying-llm-d-on-managed-kubernetes/) |

## Component Comparison

The table below shows which components are installed per platform. The components serve equivalent roles but differ in implementation.

| Component | OpenShift Container Platform | Managed Kubernetes |
|-----------|------------------------------|---------------------|
| TLS certificates | cert-manager | cert-manager |
| Service mesh / gateway | Service Mesh 3 (Istio-based) | Istio via Sail Operator |
| Inference controller | KServe (via RHOAI) | KServe (via Helm) |
| Multi-node inference | LeaderWorkerSet | LeaderWorkerSet |
| GPU support | NVIDIA GPU Operator | NVIDIA device plugin (pre-installed on CKS; manual on AKS) |
| Load balancer | MetalLB (bare metal) | Cloud provider LB (built-in) |

## Next Steps

Once operators are installed and healthy, proceed to [Step 03: Control Plane Readiness](../03-control-plane-readiness/).
