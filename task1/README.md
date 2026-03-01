# Task 1: Kubernetes Cluster Setup & Microservices Deployment

## 🎯 Objective
Set up an AKS (Azure Kubernetes Service) cluster and deploy a 3-tier microservices application — React frontend, FastAPI backend, and PostgreSQL database — with production-grade Kubernetes resources.

## 🏗️ Architecture

```
                    ┌─────────────────────────────────────────┐
                    │         Azure Load Balancer              │
                    └───────────────┬─────────────────────────┘
                                    │
                    ┌───────────────▼─────────────────────────┐
                    │      NGINX Ingress Controller            │
                    │      /  → Frontend    /api → Backend     │
                    └───────────────┬─────────────────────────┘
                         ┌──────────┼──────────┐
                         ▼                     ▼
              ┌─────────────────┐   ┌─────────────────┐
              │  Frontend (2)    │   │  Backend (3)     │
              │  React + Nginx   │   │  FastAPI         │
              │  HPA: 2-5       │   │  HPA: 3-10       │
              └─────────────────┘   └────────┬─────────┘
                                             │
                                  ┌──────────▼─────────┐
                                  │  PostgreSQL (1)     │
                                  │  StatefulSet + PVC  │
                                  │  5Gi Azure Disk     │
                                  └────────────────────┘
```

## 📁 Structure

```
task1/
├── infrastructure/
│   └── setup-aks.sh              # Full AKS cluster + app deployment script
├── frontend/                     # React payment dashboard
│   ├── Dockerfile                # Multi-stage: Node build → Nginx serve
│   ├── nginx.conf                # Reverse proxy + security headers
│   ├── src/App.js                # Dashboard with CRUD + stats
│   └── src/index.css             # Dark-mode design system
├── backend/                      # Python FastAPI API
│   ├── Dockerfile                # Multi-stage with non-root user
│   ├── requirements.txt
│   └── app/
│       ├── main.py               # Health, CRUD, Prometheus /metrics
│       ├── config.py             # Env-based configuration
│       ├── database.py           # SQLAlchemy connection pool
│       ├── models.py             # Transaction ORM model
│       └── schemas.py            # Pydantic validation
└── k8s/
    ├── namespace.yaml            # dodo-app NS with PSS labels
    ├── configmaps.yaml           # Backend + frontend configs
    ├── secrets.yaml              # DB credentials (base64)
    ├── database.yaml             # StatefulSet + Headless Service + PVC
    ├── backend.yaml              # Deployment (3 replicas) + Service
    ├── frontend.yaml             # Deployment (2 replicas) + Service
    ├── hpa.yaml                  # HPA v2 with scaling behavior
    ├── ingress.yaml              # NGINX path-based routing
    ├── network-policies.yaml     # Zero-trust micro-segmentation (Bonus)
    └── pdb.yaml                  # Pod Disruption Budgets (Bonus)
```

## 🚀 Quick Start

### Option A: Azure CLI
```bash
# 1. Create AKS cluster and deploy everything
chmod +x infrastructure/setup-aks.sh
./infrastructure/setup-aks.sh

# 2. Get the external IP
kubectl get svc -n ingress-nginx

# 3. Access the app
# http://<EXTERNAL-IP>/          → Dashboard
# http://<EXTERNAL-IP>/api/health → API Health Check
```

### Option B: Azure Portal
1. **Create AKS Cluster**: Portal → Kubernetes services → + Create
   - Resource Group: `dodo-payment`, Name: `dodo-aks`
   - Region: Central India, Node Size: Standard_B2s, Count: 2
   - Networking: Azure CNI
2. **Connect**: Click "Connect" → copy the credentials command
3. **Deploy**: Run `kubectl apply -f k8s/` commands from the script

## ✅ Features Implemented

| Feature | Status | Details |
|---------|--------|---------|
| 3 Microservices | ✅ | React frontend, FastAPI backend, PostgreSQL |
| Deployments & Services | ✅ | Rolling updates, ClusterIP services |
| ConfigMaps & Secrets | ✅ | Externalized configuration |
| NGINX Ingress | ✅ | Path-based routing with rate limiting |
| HPA | ✅ | CPU/Memory based scaling with behavior policies |
| Health Probes | ✅ | Liveness, readiness, startup for all services |
| Resource Limits | ✅ | CPU & memory requests/limits on all containers |
| **StatefulSet** (Bonus) | ✅ | PostgreSQL with PVC (5Gi Azure Disk) |
| **Network Policies** (Bonus) | ✅ | Default-deny + explicit allow (zero-trust) |
| **PDBs** (Bonus) | ✅ | Frontend: min 1, Backend: min 2 |
| Non-root Containers | ✅ | Security context on all pods |
| Prometheus Metrics | ✅ | Backend exposes /metrics endpoint |

## 🔑 Design Decisions

1. **StatefulSet for PostgreSQL** over Deployment — provides stable network identity, ordered pod management, and persistent storage that survives pod restarts.

2. **HPA v2 with scaling behavior** — stabilization windows prevent flapping (60s up, 300s down). Backend scales on both CPU and memory.

3. **Zero-trust Network Policies** — default deny all, then explicit allow. Frontend only accepts from ingress, backend only from frontend, database only from backend.

4. **Multi-stage Docker builds** — smaller images (security + faster pulls). Non-root users for defense-in-depth.

5. **Headless Service for PostgreSQL** — DNS resolves directly to pod IP, required for StatefulSet stable network identity.
