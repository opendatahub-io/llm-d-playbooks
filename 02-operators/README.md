# Step 02: Operators

## Purpose
Install required operators for LLM deployment

## Overview
This step handles the installation of operators required for LLM-D deployment, including both shared LLM-D operators and platform-specific dependencies.

## Components

### LLM-D Operators
- **Directory**: [apply/llm-d-operators/](apply/llm-d-operators/)
- **Purpose**: Shared intent LLM-D operators (scripts may differ by platform)

### xKS Dependencies
- **Directory**: [apply/xks-dependencies/](apply/xks-dependencies/)
- **Purpose**: Platform-specific dependencies for xKS

### OCP Dependencies
- **Directory**: [apply/ocp-dependencies/](apply/ocp-dependencies/)
- **Purpose**: Platform-specific dependencies for OCP

## Installation Order
1. Install platform-specific dependencies first
2. Install LLM-D operators
3. Verify operator installation

## Validation
- [Validation steps to be documented]

## Next Steps
Proceed to [Step 03: Control Plane Readiness](../03-control-plane-readiness/)