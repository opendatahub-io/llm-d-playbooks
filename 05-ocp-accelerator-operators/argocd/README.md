# ArgoCD Automation for OCP Accelerator Operators

## Overview

This directory provides an optional ArgoCD app-of-apps pattern for deploying all accelerator operators via GitOps. A root Application deploys child Application resources, each pointing to a step's `base/` manifests.

## Quick Start

### 1. Install OpenShift GitOps Operator

```bash
# Via OperatorHub UI, or:
cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: openshift-gitops-operator
  namespace: openshift-operators
spec:
  channel: latest
  name: openshift-gitops-operator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
EOF
```

### 2. Configure the Root App

Edit `bootstrap/root-app.yaml`:
- Set `spec.source.repoURL` to your fork's URL
- Set `spec.source.path` to the overlay matching your platform:
  - `05-ocp-accelerator-operators/argocd/overlays/bare-metal-ib/`
  - `05-ocp-accelerator-operators/argocd/overlays/bare-metal-roce/`
  - `05-ocp-accelerator-operators/argocd/overlays/ibm-cloud/`

### 3. Apply Bootstrap

```bash
oc apply -k 05-ocp-accelerator-operators/argocd/bootstrap/
```

This creates:
- A ClusterRoleBinding granting the GitOps controller cluster-admin
- The root Application that syncs child apps based on the selected overlay

## Platform Overlays

Each overlay's `kustomization.yaml` selects which ArgoCD Application resources to deploy:

- **bare-metal-ib**: Skips SR-IOV operator (step 10) and VF config (step 12)
- **bare-metal-roce**: Includes all steps including SR-IOV
- **ibm-cloud**: Only operators and GPU operands (no RDMA stack)

## Customization

To change the repo URL for all child apps, the root app uses a kustomize patch that replaces `spec.source.repoURL` on all Applications with the `llm-d-playbooks` managed-by label. Update the patch value in `bootstrap/root-app.yaml`.
