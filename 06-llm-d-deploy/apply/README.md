# LLM-D Deployment Components

## Overview
This directory contains deployment manifests and configurations for LLM-D and related tools.

## Components

### LLM-D
- **Directory**: [llm-d/](llm-d/)
- **Purpose**: Core LLM-D deployment manifests
- **Contents**: Kubernetes manifests, configurations, secrets

### GuideLLM
- **Directory**: [guidellm/](guidellm/)
- **Purpose**: GuideLLM and benchmark tool deployments
- **Contents**: Benchmark tool manifests, test configurations

## Deployment Order
1. Deploy LLM-D components first
2. Deploy GuideLLM and benchmark tools
3. Verify all components are running

## Configuration
- Review and customize configurations before deployment
- Ensure resource requirements match cluster capacity
- Validate network and storage configurations