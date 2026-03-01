# Task 2: CI/CD Pipeline

## 🎯 Objective
Build an end-to-end CI/CD pipeline using GitHub Actions for automated testing, building, and deployment, with ArgoCD for GitOps-based deployment management.

## 🏗️ Pipeline Architecture

```
  Push/PR to main
       │
       ▼
  ┌──────────────────────────────────────────────────┐
  │                 CI Pipeline                       │
  ├──────────┬──────────┬──────────┬────────────────┤
  │ 🔍 Lint  │ 🧪 Test  │ 🐳 Build │ 🛡️ Trivy Scan │
  │ Black    │ pytest   │ Docker   │ CVE Detection  │
  │ flake8   │ coverage │ Push Hub │ CRITICAL/HIGH  │
  │ ESLint   │          │          │                │
  └──────────┴──────────┴──────────┴────────────────┘
       │
       ▼ (update manifests with new image tags)
  ┌──────────────────────────────────────────────────┐
  │              GitOps (ArgoCD)                      │
  ├────────────────────┬─────────────────────────────┤
  │  📦 Staging        │  🚀 Production              │
  │  Auto-sync         │  Manual sync                │
  │  Self-healing      │  Canary deployment           │
  │  Auto-prune        │  Rollback support            │
  └────────────────────┴─────────────────────────────┘
```

## 📁 Structure

```
task2/
├── argocd/
│   ├── applications.yaml       # ArgoCD app definitions (staging + prod)
│   └── setup-argocd.sh         # ArgoCD installation script
└── README.md

.github/workflows/
├── ci.yaml                     # CI: Lint → Test → Build → Scan → Update
└── cd.yaml                     # CD: Staging → Production (canary) + Rollback
```

## 🚀 Setup

### GitHub Actions (CI/CD)

1. **Add GitHub Secrets** (Settings → Secrets → Actions):
   | Secret | Description |
   |--------|-------------|
   | `DOCKER_USERNAME` | Docker Hub username |
   | `DOCKER_TOKEN` | Docker Hub access token |
   | `AZURE_CREDENTIALS` | Azure service principal JSON |

2. **Branch Protection** (Settings → Branches → Add rule for `main`):
   - ✅ Require pull request reviews (1 reviewer)
   - ✅ Require status checks: `lint`, `test`
   - ✅ Restrict force pushes

3. **Push to main** — CI runs automatically

### ArgoCD (GitOps)

#### Option A: CLI
```bash
cd task2/
chmod +x argocd/setup-argocd.sh
./argocd/setup-argocd.sh
```

#### Option B: Azure Portal
1. AKS Cluster → **GitOps** → **+ Create**
2. Select **Flux v2** → Configure repo URL & path
3. Branch: `main`, Path: `task1/k8s`

## ✅ Features

| Feature | Status | Details |
|---------|--------|---------|
| Linting | ✅ | Black, flake8, isort (Python), ESLint (JS) |
| Unit Tests | ✅ | pytest with PostgreSQL service container |
| Coverage Reports | ✅ | Uploaded as GitHub artifact |
| Docker Build & Push | ✅ | Multi-arch with GitHub Actions cache |
| **Security Scanning** (Bonus) | ✅ | Trivy for CRITICAL/HIGH CVEs |
| Image Tagging | ✅ | Git SHA + latest |
| GitOps (ArgoCD) | ✅ | Auto-sync staging, manual sync production |
| Staging Environment | ✅ | Auto-deploy on main push |
| **Canary Deployment** (Bonus) | ✅ | 1 canary replica → 2 min monitoring → full rollout |
| Rollback Mechanism | ✅ | K8s rollout undo + manual workflow dispatch |
| Branch Protection | ✅ | PR reviews, status checks required |

## 🔑 Design Decisions

1. **GitOps with ArgoCD** — Git is the single source of truth. CI updates manifests, ArgoCD syncs them to the cluster. Staging auto-syncs; production requires manual approval.

2. **Canary deployment** — Deploy 1 replica with the new version alongside existing pods. Monitor for 2 minutes, then do full rollout if healthy. Safer than blue-green for cost.

3. **Trivy in CI** — Fail the pipeline on CRITICAL/HIGH vulnerabilities before images reach production. Shift-left security.

4. **Manifest-based CD** — CI commits updated image tags to Git, which triggers ArgoCD sync. This is the standard GitOps pattern (no direct cluster access from CI).
