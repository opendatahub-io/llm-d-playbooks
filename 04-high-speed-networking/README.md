# Step 04: High-Speed Networking

## Purpose
Configure high-speed networking (RoCE / InfiniBand)

## Overview
This step configures high-speed networking components required for optimal LLM performance, including RoCE (RDMA over Converged Ethernet) and InfiniBand support.

## Platform-Specific Configuration

### xKS Configuration
- **Directory**: [apply/xks/](apply/xks/)
- **Purpose**: High-speed networking configuration for xKS platforms
- **Components**: RoCE/IB drivers, network policies, device configurations

### OCP Configuration
- **Directory**: [apply/ocp/](apply/ocp/)
- **Purpose**: High-speed networking configuration for OpenShift
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
Proceed to [Step 05: Secondary Network Validation](../05-secondary-network-validation/)