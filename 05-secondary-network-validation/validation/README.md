# Secondary Network Validation

## Overview
This directory contains tools and scripts for validating secondary network performance.

## Validation Types

### Connectivity
- **Directory**: [connectivity/](connectivity/)
- **Tests**: Network reachability and basic connectivity
- **Tools**: ping, network topology validation

### Bandwidth
- **Directory**: [bandwidth/](bandwidth/)
- **Tests**: High-speed data transfer validation
- **Tools**: ib_write_bw, network throughput testing

### Latency/Stability
- **Directory**: [latency-stability/](latency-stability/)
- **Tests**: Network performance consistency and latency
- **Tools**: Latency measurement, stability analysis

## Testing Guidelines
- Run tests in sequence: connectivity → bandwidth → latency/stability
- Document baseline performance metrics
- Compare results against expected performance criteria