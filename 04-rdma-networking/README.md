# Step 04: RDMA Networking

## Purpose

Configure RDMA networking (RoCE / InfiniBand)

## Overview

This step configures RDMA networking components required for optimal LLM performance, including RoCE (RDMA over Converged Ethernet) and InfiniBand support.

## Platform-Specific Configuration

### xKS Configuration
- **Directory**: [apply/xks/](apply/xks/)
- **Purpose**: RDMA networking configuration for managed Kubernetes platforms
- **Components**: RoCE/IB drivers, network policies, device configurations

### OpenShift Container Platform Configuration
- **Directory**: [apply/ocp/](apply/ocp/)
- **Purpose**: RDMA networking configuration for OpenShift Container Platform
- **Components**: RoCE/IB drivers, network policies, device configurations

## Networking Technologies

### RoCE (RDMA over Converged Ethernet)
- Low-latency, high-throughput networking
- Ethernet-based RDMA implementation

### InfiniBand
- High-performance networking protocol
- Ultra-low latency communication

## Configuration Steps
1. Install platform-specific networking components
2. Configure RDMA drivers
3. Set up network policies
4. Validate networking configuration

## Next Steps
Proceed to [Step 05: RDMA Network Validation](../05-rdma-network-validation/)
