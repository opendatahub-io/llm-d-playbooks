# LLM Deployment Playbooks

## Overview

This repository contains comprehensive playbooks for deploying and validating LLM-D.

## Structure

This repository follows a 7-step deployment and validation process:

1. **Cluster Bring-up** - Install xKS / OCP cluster
2. **Operators** - Install required operators
3. **Control Plane Readiness** - Validate control plane readiness
4. **High-Speed Networking** - Configure high-speed networking (RoCE / IB)
5. **Secondary Network Validation** - Validate secondary network
6. **LLM-D Deploy** - Deploy LLM-D and benchmark tools
7. **LLM Deployment Validation** - Validate LLM deployment

## Platform Support

- **xKS** - Kubernetes distributions
- **OCP** - OpenShift

## Getting Started

See [STEPS.md](STEPS.md) for detailed step-by-step instructions.

## Shared Resources

Common scripts and assets are located in the `shared/` directory.