#!/bin/bash
# ═══════════════════════════════════════════════════════════════════
# Dodo Payments — AKS Cluster Setup Script
# ═══════════════════════════════════════════════════════════════════
# This script creates an Azure Kubernetes Service (AKS) cluster
# and installs required add-ons (NGINX Ingress Controller, etc.)
#
# Prerequisites:
#   - Azure CLI installed (az --version)
#   - Logged in (az login)
#   - Subscription set (az account set --subscription <id>)
# ═══════════════════════════════════════════════════════════════════

set -euo pipefail

# ── Configuration ────────────────────────────────────────────────
RESOURCE_GROUP="dodo-payment"
CLUSTER_NAME="dodo-aks"
LOCATION="centralindia"
NODE_COUNT=2
NODE_VM_SIZE="Standard_B2s"
K8S_VERSION="1.28"    # Latest stable at time of writing

echo "╔══════════════════════════════════════════════════╗"
echo "║       Dodo Payments — AKS Cluster Setup         ║"
echo "╚══════════════════════════════════════════════════╝"

# ── Step 1: Create Resource Group ────────────────────────────────
echo ""
echo "▶ Step 1: Creating Resource Group..."
az group create \
  --name "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --tags environment=assessment project=dodo-payments

# ── Step 2: Create AKS Cluster ──────────────────────────────────
echo ""
echo "▶ Step 2: Creating AKS Cluster (this takes 5-10 minutes)..."
az aks create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$CLUSTER_NAME" \
  --node-count "$NODE_COUNT" \
  --node-vm-size "$NODE_VM_SIZE" \
  --enable-managed-identity \
  --network-plugin azure \
  --location "$LOCATION" \
  --generate-ssh-keys \
  --enable-addons monitoring \
  --tags environment=assessment project=dodo-payments \
  --no-wait

echo "   ⏳ Cluster creation started. Waiting for completion..."
az aks wait \
  --resource-group "$RESOURCE_GROUP" \
  --name "$CLUSTER_NAME" \
  --created \
  --timeout 600

echo "   ✅ AKS Cluster created successfully!"

# ── Step 3: Get Credentials ─────────────────────────────────────
echo ""
echo "▶ Step 3: Fetching cluster credentials..."
az aks get-credentials \
  --resource-group "$RESOURCE_GROUP" \
  --name "$CLUSTER_NAME" \
  --overwrite-existing

# ── Step 4: Verify Cluster ──────────────────────────────────────
echo ""
echo "▶ Step 4: Verifying cluster..."
kubectl get nodes
kubectl cluster-info

# ── Step 5: Install NGINX Ingress Controller ────────────────────
echo ""
echo "▶ Step 5: Installing NGINX Ingress Controller..."
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.replicaCount=2 \
  --set controller.metrics.enabled=true \
  --set controller.metrics.serviceMonitor.enabled=true

# ── Step 6: Deploy Application ──────────────────────────────────
echo ""
echo "▶ Step 6: Deploying Dodo Payments application..."
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/configmaps.yaml
kubectl apply -f k8s/secrets.yaml
kubectl apply -f k8s/database.yaml
echo "   ⏳ Waiting for PostgreSQL to be ready..."
kubectl wait --for=condition=ready pod -l app=postgresql -n dodo-app --timeout=120s
kubectl apply -f k8s/backend.yaml
kubectl apply -f k8s/frontend.yaml
kubectl apply -f k8s/hpa.yaml
kubectl apply -f k8s/ingress.yaml
kubectl apply -f k8s/network-policies.yaml
kubectl apply -f k8s/pdb.yaml

# ── Step 7: Verify Deployment ───────────────────────────────────
echo ""
echo "▶ Step 7: Verifying deployment..."
echo ""
kubectl get pods -n dodo-app
echo ""
kubectl get svc -n dodo-app
echo ""
kubectl get hpa -n dodo-app
echo ""
kubectl get ingress -n dodo-app
echo ""
kubectl get networkpolicy -n dodo-app
echo ""
kubectl get pdb -n dodo-app

echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║        ✅ Deployment Complete!                  ║"
echo "╠══════════════════════════════════════════════════╣"
echo "║  Get Ingress IP:                                ║"
echo "║  kubectl get svc -n ingress-nginx               ║"
echo "║                                                 ║"
echo "║  Access Dashboard:                              ║"
echo "║  http://<EXTERNAL-IP>/                          ║"
echo "║                                                 ║"
echo "║  Access API:                                    ║"
echo "║  http://<EXTERNAL-IP>/api/health                ║"
echo "╚══════════════════════════════════════════════════╝"
