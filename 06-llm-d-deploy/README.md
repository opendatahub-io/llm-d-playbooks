# Step 06: LLM-D Deploy

## Purpose
Deploy LLM-D and benchmark tools

## Overview
This step deploys LLM-D  along with benchmarking and testing tools.

## Components

### LLM-D Deployment
- **Directory**: [apply/llm-d/](apply/llm-d/)
- **Purpose**: Deploy LLM-D
- **Components**: LLM-D, serving infrastructure, management components

### GuideLLM Deployment
- **Directory**: [apply/guidellm/](apply/guidellm/)
- **Purpose**: Deploy GuideLLM and other benchmark tools
- **Components**: Performance testing tools, benchmark suites, monitoring tools

## Deployment Process
1. Deploy LLM-D core components
2. Deploy GuideLLM and benchmark tools
3. Verify deployments are running
4. Configure monitoring and observability

## Dependencies
- Successful completion of Steps 01-05
- High-speed networking configured and validated
- Control plane ready and operators healthy

## Validation
- All pods are running and ready
- Services are accessible
- LLM-D APIs are responsive

## Next Steps
Proceed to [Step 07: LLM Deployment Validation](../07-llm-deployment-validation/)