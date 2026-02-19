# Control Plane Readiness Validation

## Overview
This directory contains validation tools and scripts to verify control plane readiness.

## Validation Categories

### CRDs Present
- **Directory**: [crds-present/](crds-present/)
- **Tests**: Custom Resource Definition validation
- **Checks**: Required CRDs are installed and available

### Operators Healthy
- **Directory**: [operators-healthy/](operators-healthy/)
- **Tests**: Operator health and status validation
- **Checks**: All operators are running and responding

### LLM-D Deployable
- **Directory**: [llm-d-deployable/](llm-d-deployable/)
- **Tests**: LLM-D deployment readiness validation
- **Checks**: No blocking conditions (RDMA, P-D, WideEP)

## Usage
Run validation tests in the following order:
1. CRDs Present validation
2. Operators Healthy validation
3. LLM-D Deployable validation