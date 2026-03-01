# Task 3: Monitoring, Logging & Observability

## 🎯 Objective
Implement a comprehensive observability stack with metrics (Prometheus + Grafana), logs (Loki + Fluent Bit), and traces (Jaeger) for the deployed microservices.

## 🏗️ Observability Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                    Microservices (dodo-app)                    │
│  ┌──────────┐   ┌──────────┐   ┌──────────────┐            │
│  │ Frontend  │   │ Backend  │   │  PostgreSQL   │            │
│  │          │   │ /metrics │   │ pg_exporter   │            │
│  └────┬─────┘   └──┬───┬───┘   └──────┬───────┘            │
│       │logs        │met │traces       │logs                  │
└───────┼────────────┼───┼──────────────┼──────────────────────┘
        │            │   │              │
        ▼            ▼   ▼              ▼
  ┌──────────┐ ┌──────────┐ ┌─────────┐ ┌──────────┐
  │Fluent Bit│ │Prometheus │ │ Jaeger  │ │Fluent Bit│
  │(DaemonSet)│ │          │ │Collector│ │(DaemonSet)│
  └────┬─────┘ └────┬─────┘ └────┬────┘ └────┬─────┘
       │             │            │            │
       ▼             ▼            ▼            ▼
  ┌──────────┐ ┌──────────┐ ┌─────────┐ ┌──────────┐
  │   Loki   │ │ Grafana  │◄│ Jaeger  │ │   Loki   │
  │          │─▶│Dashboards│ │ Query   │ │          │
  └──────────┘ └────┬─────┘ └─────────┘ └──────────┘
                    │
              ┌─────▼──────┐
              │Alertmanager│──▶ Slack / PagerDuty
              └────────────┘
```

## 📁 Structure

```
task3/
├── prometheus/
│   ├── values.yaml            # kube-prometheus-stack Helm values
│   └── alert-rules.yaml       # Custom PrometheusRule CRD (12 alert rules)
├── grafana/
│   └── dashboards.yaml        # Dashboard ConfigMap (9 panels)
├── loki/
│   └── values.yaml            # Loki + Fluent Bit Helm values
├── jaeger/
│   └── values.yaml            # Jaeger all-in-one Helm values
├── alerting/
│   └── slo-sli-definitions.md # SLI/SLO definitions with PromQL
├── setup-monitoring.sh        # One-command setup script
└── README.md
```

## 🚀 Setup

### Option A: CLI
```bash
cd task3/
chmod +x setup-monitoring.sh
./setup-monitoring.sh
```

### Option B: Azure Portal
1. AKS Cluster → **Monitoring** → **Insights** → Enable Container Insights
2. AKS Cluster → **Monitoring** → Enable **Managed Prometheus**
3. Create **Azure Managed Grafana** → Link AKS Prometheus data source

### Access UIs
```bash
# Grafana (admin / DodoGrafana2026!)
kubectl port-forward svc/monitoring-grafana -n monitoring 3000:80

# Prometheus
kubectl port-forward svc/monitoring-kube-prometheus-prometheus -n monitoring 9090:9090

# Jaeger
kubectl port-forward svc/jaeger-query -n monitoring 16686:16686
```

## ✅ Features

| Feature | Status | Details |
|---------|--------|---------|
| Prometheus metrics | ✅ | Auto-discovery via pod annotations |
| Custom app metrics | ✅ | http_requests_total, http_request_duration_seconds, transactions_total |
| Grafana dashboards | ✅ | 9 panels: request rate, errors, latency, CPU, memory, HPA, PVC |
| Centralized logging | ✅ | Loki + Fluent Bit with K8s metadata enrichment |
| Distributed tracing | ✅ | Jaeger all-in-one with OpenTelemetry |
| Alert rules | ✅ | 12 rules across 3 groups (app, k8s, infra) |
| Alertmanager | ✅ | Slack integration, severity-based routing |
| SLIs/SLOs | ✅ | Availability, latency, throughput with error budgets |
| **Slack integration** (Bonus) | ✅ | Critical alerts routed to #dodo-alerts |
| **Runbooks** (Bonus) | ✅ | Alert annotations include kubectl commands |
