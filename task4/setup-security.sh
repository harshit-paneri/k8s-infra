#!/bin/bash
# ═══════════════════════════════════════════════════════════════════
# Dodo Payments — Security Hardening Setup
# ═══════════════════════════════════════════════════════════════════

set -euo pipefail

echo "╔══════════════════════════════════════════════════╗"
echo "║    Dodo Payments — Security Hardening Setup      ║"
echo "╚══════════════════════════════════════════════════╝"

# ── Step 1: Apply RBAC ──────────────────────────────────────────
echo ""
echo "▶ Step 1: Applying RBAC policies..."
kubectl apply -f rbac/rbac.yaml
echo "   ✅ RBAC roles and bindings created"

# ── Step 2: Pod Security Standards ──────────────────────────────
echo ""
echo "▶ Step 2: Enforcing Pod Security Standards..."
kubectl apply -f pod-security/pod-security.yaml
echo "   ✅ PSS labels applied to namespace"

# ── Step 3: Install OPA Gatekeeper ──────────────────────────────
echo ""
echo "▶ Step 3: Installing OPA Gatekeeper..."
kubectl apply -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/release-3.14/deploy/gatekeeper.yaml
echo "   ⏳ Waiting for Gatekeeper to be ready..."
kubectl wait --for=condition=available deployment/gatekeeper-controller-manager \
  -n gatekeeper-system --timeout=120s
echo "   ✅ Gatekeeper installed"

# Apply constraints (wait for CRDs to be ready)
sleep 10
kubectl apply -f pod-security/pod-security.yaml
echo "   ✅ Gatekeeper constraints applied"

# ── Step 4: Install cert-manager ────────────────────────────────
echo ""
echo "▶ Step 4: Installing cert-manager for TLS..."
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.0/cert-manager.yaml
echo "   ⏳ Waiting for cert-manager..."
kubectl wait --for=condition=available deployment/cert-manager -n cert-manager --timeout=120s
kubectl wait --for=condition=available deployment/cert-manager-webhook -n cert-manager --timeout=120s

# Apply TLS config
kubectl apply -f tls/tls-config.yaml
echo "   ✅ TLS certificates configured"

# ── Step 5: Network Policies ───────────────────────────────────
echo ""
echo "▶ Step 5: Network Policies (already applied in Task 1)..."
kubectl get networkpolicy -n dodo-app
echo "   ✅ Network segmentation active"

# ── Step 6: Vault Setup (Optional) ─────────────────────────────
echo ""
echo "▶ Step 6: Vault / Azure Key Vault..."
echo "   Choose one:"
echo ""
echo "   Option A: HashiCorp Vault"
echo "   helm repo add hashicorp https://helm.releases.hashicorp.com"
echo "   helm install vault hashicorp/vault --namespace vault --create-namespace --set server.dev.enabled=true"
echo ""
echo "   Option B: Azure Key Vault (via Portal)"
echo "   1. Create Key Vault in Azure Portal"
echo "   2. az aks enable-addons --addons azure-keyvault-secrets-provider \\"
echo "        --resource-group dodo-payment --name dodo-aks"
echo "   3. kubectl apply -f vault/secrets-management.yaml"

# ── Verify
echo ""
echo "▶ Security Verification..."
echo ""
echo "--- RBAC Check ---"
echo "Developer can view pods?"
kubectl auth can-i get pods --as=dev@dodo.com -n dodo-app 2>/dev/null || echo "  (auth check requires RBAC subjects to exist)"
echo "Developer can delete pods?"
kubectl auth can-i delete pods --as=dev@dodo.com -n dodo-app 2>/dev/null || echo "  (expected: no)"

echo ""
echo "--- Network Policies ---"
kubectl get networkpolicy -n dodo-app

echo ""
echo "--- Certificates ---"
kubectl get certificates -n dodo-app 2>/dev/null || echo "  (cert-manager CRDs may take a moment)"

echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║     ✅ Security Hardening Complete!              ║"
echo "╚══════════════════════════════════════════════════╝"
