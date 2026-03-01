#!/bin/bash
# ═══════════════════════════════════════════════════════════════════
# Dodo Payments — Observability Stack Setup
# ═══════════════════════════════════════════════════════════════════

set -euo pipefail

echo "╔══════════════════════════════════════════════════╗"
echo "║     Dodo Payments — Observability Setup          ║"
echo "╚══════════════════════════════════════════════════╝"

# ── Add Helm repos ──────────────────────────────────────────────
echo "▶ Adding Helm repositories..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add jaegertracing https://jaegertracing.github.io/helm-charts
helm repo update

# ── Create monitoring namespace ─────────────────────────────────
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

# ── Install kube-prometheus-stack ───────────────────────────────
echo ""
echo "▶ Installing Prometheus + Grafana + Alertmanager..."
helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --values prometheus/values.yaml \
  --wait --timeout 5m

# ── Apply custom alert rules ───────────────────────────────────
echo ""
echo "▶ Applying custom alert rules..."
kubectl apply -f prometheus/alert-rules.yaml

# ── Install Loki + Fluent Bit ──────────────────────────────────
echo ""
echo "▶ Installing Loki + Fluent Bit..."
helm upgrade --install loki grafana/loki-stack \
  --namespace monitoring \
  --values loki/values.yaml \
  --wait --timeout 5m

# ── Install Jaeger ─────────────────────────────────────────────
echo ""
echo "▶ Installing Jaeger (distributed tracing)..."
helm upgrade --install jaeger jaegertracing/jaeger \
  --namespace monitoring \
  --values jaeger/values.yaml \
  --wait --timeout 5m

# ── Apply Grafana dashboards ──────────────────────────────────
echo ""
echo "▶ Applying Grafana dashboards..."
kubectl apply -f grafana/dashboards.yaml

# ── Verify ─────────────────────────────────────────────────────
echo ""
echo "▶ Verifying installation..."
kubectl get pods -n monitoring
echo ""
kubectl get svc -n monitoring

echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║        ✅ Observability Stack Ready!             ║"
echo "╠══════════════════════════════════════════════════╣"
echo "║  Grafana:                                       ║"
echo "║  kubectl port-forward svc/monitoring-grafana     ║"
echo "║    -n monitoring 3000:80                        ║"
echo "║  User: admin / Pass: DodoGrafana2026!           ║"
echo "║                                                 ║"
echo "║  Prometheus:                                    ║"
echo "║  kubectl port-forward svc/monitoring-kube-       ║"
echo "║    prometheus-prometheus -n monitoring 9090:9090 ║"
echo "║                                                 ║"
echo "║  Jaeger:                                        ║"
echo "║  kubectl port-forward svc/jaeger-query           ║"
echo "║    -n monitoring 16686:16686                    ║"
echo "╚══════════════════════════════════════════════════╝"
