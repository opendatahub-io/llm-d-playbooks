# LLM Deployment Validation

## Overview
This directory contains comprehensive validation tools for testing LLM deployment functionality and performance.

## Validation Types

### Functional Tests
- **Directory**: [functional/](functional/)
- **Purpose**: Basic functionality and API validation
- **Tests**: Service health, API responses, error handling
- **Tools**: curl scripts, API test suites, health checks

### Performance Tests
- **Directory**: [performance/](performance/)
- **Purpose**: Performance and scalability validation
- **Tests**: Throughput, latency, concurrent load testing

#### GuideLLM Performance Tests
- **Directory**: [performance/guidellm/](performance/guidellm/)
- **Purpose**: GuideLLM-based performance benchmarking
- **Tests**: Model inference speed, token generation rates

## Testing Guidelines
1. Run functional tests first to ensure basic operation
2. Execute performance tests only after functional validation passes
3. Document baseline metrics for future comparisons
4. Monitor system resources during testing

## Test Execution Order
1. Functional validation
2. Performance baseline establishment
3. Load testing and stress testing
4. Results analysis and reporting