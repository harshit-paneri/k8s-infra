# Task 4: Security Hardening

## 🎯 Objective
Implement comprehensive security measures across the infrastructure and application layers using defense-in-depth principles.

## 🏗️ Security Architecture

```
┌───────────────────────────────────────────────────────────┐
│                    Security Layers                         │
├───────────────────────────────────────────────────────────┤
│  Layer 1: Identity & Access                               │
│  ├── RBAC (developer / operator / admin)                 │
│  └── Azure AD Integration                                │
├───────────────────────────────────────────────────────────┤
│  Layer 2: Pod Security                                    │
│  ├── Pod Security Standards (restricted)                 │
│  ├── OPA Gatekeeper (required labels, no :latest)        │
│  └── Non-root containers, read-only root FS              │
├───────────────────────────────────────────────────────────┤
│  Layer 3: Secrets Management                              │
│  ├── HashiCorp Vault (sidecar injection)                 │
│  └── Azure Key Vault (Secrets Store CSI)                 │
├───────────────────────────────────────────────────────────┤
│  Layer 4: Network Security                                │
│  ├── Network Policies (default-deny + allowlist)         │
│  └── TLS/mTLS (cert-manager + self-signed CA)            │
├───────────────────────────────────────────────────────────┤
│  Layer 5: Supply Chain                                    │
│  ├── Trivy (container image scanning in CI)              │
│  └── Disallow :latest tag (OPA Gatekeeper)               │
└───────────────────────────────────────────────────────────┘
```

## 📁 Structure

```
task4/
├── rbac/
│   └── rbac.yaml                # Roles, ClusterRoles, RoleBindings
├── pod-security/
│   └── pod-security.yaml        # PSS labels + OPA Gatekeeper constraints
├── vault/
│   └── secrets-management.yaml  # Vault + Azure KV + CSI driver
├── tls/
│   └── tls-config.yaml          # cert-manager issuers + certificates
├── setup-security.sh            # One-command setup script
└── README.md
```

## 🚀 Setup

### Option A: CLI
```bash
cd task4/
chmod +x setup-security.sh
./setup-security.sh
```

### Option B: Azure Portal
1. **RBAC**: AKS → Access control (IAM) → Add role assignments
2. **Azure Policy**: AKS → Policies → Enable Azure Policy for Kubernetes
3. **Key Vault**: Create Key Vault → Add secrets → Enable CSI driver addon
4. **Network**: Already configured via Network Policies in Task 1

## ✅ Features

| Feature | Status | Details |
|---------|--------|---------|
| RBAC | ✅ | 3 roles: developer (read-only), operator (manage), admin (full) |
| Pod Security Standards | ✅ | Restricted level enforced on namespace |
| OPA Gatekeeper | ✅ | Required labels, disallow :latest tags |
| HashiCorp Vault | ✅ | Sidecar injection, K8s auth, policy-based access |
| Azure Key Vault | ✅ | Secrets Store CSI driver, managed identity |
| TLS (cert-manager) | ✅ | Self-signed CA + Let's Encrypt ready |
| Network Policies | ✅ | Zero-trust micro-segmentation (Task 1) |
| Container Scanning | ✅ | Trivy in CI pipeline (Task 2) |
| Non-root Containers | ✅ | securityContext on all deployments |
| Read-only Root FS | ✅ | Backend enforces readOnlyRootFilesystem |

## 🔑 Design Decisions

1. **Defense-in-depth** — Multiple overlapping security layers. Even if one control fails, others provide protection.

2. **PSS + OPA Gatekeeper** — PSS handles the baseline (no privileged, no host, etc.) while Gatekeeper adds custom policies (required labels, no :latest). Complementary, not redundant.

3. **Both Vault and Azure KV** — Shows flexibility. Vault is cloud-agnostic with richer features (dynamic secrets, leasing). Azure KV is simpler for Azure-native deployments.

4. **cert-manager with self-signed CA** — For assessment simplicity. Production would use Let's Encrypt (config included, commented out).
