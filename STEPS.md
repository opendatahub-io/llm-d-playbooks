# LLM Deployment Steps

This document outlines the 7-step sequence for deploying and validating LLM-D.

## Step 01: Cluster Bring-up
- **Purpose**: Install xKS / OCP cluster
- **Directory**: [01-cluster-bring-up/](01-cluster-bring-up/)
- **Platforms**: xKS, OCP

## Step 02: Operators
- **Purpose**: Install required operators
- **Directory**: [02-operators/](02-operators/)
- **Components**: LLM-D operators, platform-specific dependencies

## Step 03: Control Plane Readiness
- **Purpose**: Validate control plane readiness
- **Directory**: [03-control-plane-readiness/](03-control-plane-readiness/)
- **Validations**: CRDs present, operators healthy, LLM-D deployable

## Step 04: High-Speed Networking
- **Purpose**: Configure high-speed networking (RoCE / IB)
- **Directory**: [04-high-speed-networking/](04-high-speed-networking/)
- **Platforms**: xKS, OCP

## Step 05: Secondary Network Validation
- **Purpose**: Validate secondary network
- **Directory**: [05-secondary-network-validation/](05-secondary-network-validation/)
- **Tests**: Connectivity, bandwidth, latency/stability

## Step 06: LLM-D Deploy
- **Purpose**: Deploy LLM-D and benchmark tools
- **Directory**: [06-llm-d-deploy/](06-llm-d-deploy/)
- **Components**: LLM-D, GuideLLM

## Step 07: LLM Deployment Validation
- **Purpose**: Validate LLM deployment
- **Directory**: [07-llm-deployment-validation/](07-llm-deployment-validation/)
- **Tests**: Functional tests, performance tests

## Shared Resources

Common utilities and assets are available in [shared/](shared/).