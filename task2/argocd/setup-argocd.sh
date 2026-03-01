#!/bin/bash
# ═══════════════════════════════════════════════════════════════════
# ArgoCD Setup Script
# ═══════════════════════════════════════════════════════════════════
# Installs ArgoCD on the AKS cluster and configures applications.
#
# Prerequisites:
#   - kubectl configured for your AKS cluster
#   - Helm installed
# ═══════════════════════════════════════════════════════════════════

set -euo pipefail

echo "╔══════════════════════════════════════════════════╗"
echo "║          ArgoCD Setup for Dodo Payments          ║"
echo "╚══════════════════════════════════════════════════╝"

# ── Step 1: Install ArgoCD ───────────────────────────────────────
echo ""
echo "▶ Step 1: Installing ArgoCD..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "   ⏳ Waiting for ArgoCD to be ready..."
kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=180s

# ── Step 2: Expose ArgoCD UI ────────────────────────────────────
echo ""
echo "▶ Step 2: ArgoCD access information:"

# Get initial admin password
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d)

echo "   📌 Username: admin"
echo "   📌 Password: $ARGOCD_PASSWORD"
echo ""
echo "   To access the UI:"
echo "   kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "   Then open: https://localhost:8080"

# ── Step 3: Install ArgoCD CLI (optional) ────────────────────────
echo ""
echo "▶ Step 3: Install ArgoCD CLI (optional)..."
if ! command -v argocd &> /dev/null; then
    echo "   Installing argocd CLI..."
    curl -sSL -o /usr/local/bin/argocd \
      https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
    chmod +x /usr/local/bin/argocd
    echo "   ✅ ArgoCD CLI installed"
else
    echo "   ✅ ArgoCD CLI already installed"
fi

# ── Step 4: Register Applications ───────────────────────────────
echo ""
echo "▶ Step 4: Registering ArgoCD applications..."
kubectl apply -f argocd/applications.yaml

echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║        ✅ ArgoCD Setup Complete!                 ║"
echo "╠══════════════════════════════════════════════════╣"
echo "║  Run: kubectl port-forward svc/argocd-server    ║"
echo "║       -n argocd 8080:443                        ║"
echo "║                                                 ║"
echo "║  Then open: https://localhost:8080               ║"
echo "║  Username: admin                                ║"
echo "║  Password: (printed above)                      ║"
echo "╚══════════════════════════════════════════════════╝"
