# Step 05: RDMA Network Validation

## Purpose

Validate RDMA network performance and connectivity

## Overview

This step validates that RDMA networking is functioning correctly by testing connectivity, bandwidth, and latency characteristics.

## Validation Categories

### Connectivity
- **Directory**: [validation/connectivity/](validation/connectivity/)
- **Tests**: Basic connectivity validation (ping tests)
- **Purpose**: Verify RDMA reachability between nodes

### Bandwidth
- **Directory**: [validation/bandwidth/](validation/bandwidth/)
- **Tests**: Bandwidth testing (ib_write_bw, etc.)
- **Purpose**: Validate RDMA data transfer capabilities

### Latency/Stability
- **Directory**: [validation/latency-stability/](validation/latency-stability/)
- **Tests**: Latency and stability sanity checks
- **Purpose**: Verify low-latency and stable network performance

## Testing Process
1. Run connectivity tests to verify basic RDMA functionality
2. Execute bandwidth tests to validate throughput
3. Perform latency/stability tests to ensure consistent performance
4. Analyze results and identify any network issues

## Success Criteria
- All nodes can communicate over the RDMA network
- Bandwidth meets minimum requirements
- Latency is within acceptable thresholds
- Network performance is stable over time

## Next Steps
Proceed to [Step 06: LLM-D Deploy](../06-llm-d-deploy/)
