# Shared Resources

## Overview
This directory contains shared utilities, scripts, and assets used across all deployment steps.

## Components

### Scripts
- **Directory**: [scripts/](scripts/)
- **Purpose**: Common utilities and helper scripts
- **Contents**: Platform detection scripts, shared helper functions, common operations

### Assets
- **Directory**: [assets/](assets/)
- **Purpose**: Shared configuration files and test assets
- **Contents**: Routing examples, test data, configuration templates

## Usage
These shared resources are referenced and used by various steps in the deployment process. They provide common functionality to avoid duplication across the different deployment phases.

## Platform Detection
The scripts directory includes platform detection utilities to help determine whether you're working with xKS or OCP, allowing the playbooks to automatically select the appropriate platform-specific configurations.